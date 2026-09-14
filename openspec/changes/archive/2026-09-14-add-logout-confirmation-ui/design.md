## Context

`SettingsScreen` já expõe `onLogoutPressed` e renderiza `SettingsLogoutWidget` com o botão compartilhado de perigo. O contrato vigente delega esse callback no primeiro toque e exclui confirmação, enquanto o `core` já oferece `showBottomSheetWidget`, `BottomSheetScaffoldWidget`, `DangerButtonWidget` e `OutlineButtonWidget` para compor o fluxo desejado sem uma nova infraestrutura visual.

Embora a feature authentication já possua contratos e infraestrutura de logout, a rota de settings ainda não conecta essa operação. Esta mudança deve tratar somente a intenção confirmada na apresentação, mantendo sessão, command, feedback assíncrono e navegação fora do escopo.

## Goals / Non-Goals

**Goals:**

- Exigir uma confirmação explícita antes de encaminhar `onLogoutPressed`.
- Apresentar título, descrição, ação secundária outline e ação elevada em um bottom sheet alinhado ao tema atual.
- Aplicar a SafeArea somente na parte inferior do conteúdo da confirmação.
- Tratar “Voltar”, gesto de arrastar, toque fora e botão de voltar do sistema como cancelamento sem efeito.
- Manter o `build` de `SettingsScreen` declarativo por meio de um mixin específico de estado de UI e limitar os arquivos da feature alterados a `settings/presentation`.
- Disponibilizar o conteúdo da confirmação no Widget Previewer para validação visual.

**Non-Goals:**

- Executar `signOut`, consumir repository, criar command ou observar estado assíncrono.
- Navegar para welcome, emitir toast ou tratar falhas de logout.
- Alterar módulos, rotas, `SessionGuardWidget`, authentication ou o comportamento padrão dos widgets compartilhados do `core`.
- Criar testes automatizados de widget ou screen.

## Decisions

### Manter o callback como ação já confirmada

O toque no botão fixo “Sair” abrirá o bottom sheet; `onLogoutPressed` será invocado somente quando o resultado do sheet indicar confirmação. Assim, consumidores futuros podem conectar o logout real sem duplicar a proteção contra toque acidental.

A alternativa de disparar o callback antes de abrir o sheet foi rejeitada porque não permitiria cancelar a saída. Renomear o callback também foi rejeitado porque seu significado externo continua sendo solicitar o logout e não há consumidor que precise distinguir as duas etapas.

### Retornar a decisão pelo resultado do bottom sheet

`SettingsScreenStateMixin` aguardará um `bool` de `showBottomSheetWidget<bool>`. O `LogoutBottomSheetWidget` fechará o overlay com `true` em “Sair” e `false` em “Voltar”; dispensas pelo sistema retornam `null` e serão tratadas como cancelamento. O mixin somente encaminhará o callback quando o resultado for `true` e o State ainda estiver montado.

Essa abordagem mantém o conteúdo visual independente da operação futura e evita callback executado enquanto o overlay ainda está aberto. A alternativa de chamar `onLogoutPressed` diretamente dentro do widget de confirmação foi rejeitada porque misturaria a decisão visual com o efeito externo.

### Extrair a orquestração para o mixin da screen

`SettingsScreen` será um `StatefulWidget`, e `_SettingsScreenState` aplicará `SettingsScreenStateMixin on State<SettingsScreen>`. O mixin exporá `showLogoutConfirmation`, concentrando a abertura assíncrona, a verificação de `mounted` e a delegação para `widget.onLogoutPressed`; a classe de State manterá somente a composição visual.

A alternativa de manter um método privado na screen foi rejeitada para seguir o padrão adotado pelo projeto para handlers assíncronos de UI pertencentes a uma screen.

### Reutilizar o scaffold e os botões compartilhados

O sheet usará `showBottomSheetWidget` com o título “Deseja sair?” e a descrição “Você precisará entrar novamente para acessar sua conta.”. O conteúdo terá `OutlineButtonWidget` com “Voltar” e `ElevatedButtonWidget` com “Sair”, ambos em largura total e nessa ordem.

Não será criado um modal, botão ou token visual paralelo. A alternativa de estilizar botões Material diretamente na feature foi rejeitada porque perderia o padrão de tema e press-bounce do `core`.

### Aplicar SafeArea somente na parte inferior

`showBottomSheetWidget` receberá uma opção `useSafeArea`, com valor padrão `true`, encaminhada ao `showModalBottomSheet`. O fluxo de logout usará `false`, enquanto `LogoutBottomSheetWidget` envolverá suas ações em `SafeArea` com somente `bottom` habilitado.

Isso remove os insets externos de topo e laterais apenas desta confirmação e preserva todos os consumidores atuais do helper. Alterar o padrão global foi rejeitado porque mudaria outros bottom sheets sem requisito correspondente.

### Desabilitar o fluxo quando não houver efeito conectado

Quando `onLogoutPressed` for `null`, o botão original continuará desabilitado e o bottom sheet não poderá ser aberto. Isso preserva o contrato explícito da tela atual e evita apresentar uma confirmação cuja ação final não teria efeito.

### Validar a composição por preview

O preview da tela continuará fornecendo um callback representativo para permitir abrir o sheet. Um preview específico renderizará `LogoutBottomSheetWidget` dentro de `BottomSheetScaffoldWidget`, com o título e a descrição reais, para inspeção direta sem módulo, sessão ou Supabase.

## Risks / Trade-offs

- [O callback passa a ocorrer depois de uma interação adicional] → A mudança é intencional e será registrada no contrato da capability.
- [Dispensas por gesto, barreira ou sistema retornam `null` em vez de `false`] → A screen considerará somente `true` como confirmação.
- [O logout real ainda não estará disponível na rota] → O botão permanece desabilitado quando não houver callback; integração funcional será tratada em mudança própria.
- [A cópia pode evoluir com decisões de produto] → Título e descrição ficam localizados no ponto de abertura do sheet e podem ser ajustados sem alterar a fronteira com authentication.
- [A configuração de SafeArea amplia o contrato do helper compartilhado] → O novo parâmetro mantém `true` como padrão, evitando mudança visual nos consumidores existentes.
