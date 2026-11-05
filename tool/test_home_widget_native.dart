import 'dart:io';

Future<void> main(List<String> arguments) async {
  if (!File('ios/AddExpenseWidget/WidgetPresentation.swift').existsSync()) {
    stderr.writeln('Execute este comando na raiz do projeto Cordato.');
    exitCode = 1;
    return;
  }

  if (arguments.length > 1 ||
      arguments.any((platform) => !['android', 'ios'].contains(platform))) {
    stderr.writeln(
      'Uso: dart run tool/test_home_widget_native.dart [android|ios]',
    );
    exitCode = 1;
    return;
  }

  final platform = arguments.firstOrNull;
  if (platform != 'ios') {
    final wrapper = Platform.isWindows
        ? 'android/gradlew.bat'
        : './android/gradlew';
    if (!await runNativeCommand(wrapper, [
      '-p',
      'android',
      ':app:testDebugUnitTest',
    ])) {
      return;
    }
  }

  if (platform == 'android') {
    return;
  }

  if (!Platform.isMacOS) {
    stderr.writeln('Os testes Swift precisam de macOS com Xcode.');
    exitCode = 1;
    return;
  }

  final directory = await Directory.systemTemp.createTemp(
    'cordato-widget-tests-',
  );
  try {
    final sdkPlatform = await Process.run('xcrun', [
      '--show-sdk-platform-path',
    ]);
    if (sdkPlatform.exitCode != 0) {
      stderr.write(sdkPlatform.stderr);
      exitCode = sdkPlatform.exitCode;
      return;
    }

    final frameworks =
        '${sdkPlatform.stdout.toString().trim()}/Developer/Library/Frameworks';
    final libraries =
        '${sdkPlatform.stdout.toString().trim()}/Developer/usr/lib';
    final executable = '${directory.path}/widget-tests';
    if (!await runNativeCommand('xcrun', [
      'swiftc',
      'ios/AddExpenseWidget/WidgetPresentation.swift',
      'test/native/ios/main.swift',
      '-F',
      frameworks,
      '-I',
      libraries,
      '-L',
      libraries,
      '-lXCTestSwiftSupport',
      '-Xlinker',
      '-rpath',
      '-Xlinker',
      frameworks,
      '-Xlinker',
      '-rpath',
      '-Xlinker',
      libraries,
      '-o',
      executable,
    ])) {
      return;
    }

    await runNativeCommand(executable, []);
  } finally {
    await directory.delete(recursive: true);
  }
}

Future<bool> runNativeCommand(String executable, List<String> arguments) async {
  final process = await Process.start(
    executable,
    arguments,
    mode: ProcessStartMode.inheritStdio,
  );
  final commandExitCode = await process.exitCode;
  if (commandExitCode != 0) {
    exitCode = commandExitCode;
    return false;
  }

  return true;
}
