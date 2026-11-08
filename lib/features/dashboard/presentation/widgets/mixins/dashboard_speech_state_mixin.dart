import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' show ModularNavigationX;

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/widgets/toast/toast.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/expense/domain/entities/expense_entity.dart';
import 'package:cordato/features/dashboard/application/enums/speech_failure_enum.dart';
import 'package:cordato/features/dashboard/presentation/formatters/speech_error_formatter.dart';
import 'package:cordato/features/dashboard/presentation/screens/bloc/dashboard_bloc.dart';
import 'package:cordato/features/dashboard/presentation/screens/bloc/dashboard_event.dart';
import 'package:cordato/features/dashboard/presentation/screens/bloc/speech_event.dart';
import 'package:cordato/features/dashboard/presentation/screens/bloc/speech_state.dart';
import 'package:cordato/features/dashboard/presentation/widgets/action_button_dashboard_widget.dart';

mixin DashboardSpeechStateMixin
    on
        State<ActionButtonDashboardWidget>,
        TickerProvider,
        WidgetsBindingObserver {
  late final AnimationController expansion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 240),
  )..addStatusListener(_animationStatus);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    expansion.duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 240);

    if (ModalRoute.of(context)?.isCurrent == false) {
      _discardForLifecycle();
    }
  }

  @override
  void didUpdateWidget(covariant ActionButtonDashboardWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (identical(oldWidget.bloc, widget.bloc)) {
      return;
    }

    if (!oldWidget.bloc.isClosed) {
      oldWidget.bloc.add(const SpeechCancelled(lifecycle: true));
    }

    expansion.value = 0;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _discardForLifecycle();
    expansion.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        return;
      case AppLifecycleState.inactive when widget.bloc.state is SpeechPreparing:
        return;
      default:
        _discardForLifecycle();
    }
  }

  void _discardForLifecycle() {
    if (!widget.bloc.isClosed) {
      widget.bloc.add(const SpeechCancelled(lifecycle: true));
    }
  }

  void startSpeech() {
    if (ModalRoute.of(context)?.isCurrent != false) {
      widget.bloc.add(const SpeechStarted());
    }
  }

  void cancelSpeech() => widget.bloc.add(const SpeechCancelled());
  void submitSpeech() => widget.bloc.add(const SpeechSubmitted());

  void handleSpeechState(SpeechState state) {
    switch (state) {
      case SpeechCollapsing(:final failure):
        if (failure != null) {
          _showCaptureFailure(failure);
        }

        _collapseBar();
      case SpeechIdle():
        expansion.value = 0;
      default:
        if (state.expanded) {
          expansion.forward();
        }
    }
  }

  void _showCaptureFailure(SpeechFailureEnum failure) {
    if (ModalRoute.of(context)?.isCurrent == false) {
      return;
    }

    context.showToast(
      title: SpeechErrorFormatter.title(failure),
      description: SpeechErrorFormatter.description(failure),
      variant: ToastVariant.warning,
    );
  }

  void _collapseBar() {
    if (expansion.isDismissed) {
      _confirmCollapse();
      return;
    }

    expansion.reverse();
  }

  void _animationStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) {
      _confirmCollapse();
    }
  }

  void _confirmCollapse() {
    if (!mounted || widget.bloc.isClosed) {
      return;
    }

    final captureState = widget.bloc.state;

    if (captureState is! SpeechCollapsing ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }

    widget.bloc.add(SpeechCollapsed(captureState.operation));
  }

  Future<void> openExpense() async {
    if (ModalRoute.of(context)?.isCurrent == false) {
      return;
    }

    final bloc = context.read<DashboardBloc>();
    final expense = await context.pushNamed<ExpenseEntity>(
      RouteEnum.expense.path,
      arguments: (returnToPrevious: true),
    );

    if (expense != null &&
        mounted &&
        !bloc.isClosed &&
        identical(context.read<DashboardBloc>(), bloc)) {
      bloc.add(DashboardExpensesChanged());
    }
  }
}
