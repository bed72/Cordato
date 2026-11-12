import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

final class const AudioWaveformWidget({
  super.key,
  required final List<double> levels,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: 32,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final barCount = ((constraints.maxWidth + 5) / 8).floor().clamp(
              0,
              128,
            );
            final hiddenSamples = levels.length - barCount;
            final visibleLevels = hiddenSamples > 0
                ? levels.sublist(hiddenSamples)
                : levels;

            return Row(
              mainAxisAlignment: .spaceBetween,
              children: .generate(
                barCount,
                (index) => AnimatedContainer(
                  duration:
                      MediaQuery.disableAnimationsOf(context) ||
                          MediaQuery.reduceMotionOf(context)
                      ? .zero
                      : const Duration(milliseconds: 80),
                  width: 3,
                  height:
                      3 +
                      (index < visibleLevels.length
                              ? visibleLevels[index]
                              : 0) *
                          25,
                  decoration: BoxDecoration(
                    color: context.colors.onSurfaceVariant,
                    borderRadius: context.radius.cornerRadius100,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
