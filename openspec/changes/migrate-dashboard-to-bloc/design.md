> Registro de design de uma etapa anterior. Contratos atuais usam Future e
> exceções; listagem recarrega ao retornar mesmo sem alteração. Somente Sign-in
> usa ownership Modular. Consulte [a referência vigente](../../README.md).

## Context

DashboardScreenStateMixin coordenava cinco commands em 571 linhas, com snapshots,
listeners e microtasks. O piloto usa um Bloc específico da Dashboard, sem migrar
outras telas. Após revisão, o usuário aprovou simplificar o comportamento para
publicação única, abandonando seções parciais e recuperação com fases próprias.

## Escopo revisado

Cancelamento HTTP permanece adiado. Expense.get recebe sort opcional para uma
leitura eficiente do limite. Requests antigas continuam, mas restartable invalida
o emitter anterior e suas conclusões não publicam no estado atual.

## Decisions

### 1. Proprietário único

DashboardBloc, eventos e estado ficam em presentation/screens/dashboard/bloc/.
O Bloc recebe somente os contratos de User, Expense, Insight e Metrics,
sem HTTP, BuildContext, Modular, commands, ICrashClient ou callback de telemetry.
Repositories continuam retornando Either.

DashboardScreen cria o Bloc pela factory injetada, é sua única proprietária e o
fecha ao sair ou substituir a factory. A rota fornece inject<DashboardBloc> como
tear-off estável. BlocProvider.value compartilha a instância sem assumir descarte.
O mixin cuida de lifecycle/refresh; navegação fica nos widgets pelo próprio contexto.

### 2. Três fases e publicação atômica

DashboardPhaseEnum possui somente loading, ready e failure. Cada carga publica
loading sem dados e depois um único resultado completo ou erro. Não há status
auxiliares, copyWith, fases de recuperação, barreira de User, IDs de ciclo ou
observação do próprio stream. DashboardState normaliza o mês atual e usa-o como
seleção inicial por DateTime.now(), capturado uma vez em DashboardState(); o Bloc não precisa de helper _initial ou
relógio injetável. Testes configuram estados civis determinísticos pelo emit do Bloc.

As seções aguardam todas as conclusões por record.wait, inclusive em falha.
Somente depois seus Either são interpretados. Left financeiro preserva a mesma
ErrorsEntity, inclusive lista vazia e metadados; exceções inesperadas usam erro
desconhecido. User falho usa placeholder; limite falho desabilita a seta anterior
e mantém seleção. Limite vazio bem-sucedido ajusta seleção para o mês atual.

### 3. Uma sequência de carga

Abertura, troca mensal, refresh, retry e alteração confirmada executam a mesma
sequência: User e histórico em paralelo, ajuste civil, Metrics/Insights/recentes
em paralelo, publicação final. Cada carga tem cinco leituras. Troca mensal relê
os dois auxiliares, aceitando esse custo para evitar caminhos especiais.

O limite usa get(pageSize: 1, sort: 'occurred_on'), sem seguir next. Metrics usa
intervalo civil completo e groupBy category; recentes usam seis itens; Insights
recebe ano/mês. A seleção não passa do mês atual. Retry sai de ErrorScreen para o
mesmo skeleton da abertura e é apenas outra carga, sem tratamento especial.

### 4. Concorrência e perfil

Todos os eventos concretos usam um handler restartable com filtro anterior.
Abertura é única. Mês, refresh e retry bloqueados não interrompem a carga nem
entram em fila. Alteração confirmada e retorno de User substituem o handler ativo;
isClosed e emitter ativo protegem todo resultado pós-await. O fechamento é o
nativo do Bloc, sem flag, Future armazenado ou override. Não se exige identidade
do Future de close e não se promete cancelar a rede. Somente _opened mantém a
regra de abertura única.

Retorno de User/Settings com conteúdo pronto consulta somente User, publicando
loading e depois os dados financeiros confirmados com o perfil novo/fallback.
Durante loading/erro, reinicia a carga completa para não reaproveitar dados
incompletos. Alteração financeira também relê User. Retorno financeiro sem
alteração não envia evento, preservando mês e conteúdo.

### 5. UI e compatibilidade

Mês/ano permanece legível durante loading, com skeletons nos controles sem foco,
callbacks ou ações acessíveis. AppBar e as três seções mostram skeletons juntos.
Erro mostra ErrorScreen sem AppBar, seletor, seções ou FAB. Mantidos textos,
categorias, seis recentes, vazios, tema, BRL, datas civis e records de navegação.
Widgets usam context.pushNamed, validando montagem e identidade do Bloc no retorno;
onExpensesChanged sinaliza somente mutações confirmadas. Metrics não importa o
Bloc da Dashboard. Previews continuam usando o Bloc real com repositories locais.

## Verificação

Testes unitários controlam Futures para verificar publicação única, espera de
todas as seções, fallbacks, mês civil, cinco leituras, eventos bloqueados,
substituição, perfil e fechamento. Não criar testes de widgets ou Modular.
Executar pub get, analyze, test, arquitetura e OpenSpec strict. Maestro valida a
versão atualizada quando possível; bloqueios e cobertura parcial devem ser registrados.
