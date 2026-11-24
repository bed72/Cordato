import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';

import 'package:cordato/features/settings/presentation/screens/settings/bloc/export_event.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/export_state.dart';

import 'package:cordato/features/settings/application/exceptions/export_exception.dart';
import 'package:cordato/features/settings/application/repositories/interface_export_repository.dart';

final class ExportBloc({required final IExportRepository _repository})
    extends Bloc<ExportEvent, ExportState> {
  this : super(const ExportInitial()) {
    on<ExportRequestedEvent>(_export, transformer: droppable());
  }

  Future<void> _export(
    ExportRequestedEvent event,
    Emitter<ExportState> emit,
  ) async {
    emit(const ExportPreparing());

    try {
      final path = await _repository.prepare();
      if (isClosed || emit.isDone) {
        if (path != null) await _repository.discard(path: path);

        return;
      }

      if (path == null) {
        emit(const ExportEmpty());
        return;
      }

      emit(const ExportSharing());
      await _repository.share(path: path);
      if (isClosed || emit.isDone) return;

      emit(const ExportCompleted());
    } on ExportException catch (error) {
      if (!isClosed && !emit.isDone) {
        emit(ExportFailure(errors: error.errors));
      }
    } catch (error, stackTrace) {
      if (!isClosed && !emit.isDone) {
        addError(error, stackTrace);
        emit(ExportFailure(errors: .unknown()));
      }
    }
  }
}
