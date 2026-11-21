import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:cordato/features/dashboard/presentation/widgets/audio_bar_widget.dart';
import 'package:cordato/features/dashboard/presentation/screens/bloc/audio_state.dart';
import 'package:cordato/features/dashboard/presentation/widgets/mixins/dashboard_audio_state_mixin.dart';

final class const ActionButtonDashboardWidget({super.key})
    extends StatefulWidget {
  @override
  State<ActionButtonDashboardWidget> createState() =>
      _ActionButtonDashboardWidgetState();
}

final class _ActionButtonDashboardWidgetState
    extends State<ActionButtonDashboardWidget>
    with
        SingleTickerProviderStateMixin,
        WidgetsBindingObserver,
        DashboardAudioStateMixin {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: BlocConsumer<AudioBloc, AudioState>(
        bloc: widget.bloc,
        listener: (_, state) => handleAudioState(state),
        builder: (context, state) => AnimatedBuilder(
          animation: expansion,
          builder: (context, _) => AudioBarWidget(
            state: state,
            expansion: expansion.value,
            onOpenExpense: openExpense,
            onStartCapture: startAudio,
            onCancelCapture: cancelAudio,
            onSubmitCapture: submitAudio,
          ),
        ),
      ),
    );
  }
}
