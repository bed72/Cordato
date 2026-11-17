import 'dart:io';

import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'package:cordato/features/core/core_module.dart';
import 'package:cordato/features/core/application/clients/interface_share_client.dart';
import 'package:cordato/features/core/application/clients/interface_home_widget_client.dart';
import 'package:cordato/features/core/application/clients/interface_recording_client.dart';
import 'package:cordato/features/core/infrastructure/clients/share/share_client.dart';
import 'package:cordato/features/core/infrastructure/clients/home_widget/home_widget_client.dart';
import 'package:cordato/features/core/infrastructure/clients/recording/recording_client.dart';
import 'package:cordato/features/core/presentation/formatters/date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/money_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/interface_date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/interface_money_formatter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ModularBootstrap boot;

  setUpAll(() => initializeDateFormatting('pt_BR'));

  setUp(() async {
    final directory = await Directory.systemTemp.createTemp('cordato-di-');
    addTearDown(() => directory.delete(recursive: true));
    boot = bootstrapModule(
      createModule(
        register: (context) => context
          ..addInstance<Directory>(directory)
          ..module(coreModule),
      ),
    );
    addTearDown(boot.injector.dispose);
  });

  group('Shared formatters', () {
    test('resolves one money formatter without visiting routes', () {
      final formatter = boot.injector.get<IMoneyFormatter>();

      expect(formatter, isA<MoneyFormatter>());
      expect(boot.injector.get<IMoneyFormatter>(), same(formatter));
    });

    test('resolves one date formatter without visiting routes', () {
      final formatter = boot.injector.get<IDateFormatter>();

      expect(formatter, isA<DateFormatter>());
      expect(boot.injector.get<IDateFormatter>(), same(formatter));
    });
  });

  group('Shared native clients', () {
    test('resolves one recorder without preparing a recording', () {
      final recording = boot.injector.get<IRecordingClient>();

      expect(recording, isA<RecordingClient>());
      expect(boot.injector.get<IRecordingClient>(), same(recording));
    });

    test('resolves one share client without accessing the platform', () {
      final sharing = boot.injector.get<IShareClient>();

      expect(sharing, isA<ShareClient>());
      expect(boot.injector.get<IShareClient>(), same(sharing));
    });

    test('resolves one home widget client without observing launches', () {
      final homeWidget = boot.injector.get<IHomeWidgetClient>();

      expect(homeWidget, isA<HomeWidgetClient>());
      expect(boot.injector.get<IHomeWidgetClient>(), same(homeWidget));
    });
  });
}
