# Step 11 — Lifecycle dos consumidores

## Escopo e aceite anterior

A tarefa 10.7 foi encerrada a pedido explícito do usuário, por aceite, sem nova
execução Maestro. A implementação desta etapa cobre 11.1–11.5; a validação de
fluxos da 11.6 permanece pendente.

## Listeners e confirmação

SignIn, SignUp, ResendEmail e Settings agora removem o listener de results do
command anterior em `didUpdateWidget` e registram o mesmo handler na nova
instância. Rebuild com o mesmo command não refaz a assinatura. EditUser já
implementava esse padrão desde o step 9 e foi revisado sem alteração.
Dispose remove o listener vigente; as telas não descartam seus singletons.
Não há cadeias de operators ou subscriptions de listen_it nesses consumidores.

Settings captura o command ao abrir a confirmação. O callback revalida montagem,
identidade e isRunning antes do envio. Uma confirmação aberta antes da troca
não dispara a operação na dependência nova. O helper compartilhado também exige
contexto montado e confirmação verdadeira antes de chamar o callback.

## Root e SessionCommand

- AppScreen religa o listener na troca de command, incrementa a versão, reinicia
  a decisão única por dependência e agenda a leitura do command vigente.
- A leitura inicial e seu catch capturam versão/command; uma falha antiga não
  navega após substituição ou descarte. O callback pós-frame exige versão válida
  e lê a sessão mais recente, sem reusar o booleano do primeiro evento.
- AppWidget religa seu listener e invalida callbacks por revisão de sinal,
  identidade de command e navigatorKey. Alterações repetidas antes do frame
  deixam somente a última condição válida para navegação.
- A checagem de rota inicial continua usando o contexto vigente no próprio
  frame, sem capturar sessão ou navigator antigos. Links públicos e classificação
  de rotas permanecem iguais.
- Nenhum dos consumidores descarta SessionCommand root. O dispose do próprio
  SessionCommand incrementa sua revisão antes de cancelar a stream e descartar
  execute, impedindo publicação de uma leitura pendente. O construtor tradicional
  permanece pela inicialização da subscription e pelo lifecycle explícito.

## Callback

A revisão é invalidada por mudança de URL ou command, inclusive com URL igual.
O callback agendado captura a revisão e solicita um frame com ensureVisualUpdate.
O command é capturado antes dos awaits; montagem/revisão validam as continuations
e os efeitos finais. Dispose invalida a revisão sem descartar o singleton.

`_isRunning` mantém a exclusão mútua de todo o fluxo local. Uma revisão nova
aguarda a anterior; o finally libera esse bloqueio e agenda somente a revisão
final vigente. Não há outro ciclo local iniciado antes dessa liberação, portanto
o finally antigo não encerra um ciclo novo em andamento.

Confirmação ocupada do mesmo link pode compartilhar o resultado. Para outro link,
a tela aguarda e depois solicita o link vigente. Uma exceção do link anterior
não transforma o novo link em falha sem consulta: ela é absorvida somente quando
os links diferem. Erro do mesmo link mantém o fallback existente. O enum de status
e a navegação injetada continuam os mesmos.

## Verificação técnica de State — não executada em runtime

| Interleaving inspecionado | Proteção |
| --- | --- |
| SignIn/SignUp/Resend/EditUser/Settings A → B com A pendente | Listener removido de A antes de observar B; conclusão de A não chama o handler da tela |
| Dispose após troca | Remove listener de B, sem dispose de singleton |
| Sheet de logout aberta com A e confirmada após troca para B | Command capturado não coincide; callback não envia |
| AppScreen A → B → A antes de um frame ou await | Versão invalida callbacks/erros antigos mesmo quando a identidade volta a A |
| Sessão muda várias vezes antes da navegação inicial | AppScreen decide uma vez usando o valor atual no frame |
| AppWidget recebe sinal antigo, troca command/key ou recebe novo sinal | Revisão e identidades bloqueiam o callback antigo |
| Callback troca command com a mesma URL durante request | Revisão invalida efeitos antigos; o fluxo final usa o command novo |
| Callback muda várias URLs durante request | Revisões intermediárias não iniciam; somente a final consulta após liberação |
| Dispose durante confirmação ou retorno neutro de command descartado | mounted/revisão impedem toast e navegação tardios |

Esses guards foram verificados por leitura e revisão do código, não por testes
Flutter de UI ou harness de substituição. Os unitários abaixo não provam todos
os interleavings de State.

## Previews e propriedade — inspeção

Não há previews de SignIn, SignUp, ResendEmail, Callback, Root, EditUser ou logout.
O preview de convite de Settings não possui command. Nos previews relacionados,
UserScreen descarta User/UpdateAvatar e o wrapper descarta somente DeleteUser;
o formulário isolado de Expense deixa Create/Update com o wrapper; Dashboard e
ExpensesScreen possuem seus commands factory. Seções isoladas deixam o descarte
com PreviewResourceWidget. Não foi identificada necessidade de alterar previews
ou seus proprietários; não foi executado o catálogo nesta etapa.

## Checks executados

- `dart format` nos dez arquivos Dart alterados.
- `flutter analyze`: **sem diagnósticos** após corrigir os três avisos locais de
  chaves em guards multilinha encontrados na primeira análise.
- `flutter test`: **737 aprovados e quatro falhas anteriores em User**, as mesmas
  documentadas no step 10. Os testes de UpdateUser/UpdateAvatar verificam dados
  ou ausência de erro antes de executar a operação que produziria esse estado.
  Seus arquivos e commands não foram modificados nesta etapa.
- Três testes novos passaram: SessionCommand não publica leitura após descarte;
  CallbackCommand ocupado compartilha A mesmo se runAsync recebe B e B exige
  uma execução posterior; descartar CallbackCommand durante B pode concluir seu
  Future com o status anterior de A na biblioteca instalada, sem publicar B.
- Os testes existentes de confirmação (status/erro/compartilhamento) e sessão
  (leitura/eventos/revisão/erro/cancelamento) também passaram na suíte completa.
- Nenhuma dependência nova ou alteração de integração HTTP, storage ou domínio.
  ARCHITECTURE.md e AGENTS.md foram atualizados com as regras de lifecycle.
- `openspec validate align-command-it-presentation-errors`: válido.
- `git diff --check`: sem problemas. A alteração paralela em
  `expense_dismissible_widget_state_mixin.dart` foi preservada e não pertence a
  esta implementação.

## 11.6 — Fluxos pendentes

Maestro listou o iPhone Air iOS 26.2 como conectado, mas inspect_screen retornou
`Device became unreachable during deviceInfo`. Nenhum flow de entrada,
confirmação ou sessão foi executado nesta etapa. Nenhum harness temporário foi
criado e nenhuma substituição artificial de dependência foi executada em runtime.
Não houve alteração de conta ou sessão no dispositivo.

A tarefa 11.6 continua aberta para validação com app atualizado e dispositivo
acessível; os cenários de substituição permanecem explicitamente inspecionados.
