import 'dart:io';

import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/core/application/models/share_origin.dart';
import 'package:cordato/features/core/application/models/share_attachment.dart';
import 'package:cordato/features/core/application/models/file_share_outcome.dart';
import 'package:cordato/features/core/application/exceptions/file_share_exception.dart';
import 'package:cordato/features/core/application/clients/interface_file_share_client.dart';

final class FileShareClient implements IFileShareClient {
  final Set<String> _active = {};
  final Set<String> _retained = {};

  @override
  Future<void> cleanExpired() => _guard(() async {
    final root = await _root();
    final cutoff = DateTime.now().subtract(const Duration(hours: 24));

    await for (final entry in root.list(followLinks: false)) {
      final id = entry.uri.pathSegments.where((part) => part.isNotEmpty).last;
      if (entry is! Directory || !_validId(id) || _active.contains(id)) {
        continue;
      }

      DateTime? newest;
      await for (final child in entry.list(followLinks: false)) {
        final modified = (await child.stat()).modified;
        if (newest == null || modified.isAfter(newest)) {
          newest = modified;
        }
      }

      newest ??= (await entry.stat()).modified;
      if (newest.isBefore(cutoff)) {
        await entry.delete(recursive: true);
        _retained.remove(id);
      }
    }
  });

  @override
  Future<ShareAttachment> prepare({
    required Uint8List bytes,
    required String fileName,
  }) => _guard(() async {
    _validateFileName(fileName);

    final directory = await (await _root()).createTemp('attachment-');
    final id = directory.uri.pathSegments.where((part) => part.isNotEmpty).last;

    _active.add(id);
    final attachment = ShareAttachment(id: id, fileName: fileName);

    try {
      await File('${directory.path}/$fileName')
          .writeAsBytes(bytes, flush: true);
      return attachment;
    } on FileSystemException {
      await directory.delete(recursive: true);
      _active.remove(id);
      rethrow;
    }
  });

  @override
  Future<FileShareOutcome> share({
    required String mimeType,
    required ShareAttachment attachment,
    ShareOrigin? origin,
  }) {
    _retained.add(attachment.id);

    return _guard(() async {
      try {
        final file = await _file(attachment);
        await file.setLastModified(DateTime.now());

        final outcome = await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: mimeType)],
            sharePositionOrigin: origin == null
                ? null
                : Rect.fromLTWH(
                    origin.x,
                    origin.y,
                    origin.width,
                    origin.height,
                  ),
          ),
        );

        return switch (outcome.status) {
          ShareResultStatus.success => FileShareOutcome.completed,
          ShareResultStatus.dismissed => FileShareOutcome.dismissed,
          ShareResultStatus.unavailable => FileShareOutcome.unavailable,
        };
      } finally {
        _active.remove(attachment.id);
      }
    });
  }

  @override
  Future<void> discard(ShareAttachment attachment) => _guard(() async {
    if (_retained.contains(attachment.id)) {
      return;
    }

    final file = await _file(attachment);
    final directory = file.parent;
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }

    _active.remove(attachment.id);
  });

  Future<Directory> _root() async {
    final temporary = await getTemporaryDirectory();
    return Directory('${temporary.path}/cordato-file-share').create();
  }

  Future<File> _file(ShareAttachment attachment) async {
    if (!_validId(attachment.id)) {
      throw ArgumentError('Invalid attachment identifier');
    }

    _validateFileName(attachment.fileName);
    return File(
      '${(await _root()).path}/${attachment.id}/${attachment.fileName}',
    );
  }

  bool _validId(String id) => RegExp(r'^attachment-[a-zA-Z0-9]+$').hasMatch(id);

  void _validateFileName(String name) {
    if (!RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9_.-]*$').hasMatch(name)) {
      throw ArgumentError('Invalid attachment filename');
    }
  }

  Future<T> _guard<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on FileSystemException {
      throw _failure();
    } on PlatformException {
      throw _failure();
    } on MissingPluginException {
      throw _failure();
    } on MissingPlatformDirectoryException {
      throw _failure();
    }
  }

  FileShareException _failure() => const FileShareException(
    errors: ErrorsEntity(errors: [ErrorEntity(code: 'file_share_failed')]),
  );
}
