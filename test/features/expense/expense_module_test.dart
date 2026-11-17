import 'package:mocktail/mocktail.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';
import 'package:cordato/features/expense/application/repositories/interface_expense_repository.dart';
import 'package:cordato/features/expense/expense_module.dart';
import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_bloc.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/bloc/expenses_bloc.dart';

import '../../support/expense/mocks/expense_repository_mock.dart';

void main() {
  test('resolves the supplied repository without visiting routes and keeps independent Bloc factories', () async {
    final expenses = ExpenseRepositoryMock();
    when(() => expenses.get(pageSize: 6))
        .thenAnswer((_) async => ExpensePageEntity(items: [], nextPage: null));
    final boot = bootstrapModule(
      createModule(
        register: (context) => context
          ..addInstance<IExpenseRepository>(expenses)
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
    verify(() => expenses.get(pageSize: 6)).called(1);
  });
}
