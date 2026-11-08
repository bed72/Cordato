import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' show ModularNavigationX;

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/dashboard/presentation/screens/bloc/dashboard_bloc.dart';
import 'package:cordato/features/dashboard/presentation/screens/bloc/dashboard_event.dart';

import 'package:cordato/features/core/presentation/widgets/buttons/navigation_icon_button_widget.dart';

final class const MenuButtonDashboardWidget({super.key})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Menu',
    enabled: true,
    child: ExcludeSemantics(
      child: NavigationIconButtonWidget(
        iconSize: 26.0,
        icon: Icons.menu,
        onPress: () => _openSettings(context),
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
