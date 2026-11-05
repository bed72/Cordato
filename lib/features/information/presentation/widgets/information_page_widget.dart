import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/widgets/buttons/back_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/headers/collapsible_header_widget.dart';

final class const InformationPageWidget({
  super.key,
  required final String title,
  required final String description,
  required final List<Widget> children,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SelectionArea(
          child: CustomScrollView(
            slivers: [
              CollapsibleHeaderWidget(
                title: title,
                description: description,
                expandedContentMaxWidth: 680.0,
                leading: BackButtonWidget(onPress: () => context.pop()),
              ),
              SliverPadding(
                padding: .fromLTRB(
                  16.0,
                  8.0,
                  16.0,
                  32.0 + MediaQuery.paddingOf(context).bottom,
                ),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680.0),
                      child: Column(
                        spacing: 24.0,
                        crossAxisAlignment: .stretch,
                        children: children,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
