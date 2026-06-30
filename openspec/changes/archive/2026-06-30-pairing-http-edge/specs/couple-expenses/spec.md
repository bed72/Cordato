## ADDED Requirements

### Requirement: Despesas do casal são acessíveis via HTTP

O sistema SHALL expor o comportamento existente de visão de despesas do casal como
`GET /v1/pair/expenses`. O endpoint SHALL resolver a pessoa atuante via `CurrentPersonProvider`,
invocar o `GetCoupleExpensesUseCase` inalterado, e responder **200 OK** com a lista de despesas
combinadas — cada item carregando `id`, `person_id`, `amount`, `occurred_on`, `description`,
`created_at`, e `perspective` (`mine` ou `theirs`) — ordenada por `occurred_on` descendente e
`created_at` descendente como desempate. Uma lista vazia é uma resposta `200 OK` válida. Quando o
use case lança `NotPairedError` (a pessoa não está em nenhum par vivo), o `PAIRING_STATUS_ERROR`
SHALL mapear para **404** no envelope unificado. O endpoint SHALL exigir autenticação
(`Authorization: Bearer <token>`); um token ausente ou inválido SHALL responder **401** antes de
invocar o use case. O endpoint HTTP não adiciona nenhuma regra de negócio.

#### Scenario: Casal com despesas recebe a união ordenada

- **WHEN** `GET /v1/pair/expenses` é requisitado com um Bearer token válido e a pessoa está em um
  par vivo com despesas
- **THEN** o sistema responde `200 OK` com um array de despesas, cada uma com `perspective` (`mine`
  ou `theirs`), ordenada por `occurred_on` descendente

#### Scenario: Casal sem despesas recebe array vazio

- **WHEN** `GET /v1/pair/expenses` é requisitado com um Bearer token válido, a pessoa está em um
  par vivo, mas nenhum parceiro tem despesas vivas
- **THEN** o sistema responde `200 OK` com um array vazio

#### Scenario: Pessoa não emparelhada recebe 404

- **WHEN** `GET /v1/pair/expenses` é requisitado por uma pessoa que não está em nenhum par vivo
- **THEN** o sistema responde `404` no envelope unificado

#### Scenario: Request não autenticado é rejeitado

- **WHEN** `GET /v1/pair/expenses` é requisitado sem um header `Authorization: Bearer <token>` válido
- **THEN** o sistema responde `401` no envelope unificado antes de invocar o use case
