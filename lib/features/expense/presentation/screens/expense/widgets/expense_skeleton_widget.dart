import 'package:material_ui/material_ui.dart';
import 'package:skeletonizer/skeletonizer.dart';

final class const ExpenseSkeletonWidget({
  super.key,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Carregando despesa',
    liveRegion: true,
    child: ExcludeSemantics(child: Skeletonizer(child: child)),
  );
}
