import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/screens/error/error_screen.dart';

final class const CodeUnavailableWidget({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ErrorScreen(
    title: 'Solicite um código',
    actionLabel: 'Informar e-mail',
    onAction: () => context.replace(RouteEnum.authenticationSignIn.path),
    description: 'Informe seu e-mail para receber um novo código de acesso.',
  );
}
