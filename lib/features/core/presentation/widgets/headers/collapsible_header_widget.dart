import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/headers/collapsible_header_delegate.dart';

final class const CollapsibleHeaderWidget({
  super.key,
  required final String title,
  required final String description,
  required final Widget leading,
  final double? expandedContentMaxWidth,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SliverLayoutBuilder(
    builder: (context, constraints) {
      final width = constraints.crossAxisExtent;
      final textDirection = Directionality.of(context);
      final textScaler = MediaQuery.textScalerOf(context);
      final baseStyle = DefaultTextStyle.of(context).style;

      final expandedInset = math.max(
        16.0,
        (width - (expandedContentMaxWidth ?? width)) / 2.0,
      );
      final expandedStyle = baseStyle
          .merge(context.typography.headlineMedium)
          .copyWith(
            fontWeight: .w700,
            letterSpacing: -1.0,
            color: context.colors.onSurface,
          );
      final collapsedStyle = baseStyle
          .merge(context.typography.titleLarge)
          .copyWith(color: context.colors.onSurface, fontWeight: .w600);
      final descriptionStyle = baseStyle
          .merge(context.typography.bodyLarge)
          .copyWith(
            color: context.colors.onSurfaceVariant.withValues(alpha: 0.8),
          );

      double textHeight(String text, TextStyle style, double availableWidth) =>
          CollapsibleHeaderDelegate.measureTextHeight(
            text: text,
            style: style,
            width: availableWidth,
            textScaler: textScaler,
            textDirection: textDirection,
          );

      final collapsedExtent = math.max(
        kToolbarHeight,
        textHeight(title, collapsedStyle, width - 88.0) + 16.0,
      );
      final expandedExtent =
          collapsedExtent +
          24.0 +
          textHeight(title, expandedStyle, width - expandedInset * 2.0) +
          6.0 +
          textHeight(
            description,
            descriptionStyle,
            width - expandedInset * 2.0,
          ) +
          16.0;

      return SliverPersistentHeader(
        pinned: true,
        delegate: CollapsibleHeaderDelegate(
          title: title,
          width: width,
          leading: leading,
          textScaler: textScaler,
          description: description,
          expandedInset: expandedInset,
          textDirection: textDirection,
          expandedExtent: expandedExtent,
          collapsedExtent: collapsedExtent,
          expandedTitleStyle: expandedStyle,
          descriptionStyle: descriptionStyle,
          collapsedTitleStyle: collapsedStyle,
          reduceMotion: MediaQuery.disableAnimationsOf(context),
        ),
      );
    },
  );
}
