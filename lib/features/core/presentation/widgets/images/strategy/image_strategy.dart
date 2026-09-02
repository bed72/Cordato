import 'package:flutter/material.dart';

abstract interface class ImageStrategy {
  Widget build({
    required String source,
    required BoxFit? fit,
    required String? semanticLabel,
    required Color? color,
    required double? width,
    required double? height,
    required bool showLoading,
    required String? fallback,
  });
}
