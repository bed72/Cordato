import 'package:cordato/features/core/domain/entities/errors_entity.dart';

sealed class ExportState {
  const ExportState();

  bool get isBusy => this is ExportPreparing || this is ExportSharing;
}

final class ExportInitial extends ExportState {
  const ExportInitial();
}

final class ExportPreparing extends ExportState {
  const ExportPreparing();
}

final class ExportSharing extends ExportState {
  const ExportSharing();
}

final class ExportCompleted extends ExportState {
  const ExportCompleted();
}

final class ExportEmpty extends ExportState {
  const ExportEmpty();
}

final class const ExportFailure({required final ErrorsEntity errors})
    extends ExportState;
