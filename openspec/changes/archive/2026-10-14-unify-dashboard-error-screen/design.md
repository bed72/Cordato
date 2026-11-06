## Context

`DashboardScreen` compõe um Scaffold com `AppBarDashboardWidget`, seletor mensal, Metrics, Insights, despesas recentes e botão flutuante. Cada seção usa `CommandBuilder` com erro próprio e retry localizado. `UserNameWidget` também substitui o nome por um link de retry quando User falha.

`DashboardScreenStateMixin` já coordena mês, consultas, listeners, recarga após navegação e descarte. `refreshDashboard` consulta primeiro o limite do histórico e depois as três seções em paralelo, mas não recarrega User. Falha no limite apenas bloqueia a navegação para meses anteriores. Os resultados financeiros usam `Either`; exceções também podem aparecer como erros observáveis dos commands.

A mudança é de apresentação e composição. As regras atuais de HTTP JSON:API, factories de commands e lifecycle prevalecem sobre referências históricas das specs. Não serão criados testes Flutter de widgets, screens, temas, módulos ou rotas.

## Goals / Non-Goals

**Goals:**

- Ter uma `ErrorScreen` compartilhada que controla Scaffold, cabeçalho, corpo e footer.
- Mostrar um erro financeiro global imediatamente quando qualquer uma das três seções falhar.
- Oferecer recuperação única, sem perder o mês ou recriar a Dashboard.
- Remover o retry do nome e aplicar o fallback “Cordato”.
- Manter estados vazios, consultas financeiras e navegação bem-sucedida existentes.

**Non-Goals:**

- Migrar Dados pessoais ou outras telas nesta mudança.
- Criar rota de erro, gerenciador global de estado ou command agregador.
- Alterar repositories, data sources, contratos HTTP ou autorização de sessão.
- Introduzir arte externa, dependência ou cópia da paleta vermelha da referência.

## Decisions

### 1. ErrorScreen é dona do Scaffold

Criar `lib/features/core/presentation/screens/error/error_screen.dart` com classe pública `final`, StatelessWidget e primary constructor const. A screen recebe:

- `PreferredSizeWidget? appBar` para o cabeçalho do consumidor.
- `IconData icon`, com padrão de erro apropriado, como elemento visual decorativo.
- `String title` e `String description` obrigatórios.
- `String actionLabel` e `VoidCallback? onAction` para a ação principal.
- `bool isLoading`, com padrão false.
- `String? secondaryActionLabel` e `VoidCallback? onSecondaryAction` para ação secundária opcional; sem label, a ação não é renderizada.

A composição usa Material via `material_ui`, cores e tipografia do tema, `SafeArea`, margens laterais de 20 pixels e botões compartilhados. O corpo centraliza ícone destacado, título e descrição; o footer agrupa as ações na base. Em espaço reduzido ou texto ampliado, a composição permite rolagem para preservar mensagens e acesso às ações, sem truncamento ou overflow. Não há FAB nessa screen. Loading desabilita ambas as ações e é apresentado no botão principal.

Foi considerada uma composição apenas de widget de corpo. A screen completa foi escolhida porque o consumidor precisa controlar o estado de toda a página, incluindo cabeçalho e footer. O core não recebe commands ou listas de operações: o callback fornecido já coordena a recuperação.

### 2. Dashboard troca a composição sem trocar de rota

`DashboardScreen.build` retorna `ErrorScreen` quando há erro financeiro global e retorna o Scaffold atual nos demais estados. O mesmo `State` e seus commands permanecem montados.

Por decisão explícita do usuário na conclusão desta change, a ErrorScreen da Dashboard não recebe appBar. Saudação, avatar, notificações e Settings ficam ocultos durante erro financeiro e recuperação, reaparecendo somente no conteúdo normal. A tela de erro usa:

- Título: “Não foi possível carregar sua Dashboard.”
- Descrição: “Não conseguimos carregar suas informações agora. Tente novamente.”
- Ação principal: “Tentar novamente”.

Cabeçalho, seletor mensal, Metrics, Insights, recentes e FAB não são montados no erro. A Dashboard não exibe textos técnicos ou três mensagens separadas. As seções deixam de fornecer retries localizados nessa composição; componentes de falha e previews que perderem todos os consumidores devem ser removidos ou substituídos pelo preview global, após verificação dos usos.

### 3. Erro imediato e persistente até recuperação completa

A coordenação fica em `DashboardScreenStateMixin`. Observar results terminais dos três commands garante captura de falhas tipadas e exceções sem depender dos builders de seções montadas. A migração concluída em `align-command-it-presentation-errors` adapta Left para CommandFailureException nos commands; não há observação adicional de errors para a mesma detecção. A execução dos commands coordena pendências e é observada declarativamente pelos controles.

