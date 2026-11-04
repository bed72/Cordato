import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:cordato/features/core/presentation/enums/route_enum.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/link_button_widget.dart';

final class const SignInFooterWidget({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 6.0,
      mainAxisSize: .min,
      crossAxisAlignment: .center,
      children: [
        Text(
          'Já possui conta?',
          textAlign: .center,
          style: context.typography.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        LinkButtonWidget(
          label: 'Entrar',
          onTap: () => context.replace(RouteEnum.authenticationSignIn.path),
        ),
      ],
    );
  }
}
