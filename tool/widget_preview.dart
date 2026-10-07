import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final file = File('lib/features/core/presentation/previews/preview.dart');
  if (!file.existsSync()) {
    stderr.writeln('Execute este comando na raiz do projeto Cordato.');
    exitCode = 1;
    return;
  }

  final process = await Process.start('flutter', [
    'widget-preview',
    'start',
    '--web-server',
    ...arguments,
  ]);

  final signals = [
    ProcessSignal.sigint.watch().listen((_) => process.kill(.sigint)),
    ProcessSignal.sigterm.watch().listen((_) => process.kill(.sigterm)),
  ];

  bool refreshed = false;
  final input = stdin.listen(process.stdin.add);
  final refreshFile = File('tool/.widget_preview_refresh_$pid.dart');

  final output = process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) {
        stdout.writeln(line);
        if (!refreshed && line.contains('is being served at')) {
          refreshed = true;
          refreshFile.writeAsStringSync('\n');
        }
      });
  final errors = process.stderr.listen(stderr.add);

  exitCode = await process.exitCode;
  if (refreshFile.existsSync()) refreshFile.deleteSync();
  await input.cancel();
  await output.cancel();
  await errors.cancel();
  for (final signal in signals) {
    await signal.cancel();
  }
}
