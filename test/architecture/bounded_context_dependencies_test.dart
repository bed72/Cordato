import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _importPattern = RegExp(
  r'''(?:import|export)\s+['"]package:cordato/features/([^/'"]+)/([^'"]+)['"]''',
);

const _financialContexts = {'expense', 'budget', 'family', 'insight'};
const _forbiddenDomainImports = {
  'package:dio/',
  'package:bloc/',
  'package:flutter_bloc/',
  'package:bloc_concurrency/',
  'package:flutter/',
  'package:material_ui/',
  'package:supabase_flutter/',
  'package:flutter_secure_storage/',
};
const _forbiddenPresentationImports = {
  'package:dio/',
  'package:supabase_flutter/',
  'package:flutter_secure_storage/',
};
final _financialDirectWritePattern = RegExp(
  r'''\.from\s*\(\s*(?:SupabaseTableEnum\.(?:expenses|budgets)\.value|['"](?:expenses|budgets)['"])\s*\)\s*\.(?:insert|update|delete)\s*\(''',
  multiLine: true,
);

void main() {
  test('keeps out-of-scope backend contexts out of the app', () {
    final featuresDirectory = Directory('lib/features');
    final outOfScope = ['identity', 'chat']
        .where(
          (context) =>
              Directory('${featuresDirectory.path}/$context').existsSync(),
        )
        .toList();

    expect(
      outOfScope,
      isEmpty,
      reason: 'These contexts are out of scope: ${outOfScope.join(', ')}',
    );
  });

  test('keeps bounded-context dependencies within approved directions', () {
    final violations = <String>[];

    for (final file in _dartFiles()) {
      final sourceContext = _contextFrom(file);
      if (sourceContext == null) continue;

      for (final match in _importPattern.allMatches(file.readAsStringSync())) {
        final targetContext = match.group(1)!;
        final targetPath = match.group(2)!;
        if (!_financialContexts.contains(sourceContext) ||
            !_financialContexts.contains(targetContext) ||
            sourceContext == targetContext) {
          continue;
        }

        final isInfrastructure = file.uri.pathSegments.contains(
          'infrastructure',
        );
        final allowed = switch (sourceContext) {
          'family' => targetContext != 'insight' && isInfrastructure,
          'insight' => isInfrastructure,
          _ => false,
        };

        if (!allowed) {
          violations.add(
            '${file.path}: $sourceContext cannot import '
            '$targetContext ($targetPath)',
          );
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('keeps session observation separate from authentication', () {
    final violations = <String>[];

    for (final file in _dartFiles()) {
      final sourceContext = _contextFrom(file);
      if (sourceContext != 'session' && sourceContext != 'authentication') {
        continue;
      }

      for (final match in _importPattern.allMatches(file.readAsStringSync())) {
        final targetContext = match.group(1)!;
        if ((sourceContext == 'session' && targetContext == 'authentication') ||
            (sourceContext == 'authentication' && targetContext == 'session')) {
          violations.add(
            '${file.path}: $sourceContext cannot import $targetContext',
          );
        }
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('keeps domain and presentation independent from external adapters', () {
    final violations = <String>[];

    for (final file in _dartFiles()) {
      final pathSegments = file.uri.pathSegments;
      final isDomain = pathSegments.contains('domain');
      final isPresentation = pathSegments.contains('presentation');
      final isApplication = pathSegments.contains('application');
      if (!isDomain && !isPresentation && !isApplication) continue;

      final source = file.readAsStringSync();
      if (isDomain &&
          RegExp(
            r'''package:cordato/features/[^/'"]+/(?:application/repositories|data|infrastructure|presentation)/''',
          ).hasMatch(source)) {
        violations.add('${file.path}: domain imports an outer layer');
      }

      if (isPresentation &&
          RegExp(
            r'''package:cordato/features/[^/'"]+/(?:application/repositories|data|infrastructure)/''',
          ).hasMatch(source)) {
        violations.add('${file.path}: presentation imports an outer adapter');
      }

      if (isApplication &&
          RegExp(r'''package:cordato/features/[^/'"]+/presentation/''')
              .hasMatch(source)) {
        violations.add('${file.path}: application imports presentation');
      }

      if (isDomain && _forbiddenDomainImports.any(source.contains)) {
        violations.add(
          '${file.path}: domain imports a UI or external SDK dependency',
        );
      }

      if (isDomain && source.contains('package:command_it/')) {
        violations.add(
          '${file.path}: domain imports a presentation dependency',
        );
      }

      if (isPresentation &&
          _forbiddenPresentationImports.any(source.contains)) {
        violations.add(
          '${file.path}: presentation imports an external adapter SDK',
        );
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('keeps Settings dependencies on Authentication contracts and logout command', () {
    final violations = <String>[];

    for (final file in _dartFiles().where(
      (file) => file.uri.pathSegments.contains('settings'),
    )) {
      for (final match in _importPattern.allMatches(file.readAsStringSync())) {
        final targetContext = match.group(1)!;
        final targetPath = match.group(2)!;
        if (targetContext != 'authentication' ||
            targetPath.startsWith('domain/') ||
            targetPath == 'presentation/commands/logout_command.dart') {
          continue;
        }

        violations.add(
          '${file.path}: Settings can only import Authentication domain '
          'or LogoutCommand, '
          'not $targetPath',
        );
      }
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('requires financial writes to use RPCs', () {
    final violations = <String>[];

    for (final file in _dartFiles()) {
      if (!_financialContexts.contains(_contextFrom(file))) continue;
      if (!_financialDirectWritePattern.hasMatch(file.readAsStringSync())) {
        continue;
      }

      violations.add('${file.path}: direct financial table write detected');
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });
}

Iterable<File> _dartFiles() =>
    Directory('lib/features')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

String? _contextFrom(File file) {
  final segments = file.uri.pathSegments;
  final featureIndex = segments.indexOf('features');
  if (featureIndex == -1 || featureIndex + 1 >= segments.length) return null;

  final context = segments[featureIndex + 1];
  return _financialContexts.contains(context) ? context : null;
}
