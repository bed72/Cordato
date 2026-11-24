import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/export_bloc.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/export_event.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/export_state.dart';
import 'package:cordato/features/settings/presentation/screens/settings/widgets/export_expenses_widget.dart';

mixin ExportStateMixin on State<ExportExpensesWidget> {
  void requestExport() {
    context.read<ExportBloc>().add(const ExportRequestedEvent());
  }

  void handleExport(ExportState state) {
    switch (state) {
      case ExportEmpty():
        context.showToast(
          variant: .info,
          title: 'Nenhuma despesa',
          description: 'Você ainda não tem despesas para exportar.',
        );
      case ExportFailure():
        context.showToast(
          variant: .error,
          title: 'Não foi possível exportar',
          description:
              'Tente novamente. Nenhum arquivo foi confirmado como salvo.',
        );
      default:
        break;
    }
  }
}
