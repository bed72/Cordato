## Why

O botão “Sair” da tela de configurações hoje apenas delega a ação, sem proteger a pessoa contra um toque acidental. Uma confirmação visual deve tornar a intenção explícita antes que uma integração futura encerre a sessão.

## What Changes

- Abrir um bottom sheet de confirmação quando a pessoa tocar em “Sair” na tela de configurações.
- Exibir título, descrição, a ação outline “Voltar” e, abaixo dela, a ação elevada “Sair”.
- Aplicar a SafeArea somente na parte inferior do conteúdo da confirmação.
- Fechar o bottom sheet sem delegar logout quando a pessoa escolher “Voltar” ou dispensá-lo.
- Fechar o bottom sheet e invocar o callback de logout somente após a confirmação em “Sair”.
- Manter a mudança restrita à screen, aos widgets e ao preview da apresentação de settings, sem command, navegação, sessão ou acesso ao Supabase.

## Capabilities

### New Capabilities

Nenhuma.

### Modified Capabilities

- `settings-screen-ui`: altera a ação de logout para exigir confirmação em bottom sheet antes de delegar o callback.

## Impact

- Afeta `SettingsScreen`, seu mixin específico de estado de UI, os widgets de logout da feature settings e o preview correspondente.
- Reutiliza o helper de bottom sheet e os botões compartilhados existentes no `core`, tornando a SafeArea externa do helper configurável sem alterar seu comportamento padrão.
- Não altera módulos, rotas, contratos de domínio, dependências externas ou integração de autenticação.
