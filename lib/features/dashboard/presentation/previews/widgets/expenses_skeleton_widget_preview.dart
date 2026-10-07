import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/expense/presentation/screens/expenses/widgets/expenses_skeleton_widget.dart';

@CordatoPreview(
  group: 'Dashboard / Despesas',
  name: 'Skeleton de seis despesas',
  size: Size(390.0, 480.0),
)
Widget previewExpensesSkeletonWidget() => const Scaffold(
  body: SingleChildScrollView(
    padding: EdgeInsets.symmetric(vertical: 24.0),
    child: ExpensesSkeletonWidget(count: 6),
  ),
);
