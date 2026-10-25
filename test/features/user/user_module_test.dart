import 'dart:async';

import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:cordato/features/core/infrastructure/clients/http/http_client.dart';
import 'package:cordato/features/core/infrastructure/clients/http/requests/requests.dart';
import 'package:cordato/features/core/infrastructure/clients/http/responses/responses.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/storage_client.dart';
import 'package:cordato/features/core/infrastructure/clients/storage/enums/storage_key_enum.dart';
import 'package:cordato/features/core/presentation/themes/themes.dart';
import 'package:cordato/features/core/presentation/widgets/toast/toast_provider_widget.dart';
import 'package:cordato/features/user/presentation/screens/user/bloc/user_bloc.dart';
import 'package:cordato/features/user/presentation/screens/edit/bloc/edit_bloc.dart';
import 'package:cordato/features/user/presentation/screens/edit/edit_user_screen.dart';
import 'package:cordato/features/user/presentation/screens/user/user_screen.dart';
import 'package:cordato/features/user/user_module.dart';

import '../../support/core/mocks/http_client_mock.dart';
import '../../support/core/mocks/storage_client_mock.dart';

void main() {
  setUpAll(() => registerFallbackValue(const Requests(path: '')));
  testWidgets(
    'User route injects a stable factory with independent Blocs and a real repository',
    (tester) async {
      final http = HttpClientMock();
      final storage = StorageClientMock();
      when(() => storage.read(key: StorageKeyEnum.userId.key))
          .thenAnswer((_) async => '1');
      when(() => http.get(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Responses(
          status: 200,
          body: {
            'data': {
              'id': '1',
              'attributes': {
                'name': 'Pessoa',
                'email': 'person@example.com',
                'status': 'active',
              },
            },
          },
        ),
      );
      final boot = bootstrapModule(
        createModule(
          register: (context) {
            context
              ..addInstance<IHttpClient>(http)
              ..addInstance<IStorageClient>(storage);
            userDependenciesModule.register(context);
            context.module(userModule);
          },
        ),
      );
      final router = modularRouterConfig(
        boot.routes,
        injector: boot.injector,
        manager: boot.manager,
        initialRoute: '/user',
      );
      final owned = <UserBloc>[];
      final editOwned = <EditBloc>[];
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        for (final bloc in owned) {
          unawaited(bloc.close());
        }
        for (final bloc in editOwned) {
          unawaited(bloc.close());
        }
        await tester.pumpAndSettle();
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
      expect(find.text('Pessoa'), findsOneWidget);
      final first = inject<UserBloc>();
      final second = inject<UserBloc>();
      owned.addAll([first, second]);
      expect(first, isNot(same(second)));
      final factory = tester.widget<UserScreen>(find.byType(UserScreen)).bloc;
      tester.element(find.byType(UserScreen)).markNeedsBuild();
      await tester.pump();
      expect(tester.widget<UserScreen>(find.byType(UserScreen)).bloc, factory);
      final request =
          verify(() => http.get(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;
      expect(request.path, 'users/1');
      verify(() => storage.read(key: StorageKeyEnum.userId.key)).called(1);
      verifyNoMoreInteractions(storage);
      verifyNoMoreInteractions(http);

      final patch = Completer<Responses>();
      when(() => http.patch(parameter: any(named: 'parameter')))
          .thenAnswer((_) => patch.future);
      addTearDown(() {
        if (!patch.isCompleted) {
          patch.complete(
            const Responses(
              status: 200,
              body: {
                'data': {
                  'id': '1',
                  'attributes': {
                    'name': 'API',
                    'email': 'person@example.com',
                    'status': 'active',
                  },
                },
              },
            ),
          );
        }
      });
      await tester.tap(find.text('Nome'));
      await tester.pumpAndSettle();
      final edit = tester.widget<EditUserScreen>(find.byType(EditUserScreen));
      expect(edit.initialName, 'Pessoa');
      final editFirst = inject<EditBloc>();
      final editSecond = inject<EditBloc>();
      editOwned.addAll([editFirst, editSecond]);
      expect(editFirst, isNot(same(editSecond)));
      tester.element(find.byType(EditUserScreen)).markNeedsBuild();
      await tester.pump();
      expect(
        tester.widget<EditUserScreen>(find.byType(EditUserScreen)).bloc,
        edit.bloc,
      );
      await tester.enterText(find.byType(TextField), '  Novo nome  ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(find.byType(EditUserScreen), findsOneWidget);
      final update =
          verify(() => http.patch(parameter: captureAny(named: 'parameter')))
                  .captured
                  .single
              as Requests;
      expect(update.path, 'users/1');
      expect(update.body, {
        'data': {
          'id': '1',
          'type': 'users',
          'attributes': {'name': 'Novo nome'},
        },
      });
      when(() => http.get(parameter: any(named: 'parameter'))).thenAnswer(
        (_) async => const Responses(
          status: 200,
          body: {
            'data': {
              'id': '1',
              'attributes': {
                'name': 'Nome da API',
                'email': 'person@example.com',
                'status': 'active',
              },
            },
          },
        ),
      );
      patch.complete(
        const Responses(
          status: 200,
          body: {
            'data': {
              'id': '1',
              'attributes': {
                'name': 'Nome da API',
                'email': 'person@example.com',
                'status': 'active',
              },
            },
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(EditUserScreen), findsNothing);
      expect(find.byType(UserScreen), findsOneWidget);
      expect(find.text('Nome da API'), findsOneWidget);
      verify(() => http.get(parameter: any(named: 'parameter'))).called(1);
      verify(() => storage.read(key: StorageKeyEnum.userId.key)).called(2);
      verifyNoMoreInteractions(http);
      verifyNoMoreInteractions(storage);
    },
  );
}
