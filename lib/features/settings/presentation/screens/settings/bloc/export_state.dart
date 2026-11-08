import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/settings/application/models/prepared_export_model.dart';

sealed class ExportState {
  const ExportState();

  bool get canSubmit => switch (this) {
    ExportPreparing() || ExportReady() || ExportSharing() => false,
    _ => true,
  };

  bool get isBusy => !canSubmit;
}

final class const ExportInitial() extends ExportState {}

final class const ExportPreparing() extends ExportState {}

final class const ExportReady({required final PreparedExportModel export})
    extends ExportState {}

final class const ExportSharing() extends ExportState {}

final class const ExportEmpty() extends ExportState {}

final class const ExportCompleted() extends ExportState {}

final class const ExportFailure({required final ErrorsEntity errors})
    extends ExportState {}
