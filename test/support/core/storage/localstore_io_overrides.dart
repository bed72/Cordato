import 'dart:io';

final class LocalstoreIoOverrides({required final Directory directory})
    extends IOOverrides {
  @override
  Directory getCurrentDirectory() => directory;
}
