import 'package:material_ui/material_ui.dart';

final class MagicLinkMessage extends StatelessWidget {
  final String message;
  final Color color;

  const MagicLinkMessage({
    super.key,
    required this.message,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      textAlign: TextAlign.center,
      style: TextStyle(color: color),
    );
  }
}
