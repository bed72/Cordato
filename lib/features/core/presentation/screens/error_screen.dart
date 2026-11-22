import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/enums/asset_enum.dart';
import 'package:cordato/features/core/presentation/widgets/images/image_widget.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/elevated_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/outline_button_widget.dart';

final class const ErrorScreen({
  super.key,
  required final String title,
  required final String description,
  required final String actionLabel,
  required final VoidCallback? onAction,
  final bool isLoading = false,
  final PreferredSizeWidget? appBar,
  final String? secondaryActionLabel,
  final VoidCallback? onSecondaryAction,
  final AssetEnum image = AssetEnum.genericError,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const .all(16.0),
                child: Column(
                  crossAxisAlignment: .stretch,
                  children: [
                    Expanded(child: Center(child: _buildMessage(context))),
                    const SizedBox(height: 40.0),
                    _buildFooter(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Column _buildMessage(BuildContext context) => Column(
    spacing: 16.0,
    mainAxisSize: .min,
    children: [
      ExcludeSemantics(
        child: ImageWidget(
          width: 200.0,
          height: 200.0,
          fit: .contain,
          alt: image.alt,
          source: image.source,
        ),
      ),
      const SizedBox(height: 16.0),
      Semantics(
        header: true,
        child: Text(
          title,
          textAlign: .center,
          style: context.typography.headlineSmall?.copyWith(
            fontWeight: .w600,
            color: context.colors.onSurface,
          ),
        ),
      ),
      Text(
        description,
        textAlign: .center,
        style: context.typography.bodyLarge?.copyWith(
          color: context.colors.onSurfaceVariant,
        ),
      ),
    ],
  );

  Column _buildFooter() => Column(
    spacing: 12.0,
    crossAxisAlignment: .stretch,
    children: [
      Semantics(
        button: isLoading ? true : null,
        enabled: isLoading ? false : null,
        label: isLoading ? actionLabel : null,
        child: ElevatedButtonWidget(
          isLoading: isLoading,
          onTap: isLoading ? null : onAction,
          child: Flexible(child: Text(actionLabel, textAlign: .center)),
        ),
      ),
      if (secondaryActionLabel case final label?)
        OutlineButtonWidget(
          onTap: isLoading ? null : onSecondaryAction,
          child: Flexible(child: Text(label, textAlign: .center)),
        ),
    ],
  );
}
