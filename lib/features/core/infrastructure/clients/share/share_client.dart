import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'package:cordato/features/core/infrastructure/clients/share/share_client_exception.dart';

abstract interface class IShareClient {
  Future<void> discard({required String path});
  Future<void> share({required String path, required String mimeType});
  Future<String> prepare({required Uint8List bytes, required String fileName});
}

final class ShareClient({
  final DateTime Function() _now = DateTime.now,
  final Future<Directory> Function() _directory = getTemporaryDirectory,
}) implements IShareClient {
  final Set<String> _activeDirectories = {};
  static const retention = Duration(hours: 24);

  @override
  Future<String> prepare({
    required Uint8List bytes,
    required String fileName,
  }) => _run(() async {
    if (fileName.isEmpty ||
        p.basename(fileName) != fileName ||
        fileName.contains(r'\') ||
        fileName == '.' ||
        fileName == '..') {
      throw ArgumentError.value(fileName, 'fileName');
    }

    final root = await _root();
    await _cleanExpired(root);
    final directory = await root.createTemp('share-');
    _activeDirectories.add(directory.path);

    try {
      final file = File(p.join(directory.path, fileName));
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } on FileSystemException {
      await directory.delete(recursive: true);
      rethrow;
    } finally {
      _activeDirectories.remove(directory.path);
    }
  });

  @override
  Future<void> share({required String path, required String mimeType}) =>
      _run(() async {
        final directory = await _ownedDirectory(path);
        _activeDirectories.add(directory.path);

        try {
          if (await FileSystemEntity.type(path, followLinks: false) !=
              FileSystemEntityType.file) {
            throw const ShareClientException(code: 'export_file_unavailable');
          }
          await SharePlus.instance.share(
            ShareParams(
              files: [XFile(path, mimeType: mimeType)],
              sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
            ),
          );
        } finally {
          _activeDirectories.remove(directory.path);
        }
      });

  @override
  Future<void> discard({required String path}) => _run(() async {
    final directory = await _ownedDirectory(path);
    if (_activeDirectories.contains(directory.path)) {
      throw const ShareClientException(code: 'export_busy');
    }
    if (await FileSystemEntity.type(directory.path, followLinks: false) ==
        FileSystemEntityType.directory) {
      await directory.delete(recursive: true);
    }
  });

  Future<Directory> _root() async {
    final temporary = await _directory();
    final root = Directory(p.join(temporary.path, 'cordato_share'));
    await root.create(recursive: true);
    if (await FileSystemEntity.type(root.path, followLinks: false) !=
        FileSystemEntityType.directory) {
      throw const ShareClientException(code: 'export_file_unavailable');
    }
    return root;
  }

  Future<Directory> _ownedDirectory(String path) async {
    final root = await _root();
    final directory = Directory(p.dirname(path));
    if (!p.equals(p.dirname(directory.path), root.path) ||
        !p.basename(directory.path).startsWith('share-')) {
      throw ArgumentError('Attachment is outside the sharing directory');
    }
    final type = await FileSystemEntity.type(
      directory.path,
      followLinks: false,
    );
    if (type != FileSystemEntityType.directory &&
        type != FileSystemEntityType.notFound) {
      throw const ShareClientException(code: 'export_file_unavailable');
    }
    return directory;
  }

  Future<void> _cleanExpired(Directory root) async {
    final oldest = _now().subtract(retention);
    await for (final entry in root.list(followLinks: false)) {
      if (entry is! Directory ||
          !p.basename(entry.path).startsWith('share-') ||
          _activeDirectories.contains(entry.path)) {
        continue;
      }
      if ((await entry.stat()).modified.isBefore(oldest)) {
        await entry.delete(recursive: true);
      }
    }
  }

  Future<T> _run<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } on FileSystemException {
      throw const ShareClientException(code: 'export_file_failed');
    } on PlatformException {
      throw const ShareClientException(code: 'export_share_failed');
    } on MissingPluginException {
      throw const ShareClientException(code: 'export_share_unavailable');
    } on UnsupportedError {
      throw const ShareClientException(code: 'export_share_unavailable');
    }
  }
}
