import 'dart:async';

import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/authentication/authentication_module.dart';
import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/storage_client.dart';
import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/presentation/themes/themes.dart';
import 'package:cordato/features/core/presentation/widgets/bottom_sheets/confirmation_bottom_sheet_widget.dart';
import 'package:cordato/features/core/presentation/widgets/toast/toast_provider_widget.dart';
import 'package:cordato/features/settings/settings_module.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/logout_bloc.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/logout_state.dart';
import 'package:cordato/features/settings/presentation/screens/settings/settings_screen.dart';
import 'package:cordato/features/settings/presentation/screens/settings/widgets/settings_logout_widget.dart';

import '../../support/core/mocks/http_client_mock.dart';
import '../../support/core/mocks/storage_client_mock.dart';

void main() {
  setUpAll(() => registerFallbackValue(const Requests(path: '')));

  testWidgets(
    'Settings route injects independent Blocs and awaits local storage clearing without HTTP',
    (tester) async {
      final client = HttpClientMock();
      final storage = StorageClientMock();
      final clearing = Completer<void>();
      when(() => storage.clear()).thenAnswer((_) => clearing.future);
      final boot = bootstrapModule(
        createModule(
          register: (context) {
            context
              ..addInstance<IHttpClient>(client)
              ..addInstance<IStorageClient>(storage);
            context.module(authenticationModule);
            context.module(settingsModule);
          },
        ),
      );
      final router = modularRouterConfig(
        boot.routes,
        injector: boot.injector,
        manager: boot.manager,
        initialRoute: RouteEnum.settings.path,
      );
      final owned = <LogoutBloc>[];
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        if (!clearing.isCompleted) clearing.complete();
        for (final bloc in owned) {
          unawaited(bloc.close());
        }
        await tester.pumpAndSettle();
        for (final bloc in owned) {
          expect(bloc.isClosed, isTrue);
        }
        (router.routerDelegate as ChangeNotifier).dispose();
        (router.routeInformationProvider as PlatformRouteInformationProvider)
            .dispose();
        boot.injector.dispose();
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
      expect(find.text('Configurações'), findsOneWidget);
      final first = inject<LogoutBloc>();
      final second = inject<LogoutBloc>();
      owned.addAll([first, second]);
      expect(first, isNot(same(second)));
      final screen = tester.widget<SettingsScreen>(find.byType(SettingsScreen));
      tester.element(find.byType(SettingsScreen)).markNeedsBuild();
      await tester.pump();
      expect(
        tester.widget<SettingsScreen>(find.byType(SettingsScreen)).bloc,
        screen.bloc,
      );
      verifyZeroInteractions(client);
      verifyZeroInteractions(storage);
      final logout = find.descendant(
        of: find.byType(SettingsLogoutWidget),
        matching: find.byType(ElevatedButton),
      );
      await tester.tap(logout);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(ConfirmationBottomSheetWidget),
          matching: find.byType(ElevatedButton),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      verifyZeroInteractions(client);
      verify(() => storage.clear()).called(1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      clearing.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.widget<ElevatedButton>(logout).onPressed, isNull);
      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(first.state, isA<LogoutInitial>());
      expect(second.state, isA<LogoutInitial>());
      verifyNoMoreInteractions(client);
      verifyNoMoreInteractions(storage);
    },
  );
}
