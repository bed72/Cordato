import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:skeletonizer/skeletonizer.dart';

import 'package:cordato/features/core/presentation/previews/material_preview_widget.dart';
import 'package:cordato/features/dashboard/domain/repositories/interface_user_repository.dart';
import 'package:cordato/features/dashboard/presentation/commands/get_user_name_command.dart';
import 'package:cordato/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:cordato/features/dashboard/presentation/widgets/app_bar_dashboard_widget.dart';
import 'package:cordato/features/dashboard/presentation/widgets/user/user_name_skeleton_widget.dart';
import 'package:cordato/features/dashboard/presentation/widgets/user/user_name_widget.dart';

class _UserRepositoryMock extends Mock implements IUserRepository {}

void main() {
  late IUserRepository repository;

  setUp(() {
    repository = _UserRepositoryMock();
  });

  tearDown(() {
    reset(repository);
  });

  testWidgets('renders the dashboard', (tester) async {
    when(() => repository.getUserName()).thenAnswer((_) async => 'Gabriel');
    final command = GetUserNameCommand(repository: repository);

    addTearDown(command.dispose);
    await tester.pumpWidget(
      MaterialPreviewWidget(child: DashboardScreen(command: command)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.byType(AppBarDashboardWidget), findsOneWidget);
    expect(find.byType(UserNameWidget), findsOneWidget);
    expect(find.text('Gabriel'), findsOneWidget);
    expect(find.text('G'), findsOneWidget);
  });

  testWidgets('renders and handles notification and menu actions', (
    tester,
  ) async {
    when(() => repository.getUserName()).thenAnswer((_) async => 'Gabriel');
    var notificationsPressed = false;
    var menuPressed = false;
    final command = GetUserNameCommand(repository: repository);

    addTearDown(command.dispose);
    await tester.pumpWidget(
      MaterialPreviewWidget(
        child: DashboardScreen(
          command: command,
          onNotificationsPressed: () => notificationsPressed = true,
          onMenuPressed: () => menuPressed = true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.notifications_none_rounded), findsOneWidget);
    expect(find.byIcon(Icons.menu), findsOneWidget);
    expect(find.bySemanticsLabel('Notificações'), findsOneWidget);
    expect(find.bySemanticsLabel('Menu'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.notifications_none_rounded));
    await tester.tap(find.byIcon(Icons.menu));

    expect(notificationsPressed, isTrue);
    expect(menuPressed, isTrue);
  });

  testWidgets('shows the skeleton while loading the user', (tester) async {
    final completer = Completer<String?>();
    when(() => repository.getUserName()).thenAnswer((_) => completer.future);
    final command = GetUserNameCommand(repository: repository);

    addTearDown(command.dispose);
    await tester.pumpWidget(
      MaterialPreviewWidget(child: DashboardScreen(command: command)),
    );
    await tester.pump();

    expect(
      find.byWidgetPredicate((widget) => widget is Skeletonizer),
      findsOneWidget,
    );
    expect(find.byType(UserNameSkeletonWidget), findsOneWidget);
    expect(find.text('Usuário'), findsOneWidget);

    completer.complete('Gabriel');
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate((widget) => widget is Skeletonizer),
      findsNothing,
    );
    expect(find.text('Gabriel'), findsOneWidget);
  });
}
