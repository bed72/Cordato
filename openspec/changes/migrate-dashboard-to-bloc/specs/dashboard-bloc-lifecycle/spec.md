## ADDED Requirements

### Requirement: Bloc é proprietário único do fluxo da Dashboard

A Dashboard SHALL usar um Bloc de apresentação por instância de rota, com estado imutável e dependência dos contratos de repositories. SHALL NOT usar commands, snapshots CommandIt ou estado financeiro duplicado no State/mixin. Navegação, BuildContext e recursos visuais SHALL permanecer fora do Bloc. Outros consumidores SHALL manter seus commands existentes.

#### Scenario: Atualização de uma seção
- **WHEN** Insights conclui enquanto Metrics ainda carrega
- **THEN** o estado do Bloc disponibiliza Insights e mantém o ciclo ocupado
- **AND** a UI renderiza a seção sem copiar resultados para o mixin

#### Scenario: Rebuild da tela
- **WHEN** a composição visual é reconstruída sem nova intenção
- **THEN** não cria outro Bloc, listeners permanentes ou novas consultas

### Requirement: Intenções financeiras compartilham uma política de concorrência

Abertura, troca mensal, refresh, retry e alteração financeira confirmada SHALL participar de uma única coordenação financeira. Eventos bloqueados SHALL ser rejeitados antes de poder cancelar o handler vigente. Somente alteração confirmada SHALL substituir imediatamente um ciclo ocupado. Todo ciclo SHALL possuir identidade e cancelamento próprios.

#### Scenario: Evento bloqueado não interrompe consulta
- **WHEN** uma seta, refresh ou retry é acionado enquanto o ciclo está ocupado
- **THEN** o ciclo atual continua, sem cancelamento ou consulta adicional
- **AND** não é armazenada uma intenção pendente

#### Scenario: Alteração disputa com refresh
- **WHEN** um retorno com alteração confirmada chega durante refresh de outro tipo de evento
- **THEN** o ciclo anterior é invalidado e suas leituras são canceladas
- **AND** um ciclo novo começa imediatamente no mês preservado, sem esperar o Future antigo

### Requirement: Resultados obsoletos e cancelamento não publicam estado

Resultados, falhas e finalizações de ciclos invalidados SHALL NOT alterar dados, mês, fase, erro ou disponibilidade de ações. Cancelamento intencional SHALL NOT gerar erro visual ou telemetry. O fechamento SHALL invalidar e cancelar todas as leituras pertencentes à instância e impedir novas páginas ou emissões.

#### Scenario: Adapter ignora cancelamento
- **WHEN** uma leitura antiga termina depois de o ciclo novo começar
- **THEN** nenhum resultado ou erro antigo é aplicado
- **AND** o finally antigo não encerra o loading novo

#### Scenario: Descarte durante paginação histórica
- **WHEN** a Dashboard é fechada antes de uma página do limite concluir
- **THEN** a request ativa recebe cancelamento e nenhuma página seguinte é solicitada
- **AND** nenhuma emissão é aplicada à instância fechada

### Requirement: Sequência das consultas e limite histórico são preservados

A abertura SHALL consultar User, limite e três seções em paralelo no mês atual. Troca mensal SHALL consultar apenas as três seções. Refresh e alteração confirmada SHALL consultar limite antes das seções. Retry SHALL consultar User em paralelo ao limite e depois as três seções em paralelo. O limite SHALL percorrer páginas sem assumir ordem, detectar continuação repetida e representar sucesso sem histórico por null. Falha auxiliar SHALL NOT ativar erro financeiro.

#### Scenario: Limite sem histórico
- **WHEN** a leitura completa do histórico retorna nenhuma despesa
- **THEN** aplica a regra civil de ausência de histórico sem fabricar um mês histórico
- **AND** as consultas financeiras continuam para o mês válido

#### Scenario: Continuação repetida
- **WHEN** a busca de limite encontra um link já visitado
- **THEN** termina com falha auxiliar sem loop de requests
- **AND** bloqueia navegação anterior sem abrir ErrorScreen

### Requirement: Usuário possui leitura independente e substituível

Retorno válido de User ou Settings SHALL iniciar leitura nova de User, cancelando uma leitura anterior se necessário, sem reiniciar consultas financeiras. Alteração financeira isolada SHALL NOT cancelar User. Falha de usuário SHALL manter o fallback existente. Descarte ou substituição do Bloc SHALL invalidar retornos de navegação antigos.

#### Scenario: Nome alterado com leitura antiga pendente
- **WHEN** a pessoa retorna de User e a leitura anterior ainda não terminou
- **THEN** a leitura anterior é cancelada e outra começa imediatamente
- **AND** uma resposta antiga não sobrescreve nome ou avatar novos

#### Scenario: Retorno para instância obsoleta
- **WHEN** um callback de navegação termina após fechamento ou substituição do Bloc
- **THEN** não dispara leitura nem altera o Bloc antigo ou o novo

### Requirement: Erros inesperados mantêm observabilidade sem duplicação

Falhas inesperadas expostas ao Bloc SHALL ter erro e stack reportados uma única vez ao contrato de crash existente. Falhas de negócio e cancelamentos intencionais SHALL NOT ser reportados como crashes. A configuração global de CommandIt dos consumidores não migrados SHALL permanecer inalterada.

#### Scenario: Exceção inesperada na consulta
- **WHEN** um repository lança exceção inesperada para um ciclo vigente
- **THEN** o Bloc aplica a política visual pertinente e reporta erro e stack uma vez
- **AND** não depende de Command.globalExceptionHandler para esse fluxo
