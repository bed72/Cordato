import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/expense/application/models/document_model.dart';

void main() {
  test('DocumentModel owns an immutable copy without exposing SDK records', () {
    final source = Uint8List.fromList([0xef, 0xbb, 0xbf, 65]);
    final document = DocumentModel(ownerId: 'owner', bytes: source);

    source[3] = 66;

    expect(document.ownerId, 'owner');
    expect(document.bytes, [0xef, 0xbb, 0xbf, 65]);
    expect(() => document.bytes[3] = 67, throwsUnsupportedError);
  });
}
