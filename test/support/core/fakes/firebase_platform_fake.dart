import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';

final class FirebasePlatformFake({
  required var Future<FirebaseAppPlatform> Function(FirebaseOptions? options)
  initialize,
}) extends FirebasePlatform {
  String? initializedName;

  @override
  Future<FirebaseAppPlatform> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) {
    initializedName = name;
    return initialize(options);
  }
}
