import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/settings/settings_module.dart';
import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/core/core_module.dart';
import 'package:cordato/features/core/infrastructure/clients/database/database_client.dart';
import 'package:cordato/features/core/infrastructure/clients/share/share_client.dart';
import 'package:cordato/features/expense/expense_module.dart';
import 'package:cordato/features/expense/application/repositories/interface_expense_export_repository.dart';
import 'package:cordato/features/settings/application/repositories/interface_export_repository.dart';
import 'package:cordato/features/settings/presentation/screens/settings/bloc/export_bloc.dart';

void main() {
  test('Settings registers both local destinations without authentication', () {
    final boot = bootstrapModule(
      createModule(register: (context) => context.module(settingsModule)),
    );
    addTearDown(boot.injector.dispose);

    final matches = boot.routes.match(
      Uri.parse(RouteEnum.settingsSupport.path),
    );

    expect(matches, hasLength(1));
    expect(matches!.single.route.provide, isNull);
    expect(RouteEnum.settingsSupport.path, '/settings/support');
    expect(matches.single.route.path, RouteEnum.settingsSupport.path);
    final settings = boot.routes.match(Uri.parse(RouteEnum.settings.path));
    expect(settings, hasLength(1));
    expect(settings!.single.route.provide, isNotNull);
    boot.manager.enter('settings-local-test', settings.single.route.ownerTags);
    boot.manager.leave('settings-local-test', settings.single.route.ownerTags);
    expect(
      boot.routes.routes.map((route) => route.path),
      unorderedEquals([
        RouteEnum.settings.path,
        RouteEnum.settingsSupport.path,
      ]),
    );
  });

  test(
    'resolves export dependencies without visiting sibling routes',
    () async {
      final boot = bootstrapModule(
        createModule(
          register: (context) => context
            ..module(coreModule)
            ..module(expenseModule)
            ..module(settingsModule),
        ),
      );
      final database = boot.injector.get<DatabaseClient>();
      addTearDown(() async {
        await database.close();
        boot.injector.dispose();
      });

      final repository = boot.injector.get<IExportRepository>();
      expect(boot.injector.get<IExportRepository>(), same(repository));
      expect(boot.injector.get<IShareClient>(), isA<ShareClient>());
      expect(boot.injector.get<IExpenseExportRepository>(), isNotNull);
      final route = boot.routes
          .match(Uri.parse(RouteEnum.settings.path))!
          .single
          .route;
      final firstScope = Scoped();
      final secondScope = Scoped();
      route.provide!(firstScope);
      route.provide!(secondScope);
      expect(firstScope.specs.map((spec) => spec.type), [ExportBloc]);

      final firstInjector = ModuleManager().root
        ..addInstance<IExportRepository>(repository);
      final secondInjector = ModuleManager().root
        ..addInstance<IExportRepository>(repository);
      firstScope.specs.single.register(firstInjector);
      secondScope.specs.single.register(secondInjector);
      firstInjector.commit();
      secondInjector.commit();
      final first =
          firstScope.specs.single.resolve(firstInjector) as ExportBloc;
      final second =
          secondScope.specs.single.resolve(secondInjector) as ExportBloc;

      expect(first, isNot(same(second)));
      expect(firstInjector.get<ExportBloc>(), same(first));
      await firstScope.specs.single.dispose(first);
      await secondScope.specs.single.dispose(second);
      firstInjector.dispose();
      secondInjector.dispose();
      expect(first.isClosed, isTrue);
      expect(second.isClosed, isTrue);
    },
  );
}
