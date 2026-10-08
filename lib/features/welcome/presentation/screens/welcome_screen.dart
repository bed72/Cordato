import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/welcome/presentation/widgets/welcome_icon_widget.dart';
import 'package:cordato/features/welcome/presentation/widgets/welcome_slogan_widget.dart';
import 'package:cordato/features/welcome/presentation/widgets/welcome_footer_widget.dart';

class const WelcomeScreen({
  super.key,
  required final ValueChanged<BuildContext> onContinueWithEmail,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Padding(
          padding: const .symmetric(horizontal: 16.0, vertical: 32.0),
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  mainAxisAlignment: .end,
                  children: [
                    const WelcomeIconWidget(),
                    const WelcomeSloganWidget(),
                    WelcomeFooterWidget(
                      onContinueWithEmail: onContinueWithEmail,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
