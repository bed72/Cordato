import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:cordato/features/dashboard/presentation/widgets/speech_bar_widget.dart';
import 'package:cordato/features/dashboard/presentation/screens/bloc/speech_bloc.dart';
import 'package:cordato/features/dashboard/presentation/screens/bloc/speech_state.dart';
import 'package:cordato/features/dashboard/presentation/widgets/mixins/dashboard_speech_state_mixin.dart';

final class const ActionButtonDashboardWidget({
  super.key,
  required final SpeechBloc bloc,
}) extends StatefulWidget {
  @override
  State<ActionButtonDashboardWidget> createState() =>
      _ActionButtonDashboardWidgetState();
}

final class _ActionButtonDashboardWidgetState
    extends State<ActionButtonDashboardWidget>
    with
        SingleTickerProviderStateMixin,
        WidgetsBindingObserver,
        DashboardSpeechStateMixin {
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    bottom: false,
    child: BlocConsumer<SpeechBloc, SpeechState>(
      bloc: widget.bloc,
      listener: (_, state) => handleSpeechState(state),
      builder: (context, state) => AnimatedBuilder(
        animation: expansion,
        builder: (context, _) => SpeechBarWidget(
          expansion: expansion.value,
          state: state,
          onOpenExpense: openExpense,
          onStartCapture: startSpeech,
          onCancelCapture: cancelSpeech,
          onSubmitCapture: submitSpeech,
        ),
      ),
    ),
  );
}
