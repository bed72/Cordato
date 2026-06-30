## ADDED Requirements

### Requirement: Orçamento do casal é acessível via HTTP

O sistema SHALL expor o comportamento existente de visão de orçamento do casal como
`GET /v1/pair/budget`. O endpoint SHALL resolver a pessoa atuante via `CurrentPersonProvider`,
invocar o `GetCoupleBudgetUseCase` inalterado com `day = today`, e:

- Quando o use case retorna `CoupleBudgetData`: responder **200 OK** com o panorama combinado —
  carregando `start_date`, `end_date`, `amount`, `total_spent`, e `remaining`.
- Quando o use case retorna `None` (par vivo, mas nenhum parceiro tem orçamento ativo hoje):
  responder **200 OK** com corpo `null`.
- Quando o use case lança `NotPairedError`: `PAIRING_STATUS_ERROR` mapeia para **404** no
  envelope unificado.

O endpoint SHALL exigir autenticação (`Authorization: Bearer <token>`); um token ausente ou
inválido SHALL responder **401** antes de invocar o use case. O tipo de retorno do handler é
`CoupleBudgetResponse | None`; Litestar serializa `None` como `null`. O endpoint HTTP não adiciona
nenhuma regra de negócio.

#### Scenario: Casal com orçamentos ativos recebe o panorama combinado

- **WHEN** `GET /v1/pair/budget` é requisitado com um Bearer token válido e pelo menos um parceiro
  tem orçamento ativo hoje
- **THEN** o sistema responde `200 OK` com o panorama combinado (`start_date`, `end_date`, `amount`,
  `total_spent`, `remaining`)

#### Scenario: Casal sem orçamento ativo recebe 200 com null

- **WHEN** `GET /v1/pair/budget` é requisitado com um Bearer token válido, a pessoa está em um par
  vivo, mas nenhum parceiro tem orçamento ativo hoje
- **THEN** o sistema responde `200 OK` com corpo `null`

#### Scenario: Pessoa não emparelhada recebe 404

- **WHEN** `GET /v1/pair/budget` é requisitado por uma pessoa que não está em nenhum par vivo
- **THEN** o sistema responde `404` no envelope unificado

#### Scenario: Request não autenticado é rejeitado

- **WHEN** `GET /v1/pair/budget` é requisitado sem um header `Authorization: Bearer <token>` válido
- **THEN** o sistema responde `401` no envelope unificado antes de invocar o use case
