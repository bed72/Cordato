import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';

import 'package:cordato/features/metrics/application/repositories/metrics_repository.dart';
import 'package:cordato/features/metrics/domain/repositories/interface_metrics_repository.dart';
import 'package:cordato/features/metrics/infrastructure/responses/expense_metrics_response.dart';
import 'package:cordato/features/metrics/infrastructure/responses/expense_category_metrics_response.dart';

import '../../../../support/metrics/mocks/metrics_remote_data_source_mock.dart';

void main() {
  late IMetricsRepository repository;
  late MetricsRemoteDataSourceMock dataSource;

  setUp(() {
    dataSource = MetricsRemoteDataSourceMock();
    repository = MetricsRepository(remoteDataSource: dataSource);
  });

  group('MetricsRepository', () {
    test(
      'leaves the default period and grouping to the remote service',
      () async {
        final response = ExpenseMetricsResponse(
          id: 'default-period',
          totalAmount: 389205,
          endDate: DateTime(2026, 10, 31),
          startDate: DateTime(2026, 10, 1),
        );
        when(() => dataSource.getExpenses())
            .thenAnswer((_) async => Right(response));

        final data = await repository.getExpenses();

        expect(data.right.id, response.id);
        expect(data.right.categories, isNull);
        expect(data.right.totalAmount, 389205);
        expect(data.right.endDate, same(response.endDate));
        expect(data.right.startDate, same(response.startDate));
        verify(() => dataSource.getExpenses()).called(1);
        verifyNoMoreInteractions(dataSource);
      },
    );

    test(
      'delegates filters unchanged and preserves returned metrics',
      () async {
        final endDate = DateTime.utc(2026, 9, 30);
        final startDate = DateTime.utc(2026, 9, 1);
        final response = ExpenseMetricsResponse(
          id: 'remote-id',
          totalAmount: 300,
          startDate: DateTime(2026, 10, 1),
          endDate: DateTime(2026, 10, 31),
          categories: const [
            ExpenseCategoryMetricsResponse(
              totalAmount: 100,
              percentage: 33.33,
              category: 'future_category',
            ),
            ExpenseCategoryMetricsResponse(
              totalAmount: 200,
              percentage: 66.67,
              category: 'housing',
            ),
          ],
        );

        when(
          () => dataSource.getExpenses(
            endDate: endDate,
            groupBy: .category,
            startDate: startDate,
          ),
        ).thenAnswer((_) async => Right(response));

        final data = await repository.getExpenses(
          endDate: endDate,
          groupBy: .category,
          startDate: startDate,
        );

        expect(data.right.id, 'remote-id');
        expect(data.right.totalAmount, 300);
        expect(data.right.endDate, same(response.endDate));
        expect(data.right.startDate, same(response.startDate));
        expect(data.right.categories!.map((category) => category.category), [
          'future_category',
          'housing',
        ]);

        expect(data.right.categories!.last.totalAmount, 200);
        expect(data.right.categories!.first.totalAmount, 100);
        expect(data.right.categories!.last.percentage, 66.67);
        expect(data.right.categories!.first.percentage, 33.33);
        expect(() => data.right.categories!.clear(), throwsUnsupportedError);

        final captured = verify(
          () => dataSource.getExpenses(
            startDate: captureAny(named: 'startDate'),
            endDate: captureAny(named: 'endDate'),
            groupBy: .category,
          ),
        ).captured;

        expect(captured[1], same(endDate));
        expect(captured[0], same(startDate));
        verifyNoMoreInteractions(dataSource);
      },
    );

    test('preserves zero totals and an empty grouping', () async {
      when(() => dataSource.getExpenses(groupBy: .category)).thenAnswer(
        (_) async => Right(
          ExpenseMetricsResponse(
            id: 'empty',
            totalAmount: 0,
            categories: [],
            endDate: DateTime.utc(2026, 10, 31),
            startDate: DateTime.utc(2026, 10, 1),
          ),
        ),
      );

      final data = await repository.getExpenses(groupBy: .category);

      expect(data.right.totalAmount, 0);
      expect(data.right.categories, isEmpty);
      expect(data.right.categories, isNotNull);
      expect(data.right.endDate.isUtc, isTrue);
      expect(data.right.startDate.isUtc, isTrue);
    });

    test(
      'delegates incomplete periods and preserves every remote error',
      () async {
        final endDate = DateTime(2026, 10, 31);
        const errors = ErrorsResponse(
          errors: [
            ErrorResponse(
              status: '422',
              pointer: '/start_date',
              parameter: 'start_date',
              title: 'Parâmetro inválido',
              detail: 'As datas inicial e final devem ser informadas juntas.',
            ),
            ErrorResponse(detail: 'Outro erro retornado pelo serviço.'),
          ],
        );
        when(() => dataSource.getExpenses(endDate: endDate, groupBy: .category))
            .thenAnswer((_) async => const Left(errors));

        final data = await repository.getExpenses(
          endDate: endDate,
          groupBy: .category,
        );

        expect(data.isLeft, isTrue);
        expect(data.left.errors, hasLength(2));

        for (var index = 0; index < errors.errors.length; index++) {
          final source = errors.errors[index];
          final error = data.left.errors[index];

          expect(error.title, source.title);
          expect(error.detail, source.detail);
          expect(error.status, source.status);
          expect(error.pointer, source.pointer);
          expect(error.parameter, source.parameter);
        }
        verify(
          () => dataSource.getExpenses(endDate: endDate, groupBy: .category),
        ).called(1);
      },
    );

    test('converts empty remote errors to the shared unknown error', () async {
      when(() => dataSource.getExpenses())
          .thenAnswer((_) async => const Left(ErrorsResponse(errors: [])));

      final data = await repository.getExpenses();
      final unknown = ErrorsEntity.unknown().errors.single;

      expect(data.left.errors.single.title, unknown.title);
      expect(data.left.errors.single.detail, unknown.detail);
    });

    test('translates synchronous data source exceptions', () async {
      when(() => dataSource.getExpenses()).thenThrow(StateError('unexpected'));

      final data = await repository.getExpenses();
      final unknown = ErrorsEntity.unknown().errors.single;

      expect(data.left.errors.single.title, unknown.title);
      expect(data.left.errors.single.detail, unknown.detail);
    });

    test('translates asynchronous data source exceptions', () async {
      when(() => dataSource.getExpenses())
          .thenAnswer((_) async => throw StateError('offline'));

      final data = await repository.getExpenses();
      final unknown = ErrorsEntity.unknown().errors.single;

      expect(data.left.errors.single.title, unknown.title);
      expect(data.left.errors.single.detail, unknown.detail);
    });
  });
}
