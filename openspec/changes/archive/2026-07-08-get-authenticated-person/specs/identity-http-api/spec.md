## ADDED Requirements

### Requirement: Rota protegida expõe a pessoa autenticada

O sistema SHALL expor a recuperação da pessoa autenticada por um endpoint HTTP **`GET /persons/me`**,
declarado **protegido** (`@Authenticated`), que SHALL exigir uma sessão viva antes de executar o handler. O
endpoint SHALL obter a identidade do chamador do **ator autenticado** resolvido pelo guard de borda (o
`personId`), SHALL delegar a decisão ao `MeUseCase` — construindo o comando a partir do `personId` — e SHALL
NOT reler a sessão, o token, nem reimplementar autenticação na camada HTTP. O endpoint SHALL NOT aceitar
corpo de requisição.

#### Scenario: Requisição autenticada responde 200 com a pessoa

- **WHEN** o endpoint recebe uma requisição numa sessão viva
- **THEN** o `MeUseCase` é invocado com o `personId` do ator autenticado
- **AND** o sistema responde `200 OK` com a visão pública da pessoa (id, nome, e-mail)

#### Scenario: Requisição sem sessão viva é recusada pelo guard

- **WHEN** o endpoint é acessado sem `Authorization: Bearer`, ou com um token ausente/inválido/expirado/revogado
- **THEN** o guard de borda recusa com o `401` neutro compartilhado **antes** de o handler rodar
- **AND** o `MeUseCase` não é invocado

### Requirement: Resposta de sucesso não vaza a senha

O sistema SHALL responder a rota da pessoa autenticada com uma representação contendo ao menos seu
identificador, nome e e-mail. A resposta SHALL NOT conter a senha nem o hash da senha, sob nenhuma forma —
reutilizando a mesma representação pública de pessoa que o cadastro devolve.

#### Scenario: Corpo de sucesso omite qualquer material de senha

- **WHEN** a rota responde com sucesso e o sistema serializa a pessoa
- **THEN** o corpo contém o identificador, o nome e o e-mail da pessoa
- **AND** o corpo não contém a senha nem o hash da senha

### Requirement: Sessão órfã responde 401 neutro indistinguível

O sistema SHALL ramificar exaustivamente sobre o `MeResult` (um tipo `sealed`) sem depender de exceções, e
SHALL mapear a falha `PersonNotFound` para o **`401` neutro compartilhado** (code `UNAUTHENTICATED`, mesma
mensagem localizada por chave que o guard de borda usa). Essa resposta SHALL ser **indistinguível** da
recusa por token ausente/inválido/expirado, e SHALL NOT revelar que a sessão apontava para uma pessoa
inexistente ou não-ativa, nem ecoar qualquer identificador.

#### Scenario: Sessão órfã responde 401 genérico

- **WHEN** o `MeUseCase` retorna `PersonNotFound` para uma sessão viva cuja pessoa não está mais ativa
- **THEN** o sistema responde `401` no corpo de erro compartilhado com code `UNAUTHENTICATED`
- **AND** a resposta é indistinguível da recusa de um token ausente ou inválido
- **AND** o corpo não indica que a causa foi uma pessoa inexistente/não-ativa
