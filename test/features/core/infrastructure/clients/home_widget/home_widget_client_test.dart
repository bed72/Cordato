import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/widget/widget_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('home_widget');
  const updates = MethodChannel('home_widget/updates');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final launchUri = Uri.parse('cordato://widget/add-expense?homeWidget=true');

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
    messenger.setMockMethodCallHandler(updates, null);
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    group(platform.name, () {
      setUp(() {
        debugDefaultTargetPlatformOverride = platform;
      });

      test(
        'reads the initial widget URI without shared data or credentials',
        () async {
          final calls = <MethodCall>[];
          messenger.setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return launchUri.toString();
          });

          final initialUri = await WidgetClient().initialLaunch();

          expect(initialUri, launchUri);
          expect(calls.single.arguments, isNull);
          expect(calls.single.method, 'initiallyLaunchedFromHomeWidget');
        },
      );

      test('an ordinary app launch has no widget intent', () async {
        messenger.setMockMethodCallHandler(channel, (_) async => null);

        expect(await WidgetClient().initialLaunch(), isNull);
      });

      test(
        'persists only the month and integer cents before reloading widgets',
        () async {
          final calls = <MethodCall>[];
          messenger.setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return true;
          });
          final client = WidgetClient();
          await client.setMonthlySessionActive(active: true);
          final revision = client.beginMonthlyRead();

          await client.publishMonthlyTotal(
            cents: 125099,
            revision: revision,
            month: DateTime(2026, 11),
          );

          final save = calls.singleWhere(
            (call) => call.method == 'saveWidgetData',
          );
          final arguments = save.arguments as Map;

          expect(calls.last.method, 'updateWidget');
          expect(arguments['id'], 'monthly_summary');
          expect((calls.last.arguments as Map)['ios'], 'AddExpenseWidget');
          expect(jsonDecode(arguments['data'] as String), {
            'month': '2026-11',
            'cents': 125099,
          });
          expect(
            (calls.last.arguments as Map)['android'],
            'AddExpenseWidgetProvider',
          );
        },
      );

      test('rejects an older read after a newer read or a mutation', () async {
        final calls = <MethodCall>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return true;
        });
        final client = WidgetClient();
        await client.setMonthlySessionActive(active: true);
        final olderRead = client.beginMonthlyRead();
        final newerRead = client.beginMonthlyRead();

        await client.publishMonthlyTotal(
          cents: 100,
          revision: olderRead,
          month: DateTime(2026, 11),
        );
        client.requestMonthlyRefresh();
        await client.publishMonthlyTotal(
          cents: 200,
          revision: newerRead,
          month: DateTime(2026, 11),
        );

        expect(calls, isEmpty);
      });

      test(
        'logout clears cached data and blocks a late HTTP completion',
        () async {
          final calls = <MethodCall>[];
          messenger.setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return true;
          });
          final client = WidgetClient();
          await client.setMonthlySessionActive(active: true);
          final revision = client.beginMonthlyRead();

          await client.setMonthlySessionActive(active: false);
          await client.publishMonthlyTotal(
            cents: 100,
            revision: revision,
            month: DateTime(2026, 11),
          );

          final saves = calls.where((call) => call.method == 'saveWidgetData');
          expect(saves, hasLength(1));
          expect((saves.single.arguments as Map)['data'], isNull);
        },
      );

      test(
        'logout waits behind an in-flight publication and clears it last',
        () async {
          final saving = Completer<void>();
          final releaseSave = Completer<void>();
          final saved = <Object?>[];
          messenger.setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'saveWidgetData') {
              final data = (call.arguments as Map)['data'];
              if (data != null) {
                saving.complete();
                await releaseSave.future;
              }
              saved.add(data);
            }
            return true;
          });
          final client = WidgetClient();
          await client.setMonthlySessionActive(active: true);
          final publication = client.publishMonthlyTotal(
            revision: client.beginMonthlyRead(),
            month: DateTime(2026, 11),
            cents: 100,
          );
          await saving.future;

          final logout = client.setMonthlySessionActive(active: false);
          releaseSave.complete();
          await Future.wait([publication, logout]);

          expect(saved, hasLength(2));
          expect(saved.last, isNull);
        },
      );

      test('a known platform error is reported without failing metrics or poisoning the next update', () async {
        final reports = <FlutterErrorDetails>[];
        final previousHandler = FlutterError.onError;
        FlutterError.onError = reports.add;
        addTearDown(() => FlutterError.onError = previousHandler);
        messenger.setMockMethodCallHandler(channel, (_) async {
          throw PlatformException(code: 'temporarily-unavailable');
        });
        final client = WidgetClient();
        await client.setMonthlySessionActive(active: true);

        await client.publishMonthlyTotal(
          revision: client.beginMonthlyRead(),
          month: DateTime(2026, 11),
          cents: 100,
        );
        expect(reports, hasLength(1));

        final methods = <String>[];
        messenger.setMockMethodCallHandler(channel, (call) async {
          methods.add(call.method);
          return true;
        });
        await client.publishMonthlyTotal(
          revision: client.beginMonthlyRead(),
          month: DateTime(2026, 11),
          cents: 200,
        );

        expect(methods.last, 'updateWidget');
      });

      test('does not turn platform failures into a valid launch', () async {
        messenger.setMockMethodCallHandler(channel, (_) async {
          throw PlatformException(code: 'unavailable');
        });

        await expectLater(
          WidgetClient().initialLaunch(),
          throwsA(isA<PlatformException>()),
        );
      });

      test(
        'subscribes to warm launches and cancels the native listener',
        () async {
          final listening = Completer<void>();
          final cancelled = Completer<void>();
          messenger.setMockMethodCallHandler(updates, (call) async {
            if (call.method == 'listen') {
              listening.complete();
            }
            if (call.method == 'cancel') {
              cancelled.complete();
            }
            return null;
          });
          final delivered = Completer<Uri?>();
          final subscription = WidgetClient().launches.listen(
            delivered.complete,
          );
          addTearDown(subscription.cancel);
          await listening.future;

          messenger.handlePlatformMessage(
            'home_widget/updates',
            const StandardMethodCodec().encodeSuccessEnvelope(
              launchUri.toString(),
            ),
            (_) {},
          );

          expect(await delivered.future, launchUri);
          await subscription.cancel();
          await cancelled.future;
        },
      );
    });
  }

  test(
    'iOS configures the shared App Group before saving monthly data',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return true;
      });
      final client = WidgetClient();
      await client.setMonthlySessionActive(active: true);

      await client.publishMonthlyTotal(
        revision: client.beginMonthlyRead(),
        month: DateTime(2026, 11),
        cents: 0,
      );

      expect(calls.first.method, 'setAppGroupId');
      expect(calls.first.arguments, {'groupId': 'group.com.bed.cordato'});
    },
  );

  test('mutation refresh requests are observable and subscriptions are cancellable', () async {
    final client = WidgetClient();
    final delivered = Completer<void>();
    final subscription = client.monthlyRefreshRequests.listen(
      (_) => delivered.complete(),
    );

    client.requestMonthlyRefresh();
    await delivered.future;
    await subscription.cancel();
    client.requestMonthlyRefresh();
  });

  test(
    'unsupported platforms neither invoke native code nor emit launches',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final client = WidgetClient();

      expect(await client.initialLaunch(), isNull);
      expect(await client.launches.toList(), isEmpty);
    },
  );
}
