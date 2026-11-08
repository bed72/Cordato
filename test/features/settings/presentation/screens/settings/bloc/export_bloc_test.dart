import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/application/enums/share_outcome_enum.dart';
import 'package:cordato/features/core/application/models/share_origin_model.dart';
import 'package:cordato/features/core/application/models/share_attachment_model.dart';

import 'package:cordato/features/settings/application/exceptions/export_exception.dart';
import 'package:cordato/features/settings/application/models/prepared_export_model.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/export_bloc.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/export_event.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/export_state.dart';

import '../../../../../../support/settings/mocks/export_repository_mock.dart';

void main() {
  const export = PreparedExportModel(
    ownerId: 'owner',
    attachment: ShareAttachmentModel(
      id: 'attachment-test',
      fileName: 'expenses.csv',
    ),
  );
  const errors = ErrorsEntity(
    errors: [
      ErrorEntity(
        status: '403',
        pointer: '/owner',
        code: 'private',
        parameter: 'owner',
      ),
    ],
  );
  const origin = ShareOriginModel(x: 1, y: 2, width: 30, height: 40);
  late ExportRepositoryMock repository;

  setUp(() {
    repository = ExportRepositoryMock();
    when(repository.prepare).thenAnswer((_) async => export);
    when(() => repository.discard(export)).thenAnswer((_) async {});
    when(() => repository.share(export: export, origin: origin))
        .thenAnswer((_) async => ShareOutcomeEnum.completed);
  });

  Future<void> prepare(ExportBloc bloc) async {
    final ready = bloc.stream.firstWhere((state) => state is ExportReady);
    bloc.add(const ExportRequested());
    await ready;
  }

  group('Lifecycle and preparation', () {
    test('starts idle and does not perform IO automatically', () async {
      final bloc = ExportBloc(repository: repository);
      addTearDown(bloc.close);
      expect(bloc.state, isA<ExportInitial>());
      expect(bloc.state.canSubmit, isTrue);
      verifyZeroInteractions(repository);
    });

    blocTest<ExportBloc, ExportState>(
      'prepares but never shares automatically without presentation dispatch',
      build: () => ExportBloc(repository: repository),
      act: prepare,
      expect: () => [
        isA<ExportPreparing>().having(
          (state) => state.canSubmit,
          'canSubmit',
          false,
        ),
        isA<ExportReady>().having(
          (state) => state.export,
          'export',
          same(export),
        ),
      ],
      verify: (_) {
        verify(repository.prepare).called(1);
        verify(() => repository.discard(export)).called(1);
        verifyNoMoreInteractions(repository);
      },
    );

    blocTest<ExportBloc, ExportState>(
      'empty history permits a new manual attempt',
      setUp: () => when(repository.prepare).thenAnswer((_) async => null),
      build: () => ExportBloc(repository: repository),
      act: (bloc) => bloc.add(const ExportRequested()),
      expect: () => [
        isA<ExportPreparing>(),
        isA<ExportEmpty>().having(
          (state) => state.canSubmit,
          'canSubmit',
          true,
        ),
      ],
      verify: (_) {
        verify(repository.prepare).called(1);
        verifyNoMoreInteractions(repository);
      },
    );

    test(
      'discards late preparation after closure without emitting or sharing',
      () async {
        final document = Completer<PreparedExportModel?>();
        final started = Completer<void>();
        final discarded = Completer<void>();
        when(repository.prepare).thenAnswer((_) {
          started.complete();
          return document.future;
        });
        when(() => repository.discard(export)).thenAnswer((_) async {
          discarded.complete();
        });
        final bloc = ExportBloc(repository: repository);
        final states = <ExportState>[];
        final subscription = bloc.stream.listen(states.add);
        bloc.add(const ExportRequested());
        await started.future;
        final closed = bloc.close();
        document.complete(export);
        await closed;
        await discarded.future;
        await subscription.cancel();
        expect(states, [isA<ExportPreparing>()]);
        verify(repository.prepare).called(1);
        verify(() => repository.discard(export)).called(1);
        verifyNoMoreInteractions(repository);
      },
    );

    test(
      'closing with a ready file discards it through native Bloc lifecycle',
      () async {
        final discarded = Completer<void>();
        when(() => repository.discard(export)).thenAnswer((_) async {
          discarded.complete();
        });
        final bloc = ExportBloc(repository: repository);
        await prepare(bloc);
        await bloc.close();
        await discarded.future;
        verify(() => repository.discard(export)).called(1);
      },
    );

    blocTest<ExportBloc, ExportState>(
      'abandons a ready file when the route is no longer current',
      build: () => ExportBloc(repository: repository),
      act: (bloc) async {
        await prepare(bloc);
        final abandoned = bloc.stream.firstWhere(
          (state) => state is ExportInitial,
        );
        bloc.add(const ExportAbandoned());
        await abandoned;
      },
      expect: () => [
        isA<ExportPreparing>(),
        isA<ExportReady>(),
        isA<ExportPreparing>(),
        isA<ExportInitial>(),
      ],
      verify: (_) {
        verify(repository.prepare).called(1);
        verify(() => repository.discard(export)).called(1);
        verifyNoMoreInteractions(repository);
      },
    );
  });

  group('Sharing and concurrency', () {
    for (final outcome in ShareOutcomeEnum.values) {
      blocTest<ExportBloc, ExportState>(
        '${outcome.name} finishes and allows another export',
        setUp: () =>
            when(() => repository.share(export: export, origin: origin))
                .thenAnswer((_) async => outcome),
        build: () => ExportBloc(repository: repository),
        act: (bloc) async {
          await prepare(bloc);
          bloc.add(const ExportShareRequested(origin: origin));
        },
        expect: () => [
          isA<ExportPreparing>(),
          isA<ExportReady>(),
          isA<ExportSharing>(),
          isA<ExportCompleted>().having(
            (state) => state.canSubmit,
            'canSubmit',
            true,
          ),
        ],
        verify: (_) =>
            verify(() => repository.share(export: export, origin: origin))
                .called(1),
      );
    }

    test(
      'drops repeated prepare/share events during pending operations',
      () async {
        final document = Completer<PreparedExportModel?>();
        final preparing = Completer<void>();
        final sharing = Completer<void>();
        final shared = Completer<ShareOutcomeEnum>();
        when(repository.prepare).thenAnswer((_) {
          preparing.complete();
          return document.future;
        });
        when(() => repository.share(export: export, origin: origin))
            .thenAnswer((_) {
              sharing.complete();
              return shared.future;
            });
        final bloc = ExportBloc(repository: repository);
        addTearDown(bloc.close);
        final ready = bloc.stream.firstWhere((state) => state is ExportReady);
        bloc.add(const ExportRequested());
        await preparing.future;
        bloc.add(const ExportRequested());
        bloc.add(const ExportShareRequested(origin: origin));
        document.complete(export);
        await ready;
        bloc.add(const ExportRequested());
        bloc.add(const ExportShareRequested(origin: origin));
        await sharing.future;
        bloc.add(const ExportShareRequested(origin: origin));
        bloc.add(const ExportRequested());
        final completed = bloc.stream.firstWhere(
          (state) => state is ExportCompleted,
        );
        shared.complete(ShareOutcomeEnum.completed);
        await completed;
        verify(repository.prepare).called(1);
        verify(() => repository.share(export: export, origin: origin))
            .called(1);
      },
    );

    test('can prepare and share a second time after completion', () async {
      final bloc = ExportBloc(repository: repository);
      addTearDown(bloc.close);
      for (int attempt = 0; attempt < 2; attempt++) {
        await prepare(bloc);
        final completed = bloc.stream.firstWhere(
          (state) => state is ExportCompleted,
        );
        bloc.add(const ExportShareRequested(origin: origin));
        await completed;
      }
      verify(repository.prepare).called(2);
      verify(() => repository.share(export: export, origin: origin)).called(2);
    });

    test(
      'close while sharing does not emit completion or start another operation',
      () async {
        final shared = Completer<ShareOutcomeEnum>();
        final started = Completer<void>();
        when(() => repository.share(export: export, origin: origin))
            .thenAnswer((_) {
              started.complete();
              return shared.future;
            });
        final bloc = ExportBloc(repository: repository);
        await prepare(bloc);
        bloc.add(const ExportShareRequested(origin: origin));
        await started.future;
        final closed = bloc.close();
        shared.complete(ShareOutcomeEnum.completed);
        await closed;
        expect(bloc.state, isA<ExportSharing>());
        verify(() => repository.share(export: export, origin: origin))
            .called(1);
      },
    );
  });

  group('Failures and retry', () {
    blocTest<ExportBloc, ExportState>(
      'preserves expected errors without telemetry',
      setUp: () =>
          when(repository.prepare)
              .thenThrow(const ExportException(errors: errors)),
      build: () => ExportBloc(repository: repository),
      act: (bloc) => bloc.add(const ExportRequested()),
      expect: () => [
        isA<ExportPreparing>(),
        isA<ExportFailure>().having(
          (state) => state.errors,
          'errors',
          same(errors),
        ),
      ],
      errors: () => isEmpty,
    );

    final unexpected = FormatException('private invalid response');
    blocTest<ExportBloc, ExportState>(
      'reports unexpected parsing errors and exposes only fallback',
      setUp: () => when(repository.prepare).thenThrow(unexpected),
      build: () => ExportBloc(repository: repository),
      act: (bloc) => bloc.add(const ExportRequested()),
      expect: () => [
        isA<ExportPreparing>(),
        isA<ExportFailure>().having(
          (state) => state.errors.errors.single.detail,
          'safe detail',
          'Não foi possível processar a resposta.',
        ),
      ],
      errors: () => [same(unexpected)],
    );

    blocTest<ExportBloc, ExportState>(
      'native sharing failure preserves errors and allows retry from preparation',
      setUp: () =>
          when(() => repository.share(export: export, origin: origin))
              .thenThrow(const ExportException(errors: errors)),
      build: () => ExportBloc(repository: repository),
      act: (bloc) async {
        await prepare(bloc);
        bloc.add(const ExportShareRequested(origin: origin));
      },
      expect: () => [
        isA<ExportPreparing>(),
        isA<ExportReady>(),
        isA<ExportSharing>(),
        isA<ExportFailure>()
            .having((state) => state.errors, 'errors', same(errors))
            .having((state) => state.canSubmit, 'canSubmit', true),
      ],
      errors: () => isEmpty,
    );

    test(
      'retries a failed preparation only after another manual request',
      () async {
        when(repository.prepare)
            .thenThrow(const ExportException(errors: errors));
        final bloc = ExportBloc(repository: repository);
        addTearDown(bloc.close);
        final failed = bloc.stream.firstWhere(
          (state) => state is ExportFailure,
        );
        bloc.add(const ExportRequested());
        await failed;
        verify(repository.prepare).called(1);
        when(repository.prepare).thenAnswer((_) async => null);
        final empty = bloc.stream.firstWhere((state) => state is ExportEmpty);
        bloc.add(const ExportRequested());
        await empty;
        verify(repository.prepare).called(1);
      },
    );
  });
}
