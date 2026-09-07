import 'package:pinput/pinput.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter_localizations/flutter_localizations.dart'
    as localizations;

import 'package:cordato/features/core/presentation/validators/validation.dart';
import 'package:cordato/features/core/presentation/widgets/icons/icon_widget.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

final class PinFieldWidget extends StatefulWidget {
  final Validation<String> validation;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;

  const PinFieldWidget({
    super.key,
    required this.controller,
    required this.validation,
    this.onChanged,
    this.onCompleted,
  });

  @override
  State<PinFieldWidget> createState() => _PinFieldWidgetState();
}

final class _PinFieldWidgetState extends State<PinFieldWidget> {
  bool _isFocused = false;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChanged() =>
      setState(() => _isFocused = _focusNode.hasFocus);

  @override
  Widget build(BuildContext context) {
    final defaultPinTheme = PinTheme(
      width: 48.0,
      height: 48.0,
      textStyle: context.typography.titleMedium?.copyWith(
        fontWeight: .w600,
        color: context.colors.onSurface,
      ),
      decoration: BoxDecoration(
        borderRadius: context.radius.cornerRadius100,
        border: .all(color: context.colors.onSurfaceVariant),
      ),
    );
    final activePinTheme = defaultPinTheme.copyWith(
      textStyle: defaultPinTheme.textStyle?.copyWith(
        color: context.colors.primary,
      ),
      decoration: defaultPinTheme.decoration?.copyWith(
        border: .all(color: context.colors.primary),
      ),
    );
    final errorPinTheme = defaultPinTheme.copyWith(
      textStyle: defaultPinTheme.textStyle?.copyWith(
        color: context.colors.error,
      ),
      decoration: defaultPinTheme.decoration?.copyWith(
        border: .all(color: context.colors.error),
      ),
    );

    return material.Localizations(
      locale: Localizations.localeOf(context),
      delegates: const [
        localizations.GlobalWidgetsLocalizations.delegate,
        localizations.GlobalMaterialLocalizations.delegate,
        localizations.GlobalCupertinoLocalizations.delegate,
      ],
      child: material.Material(
        color: material.Colors.transparent,
        child: Pinput(
          length: 6,
          autofocus: true,
          validator: _validate,
          keyboardType: .number,
          focusNode: _focusNode,
          showErrorWhenFocused: true,
          errorPinTheme: errorPinTheme,
          onChanged: widget.onChanged,
          controller: widget.controller,
          onCompleted: widget.onCompleted,
          focusedPinTheme: activePinTheme,
          mainAxisAlignment: .spaceBetween,
          defaultPinTheme: defaultPinTheme,
          pinputAutovalidateMode: .onSubmit,
          autofillHints: const [AutofillHints.oneTimeCode],
          errorBuilder: (failure, _) => _buildFailure(context, failure),
          submittedPinTheme: _isFocused ? activePinTheme : defaultPinTheme,
        ),
      ),
    );
  }

  String? _validate(String? value) => switch (widget.validation(value ?? '')) {
    Valid() => null,
    Invalid(:final message) => message,
  };

  Widget _buildFailure(BuildContext context, String? failure) {
    if (failure == null) return const SizedBox.shrink();

    return Padding(
      padding: const .only(top: 8.0),
      child: Row(
        spacing: 6.0,
        children: [
          IconWidget(
            size: 16.0,
            icon: Icons.info_outline,
            color: context.colors.error.withValues(alpha: .82),
          ),
          Expanded(
            child: Text(
              failure,
              style: context.typography.bodyMedium?.copyWith(
                height: 1.0,
                color: context.colors.error.withValues(alpha: .82),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
