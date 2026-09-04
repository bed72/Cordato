import 'package:material_ui/material_ui.dart';

final class AuthenticationCallbackScreen extends StatelessWidget {
  const AuthenticationCallbackScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: .min,
          spacing: 16.0,
          children: [CircularProgressIndicator(), Text('Validando acesso...')],
        ),
      ),
    ),
  );
}
