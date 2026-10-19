import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/formatters/date_formatter.dart';
import 'package:cordato/features/core/presentation/formatters/money_formatter.dart';
import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/core/presentation/previews/preview_resource_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/outline_button_widget.dart';
import 'package:cordato/features/dashboard/presentation/previews/fakes/metrics_total_animation_preview_repository.dart';
import 'package:cordato/features/dashboard/presentation/widgets/dashboard_month_selector_widget.dart';
import 'package:cordato/features/dashboard/presentation/widgets/metrics/metrics_section_widget.dart';
import 'package:cordato/features/metrics/presentation/commands/get_expense_metrics_command.dart';

@CordatoPreview(
  group: 'Dashboard / Total animado',
  name: 'Atualizações / Claro',
  size: cordatoPhonePreviewSize,
  brightness: Brightness.light,
)
@CordatoPreview(
  group: 'Dashboard / Total animado',
  name: 'Atualizações / Escuro',
  size: cordatoPhonePreviewSize,
  brightness: Brightness.dark,
)
Widget previewAnimatedExpenseTotal() => _animationPreview();

@CordatoPreview(
  group: 'Dashboard / Total animado',
  name: 'Movimento reduzido / Texto ampliado',
  size: cordatoPhonePreviewSize,
)
Widget previewReducedMotionExpenseTotal() => Builder(
  builder: (context) => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      disableAnimations: true,
      textScaler: const TextScaler.linear(1.6),
    ),
    child: _animationPreview(),
  ),
);

Widget _animationPreview() =>
    PreviewResourceWidget<
      ({
        GetExpenseMetricsCommand command,
        MetricsTotalAnimationPreviewRepository repository,
        ValueNotifier<DateTime> month,
      })
    >(
      create: () {
        final repository = MetricsTotalAnimationPreviewRepository();
        final command = GetExpenseMetricsCommand(repository: repository);
        command.execute.run((
          startDate: DateTime(2026, 10),
          endDate: DateTime(2026, 10, 31),
          groupBy: .category,
        ));
        return (
          command: command,
          repository: repository,
          month: ValueNotifier(DateTime(2026, 10)),
        );
      },
      dispose: (resource) {
        resource.command.dispose();
        resource.month.dispose();
      },
      builder: (resource) => StatefulBuilder(
        builder: (context, setState) {
          final selectedMonth = resource.month.value;

          void load() => resource.command.execute.run((
            startDate: resource.month.value,
            endDate: DateTime(
              resource.month.value.year,
              resource.month.value.month + 1,
              0,
            ),
            groupBy: .category,
          ));

          void changeMonth(int offset) {
            if (resource.command.execute.isRunning.value) return;
            setState(() {
              resource.month.value = DateTime(
                selectedMonth.year,
                selectedMonth.month + offset,
              );
              resource.repository.totalCents = 125099;
            });
            load();
          }

          void updateTotal(int cents) {
            if (resource.command.execute.isRunning.value) return;
            resource.repository.totalCents = cents;
            load();
          }

          return Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const .symmetric(vertical: 24.0),
                child: Column(
                  spacing: 16.0,
                  crossAxisAlignment: .stretch,
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: resource.command.execute.isRunning,
                      builder: (_, running, _) => DashboardMonthSelectorWidget(
                        selectedMonth: selectedMonth,
                        formatter: DateFormatter(),
                        onPreviousMonth: running ? null : () => changeMonth(-1),
                        onNextMonth: running ? null : () => changeMonth(1),
                      ),
                    ),
                    ListenableBuilder(
                      listenable: resource.command.execute.results,
                      builder: (_, _) => MetricsSectionWidget(
                        key: ValueKey(selectedMonth),
                        metrics:
                            resource.command.execute.results.value.isRunning
                            ? null
                            : resource.command.execute.results.value.data,
                        moneyFormatter: MoneyFormatter(),
                      ),
                    ),
                    Padding(
                      padding: const .symmetric(horizontal: 20.0),
                      child: ValueListenableBuilder<bool>(
                        valueListenable: resource.command.execute.isRunning,
                        builder: (_, running, _) => Column(
                          spacing: 8.0,
                          crossAxisAlignment: .stretch,
                          children: [
                            for (final (label, cents) in [
                              ('Aumentar total', 450010),
                              ('Diminuir total', 125099),
                              ('Zerar total', 0),
                              ('Restaurar total', 389205),
                              ('Mesmo total', resource.repository.totalCents),
                              ('Valor alto', 99999999999),
                            ])
                              OutlineButtonWidget(
                                label: label,
                                onTap: running
                                    ? null
                                    : () => updateTotal(cents),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
