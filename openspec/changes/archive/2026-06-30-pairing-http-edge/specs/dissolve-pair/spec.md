## ADDED Requirements

### Requirement: Dissolver par é acessível via HTTP

O sistema SHALL expor o comportamento existente de dissolução de par como `DELETE /v1/pair`. O
endpoint SHALL resolver a pessoa atuante via `CurrentPersonProvider`, invocar o
`DissolvePairUseCase` inalterado, e responder **204 No Content** sem corpo em caso de sucesso.
`NotPairedError` (quando a pessoa não está em nenhum par vivo) SHALL ser mapeado pelo
`PAIRING_STATUS_ERROR` para **404** no envelope unificado. O endpoint SHALL exigir autenticação
(`Authorization: Bearer <token>`); um token ausente ou inválido SHALL responder **401** antes de
invocar o use case. O endpoint HTTP não adiciona nenhuma regra de negócio.

#### Scenario: Membro do par dissolve com sucesso

- **WHEN** `DELETE /v1/pair` é requisitado por uma pessoa que está em um par vivo com um Bearer
  token válido
- **THEN** o sistema responde `204 No Content` sem corpo e o par é soft-deletado

#### Scenario: Pessoa não emparelhada recebe 404

- **WHEN** `DELETE /v1/pair` é requisitado por uma pessoa que não está em nenhum par vivo
- **THEN** o sistema responde `404` no envelope unificado

#### Scenario: Request não autenticado é rejeitado

- **WHEN** `DELETE /v1/pair` é requisitado sem um header `Authorization: Bearer <token>` válido
- **THEN** o sistema responde `401` no envelope unificado antes de invocar o use case
