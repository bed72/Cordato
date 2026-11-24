import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/settings/application/exceptions/export_exception.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/export_bloc.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/export_event.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/export_state.dart';

import '../../../../../../support/settings/mocks/export_repository_mock.dart';

void main() {
  const attachment = '/private/export.csv';
  const request = ExportRequestedEvent();
  const errors = ErrorsEntity(
    errors: [ErrorEntity(code: 'busy', pointer: '/expenses', parameter: 'id')],
  );
  late ExportRepositoryMock repository;

  setUp(() {
    repository = ExportRepositoryMock();
    when(repository.prepare).thenAnswer((_) async => attachment);
    when(() => repository.share(path: attachment)).thenAnswer((_) async {});
    when(() => repository.discard(path: attachment)).thenAnswer((_) async {});
  });

  group('Export states and delegation', () {
    test('starts idle without reading storage', () async {
      final bloc = ExportBloc(repository: repository);
      addTearDown(bloc.close);

      expect(bloc.state, isA<ExportInitial>());
      expect(bloc.state.isBusy, isFalse);
      verifyNever(repository.prepare);
    });

    blocTest<ExportBloc, ExportState>(
      'prepares then shares exactly once without claiming durable delivery',
      build: () => ExportBloc(repository: repository),
      act: (bloc) => bloc.add(request),
      expect: () => [
        isA<ExportPreparing>().having((state) => state.isBusy, 'busy', isTrue),
        isA<ExportSharing>().having((state) => state.isBusy, 'busy', isTrue),
        isA<ExportCompleted>().having((state) => state.isBusy, 'busy', isFalse),
      ],
      verify: (_) {
        verify(repository.prepare).called(1);
        verify(() => repository.share(path: attachment)).called(1);
        verifyNever(() => repository.discard(path: attachment));
      },
    );

    blocTest<ExportBloc, ExportState>(
      'empty history does not open sharing',
      build: () {
        when(repository.prepare).thenAnswer((_) async => null);
        return ExportBloc(repository: repository);
      },
      act: (bloc) => bloc.add(request),
      expect: () => [isA<ExportPreparing>(), isA<ExportEmpty>()],
      verify: (_) {
        verifyNever(() => repository.share(path: attachment));
      },
    );

    blocTest<ExportBloc, ExportState>(
      'expected preparation error retains original metadata',
      build: () {
        when(repository.prepare)
            .thenThrow(const ExportException(errors: errors));
        return ExportBloc(repository: repository);
      },
      act: (bloc) => bloc.add(request),
      expect: () => [
        isA<ExportPreparing>(),
        isA<ExportFailure>().having(
          (state) => state.errors,
          'errors',
          same(errors),
        ),
      ],
    );

    blocTest<ExportBloc, ExportState>(
      'sharing error retains original metadata and permits manual retry',
      build: () {
        when(() => repository.share(path: attachment))
            .thenThrow(const ExportException(errors: errors));
        return ExportBloc(repository: repository);
      },
      act: (bloc) => bloc.add(request),
      expect: () => [
        isA<ExportPreparing>(),
        isA<ExportSharing>(),
        isA<ExportFailure>().having(
          (state) => state.errors,
          'errors',
          same(errors),
        ),
      ],
    );

    final unexpected = StateError('unexpected');
    blocTest<ExportBloc, ExportState>(
      'unexpected errors remain observable and have safe UI fallback',
      build: () {
        when(repository.prepare).thenThrow(unexpected);
        return ExportBloc(repository: repository);
      },
      act: (bloc) => bloc.add(request),
      expect: () => [isA<ExportPreparing>(), isA<ExportFailure>()],
      errors: () => [same(unexpected)],
    );
  });

  group('Concurrency and lifecycle', () {
    test(
      'drops duplicates during preparation and sharing, allows new export',
      () async {
        final preparing = Completer<String?>();
        final sharing = Completer<void>();
        when(repository.prepare).thenAnswer((_) => preparing.future);
        when(() => repository.share(path: attachment))
            .thenAnswer((_) => sharing.future);
        final bloc = ExportBloc(repository: repository);
        addTearDown(bloc.close);
        final prepared = bloc.stream.firstWhere(
          (state) => state is ExportPreparing,
        );
        bloc.add(request);
        await prepared;
        bloc.add(request);
        final shared = bloc.stream.firstWhere(
          (state) => state is ExportSharing,
        );
        preparing.complete(attachment);
        await shared;
        bloc.add(request);
        final completed = bloc.stream.firstWhere(
          (state) => state is ExportCompleted,
        );
        sharing.complete();
        await completed;

        verify(repository.prepare).called(1);
        verify(() => repository.share(path: attachment)).called(1);

        final again = bloc.stream.firstWhere(
          (state) => state is ExportCompleted,
        );
        bloc.add(request);
        await again;
        verify(repository.prepare).called(1);
      },
    );

    test('manual retry after failure performs a fresh preparation', () async {
      when(repository.prepare).thenThrow(const ExportException(errors: errors));
      final bloc = ExportBloc(repository: repository);
      addTearDown(bloc.close);
      final failed = bloc.stream.firstWhere((state) => state is ExportFailure);
      bloc.add(request);
      await failed;
      when(repository.prepare).thenAnswer((_) async => attachment);
      final completed = bloc.stream.firstWhere(
        (state) => state is ExportCompleted,
      );

      bloc.add(request);
      await completed;

      verify(repository.prepare).called(2);
    });

    test(
      'closure during preparation discards the file without late sharing',
      () async {
        final pending = Completer<String?>();
        final discarded = Completer<void>();
        when(repository.prepare).thenAnswer((_) => pending.future);
        when(() => repository.discard(path: attachment)).thenAnswer((_) async {
          discarded.complete();
        });
        final bloc = ExportBloc(repository: repository);
        final preparing = bloc.stream.firstWhere(
          (state) => state is ExportPreparing,
        );
        bloc.add(request);
        await preparing;

        await bloc.close();
        pending.complete(attachment);
        await discarded.future;

        verifyNever(() => repository.share(path: attachment));
        expect(bloc.state, isA<ExportPreparing>());
      },
    );

    test('closure does not cancel an already dispatched share', () async {
      final pending = Completer<void>();
      final finished = Completer<void>();
      when(() => repository.share(path: attachment)).thenAnswer((_) async {
        await pending.future;
        finished.complete();
      });
      final bloc = ExportBloc(repository: repository);
      final sharing = bloc.stream.firstWhere((state) => state is ExportSharing);
      bloc.add(request);
      await sharing;

      await bloc.close();
      pending.complete();
      await finished.future;

      expect(bloc.state, isA<ExportSharing>());
      verifyNever(() => repository.discard(path: attachment));
    });
  });
}
