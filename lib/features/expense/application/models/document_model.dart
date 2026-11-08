import 'dart:typed_data';

final class DocumentModel({
  required Uint8List bytes,
  required final String ownerId,
}) {
  final Uint8List bytes = Uint8List.fromList(bytes).asUnmodifiableView();
}
