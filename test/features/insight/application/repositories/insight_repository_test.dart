import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/insight/application/repositories/insight_repository.dart';
import 'package:cordato/features/insight/domain/repositories/interface_insight_repository.dart';
import 'package:cordato/features/insight/infrastructure/responses/insight_date_range_response.dart';
import 'package:cordato/features/insight/infrastructure/responses/insight_period_response.dart';
import 'package:cordato/features/insight/infrastructure/responses/insight_response.dart';

import '../../../../support/insight/mocks/insight_remote_data_source_mock.dart';

void main() {
  late IInsightRepository repository;
  late InsightRemoteDataSourceMock dataSource;

  setUp(() {
    dataSource = InsightRemoteDataSourceMock();
    repository = InsightRepository(remoteDataSource: dataSource);
  });

  group('InsightRepository', () {
    test('converts all insights preserving remote content and order', () async {
      final from = DateTime(2026, 10, 1);
      final to = DateTime(2026, 10, 8);
      final comparisonFrom = DateTime(2026, 9, 1);
      final comparisonTo = DateTime(2026, 9, 8);
      final insights = [
        InsightResponse(
          id: 'z',
          title: 'Mais valor registrado',
          type: 'registered_amount_increase',
          group: 'comparison',
          description: 'De 1 a 8, você registrou 35% mais valor que nos mesmos dias do mês passado.',
          period: InsightPeriodResponse(
            from: from,
            to: to,
            comparison: InsightDateRangeResponse(
              from: comparisonFrom,
              to: comparisonTo,
            ),
          ),
        ),
        InsightResponse(
          id: 'a',
          title: 'Uma liderança recorrente',
          type: 'category_lead_streak',
          group: 'comparison',
          description: 'Moradia segue líder nos registros deste mês.',
          period: InsightPeriodResponse(
            from: DateTime(2026, 8, 1),
            to: DateTime(2026, 10, 9),
          ),
        ),
      ];
      when(() => dataSource.get()).thenAnswer((_) async => Right(insights));

      final result = await repository.get();

      expect(result.isRight, isTrue);
      expect(result.right.map((insight) => insight.id), ['z', 'a']);
      for (var index = 0; index < insights.length; index++) {
        final source = insights[index];
        final entity = result.right[index];
        expect(entity.title, source.title);
        expect(entity.description, source.description);
        expect(entity.type, source.type);
        expect(entity.group, source.group);
        expect(entity.period.from, same(source.period.from));
        expect(entity.period.to, same(source.period.to));
      }
      expect(result.right.first.period.comparison?.from, same(comparisonFrom));
      expect(result.right.first.period.comparison?.to, same(comparisonTo));
      expect(result.right.last.period.comparison, isNull);
      verify(() => dataSource.get()).called(1);
      verifyNoMoreInteractions(dataSource);
    });

    test(
      'preserves unknown types, groups and UTC dates without defaults',
      () async {
        final from = DateTime.utc(2026, 10, 1);
        final to = DateTime.utc(2026, 10, 9);
        when(() => dataSource.get()).thenAnswer(
          (_) async => Right([
            InsightResponse(
              id: 'future',
              title: ' Novo insight ',
              type: 'future_type',
              group: 'future_group',
              description: ' Descrição original ',
              period: InsightPeriodResponse(from: from, to: to),
            ),
          ]),
        );

        final insight = (await repository.get()).right.single;

        expect(insight.type, 'future_type');
        expect(insight.group, 'future_group');
        expect(insight.title, ' Novo insight ');
        expect(insight.description, ' Descrição original ');
        expect(insight.period.from, same(from));
        expect(insight.period.to, same(to));
        expect(insight.period.comparison, isNull);
      },
    );

    test('returns success for an empty list', () async {
      when(() => dataSource.get()).thenAnswer((_) async => const Right([]));

      final result = await repository.get();

      expect(result.isRight, isTrue);
      expect(result.right, isEmpty);
      verify(() => dataSource.get()).called(1);
    });

    test('preserves every remote error and its metadata', () async {
      const errors = ErrorsResponse(
        errors: [
          ErrorResponse(
            title: 'Consulta indisponível',
            detail: 'Não foi possível consultar os insights.',
            status: '503',
            pointer: '/data',
          ),
          ErrorResponse(detail: 'Tente novamente mais tarde.'),
        ],
      );
      when(() => dataSource.get()).thenAnswer((_) async => const Left(errors));

      final result = await repository.get();

      expect(result.isLeft, isTrue);
      expect(result.left.errors, hasLength(2));
      for (var index = 0; index < errors.errors.length; index++) {
        final source = errors.errors[index];
        final entity = result.left.errors[index];
        expect(entity.title, source.title);
        expect(entity.detail, source.detail);
        expect(entity.status, source.status);
        expect(entity.pointer, source.pointer);
      }
      verify(() => dataSource.get()).called(1);
    });

    test(
      'translates an empty remote error list into an unknown error',
      () async {
        when(() => dataSource.get())
            .thenAnswer((_) async => const Left(ErrorsResponse(errors: [])));

        final result = await repository.get();
        final error = result.left.errors.single;
        final unknown = ErrorsEntity.unknown().errors.single;

        expect(error.title, unknown.title);
        expect(error.detail, unknown.detail);
      },
    );

    test(
      'translates asynchronous data source exceptions into domain errors',
      () async {
        when(() => dataSource.get())
            .thenAnswer((_) async => throw StateError('offline'));

        final result = await repository.get();
        final error = result.left.errors.single;
        final unknown = ErrorsEntity.unknown().errors.single;

        expect(error.title, unknown.title);
        expect(error.detail, unknown.detail);
        verify(() => dataSource.get()).called(1);
      },
    );

    test(
      'translates synchronous data source exceptions into domain errors',
      () async {
        when(() => dataSource.get())
            .thenThrow(StateError('unexpected failure'));

        final result = await repository.get();

        expect(result.isLeft, isTrue);
        expect(result.left.errors.single.title, 'Erro desconhecido');
        verify(() => dataSource.get()).called(1);
      },
    );
  });
}
