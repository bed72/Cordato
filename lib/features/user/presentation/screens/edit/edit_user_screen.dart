import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

import 'package:cordato/features/core/presentation/widgets/header_widget.dart';
import 'package:cordato/features/core/presentation/widgets/fields/text_field_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/elevated_button_widget.dart';

import 'package:cordato/features/user/domain/entities/user_entity.dart';

import 'package:cordato/features/user/presentation/screens/edit/bloc/edit_bloc.dart';
import 'package:cordato/features/user/presentation/screens/edit/bloc/edit_state.dart';
import 'package:cordato/features/user/presentation/screens/edit/widgets/edit_user_app_bar_widget.dart';
import 'package:cordato/features/user/presentation/screens/edit/mixins/edit_user_screen_state_mixin.dart';

final class const EditUserScreen({
  super.key,
  required final String initialName,
  required final EditBloc Function() bloc,
  required final ValueChanged<BuildContext> onBackPressed,
  required final void Function(BuildContext, UserEntity) onUpdated,
}) extends StatefulWidget {
  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

final class _EditUserScreenState extends State<EditUserScreen>
    with EditUserScreenStateMixin {
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EditBloc, EditState>(
      bloc: bloc,
      listener: (_, state) => handleUpdate(state),
      builder: (_, state) => _buildContent(state),
    );
  }

  Scaffold _buildContent(EditState state) {
    return Scaffold(
      appBar: EditUserAppBarWidget(onBackPressed: widget.onBackPressed),
      body: SafeArea(
        child: Padding(
          padding: const .fromLTRB(16.0, 0.0, 16.0, 24.0),
          child: Column(
            spacing: 16.0,
            crossAxisAlignment: .stretch,
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior: .onDrag,
                    padding: const .symmetric(vertical: 24.0),
                    child: Column(
                      spacing: 24.0,
                      crossAxisAlignment: .stretch,
                      children: [
                        const HeaderWidget(
                          title: 'Nome',
                          description: 'Atualize o seu nome de exibição.',
                        ),
                        TextFieldWidget(
                          hint: 'Nome',
                          label: 'Nome',
                          inputAction: .done,
                          keyboardType: .name,
                          failure: nameFailure,
                          enabled: state.canSubmit,
                          onChanged: onNameChanged,
                          textCapitalization: .words,
                          initialValue: widget.initialName,
                          onSubmitted: (_) => updateName(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ElevatedButtonWidget(
                label: 'Atualizar',
                isLoading: state.isSubmitting,
                onTap: state.canSubmit && canUpdate ? updateName : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
