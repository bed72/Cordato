import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

import 'package:cordato/features/core/presentation/widgets/toast/toast.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/text_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/icons/background_icon_widget.dart';

final class ToastWidget extends StatelessWidget {
  final ToastData data;
  final VoidCallback onDismiss;

  const ToastWidget({super.key, required this.data, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final palette = getToastPalette(context, data.variant);

    return Semantics(
      container: true,
      liveRegion: true,
      child: GestureDetector(
        onHorizontalDragEnd: (details) {
          if ((details.primaryVelocity ?? 0).abs() > 200) onDismiss();
        },
        child: Material(
          color: palette.background,
          child: Container(
            width: .infinity,
            constraints: const BoxConstraints(minHeight: 72.0),
            padding: .fromLTRB(
              16.0,
              MediaQuery.paddingOf(context).top + 12.0,
              16.0,
              20.0,
            ),
            child: IntrinsicHeight(
              child: Row(
                spacing: 10.0,
                crossAxisAlignment: .stretch,
                children: [
                  Semantics(
                    label: getToastAccessibilityLabel(data.variant),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minWidth: 48.0,
                        minHeight: 48.0,
                      ),
                      child: AspectRatio(
                        aspectRatio: 1.0,
                        child: BackgroundIconWidget(
                          iconSize: 24.0,
                          width: .infinity,
                          height: .infinity,
                          iconColor: palette.foreground,
                          icon: getToastIcon(data.variant),
                          color: Color.lerp(
                            palette.background,
                            Colors.black,
                            .6,
                          )!,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      spacing: 2.0,
                      mainAxisSize: .min,
                      mainAxisAlignment: .center,
                      crossAxisAlignment: .start,
                      children: [
                        Text(
                          data.title,
                          maxLines: 1,
                          overflow: .ellipsis,
                          style: context.typography.bodyMedium?.copyWith(
                            fontWeight: .w600,
                            color: palette.foreground,
                          ),
                        ),
                        if (data.description != null)
                          Text(
                            data.description!,
                            maxLines: 2,
                            overflow: .ellipsis,
                            style: context.typography.bodySmall?.copyWith(
                              color: palette.foreground.withValues(alpha: .72),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (data.action != null)
                    TextButtonWidget(
                      onTap: () {
                        onDismiss();
                        data.action!.onPressed();
                      },
                      child: Text(
                        data.action!.label,
                        style: context.typography.labelMedium?.copyWith(
                          fontWeight: .w700,
                          color: palette.foreground,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
