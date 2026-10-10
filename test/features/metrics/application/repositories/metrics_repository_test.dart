import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/metrics/application/repositories/metrics_repository.dart';
import 'package:cordato/features/metrics/domain/repositories/interface_metrics_repository.dart';
import 'package:cordato/features/metrics/infrastructure/responses/expense_category_metrics_response.dart';
import 'package:cordato/features/metrics/infrastructure/responses/expense_metrics_response.dart';

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

        final result = await repository.getExpenses();

        expect(result.right.id, response.id);
        expect(result.right.totalAmount, 389205);
        expect(result.right.startDate, same(response.startDate));
        expect(result.right.endDate, same(response.endDate));
        expect(result.right.categories, isNull);
        verify(() => dataSource.getExpenses()).called(1);
        verifyNoMoreInteractions(dataSource);
      },
    );

    test(
      'delegates filters unchanged and preserves returned metrics',
      () async {
        final startDate = DateTime.utc(2026, 9, 1);
        final endDate = DateTime.utc(2026, 9, 30);
        final response = ExpenseMetricsResponse(
          id: 'remote-id',
          totalAmount: 300,
          startDate: DateTime(2026, 10, 1),
          endDate: DateTime(2026, 10, 31),
          categories: const [
            ExpenseCategoryMetricsResponse(
              category: 'future_category',
              totalAmount: 100,
              percentage: 33.33,
            ),
            ExpenseCategoryMetricsResponse(
              category: 'housing',
              totalAmount: 200,
              percentage: 66.67,
            ),
          ],
        );
        when(
          () => dataSource.getExpenses(
            startDate: startDate,
            endDate: endDate,
            groupBy: .category,
          ),
        ).thenAnswer((_) async => Right(response));

        final result = await repository.getExpenses(
          startDate: startDate,
          endDate: endDate,
          groupBy: .category,
        );

        expect(result.right.id, 'remote-id');
        expect(result.right.totalAmount, 300);
        expect(result.right.startDate, same(response.startDate));
        expect(result.right.endDate, same(response.endDate));
        expect(result.right.categories!.map((category) => category.category), [
          'future_category',
          'housing',
        ]);
        expect(result.right.categories!.first.totalAmount, 100);
        expect(result.right.categories!.first.percentage, 33.33);
        expect(result.right.categories!.last.totalAmount, 200);
        expect(result.right.categories!.last.percentage, 66.67);
        expect(() => result.right.categories!.clear(), throwsUnsupportedError);
        final captured = verify(
          () => dataSource.getExpenses(
            startDate: captureAny(named: 'startDate'),
            endDate: captureAny(named: 'endDate'),
            groupBy: .category,
          ),
        ).captured;
        expect(captured[0], same(startDate));
        expect(captured[1], same(endDate));
        verifyNoMoreInteractions(dataSource);
      },
    );

    test('preserves zero totals and an empty grouping', () async {
      when(() => dataSource.getExpenses(groupBy: .category)).thenAnswer(
        (_) async => Right(
          ExpenseMetricsResponse(
            id: 'empty',
            totalAmount: 0,
            startDate: DateTime.utc(2026, 10, 1),
            endDate: DateTime.utc(2026, 10, 31),
            categories: [],
          ),
        ),
      );

      final result = await repository.getExpenses(groupBy: .category);

      expect(result.right.totalAmount, 0);
      expect(result.right.categories, isNotNull);
      expect(result.right.categories, isEmpty);
      expect(result.right.startDate.isUtc, isTrue);
      expect(result.right.endDate.isUtc, isTrue);
    });

    test(
      'delegates incomplete periods and preserves every remote error',
      () async {
        final endDate = DateTime(2026, 10, 31);
        const errors = ErrorsResponse(
          errors: [
            ErrorResponse(
              title: 'Parâmetro inválido',
              detail: 'As datas inicial e final devem ser informadas juntas.',
              status: '422',
              pointer: '/start_date',
              parameter: 'start_date',
            ),
            ErrorResponse(detail: 'Outro erro retornado pelo serviço.'),
          ],
        );
        when(() => dataSource.getExpenses(endDate: endDate, groupBy: .category))
            .thenAnswer((_) async => const Left(errors));

        final result = await repository.getExpenses(
          endDate: endDate,
          groupBy: .category,
        );

        expect(result.isLeft, isTrue);
        expect(result.left.errors, hasLength(2));
        for (var index = 0; index < errors.errors.length; index++) {
          final source = errors.errors[index];
          final error = result.left.errors[index];
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

      final result = await repository.getExpenses();
      final unknown = ErrorsEntity.unknown().errors.single;

      expect(result.left.errors.single.title, unknown.title);
      expect(result.left.errors.single.detail, unknown.detail);
    });

    test('translates synchronous data source exceptions', () async {
      when(() => dataSource.getExpenses()).thenThrow(StateError('unexpected'));

      final result = await repository.getExpenses();
      final unknown = ErrorsEntity.unknown().errors.single;

      expect(result.left.errors.single.title, unknown.title);
      expect(result.left.errors.single.detail, unknown.detail);
    });

    test('translates asynchronous data source exceptions', () async {
      when(() => dataSource.getExpenses())
          .thenAnswer((_) async => throw StateError('offline'));

      final result = await repository.getExpenses();
      final unknown = ErrorsEntity.unknown().errors.single;

      expect(result.left.errors.single.title, unknown.title);
      expect(result.left.errors.single.detail, unknown.detail);
    });
  });
}
