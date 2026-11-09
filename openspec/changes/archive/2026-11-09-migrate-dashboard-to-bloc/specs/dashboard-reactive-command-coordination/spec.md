> Delta histórico; a política de retorno sem alteração foi substituída para a
> listagem. Consulte [a referência vigente](../../../../README.md).

## REMOVED Requirements

### Requirement: Dashboard usa uma fonte de erro financeiro por operação
**Reason**: A Dashboard deixa de observar commands e passa a receber conclusões diretamente no Bloc.
**Migration**: Usar dashboard-bloc-lifecycle, publicação atômica e invalidação lógica de cargas obsoletas.

### Requirement: Estado local da Dashboard representa o fluxo da tela
**Reason**: O fluxo deixa de pertencer ao mixin e seus dados não permanecem em commands.
**Migration**: Estado imutável e derivado pertencem ao DashboardBloc, sem cópias no State.

### Requirement: Reconstrução visual é separada da coordenação
**Reason**: CommandBuilders e listenables não serão usados pela Dashboard.
**Migration**: Usar BlocBuilder/BlocSelector e dados/status de apresentação, mantendo coordenação fora da UI.

### Requirement: Lente mensal e loading permanecem consistentes
**Reason**: A garantia continua, mas o mecanismo CommandIt foi substituído.
**Migration**: Aplicar dashboard-monthly-navigation e os eventos bloqueáveis de dashboard-bloc-lifecycle.

### Requirement: Erro financeiro persiste até recuperação corrente completa
**Reason**: A recuperação deixa de validar snapshots e ignora conclusões remanescentes do ciclo invalidado.
**Migration**: Retry é carga normal com loading e um único conteúdo completo ou erro.

### Requirement: Recuperação mantém sequência e isolamento auxiliares
**Reason**: A sequência passa a ser coordenada pelo Bloc, sem runAsync.
**Migration**: Preservar sequência de User/limite/seções definida nas specs de Bloc e navegação mensal.

### Requirement: Alterações após navegação produzem uma leitura nova
**Reason**: Atualização pendente foi substituída por invalidação lógica e reinício imediato.
**Migration**: Retorno com alteração confirmada substitui o ciclo; retorno sem alteração não consulta.

### Requirement: Retorno de User e Settings respeita leitura ocupada
**Reason**: Não haverá UserCommand na Dashboard nem espera pela leitura antiga.
**Migration**: Retorno com conteúdo pronto relê somente User; durante loading/erro substitui a carga completa.

### Requirement: Ciclos obsoletos não alteram a Dashboard
**Reason**: A garantia permanece sem mounted, listeners CommandIt ou validação de snapshots.
**Migration**: Usar identidade de ciclo, fechamento do Bloc e proteção de emissão.

### Requirement: Refatoração não corrige visual ou navegação incidentalmente
**Reason**: A proposta aprova explicitamente skeleton e novas políticas de concorrência.
**Migration**: Preservar demais visuais, textos e contratos conforme dashboard-monthly-navigation; mudar somente o escopo aprovado.
