import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:cordato/features/core/presentation/widgets/buttons/outline_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/elevated_button_widget.dart';

import 'package:cordato/features/expense/domain/entities/expense_entity.dart';

import 'package:cordato/features/expense/presentation/screens/expenses/bloc/expenses_bloc.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/bloc/expenses_event.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/bloc/expenses_state.dart';

final class const ExpenseReregistrationWidget({
  super.key,
  required final ExpensesBloc bloc,
  required final ExpenseEntity expense,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ExpensesBloc, ExpensesState>(
      bloc: bloc,
      listenWhen: (previous, current) =>
          previous is ExpensesReregistering &&
          previous.id == expense.id &&
          (current is ExpensesReregistered ||
              current is ExpensesReregisterFailure),
      listener: (context, state) {
        if (ModalRoute.of(context)?.isCurrent ?? false) {
          Navigator.of(context).pop<ExpensesState>(state);
        }
      },
      builder: (context, state) {
        final isSubmitting = state is ExpensesReregistering;

        return PopScope<ExpensesState>(
          canPop: !isSubmitting,
          child: SafeArea(
            top: false,
            left: false,
            right: false,
            child: Column(
              spacing: 16.0,
              mainAxisSize: .min,
              crossAxisAlignment: .stretch,
              children: [
                const SizedBox.shrink(),
                OutlineButtonWidget(
                  label: 'Voltar',
                  onTap: state.isBusy
                      ? null
                      : () {
                          if (ModalRoute.of(context)?.isCurrent ?? false) {
                            Navigator.of(context).pop();
                          }
                        },
                ),
                ElevatedButtonWidget(
                  label: 'Cadastrar',
                  isLoading: isSubmitting,
                  onTap: state.isBusy
                      ? null
                      : () {
                          if (bloc.isClosed ||
                              bloc.state.isBusy ||
                              !(ModalRoute.of(context)?.isCurrent ?? false)) {
                            return;
                          }

                          bloc.add(
                            ExpensesReregisterRequestedEvent(
                              expense: expense,
                              confirmedAt: DateTime.now(),
                            ),
                          );
                        },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
