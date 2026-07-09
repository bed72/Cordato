## ADDED Requirements

### Requirement: Rota protegida troca a senha da pessoa autenticada

O sistema SHALL expor uma rota HTTP protegida `PATCH /persons/me/password` que delega ao caso de uso de troca
de senha, usando o `personId` **e o `sessionId`** do ator autenticado resolvido pela borda — nunca dados do
corpo — como identidade. A rota SHALL exigir uma sessão viva (via o guard de borda declarativo); sem um
`Authorization: Bearer` válido, o handler SHALL NOT ser alcançado. Em caso de sucesso, SHALL responder
`200 OK` com a `PersonResponse` (a mesma visão pública reutilizada pelas demais rotas de pessoa).

#### Scenario: Troca autenticada com senhas válidas responde 200

- **WHEN** uma requisição autenticada envia a senha atual correta e uma nova senha válida e diferente da atual
- **THEN** o sistema responde `200 OK` com a `PersonResponse` (id, nome, e-mail), sem material de senha

### Requirement: Validação de borda do request de troca de senha

O sistema SHALL validar o corpo de `PATCH /persons/me/password` na borda antes do caso de uso. A `senha
atual` (`currentPassword`) SHALL ser validada apenas quanto à **presença** (`@NotBlank`) — a borda SHALL NOT
aplicar política à senha de confirmação, que apenas confere o hash. A `nova senha` (`newPassword`) SHALL ser
validada quanto à **presença e ao tamanho mínimo**, referenciando a constante do próprio value object
(`PasswordValueObject.MIN_LENGTH`), nunca um literal duplicado. Uma violação de borda SHALL responder `400`
com um erro por campo. O value object SHALL permanecer a autoridade única da política.

#### Scenario: Nova senha abaixo do mínimo responde 400

- **WHEN** uma requisição autenticada envia uma `newPassword` mais curta que `PasswordValueObject.MIN_LENGTH`
- **THEN** o sistema responde `400` com um erro de campo para `newPassword`, sem alcançar o caso de uso

#### Scenario: Senha atual ausente responde 400

- **WHEN** uma requisição autenticada omite ou deixa em branco a `currentPassword`
- **THEN** o sistema responde `400` com um erro de campo para `currentPassword`, sem alcançar o caso de uso

### Requirement: Resposta de sucesso da troca de senha não vaza a senha

O sistema SHALL garantir que a resposta `200` da troca de senha carregue apenas a visão pública da pessoa
(identificador, nome, e-mail) e **nenhum** material de senha — nem a senha atual, nem a nova, nem o hash.

#### Scenario: Corpo de sucesso não contém material de senha

- **WHEN** a troca de senha responde `200`
- **THEN** o corpo contém id, nome e e-mail
- **AND** o corpo não contém nenhuma senha nem hash

### Requirement: Nova senha fraca ou igual à atual responde 422

O sistema SHALL mapear a rejeição de domínio de uma nova senha fraca (`WeakPassword`) e de uma nova senha
igual à atual (`SamePassword`) a `422`. Por serem regras **públicas** (não vazam a existência de conta de
ninguém), essas respostas PODEM ter código e mensagem específicos. Ambas SHALL compartilhar o **mesmo
status** `422`, de modo que o status nunca delate qual das duas ocorreu, coerente com o split `400`/`422` por
tipo de falha.

#### Scenario: Nova senha rejeitada pela política responde 422

- **WHEN** o caso de uso rejeita a nova senha por violar a política (`WeakPassword`)
- **THEN** o sistema responde `422` com um código/mensagem específicos da senha fraca

#### Scenario: Nova senha igual à atual responde 422

- **WHEN** o caso de uso rejeita a nova senha por coincidir com a atual (`SamePassword`)
- **THEN** o sistema responde `422` com um código/mensagem específicos de senha igual

### Requirement: Senha atual incorreta e sessão órfã na troca respondem 401 neutro indistinguível

O sistema SHALL mapear tanto a senha atual incorreta (`InvalidCredentials`) quanto a sessão órfã
(`PersonNotFound`) na troca de senha à **mesma** resposta `401` neutra (código `UNAUTHENTICATED`, mensagem por
chave de i18n) que o guard de borda emite para um token ausente/inválido/expirado. As duas falhas SHALL ser
indistinguíveis entre si e de uma sessão ausente — nem o status nem o corpo SHALL revelar qual fator falhou.

#### Scenario: Senha atual incorreta responde 401 neutro

- **WHEN** o caso de uso rejeita a troca por senha atual incorreta (`InvalidCredentials`)
- **THEN** o sistema responde `401` com o corpo neutro compartilhado, sem revelar que a senha estava errada

#### Scenario: Sessão órfã responde o mesmo 401 neutro

- **WHEN** o caso de uso rejeita a troca por a pessoa não estar mais ativa (`PersonNotFound`)
- **THEN** o sistema responde `401` com o **mesmo** corpo neutro, indistinguível do caso de senha incorreta e de uma sessão ausente
