import 'package:mocktail/mocktail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/application/clients/interface_share_client.dart';
import 'package:cordato/features/expense/application/repositories/interface_export_repository.dart'
    as expense;
import 'package:cordato/features/settings/settings_module.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/export_bloc.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/export_event.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/export_state.dart';

import '../../support/core/mocks/file_share_client_mock.dart';
import '../../support/expense/mocks/export_repository_mock.dart';

void main() {
  test(
    'Settings resolves a page-owned export Bloc without visiting other routes',
    () async {
      final files = FileShareClientMock();
      final expenses = ExportRepositoryMock();
      when(files.cleanExpired).thenAnswer((_) async {});
      when(expenses.prepare).thenAnswer((_) async => null);
      final boot = bootstrapModule(
        createModule(
          register: (context) => context
            ..addInstance<IShareClient>(files)
            ..addInstance<expense.IExportRepository>(expenses)
            ..module(settingsModule),
        ),
      );
      addTearDown(boot.injector.dispose);
      final route = boot.routes.routes.singleWhere(
        (route) => route.path == RouteEnum.settings.path,
      );
      boot.manager.enter('settings-export-test', route.ownerTags);
      addTearDown(
        () => boot.manager.leave('settings-export-test', route.ownerTags),
      );
      expect(() => boot.injector.get<ExportBloc>(), throwsA(anything));
      expect(boot.injector.get<expense.IExportRepository>(), same(expenses));
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

      verify(files.cleanExpired).called(1);
      verify(expenses.prepare).called(1);
      verifyNoMoreInteractions(files);
      await spec.dispose(bloc);
      expect(bloc.isClosed, isTrue);
    },
  );
}
