import 'package:material_ui/material_ui.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/settings/domain/value_objects/support_pix.dart';

final class const SupportPixWidget({super.key}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: .min,
    crossAxisAlignment: .stretch,
    spacing: 4.0,
    children: [
      Center(
        child: Semantics(
          label: 'QR Code Pix. Use Copiar Pix para copiar o código.',
          image: true,
          child: ExcludeSemantics(
            child: SizedBox.square(
              dimension: 220.0,
              child: PrettyQrView.data(
                data: SupportPix.copyAndPaste,
                decoration: PrettyQrDecoration(
                  quietZone: PrettyQrQuietZone.standard,
                  shape: PrettyQrSmoothSymbol(color: context.colors.onSurface),
                ),
              ),
            ),
          ),
        ),
      ),
      Text(
        '${SupportPix.recipient} · ${SupportPix.city}',
        textAlign: .center,
        style: context.typography.bodyMedium,
      ),
    ],
  );
}
