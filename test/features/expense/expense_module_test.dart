import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cordato/features/core/application/clients/interface_home_widget_client.dart';

import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/storage_client.dart';
import 'package:cordato/features/expense/application/repositories/interface_expense_repository.dart';
import 'package:cordato/features/expense/expense_module.dart';
import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_bloc.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/bloc/expenses_bloc.dart';

import '../../support/core/mocks/http_client_mock.dart';
import '../../support/core/mocks/storage_client_mock.dart';
import '../../support/core/mocks/home_widget_client_mock.dart';

void main() {
  setUpAll(() => registerFallbackValue(const Requests(path: '')));

  group('Repository and Bloc bindings', () {
    test(
      'binds one HTTP-backed repository by contract without a data source',
      () async {
        final http = HttpClientMock();
        when(() => http.get(parameter: any(named: 'parameter'))).thenAnswer(
          (_) async => const Responses(
            status: 200,
            body: {'items': [], 'page': 1, 'totalPages': 0},
          ),
        );
        final boot = bootstrapModule(
          createModule(
            register: (context) {
              context.addInstance<IHttpClient>(http);
              context.addInstance<IStorageClient>(StorageClientMock());
              context.addInstance<IHomeWidgetClient>(HomeWidgetClientMock());
              context.module(expenseModule);
            },
          ),
        );
        addTearDown(boot.injector.dispose);
        final repository = inject<IExpenseRepository>();
        final form = inject<ExpenseBloc>();
        final otherForm = inject<ExpenseBloc>();
        final list = inject<ExpensesBloc>();
        final otherList = inject<ExpensesBloc>();
        expect(form, isNot(same(otherForm)));
        expect(list, isNot(same(otherList)));
        addTearDown(form.close);
        addTearDown(otherForm.close);
        addTearDown(list.close);
        addTearDown(otherList.close);
        expect(inject<IExpenseRepository>(), same(repository));
        expect((await repository.get(pageSize: 6)).items, isEmpty);
        final request =
            verify(() => http.get(parameter: captureAny(named: 'parameter')))
                    .captured
                    .single
                as Requests;
        expect(request.path, 'collections/expenses/records');
        expect(request.query, {
          'page': 1,
          'perPage': 6,
          'sort': '-occurred_on,-id',
        });
        verifyNoMoreInteractions(http);
      },
    );
  });
}
