sealed class DashboardEvent {}

final class DashboardOpened extends DashboardEvent {}

final class DashboardUserRequested extends DashboardEvent {}

final class DashboardRetryRequested extends DashboardEvent {}

final class DashboardExpensesChanged extends DashboardEvent {}

final class DashboardRefreshRequested extends DashboardEvent {}

final class DashboardNextMonthRequested extends DashboardEvent {}

final class DashboardPreviousMonthRequested extends DashboardEvent {}
