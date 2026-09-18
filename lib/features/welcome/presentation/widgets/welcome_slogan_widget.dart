import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/welcome/presentation/widgets/welcome_typewriter.dart';
import 'package:material_ui/material_ui.dart';

const _supportingPhrases = [
  'no dia a dia.',
  'sem complicação.',
  'com mais clareza.',
  'junto com quem importa.',
];

final class const WelcomeSloganWidget({super.key}) extends StatelessWidget {
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
            style: context.typography.headlineMedium?.copyWith(
              fontWeight: .w600,
              letterSpacing: -0.6,
              color: context.colors.onSurface,
            ),
          ),
        ),
        WelcomeTypewriterWidget(
          color: context.colors.onSurfaceVariant.withValues(alpha: 0.65),
          phrases: _supportingPhrases,
        ),
      ],
    );
  }
}
