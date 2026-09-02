import 'package:cordato/features/core/presentation/widgets/images/image_widget.dart';
import 'package:material_ui/material_ui.dart';

final class WelcomeIconWidget extends StatelessWidget {
  const WelcomeIconWidget({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 254.0,
    height: 254.0,
    child: Center(
      child: ImageWidget(
        fit: .contain,
        alt: 'Logo Trocado',
        source: 'assets/images/logo.webp',
      ),
    ),
  );
}
