import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/circular_progress_indicator_widget.dart';
import 'package:cordato/features/core/presentation/widgets/menu/menu_item_widget.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/export_bloc.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/export_state.dart';
import 'package:cordato/features/settings/presentation/screens/settings/mixins/export_state_mixin.dart';

final class const ExportExpensesWidget({super.key}) extends StatefulWidget {
  @override
  State<ExportExpensesWidget> createState() => _ExportExpensesWidgetState();
}

final class _ExportExpensesWidgetState extends State<ExportExpensesWidget>
    with ExportStateMixin {
  @override
  Widget build(BuildContext context) => BlocConsumer<ExportBloc, ExportState>(
    listener: (_, state) => handleExport(state),
    builder: (_, state) => MenuItemWidget(
      label: 'Exportar despesas',
      icon: Icons.ios_share_outlined,
      showChevron: !state.isBusy,
      trailing: state.isBusy
          ? SizedBox.square(
              dimension: 24.0,
              child: CircularProgressIndicatorWidget(
                color: context.colors.onSurfaceVariant,
              ),
            )
          : null,
      onPressed: state.isBusy ? null : requestExport,
    ),
  );
}
