import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/toast/toast.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/link_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/elevated_button_widget.dart';

final class WelcomeFooterWidget extends StatelessWidget {
  final ValueChanged<BuildContext> onContinueWithEmail;

  const WelcomeFooterWidget({super.key, required this.onContinueWithEmail});

  void _showTerms(BuildContext context) {
    context.showToast(
      title: 'Termos de uso',
      description: 'Em breve você poderá consultar nossos termos.',
      variant: ToastVariant.info,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .only(top: 32.0),
      child: Column(
        children: [
          SizedBox(
            height: 56.0,
            width: .infinity,
            child: ElevatedButtonWidget(
              label: 'Continuar com e-mail',
              onTap: () => onContinueWithEmail(context),
            ),
          ),
          const SizedBox(height: 32.0),
          Text(
            'Ao continuar você concorda com nossos',
            maxLines: 1,
            textAlign: .center,
            overflow: .ellipsis,
            style: context.typography.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6.0),
          Wrap(
            spacing: 6.0,
            alignment: .center,
            crossAxisAlignment: .center,
            children: [
              LinkButtonWidget(
                label: 'Termos de uso',
                onTap: () => _showTerms(context),
              ),
              Text(
                'e',
                style: context.typography.bodySmall?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              LinkButtonWidget(label: 'Políticas de Privacidade', onTap: () {}),
            ],
          ),
        ],
      ),
    );
  }
}
