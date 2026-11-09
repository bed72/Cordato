import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/icon_button_widget.dart';

import 'package:cordato/features/dashboard/presentation/screens/bloc/audio_state.dart';
import 'package:cordato/features/dashboard/presentation/widgets/audio_waveform_widget.dart';

final class const AudioControlsWidget({
  super.key,
  required final AudioState state,
  required final VoidCallback onCancel,
  required final VoidCallback onSubmit,
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
              iconColor: context.colors.onSurface,
              backgroundColor: context.colors.surface,
              onPress: state.canCancel ? onCancel : null,
              borderRadius: context.radius.cornerRadius050,
            ),
          ),
          Expanded(child: _feedback(context)),
          Semantics(
            label: 'Finalizar captura de fala',
            child: IconButtonWidget(
              width: 40,
              height: 40,
              iconSize: 24,
              icon: Icons.arrow_upward,
              iconColor: context.colors.onPrimary,
              backgroundColor: context.colors.primary,
              onPress: state.canSubmit ? onSubmit : null,
              borderRadius: context.radius.cornerRadius050,
            ),
          ),
        ],
      ),
    );
  }

  Widget _feedback(BuildContext context) => switch (state) {
    AudioListening(:final levels) => Semantics(
      liveRegion: true,
      label: 'Ouvindo fala',
      child: AudioWaveformWidget(levels: levels),
    ),
    _ => Semantics(
      liveRegion: true,
      child: Text(
        switch (state) {
          AudioPreparing() => 'Preparando…',
          AudioFinalizing() => 'Finalizando…',
          AudioReady() => 'Fala concluída. Toque na seta.',
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
