## ADDED Requirements

### Requirement: Aceitar invite code é acessível via HTTP

O sistema SHALL expor o comportamento existente de aceite de invite code como
`POST /v1/invites/{code}/accept`, onde `{code}` é o token do invite no path. Não há body — o token
já está na URL. O endpoint SHALL resolver a pessoa atuante via `CurrentPersonProvider` (o aceitante),
invocar o `AcceptInviteCodeUseCase` inalterado, e responder **201 Created** com os dados do par
criado — carregando `pair_id`, `person_a_id`, `person_b_id`, e `paired_since`. O endpoint SHALL
exigir autenticação (`Authorization: Bearer <token>`); um token ausente ou inválido SHALL responder
**401** no envelope unificado antes de invocar o use case. Os erros de domínio
(`InviteCodeNotFoundError`, `InviteCodeExpiredError`, `InviteCodeAlreadyConsumedError`,
`InviteCodeRevokedError`, `AlreadyPairedError`, `SelfPairingError`, `PersonNotActiveError`) SHALL ser
mapeados pelo `PAIRING_STATUS_ERROR` no envelope unificado. O endpoint HTTP não adiciona nenhuma
regra de negócio.

#### Scenario: Aceitante autenticado forma o par com sucesso

- **WHEN** `POST /v1/invites/{code}/accept` é requisitado por uma pessoa ativa com um Bearer token
  válido e o invite é válido para resgate
- **THEN** o sistema responde `201 Created` com os dados do par criado (`pair_id`, `person_a_id`,
  `person_b_id`, `paired_since`)

#### Scenario: Invite expirado retorna 409

- **WHEN** `POST /v1/invites/{code}/accept` é requisitado e o invite está expirado
- **THEN** o sistema responde `409` no envelope unificado

#### Scenario: Aceitante já em par retorna 409

- **WHEN** `POST /v1/invites/{code}/accept` é requisitado por uma pessoa que já está em um par vivo
- **THEN** o sistema responde `409` no envelope unificado

#### Scenario: Token desconhecido retorna 404

- **WHEN** `POST /v1/invites/{code}/accept` é requisitado com um token que não existe
- **THEN** o sistema responde `404` no envelope unificado

#### Scenario: Request não autenticado é rejeitado

- **WHEN** `POST /v1/invites/{code}/accept` é requisitado sem um header `Authorization: Bearer <token>` válido
- **THEN** o sistema responde `401` no envelope unificado antes de invocar o use case
