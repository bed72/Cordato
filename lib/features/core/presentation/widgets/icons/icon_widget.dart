import 'package:flutter/material.dart';

class IconWidget extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final double? size;
  final String? semanticsLabel;
  final FontWeight? fontWeight;

  const IconWidget({
    super.key,
    required this.icon,
    this.size,
    this.color,
    this.fontWeight,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) => Icon(
    icon,
    size: size,
    color: color,
    fontWeight: fontWeight,
    semanticLabel: semanticsLabel,
  );
}
