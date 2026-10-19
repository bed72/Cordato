## ADDED Requirements

### Requirement: Cancelamento opcional é independente de framework

As leituras usadas pela Dashboard SHALL aceitar sinal opcional de cancelamento independente de Flutter, Bloc e Dio, propagado pelos contratos de repository e data source ao HTTP. Chamadas sem sinal SHALL manter resultados e comportamento existentes. O cancelamento SHALL ser idempotente e não usar estado global de requisições.

#### Scenario: Consumidor não migrado
- **WHEN** um command existente consulta repository sem sinal de cancelamento
- **THEN** mantém sua semântica e resultado anteriores
- **AND** nenhuma alteração de propriedade ou cancelamento global é introduzida

### Requirement: Ponte HTTP cancela a request específica no Dio

A infraestrutura SHALL associar um CancelToken por request ao sinal recebido e liberar assinaturas ao concluir, falhar ou cancelar. Sinal previamente cancelado SHALL impedir envio. Cancelar um ciclo SHALL afetar somente requests ligadas ao seu sinal, sem interromper outros consumidores do cliente compartilhado.

#### Scenario: Cancelamento de ciclo com várias leituras
- **WHEN** o proprietário cancela um sinal com várias requests em andamento
- **THEN** todos os CancelTokens associados são cancelados
- **AND** uma request independente, inclusive ao mesmo endpoint, continua

#### Scenario: Sinal cancelado antes do envio
- **WHEN** uma leitura recebe um sinal já cancelado
- **THEN** nenhum acesso de rede é iniciado
- **AND** o consumidor recebe cancelamento tipado neutro

#### Scenario: Conclusão libera recursos
- **WHEN** a request termina por sucesso, falha ou cancelamento
- **THEN** remove a assinatura da ponte de cancelamento
- **AND** cancelamentos futuros não retêm ou reativam a request concluída

### Requirement: Cancelamento não é convertido em falha de negócio

Cancelamento do Dio SHALL ser traduzido para um resultado excepcional tipado independente do Dio e propagado antes dos catches genéricos de HTTP, helpers, data sources e repositories. SHALL NOT virar erro HTTP artificial, ErrorsEntity.unknown, sucesso falso ou dados vazios. Erros não relacionados a cancelamento SHALL manter o contrato vigente.

#### Scenario: Cancelamento atravessa as camadas
- **WHEN** Dio encerra uma leitura com DioExceptionType.cancel
- **THEN** o Bloc recebe cancelamento tipado através das camadas intermediárias
- **AND** não apresenta ErrorScreen, toast ou reporte de falha por esse cancelamento

#### Scenario: Falha real durante leitura
- **WHEN** uma leitura vigente recebe erro HTTP, de parsing ou de negócio sem cancelamento
- **THEN** preserva o mapeamento atual de erros e a política visual da Dashboard
- **AND** não classifica a falha como cancelamento apenas porque outra request foi cancelada
