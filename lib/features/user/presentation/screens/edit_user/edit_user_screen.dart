import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/header_widget.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/fields/text_field_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/elevated_button_widget.dart';

import 'package:cordato/features/user/presentation/screens/edit_user/widgets/edit_user_app_bar_widget.dart';

final class const EditUserScreen({
  super.key,
  required final String initialName,
  required final ValueChanged<BuildContext> onBackPressed,
  final String? nameFailure,
  final VoidCallback? onUpdatePressed,
  final ValueChanged<String>? onNameChanged,
  final bool isLoading = false,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: EditUserAppBarWidget(onBackPressed: onBackPressed),
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
                    keyboardDismissBehavior: .onDrag,
                    padding: const .symmetric(vertical: 24.0),
                    child: Column(
                      spacing: 24.0,
                      crossAxisAlignment: .stretch,
                      children: [
                        const HeaderWidget(
                          title: 'Nome',
                          description: 'Atualize o seu nome de exibição.',
                        ),
                        TextFieldWidget(
                          hint: 'Nome',
                          label: 'Nome',
                          inputAction: .done,
                          enabled: !isLoading,
                          keyboardType: .name,
                          failure: nameFailure,
                          onChanged: onNameChanged,
                          initialValue: initialName,
                          textCapitalization: .words,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ElevatedButtonWidget(
                label: 'Atualizar',
                isLoading: isLoading,
                onTap: isLoading || onUpdatePressed == null
                    ? null
                    : () {
                        context.dismissKeyboard();
                        onUpdatePressed!();
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
