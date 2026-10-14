# Step 12 — Regressão e encerramento da implementação

## Escopo

Revisão final dos dezesseis commands migrados, seus testes e contratos
documentados. Esta etapa altera somente testes unitários e Markdown.
As alterações preexistentes em `tasks.md` e `implementation-part-10.md`, que
registram o aceite do step 11, foram preservadas.

## 12.1–12.3 — Matriz unitária

As suítes abaixo verificam null inicial, sucesso nativo, delegação sem
normalização quando há entrada, falha tipada preservando a identidade da
ErrorsEntity, exceção inesperada original e nova tentativa após falha:

| Contexto | Commands e suítes revisadas | Casos particulares |
| --- | --- | --- |
| Expense | GetExpenses, GetExpense, CreateExpense, UpdateExpense, DeleteExpense | Página vazia, next opaco, filtros incompletos, ID intacto, datas civis, PATCH parcial, false na exclusão |
| Insight | GetInsights | Lista vazia, período nulo ou de vários meses, filtros incompletos |
| Metrics | GetExpenseMetrics | Total zero, categorias ausentes e vazias, datas opcionais |
| Dashboard | GetFirstExpenseMonth | Null concluído, páginas não ordenadas, página vazia com next, falha posterior, continuação repetida e interrupção cooperativa |
| User | User, UpdateUser, UpdateAvatar, DeleteUser | Nome/seed intactos, seed divergente preservada na resposta, false na exclusão |
| Authentication | SignIn, SignUp, ResendEmail, Logout | Credenciais/e-mail intactos, sessão original e false como dado válido |

Os testes de transporte de CommandFailureException cobrem todos os metadados,
ordem, nulabilidade e lista vazia. Os testes do fallback global usam a configuração
real, observam Future/results/errors e restauram os estáticos; falhas tratadas
localmente não duplicam o reporte global. Os testes de commands não comprovam
feedback, navegação ou todo interleaving dos States.

Complementos desta etapa: **11 testes novos**.

- SignIn, SignUp e ResendEmail: três testes de concorrência com Completer,
  `run` bloqueado, `runAsync` com parâmetros diferentes compartilhando o mesmo
  Future e estado de outra instância intacto; três testes de descarte pendente.
- Logout: isolamento e descarte pendente; o teste de bloqueio existente também
  confere identidade do Future compartilhado.
- GetFirstExpenseMonth: isolamento; a falha de página posterior agora carrega
  title/detail/status/pointer/parameter e um segundo erro com metadados nulos.
- GetInsights e GetExpenseMetrics: descarte durante consulta pendente.

Os seis testes novos de descarte aguardam um Completer que confirma a chamada ao
repository antes do dispose; depois liberam a resposta, aguardam o lifecycle da
biblioteca e verificam ausência de publicação tardia. Os demais testes existentes
já cobrem descarte e isolamento das mutações/consultas de Expense e User, bem
como retorno de value anterior após descarte de GetExpense e Callback.

Foram corrigidas quatro verificações em UpdateUser/UpdateAvatar que consultavam
dados/parâmetros ou ausência de erro antes de executar o command. A execução
completa também revelou o mesmo problema em dois cenários de Callback
(invalid/failure); agora aguardam a operação em variável antes das assertions.
Os statuses continuam dados válidos, sem conversão para falha tipada.

## 12.4 — Auditoria de Either na apresentação

A busca por Either/Left/isLeft/isRight e acessos left/right em
`lib/features/**/presentation/` encontrou:

- adaptação específica nos quinze commands de operação simples;
- consumo pelo algoritmo de páginas do GetFirstExpenseMonth;
- repositories fake de previews, que preservam o contrato Either;
- criação validada de AmountValueObject em fixtures/previews e no skeleton do
  formulário de Expense.

Não há interpretação de Left nos consumidores migrados. A construção de um VO
para placeholder não é interpretação de resultado assíncrono. Domínio,
repositories, data sources e política HTTP permanecem com seus contratos.

## 12.5 — Documentação

ARCHITECTURE.md recebeu a matriz consolidada de resultados e proprietários dos
dezesseis commands, incluindo valores false/vazio/zero/null e os contratos
distintos de Callback/Session. Também explicita os limites de CommandIt 9.5.2 e
os estados locais preservados. AGENTS.md aponta a matriz e orienta as verificações
após execução, sem presumir que um stub altera observáveis.

O README foi revisado: a descrição obsoleta de retry independente nas seções da
Dashboard foi substituída pelo retry financeiro único já implementado. Não houve
mudança de instalação, execução ou dependências.

## 12.6 — Checks e falhas intermediárias

- `flutter pub get`: não aplicável; pubspec e lockfile intactos, dependências já
  resolvidas. Não houve upgrade ou pacote novo.
- `dart format`: aplicado aos testes alterados.
- `flutter analyze`: **sem diagnósticos** na rodada final.
- `flutter test --reporter failures-only`: **752 testes aprovados**, incluindo
  a suíte de arquitetura existente. Nenhum teste Flutter de UI/módulos/rotas foi
  criado. Isso não amplia as garantias do teste arquitetural histórico.
