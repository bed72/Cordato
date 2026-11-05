abstract interface class IHomeWidgetLaunchRepository {
  Stream<void> get expenseLaunches;

  Future<bool> initialExpenseLaunch();
}
