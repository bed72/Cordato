import 'dart:typed_data';

import 'package:cordato/features/core/application/enums/share_outcome_enum.dart';
import 'package:cordato/features/core/application/models/share_origin_model.dart';
import 'package:cordato/features/core/application/models/share_attachment_model.dart';

abstract interface class IShareClient {
  Future<void> cleanExpired();

  Future<ShareAttachmentModel> prepare({
    required Uint8List bytes,
    required String fileName,
  });

  Future<ShareOutcomeEnum> share({
    required String mimeType,
    required ShareAttachmentModel attachment,
    ShareOriginModel? origin,
  });

  Future<void> discard(ShareAttachmentModel attachment);
}
