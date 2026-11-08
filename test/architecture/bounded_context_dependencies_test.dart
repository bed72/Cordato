import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _importPattern = RegExp(
  r'''(?:import|export)\s+['"]package:cordato/features/([^/'"]+)/([^'"]+)['"]''',
);

const _financialContexts = {'expense', 'budget', 'family'};
const _forbiddenDomainImports = {
  'package:speech_to_text/',
  'package:pocketbase/',
  'package:csv/',
  'package:share_plus/',
  'package:path_provider/',
  'package:dio/',
  'package:http/',
  'package:bloc/',
  'package:flutter_bloc/',
  'package:bloc_concurrency/',
  'package:flutter/',
  'package:material_ui/',
  'package:supabase_flutter/',
  'package:flutter_secure_storage/',
};
const _forbiddenPresentationImports = {
  'package:speech_to_text/',
  'package:share_plus/',
  'package:path_provider/',
  'package:csv/',
  'package:dio/',
  'package:pocketbase/',
  'package:http/',
  'package:supabase_flutter/',
  'package:flutter_secure_storage/',
};
final _financialDirectWritePattern = RegExp(
  r'''\.from\s*\(\s*(?:SupabaseTableEnum\.(?:expenses|budgets)\.value|['"](?:expenses|budgets)['"])\s*\)\s*\.(?:insert|update|delete)\s*\(''',
  multiLine: true,
);

