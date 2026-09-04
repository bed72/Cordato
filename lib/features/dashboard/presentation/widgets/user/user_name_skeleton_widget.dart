import 'package:material_ui/material_ui.dart';
import 'package:skeletonizer/skeletonizer.dart';

final class UserNameSkeletonWidget extends StatelessWidget {
  final Widget child;

  const UserNameSkeletonWidget({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Skeletonizer(child: child);
}
