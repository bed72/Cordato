import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart' show ModularNavigationX;

import 'package:cordato/features/core/presentation/enums/route_enum.dart';
import 'package:cordato/features/dashboard/presentation/screens/bloc/dashboard_bloc.dart';
import 'package:cordato/features/dashboard/presentation/screens/bloc/dashboard_event.dart';

import 'package:cordato/features/core/presentation/widgets/bounce_widget.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/user/presentation/widgets/generated_user_avatar_widget.dart';

final class const AvatarDashboardWidget({super.key, required final String seed})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Dados pessoais',
      enabled: true,
      child: BounceWidget.withOnPress(
        onPress: () => _openUser(context),
        child: ClipRRect(
          borderRadius: context.radius.cornerRadius100,
          child: GeneratedUserAvatarWidget(seed: seed, size: 48.0),
        ),
      ),
    );
  }

  Future<void> _openUser(BuildContext context) async {
    if (ModalRoute.of(context)?.isCurrent == false) return;
    final bloc = context.read<DashboardBloc>();
    await context.pushNamed(RouteEnum.user.path);
    if (context.mounted &&
        !bloc.isClosed &&
        identical(context.read<DashboardBloc>(), bloc)) {
      bloc.add(DashboardUserRequested());
    }
  }
}
