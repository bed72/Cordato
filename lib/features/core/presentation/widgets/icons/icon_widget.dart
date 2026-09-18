import 'package:flutter/material.dart';

class const IconWidget({
  super.key,
  required final IconData icon,
  final double? size,
  final Color? color,
  final FontWeight? fontWeight,
  final String? semanticsLabel,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Icon(
    icon,
    size: size,
    color: color,
    fontWeight: fontWeight,
    semanticLabel: semanticsLabel,
  );
}
