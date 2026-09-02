import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/welcome/presentation/widgets/welcome_typewriter.dart';
import 'package:material_ui/material_ui.dart';

final class WelcomeSloganWidget extends StatelessWidget {
  const WelcomeSloganWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 6.0,
      mainAxisSize: .min,
      children: [
        Semantics(
          header: true,
          child: Text(
            'A maneira mais simples de cuidar do seu dinheiro',
            textAlign: .center,
            style: context.typography.headlineLarge?.copyWith(
              color: context.colors.onSurface,
              fontWeight: .w600,
              letterSpacing: -0.6,
            ),
          ),
        ),
        WelcomeTypewriterWidget(
          color: context.colors.onSurfaceVariant.withValues(alpha: 0.65),
        ),
      ],
    );
  }
}
