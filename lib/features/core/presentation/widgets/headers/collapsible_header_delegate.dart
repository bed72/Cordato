import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/animations/collapsible_header_transition.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

final class const CollapsibleHeaderDelegate({
  required final String title,
  required final double width,
  required final Widget leading,
  required final bool reduceMotion,
  required final String description,
  required final double expandedInset,
  required final TextScaler textScaler,
  required final double expandedExtent,
  required final double collapsedExtent,
  required final TextStyle descriptionStyle,
  required final TextDirection textDirection,
  required final TextStyle expandedTitleStyle,
  required final TextStyle collapsedTitleStyle,
}) extends SliverPersistentHeaderDelegate {
  @override
  double get minExtent => collapsedExtent;

  @override
  double get maxExtent => expandedExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final transition = CollapsibleHeaderTransition.fromScroll(
      shrinkOffset: shrinkOffset,
      expandedExtent: maxExtent,
      collapsedExtent: minExtent,
      reduceMotion: reduceMotion,
    );
    final titleStyle = TextStyle.lerp(
      expandedTitleStyle,
      collapsedTitleStyle,
      transition.fraction,
    )!;
    final titleStart = transition.interpolate(
      collapsed: 72.0,
      expanded: expandedInset,
    );
    final titleEnd = transition.interpolate(
      collapsed: 16.0,
      expanded: expandedInset,
    );
    final titleHeight = measureTextHeight(
      text: title,
      style: titleStyle,
      textScaler: textScaler,
      textDirection: textDirection,
      width: width - titleStart - titleEnd,
    );
    final extent = (maxExtent - shrinkOffset).clamp(minExtent, maxExtent);
    final titleTop = math.min(
      transition.interpolate(
        expanded: minExtent + 24.0,
        collapsed: (minExtent - titleHeight) / 2.0,
      ),
      math.max(0.0, extent - titleHeight),
    );

    return ClipRect(
      child: Material(
        color: context.colors.surfaceContainerLowest,
        child: Stack(
          fit: .expand,
          children: [
            PositionedDirectional(
              start: 16.0,
              width: 48.0,
              height: 48.0,
              top: (minExtent - 48.0) / 2.0,
              child: leading,
            ),
            PositionedDirectional(
              end: titleEnd,
              top: titleTop,
              start: titleStart,
              child: Semantics(
                header: true,
                child: Text(title, style: titleStyle),
              ),
            ),
            PositionedDirectional(
              end: expandedInset,
              start: expandedInset,
              top: titleTop + titleHeight + 6.0,
              child: ExcludeSemantics(
                excluding: transition.descriptionOpacity == 0.0,
                child: Opacity(
                  opacity: transition.descriptionOpacity,
                  child: Text(description, style: descriptionStyle),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static double measureTextHeight({
    required String text,
    required double width,
    required TextStyle style,
    required TextScaler textScaler,
    required TextDirection textDirection,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout(maxWidth: math.max(1.0, width));

    final height = painter.height;
    painter.dispose();
    return height;
  }

  @override
  bool shouldRebuild(covariant CollapsibleHeaderDelegate oldDelegate) =>
      title != oldDelegate.title ||
      width != oldDelegate.width ||
      leading != oldDelegate.leading ||
      textScaler != oldDelegate.textScaler ||
      description != oldDelegate.description ||
      reduceMotion != oldDelegate.reduceMotion ||
      textDirection != oldDelegate.textDirection ||
      expandedInset != oldDelegate.expandedInset ||
      expandedExtent != oldDelegate.expandedExtent ||
      collapsedExtent != oldDelegate.collapsedExtent ||
      descriptionStyle != oldDelegate.descriptionStyle ||
      expandedTitleStyle != oldDelegate.expandedTitleStyle ||
      collapsedTitleStyle != oldDelegate.collapsedTitleStyle;
}
