import 'package:mocktail/mocktail.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cordato/features/core/infrastructure/clients/firebase/crash_client.dart';

import '../../../../../support/core/mocks/firebase_crashlytics_mock.dart';

void main() {
  late CrashClient client;
  late FirebaseCrashlyticsMock crashlytics;

  setUp(() {
    crashlytics = FirebaseCrashlyticsMock();
    client = CrashClient(crashlytics: crashlytics);
  });

  test('records Flutter errors with their original details', () async {
    final details = FlutterErrorDetails(
      stack: StackTrace.current,
      exception: StateError('Framework error'),
      context: ErrorDescription('Rendering a financial section'),
    );
    when(() => crashlytics.recordFlutterError(details))
        .thenAnswer((_) async {});

    await client.recordFlutterError(details);

    verify(() => crashlytics.recordFlutterError(details)).called(1);
  });

  for (final fatal in [false, true]) {
    test('preserves the exception, stack trace and fatal=$fatal', () async {
      final error = StateError('Unhandled error');
      final stackTrace = StackTrace.current;
      when(() => crashlytics.recordError(error, stackTrace, fatal: fatal))
          .thenAnswer((_) async {});

      await client.recordError(
        error: error,
        fatal: fatal,
        stackTrace: stackTrace,
      );

      verify(() => crashlytics.recordError(error, stackTrace, fatal: fatal))
          .called(1);
    });
  }

  test(
    'preserves SDK failures and reports errors as non-fatal by default',
    () async {
      final stackTrace = StackTrace.current;
      final error = StateError('Original error');
      final failure = StateError('Reporting failed');
      when(() => crashlytics.recordError(error, stackTrace, fatal: false))
          .thenAnswer((_) async => throw failure);

      await expectLater(
        client.recordError(error: error, stackTrace: stackTrace),
        throwsA(same(failure)),
      );
    },
  );
}
