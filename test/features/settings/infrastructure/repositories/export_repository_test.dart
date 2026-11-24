import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/infrastructure/clients/share/share_client_exception.dart';
import 'package:cordato/features/expense/application/exceptions/expense_exception.dart';
import 'package:cordato/features/settings/application/exceptions/export_exception.dart';
import 'package:cordato/features/settings/infrastructure/repositories/export_repository.dart';

import '../../../../support/core/mocks/share_client_mock.dart';
import '../../../../support/expense/mocks/expense_export_repository_mock.dart';

void main() {
  const attachment = '/private/export.csv';
  late ShareClientMock client;
  late ExpenseExportRepositoryMock expenses;
  late ExportRepository repository;

  setUpAll(() {
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(attachment);
  });

  setUp(() {
    client = ShareClientMock();
    expenses = ExpenseExportRepositoryMock();
    repository = ExportRepository(shareClient: client, repository: expenses);
  });

  test('empty history does not create or share files', () async {
    when(expenses.prepare).thenAnswer((_) async => null);

    expect(await repository.prepare(), isNull);
    verifyNever(
      () => client.prepare(
        bytes: any(named: 'bytes'),
        fileName: any(named: 'fileName'),
      ),
    );
  });

  test('prepares exact bytes with a date-only nonpersonal filename', () async {
    final bytes = Uint8List.fromList([1, 2, 3]);
    when(expenses.prepare).thenAnswer((_) async => bytes);
    when(
      () => client.prepare(
        bytes: any(named: 'bytes'),
        fileName: any(named: 'fileName'),
      ),
    ).thenAnswer((_) async => attachment);

    expect(await repository.prepare(), same(attachment));
    final captured = verify(
      () => client.prepare(
        bytes: captureAny(named: 'bytes'),
        fileName: captureAny(named: 'fileName'),
      ),
    ).captured;
    expect(captured[0], same(bytes));
    expect(captured[1], matches(r'^cordato-despesas-\d{4}-\d{2}-\d{2}\.csv$'));
  });

  test('shares with CSV MIME and leaves retention to the client', () async {
    when(() => client.share(path: attachment, mimeType: 'text/csv'))
        .thenAnswer((_) async {});

    await repository.share(path: attachment);

    verify(() => client.share(path: attachment, mimeType: 'text/csv'))
        .called(1);
    verifyNever(() => client.discard(path: any(named: 'path')));
  });

  test('discards abandoned attachments through the client', () async {
    when(() => client.discard(path: attachment)).thenAnswer((_) async {});

    await repository.discard(path: attachment);

    verify(() => client.discard(path: attachment)).called(1);
  });

  test('preserves Expense ErrorsEntity with all metadata', () async {
    const errors = ErrorsEntity(
      errors: [
        ErrorEntity(
          code: 'storage_busy',
          pointer: '/expenses',
          parameter: 'id',
        ),
        ErrorEntity(code: 'second'),
      ],
    );
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
  });

  test('translates technical sharing errors into application errors', () async {
    when(() => client.share(path: attachment, mimeType: 'text/csv'))
        .thenThrow(const ShareClientException(code: 'export_share_failed'));

    await expectLater(
      repository.share(path: attachment),
      throwsA(
        isA<ExportException>().having(
          (error) => error.errors.errors.single.code,
          'code',
          'export_share_failed',
        ),
      ),
    );
  });

  test('does not swallow unexpected causes or stacks', () async {
    final failure = StateError('unexpected');
    final stack = StackTrace.current;
    when(expenses.prepare)
        .thenAnswer((_) async => Error.throwWithStackTrace(failure, stack));

    try {
      await repository.prepare();
      fail('Expected unexpected error');
    } catch (error, caughtStack) {
      expect(error, same(failure));
      expect(caughtStack.toString(), stack.toString());
    }
  });
}
