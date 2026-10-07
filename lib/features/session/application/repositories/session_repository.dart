import 'package:cordato/features/session/infrastructure/local/session_local_data_source.dart';
import 'package:cordato/features/session/domain/repositories/interface_session_repository.dart';

final class SessionRepository({
  required final ISessionLocalDataSource dataSource,
}) implements ISessionRepository {
  @override
  Future<bool> loadSession() => dataSource.loadSession();

  @override
  Stream<bool> get sessionChanges => dataSource.sessionChanges;
}
