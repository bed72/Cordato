## MODIFIED Requirements

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
- **AND** o sistema responde `200 OK` com a visão pública atualizada da pessoa (id, nome, e-mail)

#### Scenario: Requisição sem sessão viva é recusada pelo guard

- **WHEN** o endpoint é acessado sem `Authorization: Bearer`, ou com um token ausente/inválido/expirado/revogado
- **THEN** o guard de borda recusa com o `401` neutro compartilhado **antes** de o handler rodar
- **AND** o use case de atualização não é invocado

## ADDED Requirements

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
- **AND** o sistema responde `200 OK` com a visão pública atualizada da pessoa (id, nome, e-mail)

#### Scenario: Requisição sem sessão viva é recusada pelo guard

- **WHEN** o endpoint é acessado sem `Authorization: Bearer`, ou com um token ausente/inválido/expirado/revogado
- **THEN** o guard de borda recusa com o `401` neutro compartilhado **antes** de o handler rodar
- **AND** o use case de troca não é invocado

### Requirement: Validação de borda do request de troca de e-mail

O sistema SHALL validar o corpo da requisição de troca de e-mail na borda HTTP, com Bean Validation, antes de
invocar o use case. O corpo SHALL estar presente e ser JSON válido; o campo `email` SHALL estar presente e no
formato válido, e o campo `password` SHALL estar presente. Toda requisição que falhe qualquer uma dessas
checagens SHALL ser recusada com `400 Bad Request`, no corpo de erro compartilhado definido pela capability
`http-error-handling`, **sem** invocar o use case. Quando mais de um campo violar suas restrições na mesma
requisição, a resposta SHALL reportar cada campo violado como um item da lista `errors`.

A restrição de formato do `email` no request SHALL referenciar a **mesma** definição do `EmailValueObject`
(seu padrão público `PATTERN`), de modo que a checagem de borda não possa divergir da regra de domínio. O
value object permanece a autoridade única da invariante — a validação de borda é uma checagem antecipada e
propositalmente igual ou mais estrita (por validar o valor cru, antes da normalização que o value object
aplica), nunca uma segunda regra independente. A borda SHALL NOT aplicar política de senha ao campo
`password` (a confirmação apenas confere a senha guardada; travar por política aqui recusaria uma senha
legítima definida antes de uma mudança de política) — valida **apenas** sua presença.

#### Scenario: Corpo ausente ou não-JSON

- **WHEN** o endpoint recebe uma requisição sem corpo ou com JSON inválido
- **THEN** o sistema responde `400 Bad Request`
- **AND** o use case de troca não é invocado

#### Scenario: Campo obrigatório ausente ou e-mail malformado

- **WHEN** o corpo não contém `email` ou `password`, ou traz um `email` em formato inválido
- **THEN** o sistema responde `400 Bad Request` no corpo de erro compartilhado
- **AND** o use case de troca não é invocado

#### Scenario: Restrição de borda não diverge do domínio

- **WHEN** a restrição de formato do `email` no request espelha a regra de domínio
- **THEN** ela referencia o mesmo padrão público do `EmailValueObject`, não um literal duplicado

#### Scenario: A borda não aplica política de senha

- **WHEN** o corpo traz uma `password` presente porém curta ou fraca
- **THEN** a borda **não** recusa por política de senha — ela repassa ao use case
- **AND** a única recusa possível por senha é o `401` neutro de confirmação incorreta, não um `400` por campo

### Requirement: Resposta de sucesso da troca de e-mail não vaza a senha

O sistema SHALL responder uma troca de e-mail bem-sucedida com uma representação da pessoa contendo ao menos
seu identificador, nome e e-mail (atualizado). A resposta SHALL NOT conter a senha (digitada ou de
confirmação) nem o hash da senha, sob nenhuma forma — reutilizando a **mesma** representação pública de pessoa
que o cadastro, o `GET /persons/me` e a troca de nome devolvem.

#### Scenario: Corpo de sucesso omite qualquer material de senha

- **WHEN** a troca é bem-sucedida e o sistema serializa a pessoa
- **THEN** o corpo contém o identificador, o nome e o e-mail atualizado da pessoa
- **AND** o corpo não contém a senha nem o hash da senha

### Requirement: E-mail inválido na troca responde 422

O sistema SHALL ramificar exaustivamente sobre o resultado do use case de troca (um tipo `sealed`) sem
depender de exceções lançadas, e SHALL mapear a falha de e-mail inválido (`InvalidEmail`) para `422
Unprocessable Entity` no corpo de erro neutro e compartilhado. Nenhum e-mail é alterado nesse caso.

#### Scenario: E-mail rejeitado pelo domínio responde 422

- **WHEN** o use case de troca retorna `InvalidEmail`
- **THEN** o sistema responde `422 Unprocessable Entity` com um corpo de erro neutro
- **AND** o e-mail da pessoa permanece inalterado

### Requirement: O conflito de e-mail na troca não vaza a existência de conta

O sistema SHALL mapear o erro `EmailAlreadyInUse` da troca para uma resposta que NÃO permita distinguir, de
fora, que aquele e-mail já pertence a outra pessoa. A resposta SHALL usar um `422 Unprocessable Entity`
genérico — o **mesmo status** das demais recusas de domínio da troca (`InvalidEmail`), de modo que o status
não sinalize qual recusa ocorreu —, SHALL NOT ecoar o e-mail tentado nem qualquer dado da pessoa existente,
SHALL NOT ser um `FieldError(field="email")`, e sua mensagem SHALL ser redigida de modo genérico. O conflito
SHALL NOT receber um status distinto (por exemplo `409`) que o diferencie das demais recusas — isso
reintroduziria o oráculo de descoberta de conta pela linha de status.

#### Scenario: Conflito de e-mail responde de forma neutra

- **WHEN** o use case de troca retorna `EmailAlreadyInUse`
- **THEN** o sistema responde `422 Unprocessable Entity` com um corpo de erro genérico e escalar
- **AND** o corpo não contém o e-mail tentado nem qualquer dado da pessoa existente
- **AND** a resposta não é um erro por campo (`field="email"`) nem um status distinto das demais recusas

### Requirement: Senha incorreta e sessão órfã na troca respondem 401 neutro indistinguível

O sistema SHALL mapear tanto a falha de confirmação de senha (`InvalidCredentials`) quanto a falha de sessão
órfã (`PersonNotFound`) do use case de troca para o **mesmo `401` neutro compartilhado** (code
`UNAUTHENTICATED`, mesma mensagem localizada por chave que o guard de borda usa). Essas duas respostas SHALL
ser **indistinguíveis** entre si e da recusa por token ausente/inválido/expirado, e SHALL NOT revelar qual
foi a causa (senha incorreta, ou pessoa inexistente/não-ativa) nem ecoar qualquer identificador.

#### Scenario: Senha de confirmação incorreta responde 401 genérico

- **WHEN** o use case de troca retorna `InvalidCredentials`
- **THEN** o sistema responde `401` no corpo de erro compartilhado com code `UNAUTHENTICATED`
- **AND** a resposta é indistinguível da recusa de um token ausente ou inválido e da falha por sessão órfã

#### Scenario: Sessão órfã responde 401 genérico

- **WHEN** o use case de troca retorna `PersonNotFound` para uma sessão viva cuja pessoa não está mais ativa
- **THEN** o sistema responde `401` no corpo de erro compartilhado com code `UNAUTHENTICATED`
- **AND** o corpo não indica que a causa foi uma pessoa inexistente/não-ativa
