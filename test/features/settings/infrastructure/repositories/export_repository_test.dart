import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/application/exceptions/file_share_exception.dart';
import 'package:cordato/features/core/application/exceptions/missing_authenticated_user_exception.dart';
import 'package:cordato/features/core/application/models/file_share_outcome.dart';
import 'package:cordato/features/core/application/models/share_attachment.dart';
import 'package:cordato/features/core/application/models/share_origin.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';
import 'package:cordato/features/expense/application/models/document_model.dart';
import 'package:cordato/features/settings/application/exceptions/export_exception.dart';
import 'package:cordato/features/settings/application/models/prepared_export_model.dart';
import 'package:cordato/features/settings/infrastructure/repositories/export_repository.dart';

import '../../../../support/core/mocks/file_share_client_mock.dart';
import '../../../../support/expense/mocks/export_repository_mock.dart';

void main() {
  setUpAll(() => registerFallbackValue(Uint8List(0)));
  const attachment = ShareAttachment(
    id: 'attachment-test',
    fileName: 'expenses.csv',
  );
  const export = PreparedExportModel(ownerId: 'owner', attachment: attachment);
  const origin = ShareOrigin(x: 1, y: 2, width: 30, height: 40);
  const errors = ErrorsEntity(
    errors: [
      ErrorEntity(
        status: '403',
        code: 'denied',
        pointer: '/owner',
        parameter: 'owner',
      ),
    ],
  );
  late ExportRepositoryMock expenses;
  late FileShareClientMock files;
  late ExportRepository repository;
  late DocumentModel document;

  setUp(() {
    expenses = ExportRepositoryMock();
    files = FileShareClientMock();
    repository = ExportRepository(
      expenseRepository: expenses,
      fileShareClient: files,
    );
    document = DocumentModel(
      ownerId: 'owner',
      bytes: Uint8List.fromList([1, 2, 3]),
    );
    when(files.cleanExpired).thenAnswer((_) async {});
    when(() => files.discard(attachment)).thenAnswer((_) async {});
    when(expenses.prepare).thenAnswer((_) async => document);
    when(
      () => files.prepare(
        bytes: any(named: 'bytes'),
        fileName: any(named: 'fileName'),
      ),
    ).thenAnswer((_) async => attachment);
  });

  group('Preparation', () {
    test(
      'cleans stale files and prepares the complete document without sharing',
      () async {
        final prepared = (await repository.prepare())!;

        expect(prepared.ownerId, 'owner');
        expect(prepared.attachment, same(attachment));
        final arguments = verify(
          () => files.prepare(
            bytes: captureAny(named: 'bytes'),
            fileName: captureAny(named: 'fileName'),
          ),
        ).captured;
        expect(arguments[0], document.bytes);
        expect(
          arguments[1],
          matches(r'^cordato-despesas-\d{4}-\d{2}-\d{2}\.csv$'),
        );
        verifyInOrder([
          files.cleanExpired,
          expenses.prepare,
          () => expenses.validateOwner('owner'),
          () => expenses.validateOwner('owner'),
        ]);
        verifyNoMoreInteractions(files);
      },
    );

    test('does not create a file for empty history', () async {
      when(expenses.prepare).thenAnswer((_) async => null);
      expect(await repository.prepare(), isNull);
      verify(files.cleanExpired).called(1);
      verifyNoMoreInteractions(files);
    });

    test('does not create or share partial history on failure', () async {
      when(expenses.prepare).thenThrow(ExpenseException(errors: errors));
      await expectLater(
        repository.prepare(),
        throwsA(
          isA<ExportException>().having(
            (error) => error.errors,
            'errors',
            same(errors),
          ),
        ),
      );
      verify(files.cleanExpired).called(1);
      verifyNoMoreInteractions(files);
    });

    test(
      'discards the prepared attachment if the owner changes during file IO',
      () async {
        final pendingFile = Completer<ShareAttachment>();
        final started = Completer<void>();
        when(
          () => files.prepare(
            bytes: any(named: 'bytes'),
            fileName: any(named: 'fileName'),
          ),
        ).thenAnswer((_) {
          started.complete();
          return pendingFile.future;
        });
        final pending = repository.prepare();
        final assertion = expectLater(
          pending,
          throwsA(
            isA<ExportException>().having(
              (error) => error.errors,
              'errors',
              same(errors),
            ),
          ),
        );
        await started.future;
        when(() => expenses.validateOwner('owner'))
            .thenThrow(ExpenseException(errors: errors));
        pendingFile.complete(attachment);
        await assertion;
        verify(() => files.discard(attachment)).called(1);
      },
    );

    test('maps absent identity without exposing SDK types', () async {
      const missing = MissingAuthenticatedUserException();
      when(expenses.prepare).thenThrow(missing);
      await expectLater(
        repository.prepare(),
        throwsA(
          isA<ExportException>().having(
            (error) => error.errors,
            'errors',
            same(missing.errors),
          ),
        ),
      );
    });

    test('preserves file failure metadata', () async {
      when(
        () => files.prepare(
          bytes: any(named: 'bytes'),
          fileName: any(named: 'fileName'),
        ),
      ).thenThrow(const FileShareException(errors: errors));
      await expectLater(
        repository.prepare(),
        throwsA(
          isA<ExportException>().having(
            (error) => error.errors,
            'errors',
            same(errors),
          ),
        ),
      );
    });

    test('does not disguise unexpected parsing errors', () async {
      final failure = FormatException('invalid data');
      when(expenses.prepare).thenThrow(failure);
      await expectLater(repository.prepare(), throwsA(same(failure)));
    });
  });

  group('Sharing and discard', () {
    for (final outcome in FileShareOutcome.values) {
      test(
        'passes anchor and MIME and returns ${outcome.name} without claiming delivery',
        () async {
          when(
            () => files.share(
              attachment: attachment,
              mimeType: 'text/csv',
              origin: origin,
            ),
          ).thenAnswer((_) async => outcome);
          expect(
            await repository.share(export: export, origin: origin),
            outcome,
          );
          verifyInOrder([
            () => expenses.validateOwner('owner'),
            () => files.share(
              attachment: attachment,
              mimeType: 'text/csv',
              origin: origin,
            ),
            () => files.discard(attachment),
          ]);
        },
      );
    }

    test('owner change before sharing prevents a native request and discards the file', () async {
      when(() => expenses.validateOwner('owner'))
          .thenThrow(ExpenseException(errors: errors));
      await expectLater(
        repository.share(export: export),
        throwsA(
          isA<ExportException>().having(
            (error) => error.errors,
            'errors',
            same(errors),
          ),
        ),
      );
      verify(() => files.discard(attachment)).called(1);
      verifyNoMoreInteractions(files);
    });

    test(
      'maps native failure and releases through the client retention policy',
      () async {
        when(() => files.share(attachment: attachment, mimeType: 'text/csv'))
            .thenThrow(const FileShareException(errors: errors));
        await expectLater(
          repository.share(export: export),
          throwsA(
            isA<ExportException>().having(
              (error) => error.errors,
              'errors',
              same(errors),
            ),
          ),
        );
        verify(() => files.discard(attachment)).called(1);
      },
    );

    test(
      'delegates explicit abandonment and preserves cleanup failure metadata',
      () async {
        when(() => files.discard(attachment))
            .thenThrow(const FileShareException(errors: errors));
        await expectLater(
          repository.discard(export),
          throwsA(
            isA<ExportException>().having(
              (error) => error.errors,
              'errors',
              same(errors),
            ),
          ),
        );
      },
    );
  });
}
