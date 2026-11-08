import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/app_module.dart';
import 'package:cordato/features/core/application/clients/interface_file_share_client.dart';
import 'package:cordato/features/core/infrastructure/clients/file_share/file_share_client.dart';
import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/expense/application/repositories/interface_export_repository.dart'
    as expense;
import 'package:cordato/features/settings/presentation/screens/settings/bloc/export_bloc.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/export_event.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/export_state.dart';

import '../../support/core/fakes/pocketbase_fixture.dart';
import '../../support/core/mocks/file_share_client_mock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Settings alone resolves the page-owned export Bloc and root-owned Expense adapter', () async {
    final fixture = PocketBaseFixture()..authenticate();
    fixture.respond = (_) => PocketBaseFixture.jsonResponse({
      'items': [],
      'page': 1,
      'totalPages': 0,
    });
    addTearDown(fixture.client.close);
    final boot = bootstrapModule(createAppModule(pocketBase: fixture.client));
    addTearDown(boot.injector.dispose);
    final client = boot.injector.get<IFileShareClient>();
    expect(client, isA<FileShareClient>());
    expect(boot.injector.get<IFileShareClient>(), same(client));
    final files = FileShareClientMock();
    when(files.cleanExpired).thenAnswer((_) async {});
    boot.injector.replaceInstance<IFileShareClient>(files);

    final route = boot.routes.routes.singleWhere(
      (route) => route.path == RouteEnum.settings.path,
    );
    boot.manager.enter('settings-export-test', route.ownerTags);
    expect(() => boot.injector.get<ExportBloc>(), throwsA(anything));
    expect(
      boot.injector.get<expense.IExportRepository>(),
      isA<expense.IExportRepository>(),
    );
    final scope = Scoped();
    route.provide!(scope);
    expect(scope.specs.map((spec) => spec.type), [ExportBloc]);
    final spec = scope.specs.single;
    boot.injector.uncommit();
    spec.register(boot.injector);
    boot.injector.commit();
    final bloc = spec.resolve(boot.injector) as ExportBloc;
    addTearDown(() async {
      if (!bloc.isClosed) {
        await spec.dispose(bloc);
      }
    });
    final empty = bloc.stream.firstWhere((state) => state is ExportEmpty);
    bloc.add(const ExportRequested());
    await empty;
    expect(
      fixture.requests.single.url.queryParameters['filter'],
      'owner = "user-1"',
    );
    expect(
      fixture.requests.single.url.path,
      '/api/collections/expenses/records',
    );
    verify(files.cleanExpired).called(1);
    verifyNoMoreInteractions(files);
    await spec.dispose(bloc);
    expect(bloc.isClosed, true);
  });
}
