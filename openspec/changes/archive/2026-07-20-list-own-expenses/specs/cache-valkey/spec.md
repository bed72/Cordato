# cache-valkey

## Purpose

Um kernel de **cache distribuído** transversal no `core`, compartilhado entre instâncias, sobre Valkey
(Redis-compatível). Expõe às features um `CachePort` puro e mínimo (leitura/escrita com TTL e um contador
incremental para invalidação por geração), implementado por um adapter Valkey na infraestrutura e ligado no
`CoreFactory`. Nasce servindo a listagem de gastos (`expense-list`), mas é genérico e cross-cutting — mora
no `core` como o contrato de erro e o guard de autenticação, não em nenhuma feature.

## ADDED Requirements

### Requirement: Um CachePort puro no core, agnóstico do cliente

O `core` SHALL definir um `CachePort` na sua camada de aplicação (driven), como um contrato **puro e
agnóstico do cliente** que as features consomem para cachear dados. O port SHALL expor, no mínimo: obter o
valor de uma chave (ou a sua ausência), gravar o valor de uma chave com um **tempo de expiração (TTL)**, e
**incrementar atomicamente** um contador nomeado retornando o novo valor (base da invalidação por geração).
As assinaturas do port SHALL usar apenas tipos neutros (chaves/valores como texto, TTL como duração) e SHALL
NOT expor nenhum tipo do cliente Redis/Valkey. A camada de `application`/`domain` SHALL NOT importar o
cliente de cache nem qualquer anotação de framework/DI.

#### Scenario: Gravar e obter um valor com TTL

- **WHEN** um valor é gravado sob uma chave com um TTL e obtido em seguida
- **THEN** o port retorna o valor gravado
- **AND** após o TTL expirar, o port passa a indicar a ausência daquela chave

#### Scenario: Chave ausente indica ausência, não erro

- **WHEN** o valor de uma chave nunca gravada (ou já expirada) é obtido
- **THEN** o port indica ausência (não lança erro)

#### Scenario: Incremento atômico de um contador

- **WHEN** um contador nomeado é incrementado
- **THEN** o port retorna o novo valor do contador
- **AND** um contador nunca antes incrementado começa de zero

### Requirement: Adapter Valkey implementa o port, wired no core

O `core` SHALL implementar o `CachePort` com um adapter **Valkey** na sua camada de infraestrutura, sobre um
cliente Redis-compatível, sendo o **único** lugar em que o tipo do cliente aparece. O adapter SHALL ser
ligado pelo `CoreFactory` (a regra "um `@Factory` por pacote"), que expõe o `CachePort` como singleton e
constrói a conexão a partir de configuração externa (host/porta), nunca de literais no código. Uma
feature que precise de cache SHALL receber o `CachePort` do kernel por injeção, nunca instanciar o cliente.

#### Scenario: O CachePort é resolvido a partir do core

- **WHEN** o contexto de aplicação sobe
- **THEN** o `CachePort` está disponível como um singleton ligado pelo `CoreFactory`
- **AND** o endereço do Valkey vem de configuração externa, não de um literal no código

#### Scenario: O tipo do cliente não escapa da infraestrutura

- **WHEN** uma feature consome o cache
- **THEN** ela depende apenas do `CachePort`
- **AND** nenhum tipo do cliente Redis/Valkey aparece em assinaturas de `application` ou `domain`
