import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:cordato/features/core/presentation/widgets/menu/menu_item_widget.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/export_bloc.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/export_state.dart';
import 'package:cordato/features/settings/presentation/screens/settings/mixins/export_state_mixin.dart';

final class const ExportWidget({super.key, required final ExportBloc bloc})
    extends StatefulWidget {
  @override
  State<ExportWidget> createState() => _ExportState();
}

final class _ExportState extends State<ExportWidget> with ExportStateMixin {
  @override
  Widget build(BuildContext context) => BlocConsumer<ExportBloc, ExportState>(
    bloc: widget.bloc,
    listener: (_, state) => handleExport(state),
    builder: (_, state) => MenuItemWidget(
      label: 'Exportar despesas',
      showChevron: !state.isBusy,
      icon: Icons.ios_share_outlined,
      onPressed: state.canSubmit ? requestExport : null,
      description: state.isBusy ? 'Preparando exportação…' : null,
    ),
  );
}
