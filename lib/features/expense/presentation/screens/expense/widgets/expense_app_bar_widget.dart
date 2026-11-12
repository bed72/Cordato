import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart' show ModularNavigationX;

import 'package:cordato/features/core/presentation/widgets/buttons/back_button_widget.dart';
import 'package:cordato/features/expense/domain/entities/expense_entity.dart';

final class const ExpenseAppBarWidget({
  super.key,
  final ExpenseEntity? createdExpense,
}) extends StatelessWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
    leadingWidth: 80.0,
    leading: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: BackButtonWidget(onPress: () => context.pop(createdExpense)),
    ),
  );
}
