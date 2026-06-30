## ADDED Requirements

### Requirement: Obter par atual é acessível via HTTP

O sistema SHALL expor o comportamento existente de leitura do par atual como `GET /v1/pair`. O
endpoint SHALL resolver a pessoa atuante via `CurrentPersonProvider`, invocar o
`GetCurrentPairUseCase` inalterado, e responder **200 OK** com os dados do par — carregando
`pair_id`, `partner_id`, `partner_name`, e `paired_since`. Quando o use case retorna `None`
(a pessoa não está em nenhum par vivo), o controller SHALL converter o `None` em
`NotPairedError`, que o `PAIRING_STATUS_ERROR` mapeia para **404** no envelope unificado. O
endpoint SHALL exigir autenticação (`Authorization: Bearer <token>`); um token ausente ou inválido
SHALL responder **401** antes de invocar o use case. O endpoint HTTP não adiciona nenhuma regra
de negócio.

#### Scenario: Pessoa autenticada em par recebe os dados do par

- **WHEN** `GET /v1/pair` é requisitado com um Bearer token válido e a pessoa está em um par vivo
- **THEN** o sistema responde `200 OK` com os dados do par (`pair_id`, `partner_id`, `partner_name`,
  `paired_since`)

#### Scenario: Pessoa não emparelhada recebe 404

- **WHEN** `GET /v1/pair` é requisitado com um Bearer token válido e a pessoa não está em nenhum
  par vivo
- **THEN** o sistema responde `404` no envelope unificado

#### Scenario: Request não autenticado é rejeitado

- **WHEN** `GET /v1/pair` é requisitado sem um header `Authorization: Bearer <token>` válido
- **THEN** o sistema responde `401` no envelope unificado antes de invocar o use case
