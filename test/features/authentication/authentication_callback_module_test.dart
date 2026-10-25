import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/authentication_module.dart';
import 'package:cordato/features/authentication/presentation/screens/callback/bloc/callback_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/callback/bloc/callback_event.dart';
import 'package:cordato/features/authentication/presentation/screens/callback/bloc/callback_state.dart';
import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/storage_client.dart';
import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/themes/themes.dart';
import 'package:cordato/features/core/presentation/widgets/toast/toast_provider_widget.dart';

import '../../support/core/mocks/http_client_mock.dart';
import '../../support/core/mocks/storage_client_mock.dart';

void main() {
  const signed = 'https://other.example/verify?signature=a%2Bb&expires=123';
  late HttpClientMock client;
  late StorageClientMock storage;
  late ModularBootstrap boot;

  setUpAll(() => registerFallbackValue(const Requests(path: '')));
  setUp(() {
    client = HttpClientMock();
    storage = StorageClientMock();
    boot = bootstrapModule(
      createModule(
        register: (context) {
          context
            ..addInstance<IHttpClient>(client)
            ..addInstance<IStorageClient>(storage);
          context.module(authenticationModule);
          context.route(
            RouteEnum.welcome.path,
            child: (_, _) => const Scaffold(body: Text('Boas-vindas')),
          );
        },
      ),
    );
  });
  tearDown(() => boot.injector.dispose());

  test(
    'registers independent CallbackBloc factories against the real repository',
    () async {
      when(() => client.get(parameter: any(named: 'parameter')))
          .thenAnswer((_) async => const Responses(status: 204, body: {}));
      final first = inject<CallbackBloc>();
      final second = inject<CallbackBloc>();
      addTearDown(first.close);
      addTearDown(second.close);
      expect(first, isNot(same(second)));
      final finished = first.stream.firstWhere(
        (state) => state is CallbackSuccess,
      );
      first.add(const CallbackRequestedEvent(verificationUrl: signed));
      await finished;
      expect(second.state, isA<CallbackInitial>());
      final request =
          verify(() => client.get(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;
      expect(request.path, signed);
      verifyZeroInteractions(storage);
    },
  );

  for (final scenario in [
    (
      query: '?verification_url=${Uri.encodeQueryComponent(signed)}',
      valid: true,
    ),
    (query: '', valid: false),
    (query: '?verification_url=first&verification_url=second', valid: false),
  ]) {
    testWidgets(
      'callback route decodes exactly one signed URL: ${scenario.query}',
      (tester) async {
        when(() => client.get(parameter: any(named: 'parameter')))
            .thenAnswer((_) async => const Responses(status: 204, body: {}));
        final router = modularRouterConfig(
          boot.routes,
          injector: boot.injector,
          initialRoute:
              '${RouteEnum.authenticationConfirmEmail.path}${scenario.query}',
        );
        addTearDown(() async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          (router.routerDelegate as ChangeNotifier).dispose();
          (router.routeInformationProvider as PlatformRouteInformationProvider)
              .dispose();
        });
        await tester.pumpWidget(
          MaterialApp.router(
            theme: Themes.light,
            locale: const Locale('pt', 'BR'),
            supportedLocales: const [Locale('pt', 'BR')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            routerConfig: router,
            builder: (_, child) => ToastProviderWidget(child: child!),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Que bom ter você por aqui'), findsOneWidget);
        expect(
          find.text(
            scenario.valid ? 'E-mail confirmado' : 'Link inválido ou expirado',
          ),
          findsOneWidget,
        );
        if (scenario.valid) {
          final request =
              verify(
                    () => client.get(parameter: captureAny(named: 'parameter')),
                  ).captured.single
                  as Requests;
          expect(request.path, signed);
        } else {
          verifyZeroInteractions(client);
        }
        verifyZeroInteractions(storage);
      },
    );
  }
}
