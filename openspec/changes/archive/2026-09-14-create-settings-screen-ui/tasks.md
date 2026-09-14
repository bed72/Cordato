## 1. Elementos Estruturais

- [x] 1.1 Criar `SettingsAppBarWidget` com `BackButtonWidget` e callback anulável.
- [x] 1.2 Criar `SettingsHeaderWidget` com título, descrição e estilos do tema.
- [x] 1.3 Criar `SettingsSectionWidget` para os títulos de seção em caixa alta.
- [x] 1.4 Criar `SettingsPremiumBadgeWidget` com label e cores semânticas do tema.

## 2. Cards E Ações

- [x] 2.1 Criar `SettingsCardWidget` com padding dos filhos e divisores somente entre itens.
- [x] 2.2 Criar `SettingsItemWidget` com ícone, label truncável, badge opcional, chevron e `BounceWidget` quando habilitado.
- [x] 2.3 Criar `SettingsInvitePartnerWidget` com o conteúdo visual de convite e callback anulável, sem estado de casal.
- [x] 2.4 Criar `SettingsLogoutWidget` reutilizando `DangerButtonWidget` em largura total e sem lógica de sessão ou confirmação.

## 3. Composição Da Tela

- [x] 3.1 Substituir o placeholder de `SettingsScreen` pela composição com app bar, header, seções “Casal”, “Conta” e “Informações”, região rolável e logout.
- [x] 3.2 Expor e encaminhar callbacks anuláveis para voltar, convidar parceiro, dados pessoais, subscrição, termos, privacidade, ajuda e sair, preservando o construtor `const` sem argumentos da rota atual.
- [x] 3.3 Atualizar `settings_screen_preview.dart` com callbacks representativos para inspeção dos estados habilitados no tema real.

## 4. Verificação

- [x] 4.1 Formatar os arquivos de apresentação alterados e confirmar que imports usam `material_ui` e caminhos `package:cordato/`.
- [x] 4.2 Inspecionar o preview em tamanho de telefone, incluindo ordem, rolagem em altura reduzida, truncamento e estados habilitado/desabilitado.
- [x] 4.3 Executar `flutter analyze` e corrigir todos os diagnósticos causados pela mudança.
- [x] 4.4 Executar `flutter test` e registrar qualquer falha anterior ou não relacionada.
