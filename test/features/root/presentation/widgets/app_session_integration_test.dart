import 'dart:async';

import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/authentication_module.dart';
import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/storage_client.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/enums/storage_key_enum.dart';
import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/widgets/bottom_sheets/confirmation_bottom_sheet_widget.dart';
import 'package:cordato/features/root/presentation/screens/app/app_screen.dart';
import 'package:cordato/features/root/presentation/widgets/app_widget.dart';
import 'package:cordato/features/session/presentation/bloc/session_bloc.dart';
import 'package:cordato/features/session/session_module.dart';
import 'package:cordato/features/settings/settings_module.dart';
import 'package:cordato/features/settings/presentation/screens/settings/widgets/settings_logout_widget.dart';
import 'package:cordato/features/welcome/welcome_module.dart';

import '../../../../support/core/mocks/http_client_mock.dart';
import '../../../../support/core/mocks/storage_client_mock.dart';

void main() {
  setUpAll(() => registerFallbackValue(const Requests(path: '')));

  testWidgets(
    'one application owner observes real sign-in persistence and real logout clearing',
    (tester) async {
      final storage = StorageClientMock();
      final client = HttpClientMock();
      final changes = StreamController<String?>.broadcast();
      final navigatorKey = GlobalKey<NavigatorState>();
      final owners = <SessionBloc>[];
      String? token;
      when(() => storage.watch(key: StorageKeyEnum.opaqueToken.key))
          .thenAnswer((_) => changes.stream);
      when(() => storage.read(key: StorageKeyEnum.opaqueToken.key))
          .thenAnswer((_) async => token);
      when(
        () => storage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((invocation) async {
        if (invocation.namedArguments[#key] == StorageKeyEnum.opaqueToken.key) {
          token = invocation.namedArguments[#value] as String;
          changes.add(token);
        }
      });
      when(storage.clear).thenAnswer((_) async {
        token = null;
        changes.add(null);
      });
      when(() => client.post(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Responses(
          status: 200,
          body: {
            'data': {
              'attributes': {'token': 'fixture-token'},
              'relationships': {
                'user': {
                  'data': {'id': 'fixture-user'},
                },
              },
            },
          },
        ),
      );
      when(() => client.delete(parameter: any(named: 'parameter')))
          .thenAnswer((_) async => const Responses(status: 204, body: {}));
      final module = createModule(
        register: (context) {
          context
            ..addInstance<IStorageClient>(storage)
            ..addInstance<IHttpClient>(client)
            ..module(sessionModule)
            ..module(welcomeModule)
            ..module(settingsModule);
          authenticationModule.register(context);
          context
            ..route('/', child: (_, _) => const AppScreen())
            ..route(
              '/dashboard',
              child: (_, _) => const Scaffold(body: Text('Painel de teste')),
            );
        },
      );
      SessionBloc createOwner() {
        final bloc = inject<SessionBloc>();
        owners.add(bloc);
        return bloc;
      }

      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        unawaited(changes.close());
        await tester.pumpAndSettle();
        expect(changes.hasListener, isFalse);
        expect(owners.single.isClosed, isTrue);
      });
      await tester.pumpWidget(
        ModularApp(
          module: module,
          navigatorKey: navigatorKey,
          initialRoute: '/',
          child: AppWidget(bloc: createOwner, navigatorKey: navigatorKey),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Continuar'), findsOneWidget);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();
      expect(find.text('Que bom ter você por aqui'), findsOneWidget);
      await tester.enterText(
        find.byType(TextField).first,
        'person@example.com',
      );
      await tester.enterText(find.byType(TextField).last, 'Teste1');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.text('Painel de teste'), findsOneWidget);
      expect(token, 'fixture-token');
      expect(owners, hasLength(1));
      expect(owners.single.isClosed, isFalse);
      tester
          .element(find.text('Painel de teste'))
          .pushNamed(RouteEnum.settings.path);
      await tester.pumpAndSettle();
      expect(find.text('Configurações'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(SettingsLogoutWidget),
          matching: find.byType(ElevatedButton),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(ConfirmationBottomSheetWidget),
          matching: find.byType(ElevatedButton),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Continuar'), findsOneWidget);
      expect(token, isNull);
      expect(owners, hasLength(1));
      expect(owners.single.isClosed, isFalse);
      verify(() => storage.read(key: StorageKeyEnum.opaqueToken.key)).called(1);
      verify(() => storage.watch(key: StorageKeyEnum.opaqueToken.key))
          .called(1);
      verify(storage.clear).called(1);
      verify(() => client.post(parameter: any(named: 'parameter'))).called(1);
      verify(() => client.delete(parameter: any(named: 'parameter'))).called(1);
    },
  );
}
