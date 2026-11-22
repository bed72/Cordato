import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:localstore/localstore.dart';

import 'package:cordato/features/core/infrastructure/clients/widget_client.dart';
import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/expense/application/repositories/interface_expense_repository.dart';
import 'package:cordato/features/expense/expense_module.dart';
import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_bloc.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/bloc/expenses_bloc.dart';

import '../../support/core/mocks/widget_client_mock.dart';
import '../../support/core/storage/localstore_test_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('resolves local repositories without visiting Expense and preserves independent Bloc factories', () async {
    final storage = LocalstoreTestStorage();
    await storage.open();
    addTearDown(storage.close);
    final boot = bootstrapModule(
      createModule(
        register: (context) => context
          ..addInstance<Localstore>(storage.database)
          ..addInstance<IWidgetClient>(WidgetClientMock())
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
    final created = await storage.expense(
      () => repository.create(cents: 1, description: 'Local'),
    );
    expect((await repository.getById(id: created.id)).description, 'Local');
    expect(
      boot.routes.routes.map((route) => route.path),
      unorderedEquals([RouteEnum.expenses.path, RouteEnum.expense.path]),
    );
    expect(
      boot.routes
          .match(Uri.parse(RouteEnum.expense.path))!
          .single
          .route
          .provide,
      isNotNull,
    );
    expect(RouteEnum.expense.authenticated, isFalse);
    expect(RouteEnum.expenses.authenticated, isFalse);
  });
}
