import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';

import 'package:cordato/features/settings/presentation/screens/settings/bloc/export_event.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/export_state.dart';

import 'package:cordato/features/settings/application/exceptions/export_exception.dart';
import 'package:cordato/features/settings/application/models/prepared_export_model.dart';
import 'package:cordato/features/settings/application/repositories/interface_export_repository.dart';

final class ExportBloc({required final IExportRepository repository})
    extends Bloc<ExportEvent, ExportState> {
  this : super(const ExportInitial()) {
    on<ExportRequested>(_prepare, transformer: droppable());
    on<ExportAbandoned>(_abandon, transformer: droppable());
    on<ExportShareRequested>(_share, transformer: droppable());
  }

  Future<void> _prepare(
    ExportRequested event,
    Emitter<ExportState> emit,
  ) async {
    if (!state.canSubmit) {
      return;
    }

    emit(const ExportPreparing());
    PreparedExportModel? prepared;

    try {
      prepared = await repository.prepare();
      if (isClosed || emit.isDone) return;

      if (prepared == null) {
        emit(const ExportEmpty());
        return;
      }

      emit(ExportReady(export: prepared));
      await emit.onEach(
        stream.takeWhile((next) => next is ExportReady),
        onData: (_) {},
      );
    } on ExportException catch (exception) {
      if (!isClosed && !emit.isDone) {
        emit(ExportFailure(errors: exception.errors));
      }
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed && !emit.isDone) {
        emit(ExportFailure(errors: .unknown()));
      }
    } finally {
      if (prepared != null && (isClosed || emit.isDone)) {
        await _discard(prepared);
      }
    }
  }

  Future<void> _share(
    ExportShareRequested event,
    Emitter<ExportState> emit,
  ) async {
    if (state case ExportReady(:final export)) {
      emit(const ExportSharing());

      try {
        await repository.share(export: export, origin: event.origin);
        if (!isClosed && !emit.isDone) emit(const ExportCompleted());
      } on ExportException catch (exception) {
        if (!isClosed && !emit.isDone) {
          emit(ExportFailure(errors: exception.errors));
        }
      } catch (error, stackTrace) {
        addError(error, stackTrace);
        if (!isClosed && !emit.isDone) emit(ExportFailure(errors: .unknown()));
      }
    }
  }

  Future<void> _abandon(
    ExportAbandoned event,
    Emitter<ExportState> emit,
  ) async {
    if (state case ExportReady(:final export)) {
      emit(const ExportPreparing());

      await _discard(export);
      if (!isClosed && !emit.isDone) emit(const ExportInitial());
    }
  }

  Future<void> _discard(PreparedExportModel export) async {
    try {
      await repository.discard(export);
    } on ExportException {
      return;
    } catch (error, stackTrace) {
      addError(error, stackTrace);
    }
  }
}
