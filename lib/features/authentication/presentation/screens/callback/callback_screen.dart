import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:cordato/features/core/presentation/enums/asset_enum.dart';
import 'package:cordato/features/core/presentation/widgets/images/image_widget.dart';
import 'package:cordato/features/core/presentation/extensions/context_extension.dart';

import 'package:cordato/features/authentication/presentation/screens/callback/bloc/callback_bloc.dart';
import 'package:cordato/features/authentication/presentation/screens/callback/bloc/callback_state.dart';
import 'package:cordato/features/authentication/presentation/screens/callback/widgets/animated_ellipsis_widget.dart';
import 'package:cordato/features/authentication/presentation/screens/callback/mixins/callback_screen_state_mixin.dart';

final class const CallbackScreen({
  super.key,
  required final String? verificationUrl,
  required final CallbackBloc Function() bloc,
}) extends StatefulWidget {
  @override
  State<CallbackScreen> createState() => _CallbackScreenState();
}

final class _CallbackScreenState extends State<CallbackScreen>
    with CallbackScreenStateMixin {
  @override
  Widget build(BuildContext context) {
    return BlocListener<CallbackBloc, CallbackState>(
      bloc: bloc,
      listener: (_, state) => handleConfirmation(state),
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Column(
              spacing: 24,
              mainAxisSize: .min,
              children: [
                ImageWidget(
                  width: 254,
                  height: 254,
                  fit: .contain,
                  alt: AssetEnum.logo.alt,
                  source: AssetEnum.logo.source,
                ),
                Semantics(
                  excludeSemantics: true,
                  label: 'Validando acesso...',
                  child: Text.rich(
                    TextSpan(
                      text: 'Validando acesso ',
                      style: context.typography.titleLarge?.copyWith(
                        fontWeight: .w700,
                        color: context.colors.onSurface,
                      ),
                      children: [
                        WidgetSpan(
                          alignment: .baseline,
                          baseline: .alphabetic,
                          child: AnimatedEllipsisWidget(
                            style: context.typography.titleLarge?.copyWith(
                              fontWeight: .w700,
                              color: context.colors.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    textAlign: .center,
                    style: context.typography.bodyLarge,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
