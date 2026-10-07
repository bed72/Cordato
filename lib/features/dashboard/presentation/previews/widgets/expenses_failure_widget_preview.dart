import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/dashboard/presentation/widgets/expenses/expenses_failure_widget.dart';

@CordatoPreview(
  group: 'Dashboard / Despesas',
  name: 'Falha com descrição',
  size: Size(390.0, 200.0),
)
Widget previewExpensesFailureWidget() =>
    const Scaffold(body: Center(child: ExpensesFailureWidget()));
