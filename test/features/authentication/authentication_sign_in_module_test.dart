import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/authentication/authentication_module.dart';
import 'package:cordato/features/authentication/presentation/screens/sign_in/sign_in_screen.dart';
import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/storage_client.dart';
import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/themes/themes.dart';
import 'package:cordato/features/core/presentation/widgets/toast/toast_provider_widget.dart';

import '../../support/core/mocks/http_client_mock.dart';
import '../../support/core/mocks/storage_client_mock.dart';

void main() {
  testWidgets('sign-in route owns one Bloc per page and closes on exit', (
    tester,
  ) async {
    final module = createModule(
      register: (context) => context
        ..addInstance<IHttpClient>(HttpClientMock())
        ..addInstance<IStorageClient>(StorageClientMock())
        ..module(authenticationModule)
        ..route('/empty', child: (_, _) => const Scaffold()),
    );
    await tester.pumpWidget(
      ModularApp(
        module: module,
        initialRoute: RouteEnum.authenticationSignIn.path,
        defaultTransition: TransitionType.none,
        child: Builder(
          builder: (context) => MaterialApp.router(
            routerConfig: ModularApp.routerConfigOf(context),
            theme: Themes.light,
            locale: const Locale('pt', 'BR'),
            supportedLocales: const [Locale('pt', 'BR')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            builder: (_, child) => ToastProviderWidget(child: child!),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final screen = find.byType(SignInScreen);
    final first = tester.widget<SignInScreen>(screen).bloc;

    tester.element(screen).markNeedsBuild();
    await tester.pump();
    expect(tester.widget<SignInScreen>(screen).bloc, same(first));
    expect(first.isClosed, isFalse);

    tester.element(screen).navigate('/empty');
    await tester.pumpAndSettle();
    expect(first.isClosed, isTrue);

    tester
        .element(find.byType(Scaffold))
        .navigate(RouteEnum.authenticationSignIn.path);
    await tester.pumpAndSettle();
    final second = tester.widget<SignInScreen>(screen).bloc;
    expect(second, isNot(same(first)));
    expect(second.isClosed, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(second.isClosed, isTrue);
    expect(tester.takeException(), isNull);
  });
}
