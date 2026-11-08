import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/application/models/share_origin_model.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/formatters/error_message_formatter.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/export_event.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/export_state.dart';
import 'package:cordato/features/settings/presentation/screens/settings/widgets/export_widget.dart';

mixin ExportStateMixin on State<ExportWidget> {
  void requestExport() {
    if (!widget.bloc.isClosed && widget.bloc.state.canSubmit) {
      widget.bloc.add(const ExportRequested());
    }
  }

  void handleExport(ExportState state) {
    if (!mounted || widget.bloc.isClosed) return;

    if (!(ModalRoute.of(context)?.isCurrent ?? false)) {
      if (state is ExportReady) {
        widget.bloc.add(const ExportAbandoned());
      }

      return;
    }

    switch (state) {
      case ExportReady():
        widget.bloc.add(ExportShareRequested(origin: _origin()));
      case ExportEmpty():
        context.showToast(title: 'Você ainda não tem despesas para exportar');
      case ExportFailure(:final errors):
        context.showToast(
          variant: .error,
          title: 'Erro ao exportar despesas',
          description: ErrorMessageFormatter.formatAll(
            errors.errors,
            fallback: 'Não foi possível exportar as despesas.',
          ),
        );
      default:
        break;
    }
  }

  ShareOriginModel? _origin() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) {
      return null;
    }

    final offset = box.localToGlobal(Offset.zero);
    return ShareOriginModel(
      x: offset.dx,
      y: offset.dy,
      width: box.size.width,
      height: box.size.height,
    );
  }
}
