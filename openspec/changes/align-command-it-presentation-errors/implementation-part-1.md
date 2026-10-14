# Parte 1 — Simplificação isolada da Dashboard

## Baseline confirmado em 14/10/2026

- `git status --short`: somente esta change não versionada; `git diff` vazio antes da implementação.
- Lockfile e package config apontam para CommandIt 9.5.2, listen_it 6.0.0, Flutter Modular 7.1.1 e auto_injector 2.2.0. Nenhuma resolução de dependências foi necessária.
- `flutter analyze`: nenhum problema; `flutter test`: 671 testes aprovados antes das alterações.
- A change ativa `unify-dashboard-error-screen` foi relida. A Dashboard não passa `appBar` à ErrorScreen, apesar da intenção anterior de preservar cabeçalho. Seus artefatos permanecem intactos; a documentação canônica registra a divergência.
- Não há dispositivo conectado no Maestro; tampouco foi confirmado um ambiente financeiro controlado para atrasos/falhas. As tarefas 1.6 e 2.6 permanecem abertas pela validação runtime pendente.

## Fontes e estado observado

Foram reabertos os mixins e screens de Dashboard, Expense e Expenses, formulário,
seções financeiras, seletor, ErrorScreen, previews, botões compartilhados,
BounceWidget e testes existentes de commands. Não há testes Flutter de UI a
manter nesta etapa.

| Consumidor | Baseline |
| --- | --- |
| Dashboard | Três `results` e três `errors` chamavam o mesmo handler que detectava falha, fazia `setState` vazio e drenava pendências. Cinco listeners de execução, incluindo User, também chamavam esse caminho. |
| Seções da Dashboard | `CommandBuilder` próprio, saída Either anulável, Left oculto; skeleton sem resultados anteriores, vazio válido e dados sem acúmulo. |
| ExpenseScreen | Cópias locais de entidade, erro e loading preenchidas pelo await; guards de mounted, ID e identidade do command; três factories pertencem à screen. |
| ExpenseFormWidget | Listeners de results para efeitos de criação/edição; controllers, validação, pickers e modo hold locais; remove assinaturas sem descartar commands da screen. |
| ExpensesScreen | Página Either incorporada por revisão; itens, next, filtros, feedback, loading, retry, edição/exclusão e controller locais; guards por mounted/command/revisão. |

## Inventário de unidades futuras

Todos os caminhos abaixo estão em `lib/features/`, salvo os testes. Screen inclui
seu mixin e widgets que recebem o command. Os testes de command seguem o mesmo
caminho de apresentação em `test/features/`, com o sufixo `_test.dart`; a exceção
vigente de Resend está indicada explicitamente.

