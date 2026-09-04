import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:cordato/features/core/presentation/previews/material_preview_widget.dart';
import 'package:cordato/features/dashboard/domain/repositories/interface_user_repository.dart';
import 'package:cordato/features/dashboard/presentation/commands/get_user_name_command.dart';
import 'package:cordato/features/dashboard/presentation/widgets/avatar_dashboard_widget.dart';
import 'package:cordato/features/dashboard/presentation/widgets/user/user_name_widget.dart';

class _UserRepositoryMock extends Mock implements IUserRepository {}

void main() {
  late IUserRepository repository;

  setUp(() {
    repository = _UserRepositoryMock();
  });

  testWidgets('renders the name and morning greeting', (tester) async {
    when(() => repository.getUserName()).thenAnswer((_) async => 'Gabriel');
    final command = GetUserNameCommand(repository: repository);
    addTearDown(command.dispose);
    command.execute.run();

    await tester.pumpWidget(
      MaterialPreviewWidget(child: UserNameWidget(command: command)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bom dia'), findsOneWidget);
    expect(find.text('Gabriel'), findsOneWidget);
    expect(find.byType(AvatarDashboardWidget), findsOneWidget);
  });

  testWidgets('renders the afternoon greeting', (tester) async {
    when(() => repository.getUserName()).thenAnswer((_) async => 'Gabriel');
    final command = GetUserNameCommand(repository: repository);
    addTearDown(command.dispose);
    command.execute.run();

    await tester.pumpWidget(
      MaterialPreviewWidget(child: UserNameWidget(command: command)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Boa tarde'), findsOneWidget);
  });

  testWidgets('renders the night greeting', (tester) async {
    when(() => repository.getUserName()).thenAnswer((_) async => 'Gabriel');
    final command = GetUserNameCommand(repository: repository);
    addTearDown(command.dispose);
    command.execute.run();

    await tester.pumpWidget(
      MaterialPreviewWidget(child: UserNameWidget(command: command)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Boa noite'), findsOneWidget);
  });

  testWidgets('renders the late night greeting', (tester) async {
    when(() => repository.getUserName()).thenAnswer((_) async => 'Gabriel');
    final command = GetUserNameCommand(repository: repository);
    addTearDown(command.dispose);
    command.execute.run();

    await tester.pumpWidget(
      MaterialPreviewWidget(child: UserNameWidget(command: command)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Isso são horas?'), findsOneWidget);
  });
}
