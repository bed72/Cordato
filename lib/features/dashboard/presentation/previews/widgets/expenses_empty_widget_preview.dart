import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/dashboard/presentation/widgets/expenses/expenses_empty_widget.dart';

@CordatoPreview(
  group: 'Dashboard / Despesas',
  name: 'Estado vazio',
  size: Size(390.0, 180.0),
)
Widget previewExpensesEmptyWidget() =>
    const Scaffold(body: Center(child: ExpensesEmptyWidget()));
