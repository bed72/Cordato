import 'package:cordato/features/core/application/models/share_origin_model.dart';

sealed class ExportEvent {
  const ExportEvent();
}

final class const ExportRequested() extends ExportEvent {}

final class const ExportShareRequested({final ShareOriginModel? origin})
    extends ExportEvent {}

final class const ExportAbandoned() extends ExportEvent {}
