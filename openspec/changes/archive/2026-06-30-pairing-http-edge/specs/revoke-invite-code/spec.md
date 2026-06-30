## ADDED Requirements

### Requirement: Revogar invite code é acessível via HTTP

O sistema SHALL expor o comportamento existente de revogação de invite code como
`DELETE /v1/invites/{code}` onde `{code}` é o token do invite. O endpoint SHALL resolver a pessoa
atuante via `CurrentPersonProvider`, invocar o `RevokeInviteCodeUseCase` inalterado, e responder
**204 No Content** sem corpo em caso de sucesso. O endpoint SHALL exigir autenticação
(`Authorization: Bearer <token>`); um token ausente ou inválido SHALL responder **401** no envelope
unificado antes de invocar o use case. Os erros de domínio (`InviteCodeNotFoundError`,
`InviteCodeAlreadyConsumedError`) SHALL ser mapeados pelo `PAIRING_STATUS_ERROR` no envelope
unificado — sem leakage do framework. O endpoint HTTP não adiciona nenhuma regra de negócio.

#### Scenario: Criador revoga seu invite code com sucesso

- **WHEN** `DELETE /v1/invites/{code}` é requisitado pela pessoa que criou o invite, com um token
  válido e o invite está em estado revogável
- **THEN** o sistema responde `204 No Content` sem corpo

#### Scenario: Token desconhecido ou não pertencente ao criador retorna 404

- **WHEN** `DELETE /v1/invites/{code}` é requisitado com um token que não existe ou que não pertence
  à pessoa atuante
- **THEN** o sistema responde `404` no envelope unificado

#### Scenario: Invite já consumido retorna 409

- **WHEN** `DELETE /v1/invites/{code}` é requisitado para um invite cujo `consumed_at` está definido
- **THEN** o sistema responde `409` no envelope unificado

#### Scenario: Request não autenticado é rejeitado

- **WHEN** `DELETE /v1/invites/{code}` é requisitado sem um header `Authorization: Bearer <token>` válido
- **THEN** o sistema responde `401` no envelope unificado antes de invocar o use case
