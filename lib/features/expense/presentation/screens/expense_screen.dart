import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/expense/presentation/widgets/expense_app_bar_widget.dart';
import 'package:cordato/features/expense/presentation/widgets/expense_form_widget.dart';

final class ExpenseScreen extends StatelessWidget {
  final VoidCallback onBackPressed;

  const ExpenseScreen({super.key, required this.onBackPressed});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: ExpenseAppBarWidget(onBackPressed: onBackPressed),
    body: const SafeArea(child: ExpenseFormWidget()),
  );
}
