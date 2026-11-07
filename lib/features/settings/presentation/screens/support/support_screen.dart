import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart' show ModularNavigationX;

import 'package:cordato/features/core/presentation/widgets/header_widget.dart';
import 'package:cordato/features/core/presentation/widgets/cards/summary_card_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/back_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/elevated_button_widget.dart';

import 'package:cordato/features/settings/presentation/screens/support/mixins/support_screen_state_mixin.dart';
import 'package:cordato/features/settings/presentation/screens/support/widgets/support_pix_widget.dart';

final class const SupportScreen({super.key}) extends StatefulWidget {
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

final class _SupportScreenState extends State<SupportScreen>
    with SupportScreenStateMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 72.0,
        leading: BackButtonWidget(onPress: () => context.pop()),
      ),
      body: SafeArea(
        child: Padding(
          padding: const .fromLTRB(16.0, 24.0, 16.0, 24.0),
          child: LayoutBuilder(
            builder: (_, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: .stretch,
                    children: [
                      const HeaderWidget(
                        title: 'Gostou do Cordato?',
                        description: 'Nos ajude a manter o app funcionando.',
                      ),
                      const SizedBox(height: 32.0),
                      const Spacer(),
                      const SupportPixWidget(),
                      const SizedBox(height: 32.0),
                      const Spacer(),
                      const SummaryCardWidget(
                        title: 'Seu apoio faz a diferença',
                        summary:
                            'O valor é livre. No aplicativo do seu banco, use Pix Copia e Cola '
                            'ou escaneie o QR Code com outro aparelho. Confira o destinatário '
                            'antes de confirmar. O Cordato não confirma pagamentos.',
                      ),
                      const SizedBox(height: 32.0),
                      ElevatedButtonWidget(label: 'Copiar Pix', onTap: copyPix),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