- A primeira execução, após corrigir User, terminou com 748 aprovados e duas
  falhas em Callback por assertion anterior à execução. As tentativas seguintes
  identificaram também que dois novos testes de descarte precisavam aguardar a
  chamada ao repository; todos os novos testes de descarte passaram a confirmar
  esse início. Uma nova rodada ainda encontrou a ordem incorreta em Callback,
  corrigida definitivamente com o await em variável. A rodada final passou.

## 12.7 — Evidência Maestro consolidada e aceite

Nesta sessão, list_devices apresentou o iPhone Air iOS 26.2 como conectado;
inspect_screen falhou com `Device became unreachable during deviceInfo`.
Não foi executado flow final nem criado novo launcher/harness.
O usuário escolheu explicitamente **“Encerrar por aceite”** para 12.7.
O aceite encerra a tarefa sem ampliar a cobertura demonstrada abaixo.

| Matriz do design | Evidência efetiva e limitações |
| --- | --- |
| D01–D06 — Dashboard | Aceites dos steps 1/2 e 5, registrados em parts 1 e 4; sem relatório adicional da matriz controlada nem execução final pelo agente |
| D07–D08 — pendências e dependências | Inspeção técnica e testes dos limites do command; não execução runtime de todos os interleavings de Dashboard |
| E01–E02 — consulta e IDs | Part 5: duas consultas reais por gesto e nove cenários controlados Maestro autorizados, incluindo loading/retry, erro tipado/vazio/inesperado, A/B/C, retirada de ID, substituição e descarte |
| E03–E04 — formulário e PATCH | Part 6: hold bem-sucedido/interrompido, falhas, cancelamento de pickers, toque simples, edição de descrição e data, erros de campo; contadores de repository e callbacks do harness, sem comprovar router real ou contagem visual de toasts |
| E05–E06 — listagem e gestos | Part 6: confirmação/cancelamento/falhas de exclusão e remoção de cabeçalho; part 7: filtros, paginação/refresh e revisão inspecionados, encerrados por aceite, sem matriz adicional de rolagem extensa/edição para fora da lente |
| U01 — nome/avatar | Part 8: testes de commands e inspeção de timer/seed; aceite sem nova execução Maestro |
| A01 — autenticação/logout | Part 9: testes e inspeção; aceite sem execução adicional em dispositivo |
| A02, L01 — Callback/Root/substituição | Part 10: testes de commands e inspeção de State, aceite sem substituição artificial em runtime |
| L02 — propriedade/previews | Inventário e revisão de lifecycle nas etapas anteriores; catálogo não executado nesta rodada |

Os launchers autorizados de Expense foram removidos nas etapas correspondentes.
`tool/` contém somente `android_usb_proxy.py` e `widget_preview.dart`; nenhum
arquivo de validação temporária Dart foi encontrado. As evidências anteriores
permanecem nos respectivos relatórios, sem transformar aceites ou inspeções em
testes de fluxo completos.

## 12.8–12.9 — Escopo e ganhos concretos

Reduções verificadas no código vigente e nos registros de implementação:

- Dashboard: fontes financeiras de erro de seis para três, removendo três
  listeners redundantes de errors e a releitura de errors no detector de falha.
- Dashboard: removido um `setState(() {})` global; seções observam seus próprios
  snapshots e controles observam execução declarativamente.
- ExpenseScreen: removidas três cópias de consulta (expense, loadErrors,
  isLoading) e quatro setState da consulta; ficam intenção e revisão do ID.
- ExpensesScreen: removido um campo de loading, quatro atribuições de
  sincronização e dois setState de finalização; loading deriva da execução e
  da intenção vigente, sem finally de consulta antigo disparando recarga.
- Os dezesseis commands concentram a adaptação de falhas; consumidores usam
  snapshots nativos, sem repetir a interpretação de Left.

Controles mantidos: lente mensal, latch e ciclo de recuperação, revisões e
identidade, intenções coalescidas de navegação/User/ID/lente, páginas e continuação,
feedback aceito, controllers, filtros, pendingDeleteId até finalizar gesto,
estado de formulário/hold, avatar temporário/confirmado e timers/cooldown.
São responsabilidades do fluxo ou da interação, não cópias de uma request.

O diff desta sessão foi revisado por camada: somente testes e documentação,
sem Dart de produção, nova dependência, geração, comentários Dart, domínio,
HTTP/storage ou mudança visual. A revisão histórica desde 56ac2e4 também
confirma pubspec/lockfile, domínios, repositories e data sources intactos.
Esse intervalo inclui trabalho paralelo já registrado de tema/botões, animação
de métricas e restauração do gesto de edição; esses diffs não foram atribuídos
à refatoração nem revertidos. A outra change, unify-dashboard-error-screen,
permanece independente, com sua divergência de cabeçalho documentada.

Limites reais remanescentes são os cenários runtime indicados na matriz e o
teste de ResendEmail no caminho histórico. Não são falhas unitárias abertas.
Não houve commit, push, sync de specs ou archive.

`openspec validate align-command-it-presentation-errors --strict`: **válido**.
`git diff --check`: **sem problemas**. O grupo 12 está concluído, totalizando
**85/85 tarefas**, com 12.7 encerrada pelo aceite e os limites runtime acima.
