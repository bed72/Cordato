## ADDED Requirements

### Requirement: Criar invite code é acessível via HTTP

O sistema SHALL expor o comportamento existente de criação de invite code como `POST /v1/invites`. O
endpoint SHALL resolver a pessoa atuante via `CurrentPersonProvider`, invocar o `CreateInviteCodeUseCase`
inalterado, e responder **201 Created** com o invite code criado — carregando `id`, `code`, `creator_id`,
`created_at`, `expires_at`, e `consumed_at` (null). O endpoint SHALL exigir autenticação
(`Authorization: Bearer <token>`); um token ausente ou inválido SHALL responder **401** no envelope
unificado antes de invocar o use case. O endpoint HTTP não adiciona nenhuma regra de negócio — é
transporte sobre o use case.

#### Scenario: Pessoa autenticada recebe o invite code criado

- **WHEN** `POST /v1/invites` é requisitado com um Bearer token válido
- **THEN** o sistema responde `201 Created` com um objeto invite code carregando `id`, `code`,
  `creator_id`, `created_at`, `expires_at`, e `consumed_at` null

#### Scenario: Request não autenticado é rejeitado

- **WHEN** `POST /v1/invites` é requisitado sem um header `Authorization: Bearer <token>` válido
- **THEN** o sistema responde `401` no envelope unificado antes de invocar o use case
