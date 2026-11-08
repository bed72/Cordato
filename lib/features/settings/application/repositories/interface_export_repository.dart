import 'package:cordato/features/core/application/enums/share_outcome_enum.dart';
import 'package:cordato/features/core/application/models/share_origin_model.dart';

import 'package:cordato/features/settings/application/models/prepared_export_model.dart';

abstract interface class IExportRepository {
  Future<PreparedExportModel?> prepare();

  Future<ShareOutcomeEnum> share({
    required PreparedExportModel export,
    ShareOriginModel? origin,
  });

  Future<void> discard(PreparedExportModel export);
}
