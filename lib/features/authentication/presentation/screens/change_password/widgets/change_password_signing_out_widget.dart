import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/header_widget.dart';

final class const ChangePasswordSigningOutWidget({super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: .all(16.0),
          child: Column(
            spacing: 24.0,
            mainAxisSize: .min,
            children: [
              HeaderWidget(
                title: 'Sua senha foi alterada',
                description: 'Estamos encerrando sua sessão.',
              ),
              CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    ),
  );
}
