import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:cordato/features/expense/domain/entities/expense_suggestion_entity.dart';
import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_suggestions_event.dart';
import 'package:cordato/features/expense/presentation/screens/expense/bloc/expense_suggestions_state.dart';
import 'package:cordato/features/expense/presentation/screens/expense/widgets/fields/expense_description_field_widget.dart';

mixin ExpenseDescriptionFieldStateMixin
    on State<ExpenseDescriptionFieldWidget> {
  StreamSubscription<ExpenseSuggestionsState>? _subscription;
  Completer<Iterable<ExpenseSuggestionEntity>>? _pending;
  int _revision = 0;

  Future<Iterable<ExpenseSuggestionEntity>> lookup(TextEditingValue value) {
    invalidate();
    if (!widget.enabled || widget.suggestionsBloc.isClosed) {
      return Future.value(const []);
    }

    final revision = ++_revision;
    final pending = Completer<Iterable<ExpenseSuggestionEntity>>();

    _pending = pending;
    _subscription = widget.suggestionsBloc.stream.listen(
      (state) {
        if (state.revision != revision || pending.isCompleted) return;
        switch (state) {
          case ExpenseSuggestionsSuccess(:final suggestions):
            pending.complete(suggestions.take(1));
          case ExpenseSuggestionsFailure() || ExpenseSuggestionsIdle():
            pending.complete(const []);
          case ExpenseSuggestionsLoading():
            return;
        }
        unawaited(_subscription?.cancel());
        _subscription = null;
      },
      onDone: () {
        if (!pending.isCompleted) pending.complete(const []);
      },
    );

    widget.suggestionsBloc.add(
      ExpenseSuggestionsRequested(revision: revision, query: value.text.trim()),
    );

    return pending.future;
  }

  void invalidate() {
    _revision++;
    final pending = _pending;
    if (pending != null && !pending.isCompleted) pending.complete(const []);

    _pending = null;
    unawaited(_subscription?.cancel());
    _subscription = null;
    if (!widget.suggestionsBloc.isClosed) {
      widget.suggestionsBloc.add(
        ExpenseSuggestionsInvalidated(revision: _revision),
      );
    }
  }

  @override
  void didUpdateWidget(ExpenseDescriptionFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.suggestionsBloc != widget.suggestionsBloc) {
      if (!oldWidget.suggestionsBloc.isClosed) {
        oldWidget.suggestionsBloc.add(
          ExpenseSuggestionsInvalidated(revision: ++_revision),
        );
      }
      invalidate();
    }
  }

  @override
  void dispose() {
    invalidate();
    super.dispose();
  }
}
