import 'package:cordato/features/core/application/models/share_origin.dart';
import 'package:cordato/features/core/application/models/file_share_outcome.dart';

import 'package:cordato/features/settings/application/models/prepared_export_model.dart';

abstract interface class IExportRepository {
  Future<PreparedExportModel?> prepare();

  Future<FileShareOutcome> share({
    required PreparedExportModel export,
    ShareOrigin? origin,
  });

  Future<void> discard(PreparedExportModel export);
}
