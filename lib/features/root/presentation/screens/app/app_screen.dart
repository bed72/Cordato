import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/enums/asset_enum.dart';
import 'package:cordato/features/core/presentation/widgets/images/image_widget.dart';

import 'package:cordato/features/session/presentation/commands/session_command.dart';
import 'package:cordato/features/root/presentation/screens/app/mixins/app_screen_state_mixin.dart';

final class const AppScreen({
  super.key,
  required final SessionCommand command,
  required final ValueChanged<BuildContext> onAuthenticated,
  required final ValueChanged<BuildContext> onUnauthenticated,
}) extends StatefulWidget {
  @override
  State<AppScreen> createState() => _AppScreenState();
}

final class _AppScreenState extends State<AppScreen> with AppScreenStateMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ImageWidget(
            width: 254,
            height: 254,
            fit: .contain,
            alt: AssetEnum.logo.alt,
            source: AssetEnum.logo.source,
          ),
        ),
      ),
    );
  }
}
