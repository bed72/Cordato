import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/enums/asset_enum.dart';
import 'package:cordato/features/core/presentation/widgets/images/image_widget.dart';

import 'package:cordato/features/session/presentation/commands/session_command.dart';
import 'package:cordato/features/session/presentation/screens/splash/mixins/splash_screen_state_mixin.dart';

final class const SplashScreen({
  super.key,
  required final SessionCommand command,
  required final ValueChanged<BuildContext> onAuthenticated,
  required final ValueChanged<BuildContext> onUnauthenticated,
}) extends StatefulWidget {
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

final class _SplashScreenState extends State<SplashScreen>
    with SplashScreenStateMixin {
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
