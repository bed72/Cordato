import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:cordato/features/core/presentation/widgets/fields/text_field_widget.dart';
import 'package:cordato/features/core/presentation/widgets/fields/mixins/autocomplete_text_field_state_mixin.dart';

final class const AutocompleteTextFieldWidget<T extends Object>({
  super.key,
  required final String label,
  required final String hint,
  required final VoidCallback onInvalidated,
  required final ValueChanged<T> onSelected,
  required final TextEditingController controller,
  required final String Function(T) displayStringForOption,
  required final Widget Function(
    BuildContext context,
    Iterable<T> options,
    VoidCallback onDismiss,
    AutocompleteOnSelected<T> onSelected,
  )
  optionsViewBuilder,
  required final FutureOr<Iterable<T>> Function(TextEditingValue)
  optionsBuilder,
  final String? failure,
  final bool enabled = true,
  final ValueChanged<String>? onChanged,
  final ValueChanged<String>? onSubmitted,
  final TextInputAction inputAction = .next,
  final TextCapitalization textCapitalization = .sentences,
}) extends StatefulWidget {
  @override
  State<AutocompleteTextFieldWidget<T>> createState() =>
      _AutocompleteTextFieldState<T>();
}

final class _AutocompleteTextFieldState<T extends Object>
    extends State<AutocompleteTextFieldWidget<T>>
    with AutocompleteTextFieldStateMixin<T> {
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => RawAutocomplete<T>(
      key: ValueKey(focusRevision),
      focusNode: focus,
      onSelected: selectOption,
      optionsBuilder: buildOptions,
      textEditingController: fieldController,
      optionsViewOpenDirection: optionsDirection,
      displayStringForOption: widget.displayStringForOption,
      optionsViewBuilder: (context, select, options) => optionsAreCurrent
          ? SizedBox(
              width: constraints.maxWidth,
              child: widget.optionsViewBuilder(
                context,
                options,
                dismissOptions,
                select,
              ),
            )
          : const SizedBox.shrink(),
      fieldViewBuilder: (context, controller, focusNode, submit) => Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              dismissOptions();
              return null;
            },
          ),
        },
        child: TextFieldWidget(
          key: fieldKey,
          hint: widget.hint,
          label: widget.label,
          focusNode: focusNode,
          controller: controller,
          enabled: widget.enabled,
          failure: widget.failure,
          onChanged: widget.onChanged,
          inputAction: widget.inputAction,
          textCapitalization: widget.textCapitalization,
          onSubmitted: (value) => submitField(value, submit),
        ),
      ),
    ),
  );
}
