## REMOVED Requirements

### Requirement: Dashboard usa uma fonte de erro financeiro por operação
**Reason**: A Dashboard deixa de observar commands e passa a receber conclusões diretamente no Bloc.
**Migration**: Usar dashboard-bloc-lifecycle e a regra mensal de primeira falha financeira com cancelamento.

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
**Reason**: A recuperação deixa de validar snapshots e cancela consultas remanescentes.
**Migration**: Usar identidade do ciclo e três sucessos financeiros vigentes na recuperação global.

### Requirement: Recuperação mantém sequência e isolamento auxiliares
**Reason**: A sequência passa a ser coordenada pelo Bloc, sem runAsync.
**Migration**: Preservar sequência de User/limite/seções definida nas specs de Bloc e navegação mensal.

### Requirement: Alterações após navegação produzem uma leitura nova
**Reason**: Atualização pendente foi substituída por cancelamento e reinício imediato.
**Migration**: Retorno com alteração confirmada substitui o ciclo; retorno sem alteração não consulta.

### Requirement: Retorno de User e Settings respeita leitura ocupada
**Reason**: Não haverá UserCommand na Dashboard nem espera pela leitura antiga.
**Migration**: Leitura independente de User cancela a anterior e inicia outra no retorno válido.

### Requirement: Ciclos obsoletos não alteram a Dashboard
**Reason**: A garantia permanece sem mounted, listeners CommandIt ou validação de snapshots.
**Migration**: Usar identidade de ciclo, cancelamento, fechamento do Bloc e proteção de emissão.

### Requirement: Refatoração não corrige visual ou navegação incidentalmente
**Reason**: A proposta aprova explicitamente skeleton e novas políticas de concorrência.
**Migration**: Preservar demais visuais, textos e contratos conforme dashboard-monthly-navigation; mudar somente o escopo aprovado.
