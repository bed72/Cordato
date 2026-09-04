import 'package:material_ui/material_ui.dart';

final class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: SafeArea(child: Center(child: Text('Dashboard'))),
  );
}