void main() {
  group('Bounded contexts and feature isolation', () {
    test('keeps out-of-scope backend contexts out of the app', () {
      final featuresDirectory = Directory('lib/features');
      final outOfScope = ['identity', 'chat', 'insight']
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

        for (final match in _importPattern.allMatches(
          file.readAsStringSync(),
        )) {
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
            'family' => isInfrastructure,
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

        for (final match in _importPattern.allMatches(
          file.readAsStringSync(),
        )) {
          final targetContext = match.group(1)!;
          if ((sourceContext == 'session' &&
                  targetContext == 'authentication') ||
              (sourceContext == 'authentication' &&
                  targetContext == 'session')) {
            violations.add(
              '${file.path}: $sourceContext cannot import $targetContext',
            );
          }
        }
      }

      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  });

  group('Layer boundaries and application contracts', () {
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
              r'''package:cordato/features/[^/'"]+/(?:application/(?:repositories|models|exceptions)|data|infrastructure|presentation)/''',
            ).hasMatch(source)) {
          violations.add('${file.path}: domain imports an outer layer');
        }

        if (isPresentation) {
          for (final match in _importPattern.allMatches(source)) {
            final targetContext = match.group(1)!;
            final targetPath = match.group(2)!;
            final isFeatureRepositoryContract =
                (targetContext == 'authentication' ||
                    targetContext == 'session' ||
                    targetContext == 'user' ||
                    targetContext == 'expense' ||
                    targetContext == 'metrics') &&
                targetPath ==
                    'application/repositories/interface_${targetContext}_repository.dart';
            final isRootWidgetContract =
                targetContext == 'root' &&
                {
                  'application/repositories/interface_home_widget_sync_repository.dart',
                  'application/repositories/interface_home_widget_launch_repository.dart',
                }.contains(targetPath);
            final isApplicationContract =
                (targetContext == 'dashboard' &&
                    targetPath ==
                        'application/repositories/interface_speech_repository.dart') ||
                isFeatureRepositoryContract ||
                isRootWidgetContract ||
                (targetContext == 'settings' &&
                    targetPath ==
                        'application/repositories/interface_export_repository.dart');
            final isOuterAdapter =
                targetPath.startsWith('application/clients/') ||
                targetPath.startsWith('application/repositories/') ||
                targetPath.startsWith('data/') ||
                targetPath.startsWith('infrastructure/');
            if (isOuterAdapter && !isApplicationContract) {
              violations.add(
                '${file.path}: presentation imports an outer adapter (${match.group(0)})',
              );
            }
          }
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

    test('keeps migrated application contracts independent from adapters', () {
      final violations = <String>[];
      for (final file in _dartFiles().where(
        (file) =>
            (file.uri.pathSegments.contains('authentication') ||
                file.uri.pathSegments.contains('session') ||
                file.uri.pathSegments.contains('user') ||
                file.uri.pathSegments.contains('expense') ||
                file.uri.pathSegments.contains('settings') ||
                file.uri.pathSegments.contains('core') ||
                file.uri.pathSegments.contains('metrics')) &&
            file.uri.pathSegments.contains('application'),
      )) {
        final source = file.readAsStringSync();
        for (final match in _importPattern.allMatches(source)) {
          final targetPath = match.group(2)!;
          if (targetPath.startsWith('infrastructure/') ||
              targetPath.startsWith('presentation/')) {
            violations.add(
              '${file.path}: application contract imports an adapter (${match.group(0)})',
            );
          }
        }
        if (_forbiddenDomainImports.any(source.contains) ||
            source.contains('package:command_it/')) {
          violations.add(
            '${file.path}: application contract imports a UI or external SDK dependency',
          );
        }
      }
      expect(violations, isEmpty, reason: violations.join('\n'));
    });

    test('keeps Settings dependencies on Authentication contracts and exceptions', () {
      final violations = <String>[];

      for (final file in _dartFiles().where(
        (file) => file.uri.pathSegments.contains('settings'),
      )) {
        for (final match in _importPattern.allMatches(
          file.readAsStringSync(),
        )) {
          final targetContext = match.group(1)!;
          final targetPath = match.group(2)!;
          if (targetContext != 'authentication' ||
              targetPath.startsWith('domain/') ||
              targetPath ==
                  'application/repositories/interface_authentication_repository.dart' ||
              targetPath ==
                  'application/exceptions/authentication_exception.dart') {
            continue;
          }

          violations.add(
            '${file.path}: Settings can only import Authentication domain, '
            'repository contract or application exception, '
            'not $targetPath',
          );
        }
      }

      expect(violations, isEmpty, reason: violations.join('\n'));
    });
  });

  group('Migration constraints and financial writes', () {
    test('keeps migrated contexts on direct repository results without data sources', () {
      final violations = <String>[];
      for (final file in _dartFiles().where(
        (file) =>
            file.uri.pathSegments.contains('user') ||
            file.uri.pathSegments.contains('metrics') ||
            file.uri.pathSegments.contains('expense'),
      )) {
        final source = file.readAsStringSync();
        if (source.contains('features/core/domain/either.dart') ||
            RegExp(r'\b(?:Either|Left|Right)\s*[<(]').hasMatch(source)) {
          violations.add(
            '${file.path}: migrated contexts must use direct results and exceptions',
          );
        }
        if (file.path.contains('/domain/repositories/') ||
            file.path.endsWith('_data_source.dart')) {
          violations.add(
            '${file.path}: migrated context has a legacy repository/data source layer',
          );
        }
        for (final match in _importPattern.allMatches(source)) {
          final targetPath = match.group(2)!;
          if (match.group(1) == 'core' &&
              targetPath.startsWith('infrastructure/') &&
              !file.uri.pathSegments.contains('infrastructure')) {
            violations.add(
              '${file.path}: only infrastructure may use core clients (${match.group(0)})',
            );
          }
        }
      }
      expect(violations, isEmpty, reason: violations.join('\n'));
    });

    test(
      'keeps User and Metrics presentation on Bloc without legacy commands',
      () {
        final violations = <String>[];
        for (final file in _dartFiles().where(
          (file) =>
              file.path.startsWith('lib/features/user/') ||
              file.path.startsWith('lib/features/metrics/'),
        )) {
          final source = file.readAsStringSync();
          if (file.uri.pathSegments.contains('commands') ||
              source.contains('package:command_it/') ||
              source.contains('presentation/commands/')) {
            violations.add(
              '${file.path}: migrated contexts must use Bloc, not commands',
            );
          }
        }
        expect(violations, isEmpty, reason: violations.join('\n'));
      },
    );

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
