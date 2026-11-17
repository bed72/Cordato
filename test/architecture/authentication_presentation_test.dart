import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cordato/features/core/presentation/enums/route_enum.dart';

void main() {
  test('authentication exposes only email and code routes', () {
    expect(
      RouteEnum.values
          .where((route) => route.path.startsWith('/authentication/'))
          .map((route) => route.path),
      ['/authentication/sign-in', '/authentication/confirm'],
    );
  });

  test('removed password and registration consumers are not restored', () {
    final forbidden = RegExp(
      r'PasswordValidation|PasswordFieldWidget|SignUpBloc|PasswordRecoveryBloc|ChangePasswordBloc|ResetPasswordBloc|CallbackBloc|requestPasswordReset|confirmPasswordReset|changePassword|confirmEmail|\.signIn\(',
    );
    for (final file
        in Directory('lib/features/authentication')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))) {
      expect(
        forbidden.hasMatch(file.readAsStringSync()),
        isFalse,
        reason: file.path,
      );
    }
  });

  test('native callback registrations are removed while the iOS widget scheme remains', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final entitlements = File('ios/Runner/Runner.entitlements')
        .readAsStringSync();
    final info = File('ios/Runner/Info.plist').readAsStringSync();
    expect(manifest, isNot(contains('config_authentication_')));
    expect(manifest, isNot(contains('android:autoVerify')));
    expect(entitlements, isNot(contains('associated-domains')));
    expect(entitlements, contains('group.com.bed.cordato'));
    expect(info, contains('<string>cordato</string>'));
    expect(info, isNot(contains('<string>trocado</string>')));
  });

  test('confirmation keeps its code in the form and delegates session navigation', () {
    final state = File(
      'lib/features/authentication/presentation/screens/code/bloc/code_state.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/features/authentication/presentation/screens/code/code_screen.dart',
    ).readAsStringSync();
    final mixin = File(
      'lib/features/authentication/presentation/screens/code/mixins/code_screen_state_mixin.dart',
    ).readAsStringSync();
    expect(state, isNot(matches(RegExp(r'\bString\b'))));
    expect(screen, contains('bloc: widget.codeBloc'));
    expect(screen, contains('bloc: widget.resendBloc'));
    expect(mixin, contains('_userId = userId'));
    expect(mixin, isNot(contains('RouteEnum.dashboard')));
    expect(mixin, isNot(contains('Timer')));
    expect(mixin, isNot(contains('.close()')));
  });
}
