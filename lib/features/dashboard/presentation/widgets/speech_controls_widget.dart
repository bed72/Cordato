import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/icon_button_widget.dart';

import 'package:cordato/features/dashboard/presentation/widgets/speech_waveform_widget.dart';
import 'package:cordato/features/dashboard/presentation/screens/bloc/speech_state.dart';

final class const SpeechControlsWidget({
  super.key,
  required final VoidCallback onCancel,
  required final VoidCallback onSubmit,
  required final SpeechState state,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        spacing: 8,
        children: [
          Semantics(
            label: 'Cancelar e descartar fala',
            child: IconButtonWidget(
              icon: Icons.close,
              width: 40,
              height: 40,
              iconSize: 24,
              borderRadius: context.radius.cornerRadius050,
              onPress: state.canCancel ? onCancel : null,
              backgroundColor: context.colors.surface,
              iconColor: context.colors.onSurface,
            ),
          ),
          Expanded(child: _feedback(context)),
          Semantics(
            label: 'Finalizar captura de fala',
            child: IconButtonWidget(
              icon: Icons.arrow_upward,
              width: 40,
              height: 40,
              iconSize: 24,
              borderRadius: context.radius.cornerRadius050,
              onPress: state.canSubmit ? onSubmit : null,
              backgroundColor: context.colors.primary,
              iconColor: context.colors.onPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _feedback(BuildContext context) => switch (state) {
    SpeechListening(:final levels) => Semantics(
      liveRegion: true,
      label: 'Ouvindo fala',
      child: SpeechWaveformWidget(levels: levels),
    ),
    _ => Semantics(
      liveRegion: true,
      child: Text(
        switch (state) {
          SpeechPreparing() => 'Preparando…',
          SpeechFinalizing() => 'Finalizando…',
          SpeechReady() => 'Fala concluída. Toque na seta.',
          _ => 'Concluindo…',
        },
        maxLines: 1,
        textAlign: .center,
        overflow: .ellipsis,
        style: context.typography.labelMedium?.copyWith(
          fontSize: 13,
          color: context.colors.onSurface,
        ),
      ),
    ),
  };
}
