import 'package:cordato/features/core/infrastructure/clients/widget_client.dart';
import 'package:cordato/features/metrics/application/repositories/interface_metrics_repository.dart';
import 'package:cordato/features/root/application/repositories/interface_widget_sync_repository.dart';

final class WidgetSyncRepository({
  required final IWidgetClient _client,
  required final IMetricsRepository _repository,
}) implements IWidgetSyncRepository {
  @override
  Stream<void> get refreshRequests => _client.refresh;

  @override
  Future<void> enable() => _client.setMonthly(active: true);

  @override
  Future<void> refresh() async {
    await _repository.getExpenses();
  }
}
