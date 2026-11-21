import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Settings has no authentication or session dependency', () {
    final retiredDependency = RegExp(
      r'features/(?:authentication|session)/|LogoutBloc|LogoutState|MissingAuthenticatedUserException',
    );
    for (final file
        in Directory('lib/features/settings')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))) {
      expect(
        retiredDependency.hasMatch(file.readAsStringSync()),
        isFalse,
        reason: file.path,
      );
    }
  });

  test('Settings receives the export Bloc without owning its lifecycle', () {
    final source = File(
      'lib/features/settings/presentation/screens/settings/settings_screen.dart',
    ).readAsStringSync();

    expect(source, contains('extends StatelessWidget'));
    expect(source, contains('required final ExportBloc exportBloc'));
    expect(source, isNot(contains('.close(')));
    expect(source, isNot(contains('onPersonalDataPressed')));
    expect(source, contains('RouteEnum.user.path'));
  });

  test('the single Settings module declares full local destinations', () {
    final source = File('lib/features/settings/settings_module.dart')
        .readAsStringSync();

    expect(source, contains('RouteEnum.settings.path'));
    expect(source, contains('RouteEnum.settingsSupport.path'));
    expect(source, isNot(contains('path:')));
    expect(source, contains('scope.addBloc<ExportBloc>'));
  });
}
