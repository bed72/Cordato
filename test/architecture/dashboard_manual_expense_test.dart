import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Dashboard has no recording or audio dependencies, including previews',
    () {
      final retiredDependency = RegExp(
        r'audio|áudio|speech|recording|microphone|microfone|onLongPress|capturar fala|reconhecedor',
        caseSensitive: false,
      );

      for (final file
          in Directory('lib/features/dashboard')
              .listSync(recursive: true)
              .whereType<File>()
              .where((file) => file.path.endsWith('.dart'))) {
        expect(
          retiredDependency.hasMatch(file.path),
          isFalse,
          reason: file.path,
        );
        expect(
          retiredDependency.hasMatch(file.readAsStringSync()),
          isFalse,
          reason: file.path,
        );
      }
    },
  );

  test('manual action preserves typed navigation and reloads only its live Dashboard', () {
    final source = File(
      'lib/features/dashboard/presentation/widgets/action_button_dashboard_widget.dart',
    ).readAsStringSync();

    expect(source, contains('extends StatelessWidget'));
    expect(source, contains('context.pushNamed<ExpenseEntity>'));
    expect(source, contains('RouteEnum.expense.path'));
    expect(source, contains('arguments: (returnToPrevious: true)'));
    expect(source, contains('ModalRoute.of(context)?.isCurrent == false'));
    expect(source, contains('expense != null'));
    expect(source, contains('context.mounted'));
    expect(source, contains('!bloc.isClosed'));
    expect(source, contains('identical(context.read<DashboardBloc>(), bloc)'));
    expect(source, contains('bloc.add(DashboardExpensesChanged())'));
    expect(
      source,
      isNot(
        matches(
          r'AnimationController|WidgetsBindingObserver|TickerProvider|BlocConsumer',
        ),
      ),
    );
  });

  test('manual expense button reuses the accessible themed core button', () {
    final source = File(
      'lib/features/dashboard/presentation/widgets/expense_action_button_widget.dart',
    ).readAsStringSync();

    expect(source, contains('IconButtonWidget('));
    expect(source, contains('onPress: onTap'));
    expect(source, contains("label: 'Adicionar gasto'"));
    expect(source, contains('Semantics('));
    expect(source, contains('ExcludeSemantics('));
    expect(source, contains('width: 48.0'));
    expect(source, contains('height: 48.0'));
    expect(source, contains('context.colors.primary'));
    expect(source, contains('context.colors.onPrimary'));
    expect(source, contains('context.radius.cornerRadius100'));
    expect(source, isNot(contains('onLongPress')));
  });
}
