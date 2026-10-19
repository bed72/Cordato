import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart' show ModularNavigationX;

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/link_button_widget.dart';
import 'package:cordato/features/core/presentation/enums/route_enum.dart';

final class const SignUpFooterWidget({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6.0,
      alignment: .center,
      crossAxisAlignment: .center,
      children: [
        Text(
          'Não possui conta?',
          style: context.typography.bodySmall?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        LinkButtonWidget(
          label: 'Crie agora',
          onTap: () => context.replace(RouteEnum.authenticationSignUp.path),
        ),
      ],
    );
  }
}
