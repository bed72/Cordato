import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart' show ModularNavigationX;

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/link_button_widget.dart';

final class const SignUpFooterWidget({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 6.0,
      mainAxisSize: .min,
      crossAxisAlignment: .stretch,
      children: [
        Text(
          'Não tem conta?',
          textAlign: .center,
          style: context.typography.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        Wrap(
          spacing: 6.0,
          alignment: .center,
          crossAxisAlignment: .center,
          children: [
            LinkButtonWidget(
              label: 'Crie uma',
              onTap: () => context.replace(RouteEnum.authenticationSignUp.path),
            ),
            Text(
              'ou',
              style: context.typography.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            LinkButtonWidget(
              label: 'recupere sua senha',
              onTap: () => context.pushNamed(
                RouteEnum.authenticationPasswordRecovery.path,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
