import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory workspace;
  late File pubspec;

  setUp(() {
    workspace = Directory.systemTemp.createTempSync('cordato-release-version-');
    pubspec = File('${workspace.path}/pubspec.yaml');
  });

  tearDown(() {
    workspace.deleteSync(recursive: true);
  });

  Future<ProcessResult> calculateVersion({
    required String version,
    String runNumber = '1',
    String attempt = '1',
  }) async {
    pubspec.writeAsStringSync('name: cordato\nversion: $version\n');

    return Process.run(
      'bash',
      ['tool/android_release_version.sh', pubspec.path],
      environment: {
        'GITHUB_RUN_NUMBER': runNumber,
        'GITHUB_RUN_ATTEMPT': attempt,
      },
    );
  }

  group('Android release version', () {
    for (final scenario in [
      (version: '1.0.0+1', runNumber: '1', name: '1.0.0', code: 6),
      (version: '1.0.1+1', runNumber: '2', name: '1.0.1', code: 7),
      (version: '1.1.0+1', runNumber: '3', name: '1.1.0', code: 8),
      (version: '1.1.0+99', runNumber: '4', name: '1.1.0', code: 9),
      (version: '2.0.0', runNumber: '5', name: '2.0.0', code: 10),
      (
        version: '2.0.0+1',
        runNumber: '2099999995',
        name: '2.0.0',
        code: 2100000000,
      ),
    ]) {
      test('${scenario.version} run ${scenario.runNumber}', () async {
        final calculation = await calculateVersion(
          version: scenario.version,
          runNumber: scenario.runNumber,
        );

        expect(calculation.exitCode, 0);
        expect(calculation.stderr, isEmpty);
        expect(
          calculation.stdout,
          'build_name=${scenario.name}\nbuild_number=${scenario.code}\n',
        );
        expect(
          pubspec.readAsStringSync(),
          'name: cordato\nversion: ${scenario.version}\n',
        );
      });
    }

    test('retries preserve the build code of the original run', () async {
      final firstAttempt = await calculateVersion(
        version: '1.0.0+1',
        runNumber: '8',
      );
      final retryAttempt = await calculateVersion(
        version: '1.0.0+1',
        runNumber: '8',
        attempt: '2',
      );

      expect(firstAttempt.exitCode, 0);
      expect(retryAttempt.exitCode, 0);
      expect(retryAttempt.stdout, firstAttempt.stdout);
    });

    for (final runNumber in [
      '',
      '0',
      '-1',
      '01',
      '1.5',
      'abc',
      '2099999996',
      '99999999999',
    ]) {
      test('rejects invalid run number "$runNumber"', () async {
        final calculation = await calculateVersion(
          version: '1.0.0+1',
          runNumber: runNumber,
        );

        expect(calculation.exitCode, isNot(0));
        expect(calculation.stdout, isEmpty);
        expect(calculation.stderr, isNotEmpty);
      });
    }

    for (final version in ['', '1.0', '1.0.0+abc', '1.0.0\nversion: 2.0.0']) {
      test('rejects invalid version "$version"', () async {
        final calculation = await calculateVersion(version: version);

        expect(calculation.exitCode, isNot(0));
        expect(calculation.stdout, isEmpty);
        expect(calculation.stderr, isNotEmpty);
      });
    }
  });
}
