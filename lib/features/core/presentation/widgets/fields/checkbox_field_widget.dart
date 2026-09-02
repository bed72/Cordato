import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

class CheckboxFieldWidget extends StatelessWidget {
  final bool checked;
  final String label;
  final String? failure;
  final ValueChanged<bool> onChanged;

  const CheckboxFieldWidget({
    super.key,
    required this.checked,
    required this.label,
    required this.onChanged,
    this.failure,
  });

  bool get _isFailure => failure != null;

  @override
  Widget build(BuildContext context) => Column(
    spacing: 6.0,
    crossAxisAlignment: .start,
    children: [_buildRow(context), if (_isFailure) _buildFailure(context)],
  );

  Widget _buildRow(BuildContext context) => Row(
    crossAxisAlignment: .start,
    children: [
      _buildCheckbox(context),
      const SizedBox(width: 8.0),
      Expanded(
        child: Text(
          label,
          style: context.typography.bodyMedium?.copyWith(
            color: _isFailure
                ? context.colors.error
                : context.colors.onSurfaceVariant,
          ),
        ),
      ),
    ],
  );

  Widget _buildCheckbox(BuildContext context) => SizedBox(
    width: 24.0,
    height: 24.0,
    child: Checkbox(
      value: checked,
      onChanged: (value) => onChanged(value ?? false),
      isError: _isFailure,
      side: BorderSide(
        color: _isFailure
            ? context.colors.error
            : context.colors.onSurfaceVariant,
      ),
    ),
  );

  Widget _buildFailure(BuildContext context) => Row(
    spacing: 6.0,
    children: [
      Icon(Icons.info_outline, size: 16.0, color: context.colors.error),
      Expanded(
        child: Text(
          failure!,
          style: context.typography.bodyMedium?.copyWith(
            color: context.colors.error,
          ),
        ),
      ),
    ],
  );
}
