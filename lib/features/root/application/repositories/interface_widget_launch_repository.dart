abstract interface class IWidgetLaunchRepository {
  Stream<void> get expenseLaunches;

  Future<bool> initialExpenseLaunch();
}
