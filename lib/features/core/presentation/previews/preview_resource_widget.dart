import 'package:material_ui/material_ui.dart';

final class const PreviewResourceWidget<T>({
  super.key,
  required final T Function() create,
  required final void Function(T resource) dispose,
  required final Widget Function(T resource) builder,
}) extends StatefulWidget {
  @override
  State<PreviewResourceWidget<T>> createState() =>
      PreviewResourceWidgetState<T>();
}

final class PreviewResourceWidgetState<T>
    extends State<PreviewResourceWidget<T>> {
  late final T resource;

  @override
  void initState() {
    super.initState();
    resource = widget.create();
  }

  @override
  void dispose() {
    widget.dispose(resource);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(resource);
}
