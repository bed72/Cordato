import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/settings/presentation/layouts/support_pix_layout.dart';

void main() {
  group('SupportPixLayout', () {
    test('centers the original QR size when there is room', () {
      const layout = SupportPixLayout(
        availableHeight: 400.0,
        availableWidth: 320.0,
        recipientHeight: 24.0,
      );

      expect(layout.qrSize, 220.0);
      expect(layout.contentHeight, 400.0);
    });

    test('shrinks the QR to fit the height without scrolling', () {
      const layout = SupportPixLayout(
        availableHeight: 208.0,
        availableWidth: 288.0,
        recipientHeight: 24.0,
      );

      expect(layout.qrSize, 180.0);
      expect(layout.contentHeight, 208.0);
    });

    test(
      'preserves a readable minimum and allows scrolling in short areas',
      () {
        const layout = SupportPixLayout(
          availableHeight: 100.0,
          availableWidth: 288.0,
          recipientHeight: 24.0,
        );

        expect(layout.qrSize, 144.0);
        expect(layout.contentHeight, 172.0);
      },
    );

    test('reserves the actual wrapped and scaled recipient height', () {
      const layout = SupportPixLayout(
        availableHeight: 250.0,
        availableWidth: 288.0,
        recipientHeight: 80.0,
      );

      expect(layout.qrSize, 166.0);
      expect(layout.contentHeight, 250.0);
    });

    test('limits the QR to the available width', () {
      const layout = SupportPixLayout(
        availableHeight: 300.0,
        availableWidth: 120.0,
        recipientHeight: 48.0,
      );

      expect(layout.qrSize, 120.0);
      expect(layout.contentHeight, 300.0);
    });

    test('keeps scrollable content when the header exhausts the viewport', () {
      const layout = SupportPixLayout(
        availableHeight: -20.0,
        availableWidth: 288.0,
        recipientHeight: 24.0,
      );

      expect(layout.qrSize, 144.0);
      expect(layout.contentHeight, 172.0);
    });
  });
}
