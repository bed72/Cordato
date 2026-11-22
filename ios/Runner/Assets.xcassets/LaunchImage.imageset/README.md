# Assets da tela de abertura iOS

Este catálogo pertence à tela de abertura nativa do Runner. Ao trocar imagens,
preserve as referências de `Contents.json` e do storyboard de lançamento e
mantenha consistência com `assets/images/splash_ios.png` na apresentação Flutter.
Hot reload não atualiza a tela de abertura nativa; gere e instale novo build.

Abra `ios/Runner.xcworkspace` no Xcode, a partir da raiz do projeto, para editar
o catálogo. Confira manualmente a abertura e a transição para Flutter nos temas
e tamanhos suportados; testes unitários não comprovam o resultado visual.

O app atual usa armazenamento local, sem login. Estes assets não configuram
Localstore, assinatura, App Group ou o widget WidgetKit.
Consulte o [README do projeto](../../../../README.md) para execução e limites.
