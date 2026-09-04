import 'package:material_ui/material_ui.dart';
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

  testWidgets('renders the name, avatar, and greeting', (tester) async {
    when(() => repository.getUserName()).thenAnswer((_) async => 'Gabriel');
    final command = GetUserNameCommand(repository: repository);
    addTearDown(command.dispose);
    command.execute.run();

    await tester.pumpWidget(
      MaterialPreviewWidget(child: UserNameWidget(command: command)),
    );
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            {
              'Bom dia',
              'Boa tarde',
              'Boa noite',
              'Isso são horas?',
            }.contains(widget.data),
      ),
      findsOneWidget,
    );
    expect(find.text('Gabriel'), findsOneWidget);
    expect(find.byType(AvatarDashboardWidget), findsOneWidget);
  });
}
