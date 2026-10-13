import 'package:flutter/foundation.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

abstract interface class ICrashClient {
  Future<void> recordFlutterError(FlutterErrorDetails details);

  Future<void> recordError({
    required Object error,
    required StackTrace stackTrace,
    bool fatal = false,
  });
}

final class CrashClient({required final FirebaseCrashlytics crashlytics})
    implements ICrashClient {
  @override
  Future<void> recordFlutterError(FlutterErrorDetails details) =>
      crashlytics.recordFlutterError(details);

  @override
  Future<void> recordError({
    required Object error,
    required StackTrace stackTrace,
    bool fatal = false,
  }) => crashlytics.recordError(error, stackTrace, fatal: fatal);
}
