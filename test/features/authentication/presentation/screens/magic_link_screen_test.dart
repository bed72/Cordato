import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/domain/failures/authentication_failure.dart';
import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';
import 'package:cordato/features/authentication/presentation/commands/magic_link_command.dart';
import 'package:cordato/features/authentication/presentation/screens/magic_link_screen.dart';
import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/presentation/previews/material_preview_widget.dart';

class _AuthenticationRepositoryMock extends Mock
    implements IAuthenticationRepository {}

void main() {
  const email = 'person@example.com';

  late IAuthenticationRepository repository;
  late ModularBootstrap bootstrap;

  setUp(() {
    repository = _AuthenticationRepositoryMock();
    bootstrap = bootstrapModule(
      createModule(
        register: (c) {
          c
            ..addInstance<IAuthenticationRepository>(repository)
            ..addSingleton<MagicLinkCommand>(MagicLinkCommand.new);
        },
      ),
    );
  });

  testWidgets('renders the email field and send button', (tester) async {
    await tester.pumpWidget(
      MaterialPreviewWidget(
        child: MagicLinkScreen(command: bootstrap.injector.get()),
      ),
    );

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Enviar link'), findsOneWidget);
  });

  testWidgets('sends the email and shows success feedback', (tester) async {
    when(() => repository.requestMagicLink(email: email))
        .thenAnswer((_) async => const Right<Failure, void>(null));

    await tester.pumpWidget(
      MaterialPreviewWidget(
        child: MagicLinkScreen(command: bootstrap.injector.get()),
      ),
    );
    await tester.enterText(find.byType(TextField), email);
    await tester.tap(find.text('Enviar link'));
    await tester.pumpAndSettle();

    verify(() => repository.requestMagicLink(email: email)).called(1);
    expect(find.text('Link enviado para $email.'), findsOneWidget);
  });

  testWidgets('does not send an invalid email', (tester) async {
    await tester.pumpWidget(
      MaterialPreviewWidget(
        child: MagicLinkScreen(command: bootstrap.injector.get()),
      ),
    );
    await tester.enterText(find.byType(TextField), 'invalid-email');
    await tester.tap(find.text('Enviar link'));
    await tester.pump();

    verifyNever(() => repository.requestMagicLink(email: any(named: 'email')));
    expect(find.text('Informe um email válido.'), findsOneWidget);
  });
}
