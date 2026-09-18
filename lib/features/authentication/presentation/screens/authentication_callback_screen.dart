import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/enums/asset_enum.dart';
import 'package:cordato/features/core/presentation/widgets/images/image_widget.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/authentication/presentation/widgets/animated_ellipsis_widget.dart';

final class const AuthenticationCallbackScreen({super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            spacing: 24.0,
            mainAxisSize: .min,
            children: [
              ImageWidget(
                width: 254.0,
                height: 254.0,
                alt: AssetEnum.logo.alt,
                source: AssetEnum.logo.source,
              ),
              Semantics(
                excludeSemantics: true,
                label: 'Validando acesso...',
                child: Row(
                  spacing: 1.0,
                  mainAxisSize: .min,
                  textBaseline: .alphabetic,
                  crossAxisAlignment: .baseline,
                  children: [
                    Text(
                      'Validando acesso',
                      style: context.typography.headlineSmall?.copyWith(
                        fontWeight: .w600,
                      ),
                    ),
                    AnimatedEllipsisWidget(
                      style: context.typography.headlineSmall?.copyWith(
                        fontWeight: .w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
