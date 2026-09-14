import 'package:material_ui/material_ui.dart';

final class PreviewResourceWidget<T> extends StatefulWidget {
  final T Function() create;
  final void Function(T resource) dispose;
  final Widget Function(T resource) builder;

  const PreviewResourceWidget({
    super.key,
    required this.create,
    required this.dispose,
    required this.builder,
  });

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
