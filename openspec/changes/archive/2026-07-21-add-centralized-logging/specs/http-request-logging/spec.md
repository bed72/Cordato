## ADDED Requirements

### Requirement: Toda requisição HTTP é logada com method, path, status e duração

O sistema SHALL interceptar, por um filtro de servidor HTTP cross-cutting, toda requisição recebida —
autenticada ou não — e SHALL registrar, através de `LoggerPort`, ao menos o método HTTP, o path, o status
da resposta e a duração do processamento em milissegundos, após a resposta ser produzida.

#### Scenario: Requisição bem-sucedida é logada

- **WHEN** uma requisição a qualquer rota é processada e responde `2xx`
- **THEN** um registro de log é emitido com method, path, status e duração dessa requisição

#### Scenario: Requisição que resulta em erro também é logada

- **WHEN** uma requisição a qualquer rota responde `4xx` ou `5xx`
- **THEN** um registro de log é emitido com o status efetivo da resposta, sem suprimir o registro por causa do erro

### Requirement: Cada requisição recebe um correlation id propagado por MDC

O filtro SHALL gerar um identificador de correlação único por requisição e disponibilizá-lo via MDC sob
uma chave estável (`correlation_id`), de modo que qualquer chamada a `LoggerPort` feita durante o
processamento dessa requisição possa ser associada a ela. O identificador SHALL também ser devolvido ao
cliente num cabeçalho de resposta dedicado.

#### Scenario: Logs da mesma requisição compartilham o correlation id

- **WHEN** uma requisição autenticada aciona tanto o filtro de autenticação quanto um use case que loga, e depois o próprio filtro de log de request/response
- **THEN** todos os registros de log emitidos durante essa requisição carregam o mesmo valor de correlation id

#### Scenario: Cliente recebe o correlation id na resposta

- **WHEN** qualquer requisição é respondida
- **THEN** a resposta inclui um cabeçalho com o correlation id gerado para essa requisição

#### Scenario: Requisições distintas recebem correlation ids distintos

- **WHEN** duas requisições chegam em sequência
- **THEN** cada uma recebe um correlation id diferente