| Command | Consumidores a migrar juntos | Módulos e previews |
| --- | --- | --- |
| GetExpensesCommand | `expense/.../screens/expenses/{expenses_screen,mixins/expenses_screen_state_mixin}.dart`; Dashboard screen/mixin e `widgets/expenses/expenses_section_widget.dart` | `expense_module.dart`, `dashboard_module.dart`; `expenses_screen_preview.dart`, `expenses_section_widget_preview.dart`, `dashboard_screen_preview.dart` |
| GetExpenseCommand | `expense/.../screens/expense/{expense_screen,mixins/expense_screen_state_mixin}.dart` | `expense_module.dart`; sem preview direto de consulta |
| CreateExpenseCommand | Expense screen/mixin e `widgets/expense_form_widget.dart`/seu mixin | `expense_module.dart`; `expense_form_widget_preview.dart` |
| UpdateExpenseCommand | Expense screen/mixin e formulário/mixin; entidade devolvida à listagem | `expense_module.dart`; `expense_form_widget_preview.dart` |
| DeleteExpenseCommand | Expenses screen/mixin, confirmação e handlers de gesto/acessibilidade | `expense_module.dart`; `expenses_screen_preview.dart` |
| GetInsightsCommand | Dashboard screen/mixin e `widgets/insights/insights_section_widget.dart` | `insight_module.dart`, `dashboard_module.dart`; `insights_section_widget_preview.dart`, `dashboard_screen_preview.dart` |
| GetExpenseMetricsCommand | Dashboard screen/mixin e `widgets/metrics/metrics_section_widget.dart` | `metrics_module.dart`, `dashboard_module.dart`; `metrics_section_widget_preview.dart`, `dashboard_screen_preview.dart` |
| UserCommand | User screen/mixin; Dashboard screen/mixin, `app_bar_dashboard_widget.dart`, `user/user_name_widget.dart` | `user_module.dart`, `dashboard_module.dart`; `user_screen_preview.dart`, `dashboard_screen_preview.dart` |
| UpdateUserCommand | `user/.../screens/edit_user/` screen/mixin | `user_module.dart`; sem preview consumidor atual |
| UpdateAvatarCommand | `user/.../screens/user/` screen/mixin | `user_module.dart`; `user_screen_preview.dart` |
| DeleteUserCommand | `user/.../screens/user/` screen/mixin | `user_module.dart`; `user_screen_preview.dart` |
| SignInCommand | `authentication/.../screens/sign_in/` screen/mixin e `widgets/button_sign_in_builder_widget.dart` | `authentication_module.dart`; sem preview consumidor atual |
| SignUpCommand | `authentication/.../screens/sign_up/` screen/mixin e `widgets/button_sign_up_builder_widget.dart` | `authentication_module.dart`; sem preview consumidor atual |
| ResendEmailCommand | `authentication/.../screens/resend_email/` screen/mixin | `authentication_module.dart`; teste ainda em `screens/resend_email_verification/commands/resend_email_verification_command_test.dart` |
| LogoutCommand | `settings/.../screens/settings/` screen/mixin | `settings_module.dart`; sem preview consumidor atual; teste em `authentication/presentation/commands/logout_command_test.dart` |
| GetFirstExpenseMonthCommand | Dashboard screen/mixin | `dashboard_module.dart`; `dashboard_screen_preview.dart` |

Os fakes de repository mantêm Either: `ExpensesPreviewRepository`,
`ExpensesListPreviewRepository`, `ExpensePreviewRepository`,
`DashboardUserPreviewRepository`, `UserPreviewRepository`,
`InsightsPreviewRepository` e `MetricsPreviewRepository`. Os mocks dos contratos
ficam em `test/support/{expense,insight,metrics,user,authentication}/mocks/`.
Não há fake de command nem migração de repository nesta unidade.

Cada futura alteração de saída precisa incluir seus consumidores compartilhados,
seções, previews e testes na mesma unidade. A presente etapa preserva todas as
saídas Either; Callback e Session continuam fora das dezesseis adaptações.

## Propriedade e lifecycle

O AutoInjector descarta instâncias retidas em binds; factory não é retida.
O Modular descarta Disposable do escopo com path quando sua última rota sai;
registros de módulos sem path pertencem ao root.

| Recurso | Quem descarta | Quem somente observa |
| --- | --- | --- |
| Cinco commands factory da Dashboard | DashboardScreenStateMixin, também ao substituir dependências | AppBar/UserName e três seções |
| Get/Create/Update de Expense | ExpenseScreenStateMixin | Formulário e seus builders |
| Get/Delete da listagem | ExpensesScreenStateMixin | Componentes de lista/gesto |
| UserCommand e UpdateAvatar factory | UserScreenStateMixin | Componentes do perfil |
| UpdateUser/DeleteUser lazy singleton de `/user` | Modular | EditUser/User removem assinaturas próprias |
| Logout lazy singleton de `/settings` | Modular | Settings remove sua assinatura |
| SignIn/SignUp/Resend/Callback/Session root | Escopo root | Telas consumidoras removem suas assinaturas |
| Previews de seção/formulário isolados | PreviewResourceWidget | Widget de seção/formulário |
| Preview da Dashboard/listagem | Screen | Wrapper de User na Dashboard tem dispose vazio |
| Preview de User | Screen para User/Avatar; wrapper para Delete | Perfil remove assinatura de Delete |

