import 'dart:convert';
import 'dart:io';

Map<String, String> associationFiles({
  required String appleAppId,
  required List<String> androidSha256,
}) {
  if (!RegExp(r'^[A-Z0-9]{10}\.com\.bed\.cordato$').hasMatch(appleAppId)) {
    throw const FormatException(
      'Informe o application-identifier Apple: PREFIX.com.bed.cordato.',
    );
  }
  final fingerprintPattern = RegExp(r'^(?:[A-Fa-f0-9]{2}:){31}[A-Fa-f0-9]{2}$');
  if (androidSha256.isEmpty ||
      androidSha256.any((value) => !fingerprintPattern.hasMatch(value))) {
    throw const FormatException(
      'Informe ao menos um SHA-256 Android com 32 pares hexadecimais separados por dois-pontos.',
    );
  }

  const encoder = JsonEncoder.withIndent('  ');
  final android = [
    {
      'relation': ['delegate_permission/common.handle_all_urls'],
      'target': {
        'namespace': 'android_app',
        'package_name': 'com.bed.cordato',
        'sha256_cert_fingerprints': androidSha256
            .map((value) => value.toUpperCase())
            .toSet()
            .toList(),
      },
    },
  ];
  final apple = {
    'applinks': {
      'details': [
        {
          'appIDs': [appleAppId],
          'components': [
            {'/': '/authentication/confirm-email'},
          ],
        },
      ],
    },
  };
  return {
    'assetlinks.json': '${encoder.convert(android)}\n',
    'apple-app-site-association': '${encoder.convert(apple)}\n',
  };
}

Future<void> main(List<String> arguments) async {
  if (arguments.length < 2) {
    stderr.writeln(
      'Uso: dart run tool/app_links.dart PREFIX.com.bed.cordato SHA256 [SHA256...]',
    );
    exitCode = 64;
    return;
  }

  final Map<String, String> files;
  try {
    files = associationFiles(
      appleAppId: arguments.first,
      androidSha256: arguments.skip(1).toList(),
    );
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 64;
    return;
  }

  final directory = Directory('build/app_links/.well-known');
  await directory.create(recursive: true);
  for (final entry in files.entries) {
    await File('${directory.path}/${entry.key}').writeAsString(entry.value);
  }
  stdout.writeln(
    'Arquivos gerados em build/app_links; nenhum deploy executado.',
  );
}
