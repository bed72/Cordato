import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/authentication/presentation/commands/magic_link_command.dart';
import 'package:cordato/features/authentication/presentation/validators/email_validation.dart';

import 'package:cordato/features/authentication/presentation/widgets/field_magic_link_widget.dart';
import 'package:cordato/features/authentication/presentation/widgets/header_magic_link_widget.dart';
import 'package:cordato/features/authentication/presentation/widgets/app_bar_magic_link_widget.dart';
import 'package:cordato/features/authentication/presentation/mixins/magic_link_screen_state_mixin.dart';
import 'package:cordato/features/authentication/presentation/widgets/button_magic_link_builder_widget.dart';

final class const MagicLinkScreen({
  super.key,
  required final MagicLinkCommand command,
  required final EmailValidation validation,
  required final ValueChanged<BuildContext> onConfirmationCode,
}) extends StatefulWidget {
  @override
  State<MagicLinkScreen> createState() => _MagicLinkScreenState();
}

final class _MagicLinkScreenState extends State<MagicLinkScreen>
    with MagicLinkScreenStateMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBarMagicLinkWidget(),
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
                        const HeaderMagicLinkWidget(),
                        FieldMagicLinkWidget(
                          failure: failure,
                          controller: controller,
                          onChanged: clearFailure,
                          onSubmitted: (_) => sendMagicLink(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ButtonMagicLinkBuilderWidget(
                command: widget.command,
                onPressed: sendMagicLink,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
