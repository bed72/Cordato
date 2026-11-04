final class const CollapsibleHeaderTransition({
  required final double fraction,
}) {
  factory CollapsibleHeaderTransition.fromScroll({
    required double shrinkOffset,
    required double expandedExtent,
    required double collapsedExtent,
    bool reduceMotion = false,
  }) {
    final range = expandedExtent - collapsedExtent;
    final progress = range <= 0.0
        ? 1.0
        : (shrinkOffset / range).clamp(0.0, 1.0).toDouble();

    return CollapsibleHeaderTransition(
      fraction: reduceMotion ? (progress < 0.5 ? 0.0 : 1.0) : progress,
    );
  }

  double get descriptionOpacity =>
      (1.0 - fraction * 2.0).clamp(0.0, 1.0).toDouble();

  double interpolate({required double expanded, required double collapsed}) =>
      expanded + (collapsed - expanded) * fraction;
}
