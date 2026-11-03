import 'package:flutter/services.dart';
import 'package:flutter_lucide_animated/flutter_lucide_animated.dart' as lucide;
import 'package:material_ui/material_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/icon_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/icons/icon_widget.dart';
import 'package:cordato/features/core/presentation/widgets/fields/colored_text_selection_controls.dart';

class const TextFieldWidget({
  super.key,
  required final String hint,
  required final String label,
  final String? failure,
  final String? initialValue,
  final FocusNode? focusNode,
  final lucide.LucideAnimatedIconData? trailingIcon,
  final TextInputType? keyboardType,
  final TextInputAction? inputAction,
  final Iterable<String>? autofillHints,
  final VoidCallback? onTrailingIconTap,
  final ValueChanged<String>? onChanged,
  final TextEditingController? controller,
  final ValueChanged<String>? onSubmitted,
  final ValueChanged<bool>? onFocusChanged,
  final List<TextInputFormatter>? inputFormatters,
  final int maxLines = 1,
  final bool enabled = true,
  final bool readOnly = false,
  final bool absorbing = false,
  final bool autofocus = false,
  final bool obscureText = false,
  final bool hideTrailingIconWhenEmpty = false,
  final TextCapitalization textCapitalization = .none,
}) extends StatefulWidget {
  @override
  State<TextFieldWidget> createState() => _TextFieldWidgetState();
}

class _TextFieldWidgetState extends State<TextFieldWidget> {
  late FocusNode _focus;
  late TextEditingController _controller;

  bool _hasText = false;
  bool _isFocused = false;
  bool get _isFailure => widget.failure != null;

  Color _color() {
    final colors = context.colors;
    if (!widget.enabled) {
      return colors.onSurfaceVariant.withValues(alpha: .82);
    }
    if (_isFailure) return colors.error;
    if (_isFocused) return colors.primary;

    return colors.onSurfaceVariant;
  }

  @override
  void initState() {
    super.initState();
    _focus = widget.focusNode ?? FocusNode();
    _controller =
        widget.controller ??
        TextEditingController(text: widget.initialValue ?? '');

    _focus.addListener(_onFocusChange);
    _isFocused = _focus.hasFocus;

    _hasText = _controller.text.isNotEmpty;
    _controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(TextFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _focus.removeListener(_onFocusChange);
      if (oldWidget.focusNode == null) _focus.dispose();
      _focus = widget.focusNode ?? FocusNode();
      _focus.addListener(_onFocusChange);
      _isFocused = _focus.hasFocus;
    }
    if (oldWidget.controller != widget.controller) {
      final value = _controller.value;
      _controller.removeListener(_onControllerChanged);
      if (oldWidget.controller == null) _controller.dispose();

      _controller = widget.controller ?? TextEditingController.fromValue(value);
      _controller.addListener(_onControllerChanged);
      _hasText = _controller.text.isNotEmpty;
    }
    if (widget.controller == null &&
        oldWidget.controller == null &&
        widget.initialValue != oldWidget.initialValue &&
        _controller.text != (widget.initialValue ?? '')) {
      _controller.text = widget.initialValue ?? '';
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    if (widget.focusNode == null) _focus.dispose();

    _controller.removeListener(_onControllerChanged);
    if (widget.controller == null) _controller.dispose();

    super.dispose();
  }

  void _onFocusChange() {
    setState(() => _isFocused = _focus.hasFocus);
    widget.onFocusChanged?.call(_focus.hasFocus);
  }

  void _onControllerChanged() {
    setState(() => _hasText = _controller.text.isNotEmpty);
  }

  void _onChanged(String value) {
    widget.onChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();

    return Column(
      crossAxisAlignment: .start,
      children: [
        _buildLabel(color),
        const SizedBox(height: 4.0),
        AbsorbPointer(absorbing: widget.absorbing, child: _buildField(color)),
        if (_isFailure) ...[const SizedBox(height: 8.0), _buildFailure(color)],
      ],
    );
  }

  Widget _buildLabel(Color color) => Text(
    widget.label,
    style: context.typography.bodyLarge?.copyWith(
      color: color,
      fontWeight: .w500,
    ),
  );

  Widget _buildField(Color color) => TextSelectionTheme(
    data: TextSelectionTheme.of(context).copyWith(
      cursorColor: color,
      selectionHandleColor: color,
      selectionColor: color.withValues(alpha: .4),
    ),
    child: SizedBox(
      height: 56.0,
      child: TextField(
        focusNode: _focus,
        cursorHeight: 16.0,
        cursorColor: color,
        autocorrect: false,
        onChanged: _onChanged,
        enabled: widget.enabled,
        controller: _controller,
        enableSuggestions: false,
        readOnly: widget.readOnly,
        textAlignVertical: .center,
        autofocus: widget.autofocus,
        obscureText: widget.obscureText,
        onSubmitted: widget.onSubmitted,
        keyboardType: widget.keyboardType,
        autofillHints: widget.autofillHints,
        textInputAction: widget.inputAction,
        inputFormatters: widget.inputFormatters,
        spellCheckConfiguration: const .disabled(),
        textCapitalization: widget.textCapitalization,
        maxLines: widget.obscureText ? 1 : widget.maxLines,
        style: context.typography.bodyMedium?.copyWith(
          color: color,
          height: 1.0,
        ),
        selectionControls: ColoredTextSelectionControls(
          color: color,
          delegate: context.platform == .iOS
              ? cupertinoTextSelectionHandleControls
              : materialTextSelectionHandleControls,
        ),
        decoration: InputDecoration(
          hintMaxLines: 1,
          hintText: widget.hint,
          suffixIcon: _buildSuffixIcon(color),
          constraints: const .tightFor(height: 56.0),
          errorBorder: _outlinedBorder(context.colors.error),
          border: _outlinedBorder(context.colors.onSurfaceVariant),
          focusedErrorBorder: _outlinedBorder(context.colors.error),
          focusedBorder: _outlinedBorder(
            _isFailure ? context.colors.error : context.colors.primary,
          ),
          contentPadding: const .symmetric(horizontal: 8.0, vertical: 20.0),
          hintStyle: context.typography.bodyMedium?.copyWith(
            height: 1.0,
            color: color.withValues(alpha: .82),
          ),
          disabledBorder: _outlinedBorder(
            context.colors.onSurfaceVariant.withValues(alpha: .4),
          ),
          enabledBorder: _outlinedBorder(
            _isFailure ? context.colors.error : context.colors.onSurfaceVariant,
          ),
        ),
      ),
    ),
  );

  Widget? _buildSuffixIcon(Color color) {
    if (widget.trailingIcon == null) return null;
    if (widget.hideTrailingIconWhenEmpty && !_hasText) return null;

    return IconButtonWidget(
      iconColor: color,
      withoutBackground: true,
      icon: widget.trailingIcon!,
      onPress: widget.enabled && !widget.absorbing
          ? widget.onTrailingIconTap
          : null,
      backgroundColor: Colors.transparent,
    );
  }

  Widget _buildFailure(Color color) {
    final failureColor = color.withValues(alpha: .82);

    return Row(
      spacing: 6.0,
      children: [
        IconWidget(icon: lucide.circle_help, color: failureColor, size: 16.0),
        Expanded(
          child: Text(
            widget.failure!,
            style: context.typography.bodyMedium?.copyWith(
              height: 1.0,
              color: failureColor,
            ),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _outlinedBorder(Color color) => OutlineInputBorder(
    borderSide: BorderSide(color: color),
    borderRadius: context.radius.cornerRadius100,
  );
}
