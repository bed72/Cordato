import 'package:cordato/features/user/domain/entities/user_entity.dart';
import 'package:cordato/features/core/domain/entities/errors_entity.dart';
import 'package:cordato/features/expense/domain/entities/expense_page_entity.dart';
import 'package:cordato/features/metrics/domain/entities/expense_metrics_entity.dart';
import 'package:cordato/features/dashboard/presentation/enums/dashboard_phase_enum.dart';

final class DashboardState({
  DateTime? currentMonth,
  final UserEntity? user,
  final DateTime? firstMonth,
  final DateTime? _selectedMonth,
  final ExpensePageEntity? expenses,
  final ErrorsEntity? financialError,
  final ExpenseMetricsEntity? metrics,
  final bool hasNoExpenseHistory = false,
  final DashboardPhaseEnum phase = .loading,
}) {
  final DateTime _referenceDate = currentMonth ?? .now();

  bool get canRetry => phase == .failure;
  bool get canRefresh => phase == .ready;
  bool get isLoading => phase == .loading;
  bool get hasFinancialError => phase == .failure;
  bool get isEmpty =>
      phase == .ready &&
      expenses?.items.isEmpty == true &&
      metrics?.totalAmount == 0;
  DateTime get selectedMonth => _selectedMonth ?? currentMonth;
  DateTime get currentMonth =>
      DateTime(_referenceDate.year, _referenceDate.month);
  bool get canGoForward =>
      phase == .ready && selectedMonth.isBefore(currentMonth);
  bool get canGoBack =>
      phase == .ready &&
      firstMonth != null &&
      selectedMonth.isAfter(firstMonth!);
}
