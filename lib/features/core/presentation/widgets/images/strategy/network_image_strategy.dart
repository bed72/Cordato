import 'package:cordato/features/core/presentation/widgets/circular_progress_indicator_widget.dart';
import 'package:flutter/material.dart';

import 'package:cordato/features/core/presentation/widgets/images/strategy/image_strategy.dart';

final class NetworkImageStrategy implements ImageStrategy {
  const NetworkImageStrategy();

  @override
  Widget build({
    required String source,
    required BoxFit? fit,
    required Color? color,
    required double? width,
    required double? height,
    required bool showLoading,
    required String? fallback,
    required String? semanticLabel,
  }) {
    return Image.network(
      source,
      fit: fit,
      width: width,
      color: color,
      height: height,
      isAntiAlias: true,
      filterQuality: .high,
      semanticLabel: semanticLabel,
      loadingBuilder: showLoading
          ? (_, child, progress) =>
                progress == null ? child : _loading(width, height)
          : null,
      errorBuilder: (_, _, _) =>
          _fallback(fallback, fit, width, height, showLoading),
    );
  }

  CircularProgressIndicatorWidget _loading(double? width, double? height) =>
      CircularProgressIndicatorWidget(width: width, height: height);

  Widget _fallback(
    String? fallback,
    BoxFit? fit,
    double? width,
    double? height,
    bool showLoading,
  ) {
    if (fallback == null) {
      return showLoading
          ? _loading(width, height)
          : SizedBox(width: width, height: height);
    }

    return Image.network(
      fallback,
      fit: fit,
      width: width,
      height: height,
      errorBuilder: (_, _, _) => SizedBox(width: width, height: height),
    );
  }
}
