import 'package:material_ui/material_ui.dart';
import 'package:flutter_modular/flutter_modular.dart' show ModularNavigationX;

import 'package:cordato/features/core/presentation/widgets/header_widget.dart';
import 'package:cordato/features/core/presentation/widgets/cards/summary_card_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/back_button_widget.dart';
import 'package:cordato/features/core/presentation/widgets/buttons/elevated_button_widget.dart';

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
      appBar: AppBar(
        leadingWidth: 80.0,
        leading: BackButtonWidget(onPress: () => context.pop()),
      ),
      body: SafeArea(
        child: Padding(
          padding: const .all(16.0),
          child: Column(
            spacing: 16.0,
            crossAxisAlignment: .stretch,
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => Column(
                    spacing: 16.0,
                    crossAxisAlignment: .stretch,
                    children: [
                      Expanded(
                        child: CustomScrollView(
                          slivers: [
                            const SliverToBoxAdapter(
                              child: HeaderWidget(
                                title: 'Gostou do Cordato?',
                                description:
                                    'Nos ajude a manter o app funcionando.',
                              ),
                            ),
                            SliverLayoutBuilder(
                              builder: (context, constraints) =>
                                  SliverToBoxAdapter(
                                    child: Padding(
                                      padding: const .only(top: 16.0),
                                      child: SupportPixWidget(
                                        availableHeight:
                                            constraints.remainingPaintExtent -
                                            16.0,
                                      ),
                                    ),
                                  ),
                            ),
                          ],
                        ),
                      ),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: constraints.maxHeight * 0.6,
                        ),
                        child: const SingleChildScrollView(
                          child: SummaryCardWidget(
                            title: 'Seu apoio faz a diferença',
                            summary:
                                'O valor é livre. No aplicativo do seu banco, use Pix Copia e Cola '
                                'ou escaneie o QR Code com outro aparelho. Confira o destinatário '
                                'antes de confirmar. O Cordato não confirma pagamentos.',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ElevatedButtonWidget(label: 'Copiar Pix', onTap: copyPix),
            ],
          ),
        ),
      ),
    );
  }
}