`Listenable.merge` não cria assinatura ao construir e não possui dispose próprio;
encaminha add/remove às fontes. ListenableBuilder remove suas assinaturas ao sair
ou receber outra composição. As fontes são listas estáveis criadas no init e na
troca de dependências, não no build. Não há cadeia de operators própria.

## Simplificação implementada

- `_financialSignals`: seis fontes para três; removidos os três listeners redundantes de `errors` e sua releitura em `_failed`.
- `_financialResultChanged`: results terminal com Left ou exceção ativa o latch uma vez, mesmo quando as seções estão ocultas.
- `_executionChanged`: somente drena intenção financeira pendente. `_userLoadingChanged` conserva a intenção específica de User.
- Seletor observa as quatro execuções financeiras/limite e o valor do limite, necessário à disponibilidade do mês anterior. Retry observa as cinco execuções.
- Eliminado o único `setState(() {})` global; dados das seções continuam atualizados pelos seus builders. Transições locais de mês, erro e ciclo continuam usando setState.
- Mantidos selectedMonth, `_dependenciesVersion`, `_refreshPendingAfterNavigation`, `_userRefreshPending`, `_isRefreshingDashboard`, isRecovering, hasFinancialError e `_isOpeningExpenses`, com as finalidades da seção 6 do design.

## Ordem terminal e coordenação

CommandIt 9.5.2 publica results terminal síncrono antes de marcar a execução
ociosa e atualizar value. O notifier público de isRunning armazena a mudança
imediatamente, mas notifica assinantes de forma assíncrona. runAsync completa
depois de atualizar value; uma chamada enquanto ocupado pode compartilhar o
Future anterior. Descarte pode completar com value anterior.

Quatro novos testes unitários em `get_expenses_command_test.dart` comprovaram:
results terminal Right, Left e exceção chegam com isRunning ainda true e value
anterior; a notificação idle ocorre depois; uma microtask após idle inicia uma
consulta nova, com parâmetros diferentes e exatamente uma chamada por consulta.
As assinaturas são removidas ao fim de cada cenário. Não são testes do State.

Na Dashboard, a intenção é consumida antes do scheduling, revalidada por
mounted/versão e recolocada se outra execução ocupar o conjunto. O finally do
ciclo também verifica pendência quando libera `_isRefreshingDashboard`. User
preserva sua microtask e a identidade da instância. Esses caminhos foram
inspecionados, sem substituir filas ou relaxar guards.

## Limites de validação

D01–D06 (abertura, setas, erro imediato/persistente, retry, falhas auxiliares,
limite e retorno de navegação) aguardam Maestro em dispositivo conectado e
ambiente controlado. D07–D08 tiveram inspeção técnica dos caminhos existentes;
não houve execução de State com troca artificial de dependências. Nenhum harness
temporário, credencial, hook de simulação ou alteração financeira foi criado.
As evidências da change anterior não são validação runtime desta refatoração.

## Checks finais

- `flutter analyze`: nenhum problema.
- `flutter test`: 675 testes aprovados, incluindo os quatro novos casos de ordem/scheduling.
- `openspec validate align-command-it-presentation-errors --strict`: change válida.
- `git diff --check`: sem problemas de whitespace.
- Revisão do diff: alterações limitadas à composição/mixin da Dashboard, testes do command existente e documentação; sem mudança de contrato, dependência, HTTP, domínio ou comentários Dart novos.
- Grupos 1 e 2: dez tarefas concluídas de doze. 1.6 está parcial pelos checks aprovados e falta de ambiente runtime; 2.6 aguarda a matriz Maestro antes de considerar a Parte 1 completamente validada.

## Aceite posterior do usuário

O usuário informou “Validei, tudo ok. Segue para proxima step”. A Parte 1 foi
aceita e as tarefas 1.6 e 2.6 encerradas com essa confirmação e os checks acima.
Não foram fornecidos detalhes do dispositivo, ambiente, cenários ou relatórios.
O registro de limitações descreve a validação realizada pelo agente; não se
atribui execução Maestro ao agente nem se presume cobertura de cenários
artificiais a partir do aceite. Próxima unidade: grupo 3.
