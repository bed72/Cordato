import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/fields/email_field_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/elevated_button_widget.dart';

import 'package:cordato/features/authentication/presentation/screens/confirm/widgets/header_confirm_widget.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_up/widgets/app_bar_sign_up_widget.dart';

final class const ConfirmScreen({
  super.key,
  required final String email,
  required final ValueChanged<BuildContext> onSignIn,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppBarSignUpWidget(),
      body: SafeArea(
        child: Padding(
          padding: const .fromLTRB(16.0, 0.0, 16.0, 24.0),
          child: Column(
            spacing: 16.0,
            crossAxisAlignment: .stretch,
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const .symmetric(vertical: 24.0),
                    child: Column(
                      spacing: 24.0,
                      crossAxisAlignment: .stretch,
                      children: [
                        const HeaderConfirmWidget(),
                        EmailFieldWidget(
                          enabled: false,
                          label: 'E-mail',
                          initialValue: email,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ElevatedButtonWidget(
                label: 'Reenviar',
                onTap: () => onSignIn(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
