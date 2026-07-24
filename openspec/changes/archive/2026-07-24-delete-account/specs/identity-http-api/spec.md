## ADDED Requirements

### Requirement: Rota protegida apaga a conta da pessoa autenticada

O sistema SHALL expor a exclusão da própria conta por um endpoint HTTP **`DELETE /persons/me`**, declarado
**protegido** (`@Authenticated`), que SHALL exigir uma sessão viva antes de executar o handler. O endpoint
SHALL aceitar um corpo JSON com `password` (a senha atual, para confirmação), SHALL obter a identidade do
chamador do **ator autenticado** resolvido pelo guard de borda (o `personId`), e SHALL delegar a decisão ao
use case de exclusão de conta — construindo o comando a partir do `personId` do ator e da `password` do
corpo. O endpoint SHALL NOT reler a sessão ou o token, SHALL NOT reimplementar autenticação, e SHALL NOT
permitir apagar a conta de outra pessoa que não a autenticada.

#### Scenario: Requisição autenticada com senha correta responde sem corpo

- **WHEN** o endpoint recebe, numa sessão viva, um corpo com a senha atual correta
- **THEN** o use case de exclusão de conta é invocado com o `personId` do ator autenticado e a senha do
  corpo
- **AND** o sistema responde `204 No Content`, sem corpo

#### Scenario: Requisição sem sessão viva é recusada pelo guard

- **WHEN** o endpoint é acessado sem `Authorization: Bearer`, ou com um token ausente/inválido/expirado/revogado
- **THEN** o guard de borda recusa com o `401` neutro compartilhado **antes** de o handler rodar
- **AND** o use case de exclusão de conta não é invocado

### Requirement: Validação de borda do request de exclusão de conta é apenas de presença

O sistema SHALL validar o corpo da requisição de exclusão de conta na borda HTTP, com Bean Validation, antes
de invocar o use case. O corpo SHALL estar presente e ser JSON válido, e o campo `password` SHALL estar
presente. Toda requisição que falhe qualquer uma dessas checagens SHALL ser recusada com `400 Bad Request`,
no corpo de erro compartilhado definido pela capability `http-error-handling`, **sem** invocar o use case. A
borda SHALL NOT aplicar política de senha ao campo `password` (a confirmação apenas confere a senha
guardada) — valida **apenas** sua presença, mesma postura já adotada pela troca de e-mail e pela troca de
senha.

#### Scenario: Corpo ausente ou não-JSON

- **WHEN** o endpoint recebe uma requisição sem corpo ou com JSON inválido
- **THEN** o sistema responde `400 Bad Request`
- **AND** o use case de exclusão de conta não é invocado

#### Scenario: Campo `password` ausente

- **WHEN** o corpo não contém `password`
- **THEN** o sistema responde `400 Bad Request` no corpo de erro compartilhado
- **AND** o use case de exclusão de conta não é invocado

#### Scenario: A borda não aplica política de senha

- **WHEN** o corpo traz uma `password` presente porém curta ou fraca
- **THEN** a borda **não** recusa por política de senha — ela repassa ao use case
- **AND** a única recusa possível por senha é o `401` neutro de confirmação incorreta, não um `400` por campo

### Requirement: Senha incorreta e sessão órfã na exclusão de conta respondem 401 neutro indistinguível

O sistema SHALL ramificar exaustivamente sobre o resultado do use case de exclusão de conta (um tipo
`sealed`) sem depender de exceções lançadas, e SHALL mapear tanto a falha de senha de confirmação incorreta
(`InvalidCredentials`) quanto a falha de sessão órfã (`PersonNotFound`) para o **mesmo `401` neutro
compartilhado** (code `UNAUTHENTICATED`, mesma mensagem localizada por chave que o guard de borda usa). Essa
resposta SHALL ser **indistinguível** da recusa por token ausente/inválido/expirado e da mesma recusa nas
demais operações de `person-profile`, e SHALL NOT revelar qual dos dois fatores falhou. Nenhum efeito da
exclusão SHALL ocorrer nesses casos.

#### Scenario: Senha de confirmação incorreta responde 401 genérico

- **WHEN** o use case de exclusão de conta retorna `InvalidCredentials`
- **THEN** o sistema responde `401` no corpo de erro compartilhado com code `UNAUTHENTICATED`
- **AND** a resposta é indistinguível da recusa por sessão órfã e da recusa de um token ausente ou inválido

#### Scenario: Sessão órfã responde 401 genérico

- **WHEN** o use case de exclusão de conta retorna `PersonNotFound` para uma sessão viva cuja pessoa não
  está mais ativa
- **THEN** o sistema responde `401` no corpo de erro compartilhado com code `UNAUTHENTICATED`
- **AND** a resposta é indistinguível da recusa por senha incorreta e da recusa de um token ausente ou
  inválido
