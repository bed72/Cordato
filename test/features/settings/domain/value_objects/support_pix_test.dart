import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/settings/domain/value_objects/support_pix.dart';

Map<String, String> decodeFields(String payload) {
  final fields = <String, String>{};
  var offset = 0;
  while (offset < payload.length) {
    final tag = payload.substring(offset, offset + 2);
    final length = int.parse(payload.substring(offset + 2, offset + 4));
    fields[tag] = payload.substring(offset + 4, offset + 4 + length);
    offset += 4 + length;
  }
  return fields;
}

void main() {
  test('Pix identifies the recipient and leaves the donation amount open', () {
    final fields = decodeFields(SupportPix.copyAndPaste);
    final account = decodeFields(fields['26']!);

    expect(fields['00'], '01');
    expect(account['00'], 'br.gov.bcb.pix');
    expect(account['01'], SupportPix.key);
    expect(fields['52'], '0000');
    expect(fields['53'], '986');
    expect(fields.containsKey('54'), isFalse);
    expect(fields['58'], 'BR');
    expect(fields['59'], 'GABRIEL RAMOS');
    expect(fields['60'], 'LAGES');
    expect(decodeFields(fields['62']!)['05'], '***');
    expect(fields['63'], '4690');
  });

  test('Pix checksum follows CRC-16 CCITT-FALSE', () {
    final payload = SupportPix.copyAndPaste;
    final content = payload.substring(0, payload.length - 4);
    var checksum = 0xffff;
    for (final byte in content.codeUnits) {
      checksum ^= byte << 8;
      for (var bit = 0; bit < 8; bit++) {
        checksum = checksum & 0x8000 != 0
            ? ((checksum << 1) ^ 0x1021) & 0xffff
            : (checksum << 1) & 0xffff;
      }
    }

    expect(
      checksum.toRadixString(16).toUpperCase().padLeft(4, '0'),
      payload.substring(payload.length - 4),
    );
  });
}
