import 'package:cordato/features/core/application/clients/interface_widget_client.dart';
import 'package:cordato/features/root/application/repositories/interface_home_widget_launch_repository.dart';
import 'package:cordato/features/root/infrastructure/serializers/home_widget_launch_serializer.dart';

final class HomeWidgetLaunchRepository({
  required final IWidgetClient homeWidgetClient,
}) implements IHomeWidgetLaunchRepository {
  @override
  Stream<void> get expenseLaunches => homeWidgetClient.launches
      .where(isHomeWidgetExpenseLaunch)
      .map<void>((_) {});

  @override
  Future<bool> initialExpenseLaunch() async =>
      isHomeWidgetExpenseLaunch(await homeWidgetClient.initialLaunch());
}
