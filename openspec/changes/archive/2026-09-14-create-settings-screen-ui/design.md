## Context

`SettingsScreen` já está registrada em `settingsModule` e aberta a partir do dashboard, mas hoje renderiza somente um `Scaffold` vazio. A referência do Trocado organiza a tela em app bar, cabeçalho, três seções e botão de logout, porém também depende de Riverpod, estado de casal, confirmação e autenticação que não pertencem ao escopo atual do Cordato.

A implementação deve permanecer integralmente em `settings/presentation`, usar `material_ui` e reutilizar os recursos visuais do `core`. Como a rota existente constrói `const SettingsScreen()` sem argumentos, novos callbacks precisam ser anuláveis para não exigir alteração no módulo.

## Goals / Non-Goals

**Goals:**

- Reproduzir a hierarquia visual e a ordem de conteúdo da tela de referência.
- Dividir a composição em widgets públicos, finais e específicos de settings.
- Permitir que integrações futuras conectem navegação e ações por callbacks.
- Preservar tema, comportamento de pressão e responsividade já adotados no Cordato.
- Manter o preview de settings útil para validação visual.

**Non-Goals:**

- Implementar ou simular pareamento, estado conectado, loading ou falha de casal.
- Executar logout, abrir confirmação, acessar sessão ou emitir toast.
- Criar commands, models, repositories, data sources ou integrações Supabase.
- Alterar `settingsModule`, rotas, navegação ou outros arquivos fora da apresentação de settings.
- Adicionar testes automatizados de widgets ou screens; a política do projeto reserva essa validação para preview e Maestro.

## Decisions

### Compor a screen com widgets específicos da feature

Serão criados `SettingsAppBarWidget`, `SettingsHeaderWidget`, `SettingsSectionWidget`, `SettingsCardWidget`, `SettingsItemWidget`, `SettingsPremiumBadgeWidget`, `SettingsInvitePartnerWidget` e `SettingsLogoutWidget`. A screen ficará responsável apenas pela ordem das seções e pelo encaminhamento dos callbacks.

Essa divisão preserva a estrutura da referência e a convenção do Cordato de widgets públicos com arquivo e classe alinhados. A alternativa de manter toda a árvore no `build` reduziria arquivos, mas deixaria a screen responsável pelos detalhes visuais de cada componente e dificultaria previews isolados futuros.

### Representar casal somente pelo convite visual

A seção “Casal” exibirá `SettingsInvitePartnerWidget`, com título “Convidar parceiro” e descrição “Comecem a usar juntos”. Estados conectado, carregando e erro não serão copiados porque exigiriam contratos e comportamento de um bounded context ainda planejado.

A alternativa de criar dados fictícios ou um enum de estado apenas para a UI foi rejeitada porque anteciparia uma API sem requisitos de produto validados.

### Expor callbacks anuláveis e não executar efeitos

`SettingsScreen` receberá callbacks opcionais para voltar, convidar parceiro, editar dados pessoais, abrir subscrição, termos, privacidade, ajuda e sair. Cada widget acionável também aceitará callback anulável e permanecerá desabilitado quando ele não for fornecido.

Isso mantém `const SettingsScreen()` válido na rota atual e distingue uma ação indisponível de um callback vazio. A alternativa de tornar os callbacks obrigatórios exigiria alterar o módulo, ultrapassando o escopo; callbacks internos vazios esconderiam ações sem efeito.

### Reutilizar os componentes e tokens existentes

O app bar reutilizará `BackButtonWidget`, a ação final reutilizará `DangerButtonWidget` e itens acionáveis reutilizarão `BounceWidget`. Cores, tipografia e raios virão de `context.colors`, `context.typography` e `context.radius`; ícones e layout virão de `material_ui`.

Não será criado um scaffold, botão, extensão de tema ou token paralelo. Detalhes próprios da tela, como espaçamento de 16 pixels e altura de item de 56 pixels, permanecerão locais.

### Manter conteúdo rolável e logout fora da rolagem principal

A screen usará `Scaffold`, app bar, `SafeArea` e uma coluna com cabeçalho, uma região `Expanded` contendo `SingleChildScrollView` e `SettingsLogoutWidget` ao final. Assim, a lista de opções rola em alturas reduzidas enquanto a ação de sair permanece separada visualmente, como na referência.

## Risks / Trade-offs

- [Callbacks não conectados na rota atual deixam ações desabilitadas] → O contrato torna esse estado explícito e permite integração posterior sem introduzir efeitos falsos neste change.
- [A seção de casal mostra apenas o estado de convite] → Limitar o widget evita representar funcionalidade de casal como implementada antes do respectivo bounded context.
- [A ação de sair não confirma nem encerra sessão] → O widget somente encaminha `onLogoutPressed`; confirmação e autenticação deverão ser especificadas em mudança própria.
- [Muitos widgets para uma tela pequena aumentam o número de arquivos] → Cada extração corresponde a uma unidade visual nomeada da estrutura de referência e mantém a screen como ponto de composição.
