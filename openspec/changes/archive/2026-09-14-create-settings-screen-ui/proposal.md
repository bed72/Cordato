## Why

A rota de configurações já existe, mas sua tela ainda é um placeholder vazio. A implementação visual deve ganhar a mesma hierarquia da tela de referência do Cordato, adaptada aos componentes e limites arquiteturais do Cordato.

## What Changes

- Compor a `SettingsScreen` com app bar, cabeçalho, conteúdo rolável e ação de saída.
- Exibir as seções “Casal”, “Conta” e “Informações” na mesma ordem da referência.
- Criar widgets próprios de settings para cabeçalho, título de seção, card agrupador, item acionável, selo premium, convite de parceiro e ação de saída.
- Encaminhar interações por callbacks anuláveis, mantendo navegação, autenticação e operações assíncronas fora deste change.
- Atualizar o preview existente para representar a tela completa e permitir inspeção visual e de interação.
- Não implementar estado de casal, assinatura, logout, dialogs, commands, repositories, módulos, rotas ou integrações externas.

## Capabilities

### New Capabilities

- `settings-screen-ui`: Estrutura visual e contratos de interação da tela de configurações e de seus widgets próprios.

### Modified Capabilities

Nenhuma.

## Impact

- Afeta somente `lib/features/settings/presentation/screens/`, `lib/features/settings/presentation/widgets/` e o preview de apresentação de settings.
- Reutiliza `material_ui`, tema/extensões do `core`, `BounceWidget`, `BackButtonWidget` e `DangerButtonWidget` já existentes.
- Não altera APIs externas, dependências, estado de sessão, domínio financeiro, Supabase, DI ou rotas.