Uma falha financeira ativa um estado local persistente de erro. Não se espera que todas as consultas terminem para exibi-lo. Sucessos de consultas ainda em execução não removem esse estado. Ausência de resultado e listas vazias não são falhas.

Fluxo de apresentação:

1. Normal/carregando: seções carregam como hoje; qualquer falha leva ao erro global.
2. Erro: mensagem única; ação fica desabilitada enquanto ainda houver consulta da Dashboard em andamento, impedindo overlap com o ciclo que falhou.
3. Recuperando: erro permanece; botão principal mostra loading e ações ficam desabilitadas.
4. Fim da recuperação: restaurar o Scaffold normal apenas se as três seções da tentativa vigente concluíram com dados nativos e snapshot terminal sem erro; outra falha mantém o erro e libera nova tentativa quando o ciclo terminar.

Resultados de tentativas anteriores não podem satisfazer a recuperação atual. Cada ciclo possui identidade local para invalidar conclusões obsoletas após troca de dependências ou descarte. Isso evita remover a tela de erro com um sucesso antigo preservado pelo command.

Foi considerado derivar a tela somente de `isLeft` com `!isLoading`. Essa abordagem foi descartada porque atrasaria o erro imediato e permitiria flashes do conteúdo durante o retry.

### 4. Recuperação coordenada pelo mixin

Um handler único inicia a tentativa apenas quando nenhuma consulta existente está rodando. Recarrega User e o limite do histórico; User pode rodar em paralelo à consulta do limite. Após resolver o limite, aplica o ajuste civil existente do mês e dispara Metrics, Insights e recentes em paralelo para a seleção efetiva.

O mês continua selecionado durante o erro. Não há reset para hoje. O ajuste existente é permitido somente quando um novo limite válido torna a seleção anterior inválida. A recuperação não introduz retry automático, não acumula solicitações por toques bloqueados e não muda a lógica de recarga após navegação.

Falha de User mantém “Cordato”; falha do limite mantém a seta anterior bloqueada. Nenhuma dessas falhas ativa ou prolonga o erro financeiro global depois que as três seções se recuperarem. A perda da sessão continua sendo tratada pelo app root.

### 5. Fallback do nome

`UserNameWidget` conserva loading por skeleton e nome/avatar retornados no sucesso. Falha tipada e exceção renderizam a mesma composição com nome “Cordato” e avatar placeholder. O link de retry e seu import são removidos. O fallback não é persistido nem sobrescreve o usuário da API.

### 6. Validação e documentação

Previews devem cobrir `ErrorScreen` com e sem appBar, ação secundária, loading, temas claro/escuro e texto ampliado, além de Dashboard com erro global e fallback do nome. Recursos de commands dos previews devem ser descartados pelo mecanismo compartilhado.

Maestro valida falha isolada de cada seção, falha enquanto outras consultas estão pendentes, erro via exceção, múltiplas falhas, retry repetido, recuperação, mês histórico e User e limite com erro independente. No erro financeiro, o cabeçalho deve permanecer ausente. Usar respostas controladas nos cenários de falha, sem provocar indisponibilidade real da API. As pendências finais de Maestro foram encerradas por aceite explícito do usuário, sem recriar os recursos removidos anteriormente.

Atualizar `ARCHITECTURE.md` e `AGENTS.md` para descrever a screen compartilhada e substituir o comportamento de retries por seção na Dashboard.

## Risks / Trade-offs

- [Uma seção indisponível oculta dados carregados das demais] → Decisão explícita de produto: a Dashboard usa um único estado financeiro de erro.
- [Consultas remanescentes continuam após a primeira falha] → Mostrar erro imediatamente e bloquear o retry até concluírem, sem cancelar commands ou criar solicitações concorrentes.
- [Erros antigos persistem nos commands durante o retry] → Usar identidade do ciclo e resultados da tentativa atual como critério de recuperação, mantendo a tela de erro estável.
- [Listeners ou callbacks sobrevivem à troca de dependências] → Remover observações antigas, invalidar o ciclo e ignorar conclusões após descarte, seguindo o lifecycle atual do mixin.
- [Footer e textos não cabem em dispositivos menores] → Layout adaptável com rolagem, SafeArea e validação com texto ampliado.

## Migration Plan

1. Adicionar a screen compartilhada e seus previews.
2. Integrar o estado global, fallback e recuperação na Dashboard; ajustar consumidores e previews das falhas locais.
3. Atualizar a documentação e validar os cenários.

Não há migração de dados, rota ou configuração de API. A entrega é uma alteração de apresentação dentro da mesma versão do aplicativo.

## Open Questions

Nenhuma decisão de produto pendente. A regra confirmada é: falha de qualquer uma das três seções financeiras substitui toda a composição financeira pela tela de erro.
