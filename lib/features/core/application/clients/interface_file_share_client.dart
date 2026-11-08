import 'dart:typed_data';

import 'package:cordato/features/core/application/models/share_origin.dart';
import 'package:cordato/features/core/application/models/share_attachment.dart';
import 'package:cordato/features/core/application/models/file_share_outcome.dart';

abstract interface class IFileShareClient {
  Future<void> cleanExpired();

  Future<ShareAttachment> prepare({
    required Uint8List bytes,
    required String fileName,
  });

  Future<FileShareOutcome> share({
    required String mimeType,
    required ShareAttachment attachment,
    ShareOrigin? origin,
  });

  Future<void> discard(ShareAttachment attachment);
}
