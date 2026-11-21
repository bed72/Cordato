import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CSV-only contracts, adapters and presentation are removed', () {
    for (final path in [
      'lib/features/expense/application/models/document_model.dart',
      'lib/features/expense/application/repositories/interface_export_repository.dart',
      'lib/features/expense/infrastructure/repositories/export_repository.dart',
      'lib/features/expense/infrastructure/serializers/csv_serializer.dart',
      'lib/features/settings/application/exceptions/export_exception.dart',
      'lib/features/settings/application/models/prepared_export_model.dart',
      'lib/features/settings/application/repositories/interface_export_repository.dart',
      'lib/features/settings/infrastructure/repositories/export_repository.dart',
      'lib/features/settings/presentation/screens/settings/bloc/export_bloc.dart',
      'lib/features/settings/presentation/screens/settings/bloc/export_event.dart',
      'lib/features/settings/presentation/screens/settings/bloc/export_state.dart',
      'lib/features/settings/presentation/screens/settings/mixins/export_state_mixin.dart',
      'lib/features/settings/presentation/screens/settings/widgets/export_widget.dart',
    ]) {
      expect(File(path).existsSync(), isFalse, reason: path);
    }
  });

  test('production has no CSV dependency or dangling export references', () {
    for (final file
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.dart'))) {
      expect(
        file.readAsStringSync(),
        isNot(
          matches(
          r'package:csv/|package:share_plus/|CsvSerializer|DocumentModel|PreparedExportModel|ExportBloc|ExportWidget|interface_export_repository\.dart|IShareClient|ShareClient|ShareAttachmentModel|ShareOriginModel|ShareOutcomeEnum|FileShareException',
          ),
        ),
        reason: file.path,
      );
    }

    expect(
      File('pubspec.yaml').readAsStringSync(),
      isNot(matches(RegExp(r'^\s+(csv|share_plus):', multiLine: true))),
    );
  });

  test(
    'Settings has no Expense dependency and does not implement backup yet',
    () {
      for (final file
          in Directory('lib/features/settings')
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => file.path.endsWith('.dart'))) {
        expect(
          file.readAsStringSync(),
          isNot(
            matches(
              r'features/expense/|package:tostore/|\.backup\(|\.restore\(',
            ),
          ),
          reason: file.path,
        );
      }
    },
  );
}
