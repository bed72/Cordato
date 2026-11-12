import 'package:material_ui/material_ui.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';

import 'package:cordato/features/core/presentation/extensions/context_extension.dart';
import 'package:cordato/features/settings/domain/value_objects/support_pix.dart';
import 'package:cordato/features/settings/presentation/layouts/support_pix_layout.dart';

final class const SupportPixWidget({
  super.key,
  final double availableHeight = 248.0,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final recipient = '${SupportPix.recipient} · ${SupportPix.city}';
      final recipientStyle = context.typography.bodyMedium;
      final painter = TextPainter(
        text: TextSpan(text: recipient, style: recipientStyle),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: constraints.maxWidth);
      final recipientHeight = painter.height;
      painter.dispose();

      final layout = SupportPixLayout(
        availableHeight: availableHeight,
        availableWidth: constraints.maxWidth,
        recipientHeight: recipientHeight,
      );

      return SizedBox(
        height: layout.contentHeight,
        child: Column(
          mainAxisSize: .min,
          mainAxisAlignment: .center,
          crossAxisAlignment: .stretch,
          spacing: SupportPixLayout.captionSpacing,
          children: [
            Center(
              child: Semantics(
                label: 'QR Code Pix. Use Copiar Pix para copiar o código.',
                image: true,
                child: ExcludeSemantics(
                  child: SizedBox.square(
                    dimension: layout.qrSize,
                    child: PrettyQrView.data(
                      data: SupportPix.copyAndPaste,
                      decoration: PrettyQrDecoration(
                        quietZone: PrettyQrQuietZone.standard,
                        shape: PrettyQrSmoothSymbol(
                          color: context.colors.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Text(recipient, textAlign: .center, style: recipientStyle),
          ],
        ),
      );
    },
  );
}
