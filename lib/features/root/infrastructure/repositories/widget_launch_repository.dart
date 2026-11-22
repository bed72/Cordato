import 'package:cordato/features/core/infrastructure/clients/widget_client.dart';
import 'package:cordato/features/root/application/repositories/interface_widget_launch_repository.dart';
import 'package:cordato/features/root/infrastructure/serializers/widget_launch_serializer.dart';

final class WidgetLaunchRepository({required final IWidgetClient _client})
    implements IWidgetLaunchRepository {
  @override
  Stream<void> get expenseLaunches =>
      _client.launches.where(isWidgetExpenseLaunch).map<void>((_) {});

  @override
  Future<bool> initialExpenseLaunch() async =>
      isWidgetExpenseLaunch(await _client.initialLaunch());
}
