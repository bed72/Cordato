import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart' show ModularNavigationX;

import 'package:cordato/features/core/presentation/widgets/cards/summary_card_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/back_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/elevated_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/headers/collapsible_header_widget.dart';

import 'package:cordato/features/settings/presentation/screens/support/widgets/support_pix_widget.dart';
import 'package:cordato/features/settings/presentation/screens/support/mixins/support_screen_state_mixin.dart';

final class const SupportScreen({super.key}) extends StatefulWidget {
  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

final class _SupportScreenState extends State<SupportScreen>
    with SupportScreenStateMixin {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: .stretch,
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  CollapsibleHeaderWidget(
                    title: 'Gostou do Cordato?',
                    description: 'Nos ajude a manter o app funcionando.',
                    leading: BackButtonWidget(onPress: () => context.pop()),
                  ),
                  const SliverPadding(
                    padding: .fromLTRB(16.0, 16.0, 16.0, 32.0),
                    sliver: SliverFillRemaining(
                      hasScrollBody: false,
                      child: Column(
                        crossAxisAlignment: .stretch,
                        children: [
                          Spacer(),
                          SupportPixWidget(),
                          SizedBox(height: 32.0),
                          Spacer(),
                          SummaryCardWidget(
                            title: 'Seu apoio faz a diferença',
                            summary:
                                'O valor é livre. No aplicativo do seu banco, use Pix Copia e Cola '
                                'ou escaneie o QR Code com outro aparelho. Confira o destinatário '
                                'antes de confirmar. O Cordato não confirma pagamentos.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const .fromLTRB(16.0, 0.0, 16.0, 24.0),
              child: ElevatedButtonWidget(label: 'Copiar Pix', onTap: copyPix),
            ),
          ],
        ),
      ),
    );
  }
}
