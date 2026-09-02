import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/welcome/presentation/widgets/welcome_hero.dart';
import 'package:cordato/features/welcome/presentation/widgets/welcome_slogan.dart';
import 'package:cordato/features/welcome/presentation/widgets/welcome_footer.dart';

class WelcomeScreen extends StatelessWidget {
  final ValueChanged<BuildContext> onContinueWithEmail;

  const WelcomeScreen({super.key, required this.onContinueWithEmail});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const .symmetric(horizontal: 16.0, vertical: 32.0),
          child: Column(
            children: [
              const Expanded(
                child: Align(
                  alignment: .bottomCenter,
                  child: Column(
                    mainAxisSize: .min,
                    children: [WelcomeIconWidget(), WelcomeSloganWidget()],
                  ),
                ),
              ),
              WelcomeFooterWidget(onContinueWithEmail: onContinueWithEmail),
            ],
          ),
        ),
      ),
    );
  }
}
