import 'package:material_ui/material_ui.dart';
import 'package:flutter_lucide_animated/flutter_lucide_animated.dart' as lucide;

import 'package:cordato/features/core/presentation/enums/asset_enum.dart';
import 'package:cordato/features/core/presentation/previews/preview.dart';
import 'package:cordato/features/core/presentation/animations/loop_animation.dart';

import 'package:cordato/features/core/presentation/widgets/icons/icon_widget.dart';
import 'package:cordato/features/core/presentation/widgets/images/image_widget.dart';
import 'package:cordato/features/core/presentation/widgets/icons/background_icon_widget.dart';

Widget _visualShell(Widget child) => Scaffold(
  body: SafeArea(
    child: Center(
      child: Padding(padding: const EdgeInsets.all(24.0), child: child),
    ),
  ),
);

@CordatoPreview(
  group: 'Core / Visuais',
  name: 'Imagem local',
  size: Size(390.0, 320.0),
)
Widget previewImageWidget() => _visualShell(
  ImageWidget(
    width: 220.0,
    height: 220.0,
    fit: .contain,
    alt: AssetEnum.logo.alt,
    source: AssetEnum.logo.source,
  ),
);

@CordatoPreview(
  group: 'Core / Visuais',
  name: 'Ícones',
  size: Size(390.0, 180.0),
)
Widget previewIconWidgets() => _visualShell(
  Builder(
    builder: (context) => Row(
      mainAxisSize: .min,
      spacing: 24.0,
      children: [
        IconWidget(
          icon: lucide.circle_dollar_sign,
          size: 32.0,
          color: Theme.of(context).colorScheme.primary,
        ),
        BackgroundIconWidget(
          icon: lucide.file_text,
          iconColor: Theme.of(context).colorScheme.onPrimary,
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      ],
    ),
  ),
);

@CordatoPreview(
  group: 'Core / Animações',
  name: 'Loop',
  size: Size(390.0, 220.0),
)
Widget previewLoopAnimation() => _visualShell(
  const SizedBox(
    height: 28.0,
    child: LoopAnimation(
      items: [Text('Planeje em conjunto'), Text('Conquiste em conjunto')],
    ),
  ),
);
