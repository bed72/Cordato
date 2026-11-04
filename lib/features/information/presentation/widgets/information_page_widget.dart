import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/widgets/header_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/back_button_widget.dart';

final class const InformationPageWidget({
  super.key,
  required final String title,
  required final String description,
  required final List<Widget> children,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 72.0,
        leading: BackButtonWidget(onPress: () => context.pop()),
      ),
      body: SafeArea(
        child: SelectionArea(
          child: SingleChildScrollView(
            padding: const .fromLTRB(16.0, 16.0, 16.0, 32.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680.0),
                child: Column(
                  spacing: 24.0,
                  crossAxisAlignment: .stretch,
                  children: [
                    HeaderWidget(title: title, description: description),
                    ...children,
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
