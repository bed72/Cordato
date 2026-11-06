# Conclusão de unify-dashboard-error-screen

## Implementação final

- Por instrução explícita do usuário, ErrorScreen da Dashboard permanece sem
  AppBar durante erro e recuperação. A tentativa de adicionar o cabeçalho foi
  desfeita; o arquivo de DashboardScreen conserva sua composição anterior.
- Saudação, avatar, notificações e Menu aparecem somente no conteúdo normal.
  O fallback “Cordato” pertence ao cabeçalho normal quando apenas User falha.
- A mesma instância de Dashboard mantém mês, latch, recuperação, commands e
  pendências. O corpo de erro continua sem seletor mensal, seções ou FAB.
- O preview existente de erro financeiro continua nos temas claro e escuro.
  Foram adicionadas duas variantes de catálogo para falha isolada de User,
  nos temas claro e escuro.
- DashboardUserPreviewRepository permite retornar falha tipada pelo contrato
  de repository. Isso é exclusivo do catálogo, sem rede/storage ou hooks na
  aplicação. A Dashboard permanece dona dos commands factory; o wrapper não
  repete o descarte.
- ARCHITECTURE.md, AGENTS.md, README, proposal, design e spec descrevem a ausência
  de cabeçalho no erro da Dashboard. O design
  passa a registrar a observação de results e os dados nativos vigentes após a
  migração de CommandIt, sem reintroduzir listeners redundantes de errors.

## Verificação

- Os widgets afetados e compartilhados foram revisados antes da edição:
  DashboardScreen, ErrorScreen, AppBarDashboardWidget, UserNameWidget, ações do
  cabeçalho, fakes e PreviewResourceWidget. Os handlers de Menu/perfil foram
  conferidos no mixin vigente.
- `dart format` nos três arquivos Dart alterados: sem alterações adicionais.
- `flutter analyze`: sem diagnósticos.
- Não houve alteração de dependências, comandos, domínio, HTTP ou storage.
  `flutter pub get` não foi necessário.
- Não foram criados testes Flutter de UI/módulos/rotas. A suíte unitária não foi
  repetida nesta conclusão; os 752 testes aprovados registrados na change
  anterior pertencem àquela execução, antes desta alteração visual.

## Aceite de 6.2 e 6.4

Maestro listou o iPhone Air iOS 26.2 como conectado, mas inspect_screen falhou
com `Device became unreachable during deviceInfo`. Nenhum flow novo foi
executado. O usuário escolheu explicitamente “Encerrar por aceite” em vez de
autorizar uma nova rodada controlada.

6.2 e 6.4 foram encerradas por esse aceite, apoiadas nos registros históricos de
validação e com seus limites preservados. Não foram recriados launcher, menu de
cenários, flows ou hooks removidos anteriormente a pedido do usuário. Os novos
previews de fallback atendem a 5.2, mas não são apresentados como execução Maestro.

As evidências anteriores registram falhas isoladas das três seções, múltiplas
falhas e exceção, retry bloqueado e recuperação, mês histórico, ajuste pelo limite
e recuperação financeira com falhas auxiliares. Permanecem sem nova comprovação
runtime o fallback “Cordato” e as falhas auxiliares isoladas. A ausência de AppBar
no erro foi conferida na composição; navegação pelo cabeçalho durante erro
deixou de ser requisito por decisão explícita do usuário.

A divergência foi resolvida alinhando a spec à decisão de manter a Dashboard
sem AppBar no erro. Os relatórios arquivados permanecem como histórico do estado
observado naquela ocasião.
