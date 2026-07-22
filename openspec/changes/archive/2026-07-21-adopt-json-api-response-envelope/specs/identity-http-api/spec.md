## MODIFIED Requirements

### Requirement: Endpoint de cadastro expõe o SignUpUseCase

O sistema SHALL expor a operação de cadastro de pessoa por um endpoint HTTP `POST /sign-up` que aceita um
corpo JSON com `name`, `email` e `password`. O endpoint SHALL delegar a decisão de negócio ao
`SignUpUseCase` existente — construindo um `SignUpCommand` a partir do corpo — e SHALL NOT reimplementar
nenhuma regra de domínio de cadastro.

#### Scenario: Cadastro bem-sucedido responde 201

- **WHEN** o endpoint recebe um corpo com um e-mail não usado, um nome válido e uma senha que cumpre a política
- **THEN** o `SignUpUseCase` é invocado com um `SignUpCommand` correspondente ao corpo
- **AND** o sistema responde `201 Created` com `data` contendo o corpo de pessoa criada

#### Scenario: A controller não valida regras de domínio

- **WHEN** o corpo é estruturalmente válido (campos presentes e do tipo esperado)
- **THEN** a controller repassa os valores ao `SignUpUseCase` sem verificar formato de e-mail, validade de nome ou política de senha
- **AND** qualquer recusa por essas regras vem do resultado do use case, não da camada HTTP

### Requirement: Resposta de sucesso não vaza a senha

O sistema SHALL responder um cadastro bem-sucedido com `data` contendo uma representação da pessoa criada
com ao menos seu identificador, nome e e-mail. `data` SHALL NOT conter a senha digitada nem o hash da senha,
sob nenhuma forma.

#### Scenario: Corpo de sucesso omite qualquer material de senha

- **WHEN** o cadastro é bem-sucedido e o sistema serializa a pessoa criada
- **THEN** `data` contém o identificador, o nome e o e-mail da pessoa
- **AND** `data` não contém a senha digitada nem o hash da senha

### Requirement: Endpoint de login expõe o SignInUseCase

O sistema SHALL expor a operação de login por um endpoint HTTP `POST /sign-in` que aceita um corpo JSON com
`email` e `password`. O endpoint SHALL delegar a decisão de negócio ao `SignInUseCase` — construindo um
`SignInCommand` a partir do corpo — e SHALL NOT reimplementar nenhuma regra de autenticação na camada HTTP.

#### Scenario: Login bem-sucedido responde 200

- **WHEN** o endpoint recebe um corpo com as credenciais de uma pessoa ativa e senha correta
- **THEN** o `SignInUseCase` é invocado com um `SignInCommand` correspondente ao corpo
- **AND** o sistema responde `200 OK` com `data` contendo o corpo de sessão criada

#### Scenario: A controller não decide autenticação

- **WHEN** o corpo é estruturalmente válido (campos presentes)
- **THEN** a controller repassa os valores ao `SignInUseCase` sem verificar existência de conta, senha ou status
- **AND** qualquer recusa vem do resultado do use case, não da camada HTTP

### Requirement: Resposta de sucesso do login devolve o token e a expiração

O sistema SHALL responder um login bem-sucedido com `data` contendo o **token opaco** em claro e o instante
de **expiração** da sessão (`{ token, expiresAt }`). `data` SHALL NOT conter a senha digitada, o hash da
senha, nem o hash do token.

#### Scenario: Corpo de sucesso traz token e expiração

- **WHEN** o login é bem-sucedido e o sistema serializa a sessão criada
- **THEN** `data` contém o token opaco em claro e o instante de expiração
- **AND** `data` não contém a senha, o hash da senha, nem o hash do token

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
- **AND** o sistema responde `200 OK` com `data` contendo a visão pública da pessoa (id, nome, e-mail)

#### Scenario: Requisição sem sessão viva é recusada pelo guard

- **WHEN** o endpoint é acessado sem `Authorization: Bearer`, ou com um token ausente/inválido/expirado/revogado
- **THEN** o guard de borda recusa com o `401` neutro compartilhado **antes** de o handler rodar
- **AND** o `MeUseCase` não é invocado

### Requirement: Resposta de sucesso da pessoa autenticada não vaza a senha

O sistema SHALL responder a rota da pessoa autenticada com `data` contendo uma representação com ao menos
seu identificador, nome e e-mail. `data` SHALL NOT conter a senha nem o hash da senha, sob nenhuma forma —
reutilizando a mesma representação pública de pessoa que o cadastro devolve.

#### Scenario: Corpo de sucesso omite qualquer material de senha

- **WHEN** a rota responde com sucesso e o sistema serializa a pessoa
- **THEN** `data` contém o identificador, o nome e o e-mail da pessoa
- **AND** `data` não contém a senha nem o hash da senha

### Requirement: Rota protegida atualiza o nome da pessoa autenticada

O sistema SHALL expor a atualização do próprio nome por um endpoint HTTP **`PATCH /persons/me/name`**,
declarado **protegido** (`@Authenticated`), que SHALL exigir uma sessão viva antes de executar o handler. O
endpoint SHALL aceitar um corpo JSON com `name`, SHALL obter a identidade do chamador do **ator autenticado**
resolvido pelo guard de borda (o `personId`), e SHALL delegar a decisão ao use case de atualização de nome —
construindo o comando a partir do `personId` do ator e do `name` do corpo. O endpoint SHALL NOT reler a
sessão, o token, nem reimplementar autenticação, e SHALL NOT permitir alterar o nome de outra pessoa que não
a autenticada. O path é um **sub-recurso de campo único** (`/persons/me/name`), simétrico ao da troca de
e-mail (`/persons/me/email`), não um `PATCH /persons/me` de patch parcial multi-campo.

