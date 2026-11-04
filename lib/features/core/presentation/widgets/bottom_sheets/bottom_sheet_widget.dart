import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/bottom_sheets/bottom_sheet_scaffold_widget.dart';

Future<T?> showBottomSheetWidget<T>({
  required BuildContext context,
  required Widget child,
  String? title,
  String? subtitle,
  EdgeInsetsGeometry? contentPadding,
  bool enableDrag = true,
  double topMargin = 32.0,
  bool useSafeArea = true,
  bool isDismissible = true,
  bool useRootNavigator = true,
}) => showModalBottomSheet<T>(
  context: context,
  enableDrag: enableDrag,
  useSafeArea: useSafeArea,
  isScrollControlled: true,
  isDismissible: isDismissible,
  useRootNavigator: useRootNavigator,
  backgroundColor: Colors.transparent,
  builder: (context) => ConstrainedBox(
    constraints: BoxConstraints(maxHeight: context.height - topMargin),
    child: BottomSheetScaffoldWidget(
      title: title,
      subtitle: subtitle,
      contentPadding: contentPadding,
      child: child,
    ),
  ),
);
