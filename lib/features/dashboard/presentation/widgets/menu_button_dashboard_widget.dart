import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' show ModularNavigationX;

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/dashboard/presentation/screens/dashboard/bloc/dashboard_bloc.dart';
import 'package:cordato/features/dashboard/presentation/screens/dashboard/bloc/dashboard_event.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/icon_button_widget.dart';

final class const MenuButtonDashboardWidget({super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Menu',
    enabled: true,
    child: ExcludeSemantics(
      child: IconButtonWidget(
        width: 48.0,
        height: 48.0,
        iconSize: 26.0,
        icon: Icons.menu,
        onPress: () => _openSettings(context),
        iconColor: context.colors.onSurface,
        borderRadius: context.radius.cornerRadius100,
        backgroundColor: context.colors.onSurface.withValues(alpha: .02),
      ),
    ),
  );

  Future<void> _openSettings(BuildContext context) async {
    if (ModalRoute.of(context)?.isCurrent == false) return;
    final bloc = context.read<DashboardBloc>();
    await context.pushNamed(RouteEnum.settings.path);
    if (context.mounted &&
        !bloc.isClosed &&
        identical(context.read<DashboardBloc>(), bloc)) {
      bloc.add(DashboardUserRequested());
    }
  }
}
