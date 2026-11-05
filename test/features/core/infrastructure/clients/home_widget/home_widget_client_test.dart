import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/home_widget/home_widget_client.dart';

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

          final initialUri = await HomeWidgetClient().initialLaunch();

          expect(initialUri, launchUri);
          expect(calls.single.method, 'initiallyLaunchedFromHomeWidget');
          expect(calls.single.arguments, isNull);
        },
      );

      test('an ordinary app launch has no widget intent', () async {
        messenger.setMockMethodCallHandler(channel, (_) async => null);

        expect(await HomeWidgetClient().initialLaunch(), isNull);
      });

      test('does not turn platform failures into a valid launch', () async {
        messenger.setMockMethodCallHandler(channel, (_) async {
          throw PlatformException(code: 'unavailable');
        });

        await expectLater(
          HomeWidgetClient().initialLaunch(),
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
          final subscription = HomeWidgetClient().launches.listen(
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
    'unsupported platforms neither invoke native code nor emit launches',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final client = HomeWidgetClient();

      expect(await client.initialLaunch(), isNull);
      expect(await client.launches.toList(), isEmpty);
    },
  );
}
