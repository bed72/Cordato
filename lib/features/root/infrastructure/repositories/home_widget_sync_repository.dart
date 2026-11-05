import 'package:cordato/features/core/application/clients/interface_home_widget_client.dart';
import 'package:cordato/features/metrics/application/repositories/interface_metrics_repository.dart';
import 'package:cordato/features/root/application/repositories/interface_home_widget_sync_repository.dart';

final class HomeWidgetSyncRepository({
  required final IHomeWidgetClient homeWidgetClient,
  required final IMetricsRepository metricsRepository,
}) implements IHomeWidgetSyncRepository {
  @override
  Stream<void> get refreshRequests => homeWidgetClient.monthlyRefreshRequests;

  @override
  Future<void> setSessionActive({required bool active}) =>
      homeWidgetClient.setMonthlySessionActive(active: active);

  @override
  Future<void> refresh() async {
    await metricsRepository.getExpenses();
  }
}
