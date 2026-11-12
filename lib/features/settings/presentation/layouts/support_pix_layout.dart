import 'dart:math' as math;

final class const SupportPixLayout({
  required final double availableHeight,
  required final double availableWidth,
  required final double recipientHeight,
}) {
  static const double captionSpacing = 4.0;

  double get qrSize => math.min(
    math.max(0.0, availableWidth),
    (availableHeight - recipientHeight - captionSpacing).clamp(144.0, 220.0),
  );

  double get contentHeight =>
      math.max(availableHeight, qrSize + captionSpacing + recipientHeight);
}