#### Scenario: Requisição autenticada com nome válido responde 200

- **WHEN** o endpoint recebe, numa sessão viva, um corpo com um nome que satisfaz as restrições de borda
- **THEN** o use case de atualização é invocado com o `personId` do ator autenticado e o nome do corpo
- **AND** o sistema responde `200 OK` com `data` contendo a visão pública atualizada da pessoa (id, nome, e-mail)

#### Scenario: Requisição sem sessão viva é recusada pelo guard

- **WHEN** o endpoint é acessado sem `Authorization: Bearer`, ou com um token ausente/inválido/expirado/revogado
- **THEN** o guard de borda recusa com o `401` neutro compartilhado **antes** de o handler rodar
- **AND** o use case de atualização não é invocado

### Requirement: Resposta de sucesso da atualização não vaza a senha

O sistema SHALL responder uma atualização de nome bem-sucedida com `data` contendo uma representação da
pessoa com ao menos seu identificador, nome (atualizado) e e-mail. `data` SHALL NOT conter a senha nem o
hash da senha, sob nenhuma forma — reutilizando a **mesma** representação pública de pessoa que o cadastro e
o `GET /persons/me` devolvem.

#### Scenario: Corpo de sucesso omite qualquer material de senha

- **WHEN** a atualização é bem-sucedida e o sistema serializa a pessoa
- **THEN** `data` contém o identificador, o nome atualizado e o e-mail da pessoa
- **AND** `data` não contém a senha nem o hash da senha

### Requirement: Rota protegida troca o e-mail da pessoa autenticada

O sistema SHALL expor a troca do próprio e-mail por um endpoint HTTP **`PATCH /persons/me/email`**, declarado
**protegido** (`@Authenticated`), que SHALL exigir uma sessão viva antes de executar o handler. O endpoint
SHALL aceitar um corpo JSON com `email` e `password` (a senha atual, para confirmação), SHALL obter a
identidade do chamador do **ator autenticado** resolvido pelo guard de borda (o `personId`), e SHALL delegar
a decisão ao use case de troca de e-mail — construindo o comando a partir do `personId` do ator e do `email`
e `password` do corpo. O endpoint SHALL NOT reler a sessão, o token, nem reimplementar autenticação, e SHALL
NOT permitir alterar o e-mail de outra pessoa que não a autenticada.

#### Scenario: Requisição autenticada com e-mail e senha válidos responde 200

- **WHEN** o endpoint recebe, numa sessão viva, um corpo com um e-mail e uma senha que satisfazem as restrições de borda
- **THEN** o use case de troca é invocado com o `personId` do ator autenticado, o e-mail e a senha do corpo
- **AND** o sistema responde `200 OK` com `data` contendo a visão pública atualizada da pessoa (id, nome, e-mail)

#### Scenario: Requisição sem sessão viva é recusada pelo guard

- **WHEN** o endpoint é acessado sem `Authorization: Bearer`, ou com um token ausente/inválido/expirado/revogado
- **THEN** o guard de borda recusa com o `401` neutro compartilhado **antes** de o handler rodar
- **AND** o use case de troca não é invocado

### Requirement: Resposta de sucesso da troca de e-mail não vaza a senha

O sistema SHALL responder uma troca de e-mail bem-sucedida com `data` contendo uma representação da pessoa
com ao menos seu identificador, nome e e-mail (atualizado). `data` SHALL NOT conter a senha (digitada ou de
confirmação) nem o hash da senha, sob nenhuma forma — reutilizando a **mesma** representação pública de
pessoa que o cadastro, o `GET /persons/me` e a troca de nome devolvem.

#### Scenario: Corpo de sucesso omite qualquer material de senha

- **WHEN** a troca é bem-sucedida e o sistema serializa a pessoa
- **THEN** `data` contém o identificador, o nome e o e-mail atualizado da pessoa
- **AND** `data` não contém a senha nem o hash da senha

### Requirement: Rota protegida troca a senha da pessoa autenticada

O sistema SHALL expor uma rota HTTP protegida `PATCH /persons/me/password` que delega ao caso de uso de troca
de senha, usando o `personId` **e o `sessionId`** do ator autenticado resolvido pela borda — nunca dados do
corpo — como identidade. A rota SHALL exigir uma sessão viva (via o guard de borda declarativo); sem um
`Authorization: Bearer` válido, o handler SHALL NOT ser alcançado. Em caso de sucesso, SHALL responder
`200 OK` com `data` contendo a `PersonResponse` (a mesma visão pública reutilizada pelas demais rotas de
pessoa).

#### Scenario: Troca autenticada com senhas válidas responde 200

- **WHEN** uma requisição autenticada envia a senha atual correta e uma nova senha válida e diferente da atual
- **THEN** o sistema responde `200 OK` com `data` contendo a `PersonResponse` (id, nome, e-mail), sem material de senha

### Requirement: Resposta de sucesso da troca de senha não vaza a senha

O sistema SHALL garantir que `data` na resposta `200` da troca de senha carregue apenas a visão pública da
pessoa (identificador, nome, e-mail) e **nenhum** material de senha — nem a senha atual, nem a nova, nem o
hash.

#### Scenario: Corpo de sucesso não contém material de senha

- **WHEN** a troca de senha responde `200`
- **THEN** `data` contém id, nome e e-mail
- **AND** `data` não contém nenhuma senha nem hash
