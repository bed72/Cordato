# Parte 3 — Consultas compartilhadas com dados nativos

## Grupo 4 concluído

| Command | Saída de execute | Adaptação |
| --- | --- | --- |
| GetExpensesCommand | ExpensePageEntity? | Right publica a mesma página; Left lança CommandFailureException com a ErrorsEntity original |
| GetInsightsCommand | List<InsightEntity>? | Right publica a mesma lista, inclusive vazia; Left conserva a falha tipada |
| GetExpenseMetricsCommand | ExpenseMetricsEntity? | Right publica a mesma entidade, preservando total zero e agrupamento ausente/vazio; Left conserva a falha tipada |
| UserCommand | UserEntity? | Right publica a mesma entidade; Left conserva a falha tipada |
| GetFirstExpenseMonthCommand | DateTime? | Menor mês civil ou null para histórico ausente; falha remota/continuação repetida lança falha tipada |

Entradas, registros factory, contratos de repository, DTOs e HTTP permanecem
vigentes. Repositories e fakes continuam retornando Either. Os callbacks dos
commands fazem a adaptação específica, sem converter genérico ou try/catch que
encapsule exceções inesperadas.

O limite histórico continua percorrendo páginas não ordenadas, inclusive página
vazia com next opaco. Após detectar o descarte, retorna null sem outra página ou
erro artificial. A neutralidade desse retorno não equivale a sucesso aceito pelo
State descartado: mounted, versão e identidade invalidam sua aplicação.

## Consumidores

- ExpensesSection, InsightsSection, MetricsSection e UserName usam onData/onNullData, whileRunning e onError, sem reler value para decidir dados ou falha.
- UserScreen recebe a entidade nativa no builder; CommandFailureException alimenta o erro localizado, e falha inesperada/lista vazia usa fallback. A atualização de avatar conserva seu estado local e o contrato Either vigente.
- ExpensesScreen recebe a página nativa. A incorporação continua no mixin, uma vez por operação válida, preservando revisão, lista acumulada, filtros, continuação, controller, loading local e retry existente.
- Dashboard detecta somente hasError terminal. Seus refreshes aceitam dados não nulos depois do await somente com command/versão/mounted vigentes e snapshot terminal sem erro.
- O seletor observa results do limite: estado inicial, loading e erro não habilitam o mês anterior; null após execução válida permite o ajuste de ausência de histórico no ciclo de refresh.
- Não há efeitos de navegação, toast ou limpeza dentro dos builders.

A remoção de Left e a adaptação dos refreshes da Dashboard são necessárias para
esta unidade permanecer compatível. A auditoria completa dos interleavings,
pendências, ciclo de recuperação e matriz de interação permanece no grupo 5.

## Previews e propriedade

Previews existentes de Dashboard, ExpensesScreen, UserScreen e seções de
despesas/insights/metrics foram inspecionados. Os records e typedefs utilizados
para configurar os fakes pertencem ao repository e continuam Either; nenhum
preview interpreta a saída antiga do command. Não foi necessário alterar esses
contratos ou adicionar um fake de command.

- Dashboard e listagem descartam suas factories, inclusive os commands construídos pelos previews.
- No preview da Dashboard, o wrapper de User mantém dispose vazio porque a screen possui a instância.
- Seções isoladas têm seus commands descartados pelo PreviewResourceWidget; as seções somente observam.
- O preview de User deixa User/Avatar para a screen e Delete para o wrapper, sem descarte duplicado.
- O notifier de mês no preview de Metrics continua pertencendo ao wrapper.
- Módulos e lifecycles não mudaram.

Essa verificação foi estática e pela análise de todos os consumers/previews;
não houve execução visual do catálogo nesta etapa.

## Evidências e checks

As cinco suítes de consulta foram adaptadas para valor nativo, identidade de
sucesso, erro original tipado no Future/results/errors e conservação dos inputs.
Continuam verificando retry, consulta ocupada, isolamento, lista/página vazia,
total zero, null do limite, parâmetros incompletos, períodos nulos e histórico
não ordenado.

Onze casos adicionais verificam falha com lista vazia depois de sucesso,
agrupamento ausente em total zero, isolamento de User, ausência de publicação
tardia após descarte, neutralidade do limite descartado e exceção inesperada do
algoritmo. O teste de consulta ocupada também comprova que runAsync com novos
parâmetros adere ao Future anterior sem executar esses parâmetros.

O teste do fallback global agora recebe Left pelo mock do repository de Expense,
exercitando a adaptação real do command sem listener local, com conclusão do
Future e ausência de reporte da falha tipada. Configuração global e assinaturas
continuam restauradas no teardown.

- flutter analyze: nenhum problema.
- flutter test: 696 testes aprovados; onze novos em relação ao grupo 3.
- openspec validate align-command-it-presentation-errors --strict: change válida.
- git diff --check: sem problemas de whitespace.
- Não houve alteração de dependências; flutter pub get não foi necessário.
- ARCHITECTURE.md e AGENTS.md atualizados para os contratos atuais e sua propriedade.
- Não há testes Flutter de UI, módulos ou rotas adicionados.
- Grupo 4: nove tarefas concluídas; progresso total 28/85. Grupo 5 permanece como a próxima unidade de auditoria e validação da recuperação coordenada.

## Limite de validação de interação

O Maestro listou apenas dispositivos desconectados. Não foi executado fluxo de
Dashboard, perfil ou listagem nesta etapa; não se reaproveita o aceite da Parte 1
como validação runtime desta migração. Skeletons, fallback Trocado, recuperação,
paginação e navegação foram preservados por inspeção, com validação de interação
pendente em dispositivo conectado. Não há harness ou hook de simulação adicionado.
