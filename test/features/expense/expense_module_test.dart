import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/application/clients/interface_home_widget_client.dart';
import 'package:cordato/features/expense/application/repositories/interface_expense_repository.dart';
import 'package:cordato/features/expense/expense_module.dart';
import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_bloc.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/bloc/expenses_bloc.dart';

import '../../support/core/fakes/pocketbase_fixture.dart';
import '../../support/core/mocks/home_widget_client_mock.dart';

void main() {
  test('resolves the shared SDK repository without visiting an Expense route and keeps independent Bloc factories', () async {
    final fixture = PocketBaseFixture();
    fixture.respond = (_) => PocketBaseFixture.jsonResponse({
      'items': [],
      'page': 1,
      'totalPages': 0,
    });
    addTearDown(fixture.client.close);
    final boot = bootstrapModule(
      createModule(
        register: (context) => context
          ..addInstance<PocketBase>(fixture.client)
          ..addInstance<IHomeWidgetClient>(HomeWidgetClientMock())
          ..module(expenseModule),
      ),
    );
    addTearDown(boot.injector.dispose);
    final repository = boot.injector.get<IExpenseRepository>();
    final form = boot.injector.get<ExpenseBloc>();
    final otherForm = boot.injector.get<ExpenseBloc>();
    final list = boot.injector.get<ExpensesBloc>();
    final otherList = boot.injector.get<ExpensesBloc>();
    addTearDown(form.close);
    addTearDown(otherForm.close);
    addTearDown(list.close);
    addTearDown(otherList.close);

    expect(form, isNot(same(otherForm)));
    expect(list, isNot(same(otherList)));
    expect(boot.injector.get<IExpenseRepository>(), same(repository));
    expect((await repository.get(pageSize: 6)).items, isEmpty);
    final request = fixture.requests.single;
    expect(request.url.path, '/api/collections/expenses/records');
    expect(request.url.queryParameters['perPage'], '6');
  });
}
