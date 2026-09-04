import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/domain/failures/authentication_failure.dart';
import 'package:cordato/features/authentication/domain/repositories/interface_authentication_repository.dart';
import 'package:cordato/features/authentication/presentation/commands/magic_link_command.dart';
import 'package:cordato/features/authentication/presentation/screens/magic_link_screen.dart';
import 'package:cordato/features/authentication/presentation/widgets/app_bar_magic_link_widget.dart';
import 'package:cordato/features/core/domain/either.dart';
import 'package:cordato/features/core/presentation/previews/material_preview_widget.dart';
import 'package:cordato/features/core/presentation/themes/themes.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/back_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/icons/background_icon_widget.dart';
import 'package:cordato/features/core/presentation/widgets/toast/toast_provider_widget.dart';

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
        child: ToastProviderWidget(
          child: MagicLinkScreen(command: bootstrap.injector.get()),
        ),
      ),
    );

    expect(find.byType(TextField), findsOneWidget);
    expect(find.byType(AppBarMagicLinkWidget), findsOneWidget);
    expect(find.text('Que bom ter você por aqui'), findsOneWidget);
    expect(
      find.text('Entre com seu e-mail e enviaremos o link'),
      findsOneWidget,
    );
    expect(find.text('Enviar'), findsOneWidget);
    expect(find.byType(BackButtonWidget), findsOneWidget);
    expect(
      tester.getSize(find.byType(BackgroundIconWidget)),
      const Size(48.0, 48.0),
    );
    expect(
      tester
          .widget<BackgroundIconWidget>(find.byType(BackgroundIconWidget))
          .icon,
      Icons.chevron_left,
    );
    expect(
      tester
          .widget<BackgroundIconWidget>(find.byType(BackgroundIconWidget))
          .backgroundColor,
      Themes.light.colorScheme.onSurface.withValues(alpha: .06),
    );
  });

  testWidgets('sends the email and shows success feedback', (tester) async {
    when(() => repository.requestMagicLink(email: email))
        .thenAnswer((_) async => const Right<Failure, void>(null));

    await tester.pumpWidget(
      MaterialPreviewWidget(
        child: ToastProviderWidget(
          child: MagicLinkScreen(command: bootstrap.injector.get()),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), email);
    final focusNode = tester
        .widget<EditableText>(find.byType(EditableText))
        .focusNode;
    expect(focusNode.hasFocus, isTrue);

    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();

    expect(focusNode.hasFocus, isFalse);
    verify(() => repository.requestMagicLink(email: email)).called(1);
    expect(find.text('E-mail enviado'), findsOneWidget);
    expect(
      find.text('Enviamos um link de acesso para o seu e-mail.'),
      findsOneWidget,
    );
  });

  testWidgets('shows an error toast when sending the email fails', (
    tester,
  ) async {
    when(() => repository.requestMagicLink(email: email)).thenAnswer(
      (_) async => const Left<Failure, void>(MagicLinkRequestFailure()),
    );

    await tester.pumpWidget(
      MaterialPreviewWidget(
        child: ToastProviderWidget(
          child: MagicLinkScreen(command: bootstrap.injector.get()),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), email);
    await tester.tap(find.text('Enviar'));
    await tester.pumpAndSettle();

    expect(find.text('Erro ao enviar e-mail'), findsOneWidget);
    expect(
      find.text('Não foi possível enviar o e-mail. Tente novamente.'),
      findsOneWidget,
    );
  });

  testWidgets('does not send an invalid email', (tester) async {
    await tester.pumpWidget(
      MaterialPreviewWidget(
        child: MagicLinkScreen(command: bootstrap.injector.get()),
      ),
    );
    await tester.enterText(find.byType(TextField), 'invalid-email');
    await tester.tap(find.text('Enviar'));
    await tester.pump();

    verifyNever(() => repository.requestMagicLink(email: any(named: 'email')));
    expect(find.text('E-mail inválido'), findsOneWidget);
  });
}
