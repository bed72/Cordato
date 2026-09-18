import 'package:material_ui/material_ui.dart';
import 'package:skeletonizer/skeletonizer.dart';

final class const UserNameSkeletonWidget({
  super.key,
  required final Widget child,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Skeletonizer(child: child);
}
