import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:cordato/features/core/presentation/widgets/fields/autocomplete_text_controller.dart';
import 'package:cordato/features/core/presentation/widgets/fields/autocomplete_text_field_widget.dart';

mixin AutocompleteTextFieldStateMixin<T extends Object>
    on State<AutocompleteTextFieldWidget<T>> {
  late AutocompleteTextController fieldController;
  final FocusNode focus = FocusNode();
  final GlobalKey fieldKey = GlobalKey();
  int focusRevision = 0;
  int _revision = 0;
  String? _queryText;
  bool _selecting = false;
  bool _hadOptions = false;
  bool _synchronizing = false;
  bool _wasComposing = false;
  bool optionsAreCurrent = false;
  Future<Iterable<T>>? _pending;
  OptionsViewOpenDirection optionsDirection = OptionsViewOpenDirection.down;

  @override
  void initState() {
    super.initState();
    fieldController = AutocompleteTextController(widget.controller.value);
    fieldController.addListener(_syncToExternal);
    widget.controller.addListener(_syncFromExternal);
    focus.addListener(_focusChanged);
  }

  @override
  void didUpdateWidget(AutocompleteTextFieldWidget<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncFromExternal);
      widget.controller.addListener(_syncFromExternal);
      _syncFromExternal();
      invalidateOptions();
    }
    if (oldWidget.enabled && !widget.enabled) {
      invalidateOptions();
      focus.unfocus();
    }
  }

  void _syncToExternal() {
    if (_synchronizing) return;
    _synchronizing = true;
    widget.controller.value = fieldController.value;
    _synchronizing = false;
    final composing = !fieldController.value.composing.isCollapsed;
    if (_wasComposing && !composing && focus.hasFocus) {
      refreshOptionsEngine();
    } else if (composing) {
      invalidateOptions();
    }
    _wasComposing = composing;
    if (!_selecting && fieldController.text != _queryText) {
      optionsAreCurrent = false;
      if (mounted) setState(() {});
    }
  }

  void _syncFromExternal() {
    if (_synchronizing) return;
    _synchronizing = true;
    fieldController.value = widget.controller.value;
    _synchronizing = false;
  }

  void _focusChanged() {
    invalidateOptions();
    if (!focus.hasFocus || !widget.enabled) return;
    final box = fieldKey.currentContext?.findRenderObject();
    final media = MediaQuery.of(context);
    if (box is RenderBox && box.hasSize) {
      final top = box.localToGlobal(Offset.zero).dy;
      final below =
          media.size.height - media.viewInsets.bottom - top - box.size.height;
      optionsDirection = below < 200 && top > below
          ? OptionsViewOpenDirection.up
          : OptionsViewOpenDirection.down;
    }
    refreshOptionsEngine();
  }

  void refreshOptionsEngine() {
    setState(() => focusRevision++);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && focus.hasFocus && widget.enabled) {
        fieldController.refreshOptions();
      }
    });
  }

  void invalidateOptions() {
    _revision++;
    _queryText = null;
    _pending = null;
    optionsAreCurrent = false;
    _hadOptions = false;
    widget.onInvalidated();
  }

  void dismissOptions() {
    invalidateOptions();
    setState(() {});
  }

  Future<Iterable<T>> buildOptions(TextEditingValue value) {
    if (!widget.enabled ||
        !focus.hasFocus ||
        !value.composing.isCollapsed ||
        _selecting) {
      return Future.value(const []);
    }
    if (_queryText == value.text && _pending != null) return _pending!;
    final revision = ++_revision;
    _queryText = value.text;
    optionsAreCurrent = false;
    return _pending = _resolveOptions(value, revision);
  }

  Future<Iterable<T>> _resolveOptions(
    TextEditingValue value,
    int revision,
  ) async {
    final options = await widget.optionsBuilder(value);
    if (!mounted ||
        revision != _revision ||
        !widget.enabled ||
        !focus.hasFocus) {
      return const [];
    }
    _hadOptions = options.isNotEmpty;
    setState(() => optionsAreCurrent = true);
    return options;
  }

  void selectOption(T option) {
    _selecting = true;
    invalidateOptions();
    widget.onSelected(option);
    _selecting = false;
    focus.unfocus();
  }

  void submitField(String value, VoidCallback selectHighlighted) {
    if (optionsAreCurrent && _hadOptions) {
      selectHighlighted();
    } else {
      invalidateOptions();
      widget.onSubmitted?.call(value);
    }
  }

  @override
  void dispose() {
    _revision++;
    widget.controller.removeListener(_syncFromExternal);
    fieldController.removeListener(_syncToExternal);
    focus.removeListener(_focusChanged);
    widget.onInvalidated();
    fieldController.dispose();
    focus.dispose();
    super.dispose();
  }
}
