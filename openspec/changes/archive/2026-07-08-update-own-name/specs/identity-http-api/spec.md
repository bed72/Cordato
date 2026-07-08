## ADDED Requirements

### Requirement: Rota protegida atualiza o nome da pessoa autenticada

O sistema SHALL expor a atualização do próprio nome por um endpoint HTTP **`PATCH /persons/me`**, declarado
**protegido** (`@Authenticated`), que SHALL exigir uma sessão viva antes de executar o handler. O endpoint
SHALL aceitar um corpo JSON com `name`, SHALL obter a identidade do chamador do **ator autenticado**
resolvido pelo guard de borda (o `personId`), e SHALL delegar a decisão ao use case de atualização de nome —
construindo o comando a partir do `personId` do ator e do `name` do corpo. O endpoint SHALL NOT reler a
sessão, o token, nem reimplementar autenticação, e SHALL NOT permitir alterar o nome de outra pessoa que não
a autenticada.

#### Scenario: Requisição autenticada com nome válido responde 200

- **WHEN** o endpoint recebe, numa sessão viva, um corpo com um nome que satisfaz as restrições de borda
- **THEN** o use case de atualização é invocado com o `personId` do ator autenticado e o nome do corpo
- **AND** o sistema responde `200 OK` com a visão pública atualizada da pessoa (id, nome, e-mail)

#### Scenario: Requisição sem sessão viva é recusada pelo guard

- **WHEN** o endpoint é acessado sem `Authorization: Bearer`, ou com um token ausente/inválido/expirado/revogado
- **THEN** o guard de borda recusa com o `401` neutro compartilhado **antes** de o handler rodar
- **AND** o use case de atualização não é invocado

### Requirement: Validação de borda do nome no request de atualização

O sistema SHALL validar o corpo da requisição de atualização na borda HTTP, com Bean Validation, antes de
invocar o use case. O corpo SHALL estar presente e ser JSON válido, e o campo `name` SHALL estar presente e
cumprir as restrições declaradas no request. Toda requisição que falhe qualquer uma dessas checagens SHALL
ser recusada com `400 Bad Request`, no corpo de erro compartilhado definido pela capability
`http-error-handling`, **sem** invocar o use case.

A restrição de `name` no request SHALL referenciar a **mesma** definição do `NameValueObject` (sua constante
de tamanho máximo), de modo que a checagem de borda não possa divergir da regra de domínio. O value object
permanece a autoridade única da invariante — a validação de borda é uma checagem antecipada e propositalmente
igual ou mais estrita (por validar o valor cru, antes da normalização que o value object aplica), nunca uma
segunda regra independente.

#### Scenario: Corpo ausente ou não-JSON

- **WHEN** o endpoint recebe uma requisição sem corpo ou com JSON inválido
- **THEN** o sistema responde `400 Bad Request`
- **AND** o use case de atualização não é invocado

#### Scenario: Nome ausente, vazio ou acima do máximo

- **WHEN** o corpo não contém `name`, ou o traz vazio, ou acima do tamanho máximo do value object
- **THEN** o sistema responde `400 Bad Request` no corpo de erro compartilhado
- **AND** o use case de atualização não é invocado

#### Scenario: Restrição de borda não diverge do domínio

- **WHEN** a restrição de tamanho do `name` no request espelha a regra de domínio
- **THEN** ela referencia a mesma constante pública do `NameValueObject`, não um literal duplicado

### Requirement: Resposta de sucesso da atualização não vaza a senha

O sistema SHALL responder uma atualização de nome bem-sucedida com uma representação da pessoa contendo ao
menos seu identificador, nome (atualizado) e e-mail. A resposta SHALL NOT conter a senha nem o hash da senha,
sob nenhuma forma — reutilizando a **mesma** representação pública de pessoa que o cadastro e o
`GET /persons/me` devolvem.

#### Scenario: Corpo de sucesso omite qualquer material de senha

- **WHEN** a atualização é bem-sucedida e o sistema serializa a pessoa
- **THEN** o corpo contém o identificador, o nome atualizado e o e-mail da pessoa
- **AND** o corpo não contém a senha nem o hash da senha

### Requirement: Nome inválido na atualização responde 422

O sistema SHALL ramificar exaustivamente sobre o resultado do use case de atualização (um tipo `sealed`) sem
depender de exceções lançadas, e SHALL mapear a falha de nome inválido (`InvalidName`) para `422
Unprocessable Entity` no corpo de erro neutro e compartilhado. Nenhum nome é alterado nesse caso.

#### Scenario: Nome rejeitado pelo domínio responde 422

- **WHEN** o use case de atualização retorna `InvalidName`
- **THEN** o sistema responde `422 Unprocessable Entity` com um corpo de erro neutro
- **AND** o nome da pessoa permanece inalterado

### Requirement: Sessão órfã na atualização responde 401 neutro indistinguível

O sistema SHALL mapear a falha `PersonNotFound` do use case de atualização para o **`401` neutro
compartilhado** (code `UNAUTHENTICATED`, mesma mensagem localizada por chave que o guard de borda usa). Essa
resposta SHALL ser **indistinguível** da recusa por token ausente/inválido/expirado e da mesma falha em
`GET /persons/me`, e SHALL NOT revelar que a sessão apontava para uma pessoa inexistente ou não-ativa, nem
ecoar qualquer identificador.

#### Scenario: Sessão órfã responde 401 genérico

- **WHEN** o use case de atualização retorna `PersonNotFound` para uma sessão viva cuja pessoa não está mais ativa
- **THEN** o sistema responde `401` no corpo de erro compartilhado com code `UNAUTHENTICATED`
- **AND** a resposta é indistinguível da recusa de um token ausente ou inválido
- **AND** o corpo não indica que a causa foi uma pessoa inexistente/não-ativa
