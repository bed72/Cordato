# identity-http-api

## Purpose

A borda HTTP do contexto `identity`: expõe o `SignUpUseCase` por `POST /sign-up`, valida a entrada na
borda com Bean Validation antes de tocar o domínio, e mapeia cada resultado — sucesso ou recusa — para um
status e um corpo `ErrorResponse` neutro e compartilhado. A camada HTTP nunca reimplementa regra de
domínio, nunca vaza a senha, e redige o conflito de e-mail de modo que o endpoint não sirva como
ferramenta de descoberta de contas.
## Requirements
### Requirement: Endpoint de cadastro expõe o SignUpUseCase

O sistema SHALL expor a operação de cadastro de pessoa por um endpoint HTTP `POST /sign-up` que aceita um
corpo JSON com `name`, `email` e `password`. O endpoint SHALL delegar a decisão de negócio ao
`SignUpUseCase` existente — construindo um `SignUpCommand` a partir do corpo — e SHALL NOT reimplementar
nenhuma regra de domínio de cadastro.

#### Scenario: Cadastro bem-sucedido responde 201

- **WHEN** o endpoint recebe um corpo com um e-mail não usado, um nome válido e uma senha que cumpre a política
- **THEN** o `SignUpUseCase` é invocado com um `SignUpCommand` correspondente ao corpo
- **AND** o sistema responde `201 Created` com um corpo de pessoa criada

#### Scenario: A controller não valida regras de domínio

- **WHEN** o corpo é estruturalmente válido (campos presentes e do tipo esperado)
- **THEN** a controller repassa os valores ao `SignUpUseCase` sem verificar formato de e-mail, validade de nome ou política de senha
- **AND** qualquer recusa por essas regras vem do resultado do use case, não da camada HTTP

### Requirement: Validação de entrada no request

O sistema SHALL validar o corpo da requisição na borda HTTP, com Bean Validation, antes de invocar o
`SignUpUseCase`. O corpo SHALL estar presente e ser JSON válido, os campos `name`, `email` e `password`
SHALL estar presentes como strings, e cada campo SHALL cumprir as restrições declaradas no request. Toda
requisição que falhe qualquer uma dessas checagens SHALL ser recusada com `400 Bad Request`, no corpo de
erro compartilhado definido pela capability `http-error-handling`, **sem** invocar o `SignUpUseCase`.
Quando mais de um campo violar suas restrições na mesma requisição, a resposta SHALL reportar cada campo
violado como um item da lista `errors`, não uma mensagem concatenada.

As restrições do request que espelham uma regra de domínio SHALL referenciar a **mesma** definição do
value object correspondente (a constante ou o padrão público), de modo que a checagem de borda não possa
divergir da regra de domínio. O value object permanece a autoridade única da invariante — a validação de
borda é uma checagem antecipada e propositalmente igual ou mais estrita (por validar o valor cru, antes da
normalização que o value object aplica), nunca uma segunda regra independente.

#### Scenario: Corpo ausente ou não-JSON

- **WHEN** o endpoint recebe uma requisição sem corpo ou com JSON inválido
- **THEN** o sistema responde `400 Bad Request`
- **AND** o `SignUpUseCase` não é invocado

#### Scenario: Campo obrigatório ausente

- **WHEN** o corpo JSON não contém um dos campos `name`, `email` ou `password`
- **THEN** o sistema responde `400 Bad Request`
- **AND** o `SignUpUseCase` não é invocado

#### Scenario: Campo viola uma restrição de borda

- **WHEN** o corpo tem um nome vazio/acima do máximo, um e-mail em formato inválido, ou uma senha abaixo do mínimo
- **THEN** o sistema responde `400 Bad Request` no corpo de erro compartilhado
- **AND** o `SignUpUseCase` não é invocado

#### Scenario: Múltiplas violações reportam cada campo

- **WHEN** dois ou mais de `name`, `email`, `password` violam suas restrições na mesma requisição
- **THEN** o sistema responde `400 Bad Request` com um item em `errors` por campo violado
- **AND** as mensagens não são concatenadas em um único campo `message`
- **AND** o `SignUpUseCase` não é invocado

#### Scenario: Restrição de borda não diverge do domínio

- **WHEN** uma restrição do request espelha uma regra de domínio (tamanho máximo do nome, mínimo da senha, formato do e-mail)
- **THEN** ela referencia a mesma constante/padrão público do value object, não um literal duplicado

### Requirement: Resposta de sucesso não vaza a senha

O sistema SHALL responder um cadastro bem-sucedido com uma representação da pessoa criada contendo ao menos
seu identificador, nome e e-mail. A resposta SHALL NOT conter a senha digitada nem o hash da senha, sob
nenhuma forma.

#### Scenario: Corpo de sucesso omite qualquer material de senha

- **WHEN** o cadastro é bem-sucedido e o sistema serializa a pessoa criada
- **THEN** o corpo da resposta contém o identificador, o nome e o e-mail da pessoa
- **AND** o corpo não contém a senha digitada nem o hash da senha

### Requirement: Mapeamento de erros de domínio para status HTTP

O sistema SHALL ramificar exaustivamente sobre o `SignUpResult` (um tipo `sealed`) sem depender de exceções
lançadas, e SHALL mapear cada `SignUpError` para um status HTTP e um corpo de erro neutro e compartilhado.
`InvalidEmail` e `InvalidName` SHALL mapear para `422 Unprocessable Entity`. `WeakPassword` SHALL mapear
para `422 Unprocessable Entity` e MAY comunicar abertamente o comprimento mínimo público de senha.

#### Scenario: Entrada inválida responde 422

- **WHEN** o `SignUpUseCase` retorna `InvalidEmail` ou `InvalidName`
- **THEN** o sistema responde `422 Unprocessable Entity` com um corpo de erro neutro
- **AND** nenhuma pessoa é criada

#### Scenario: Senha fraca pode expor a política pública

- **WHEN** o `SignUpUseCase` retorna `WeakPassword`
- **THEN** o sistema responde `422 Unprocessable Entity`
- **AND** o corpo de erro pode indicar o comprimento mínimo público exigido

### Requirement: O conflito de e-mail não vaza a existência de conta

O sistema SHALL mapear o erro `EmailAlreadyInUse` para uma resposta que NÃO permita distinguir, de fora,
que aquele e-mail já está cadastrado. A resposta SHALL NOT ecoar o e-mail tentado nem qualquer dado da
pessoa existente, e sua mensagem SHALL ser redigida de modo genérico, de forma que o endpoint não sirva
como ferramenta de descoberta de contas alheias.

#### Scenario: Conflito de e-mail responde de forma neutra

- **WHEN** o `SignUpUseCase` retorna `EmailAlreadyInUse`
- **THEN** o sistema responde com um status de recusa de cadastro e um corpo de erro genérico
- **AND** o corpo não contém o e-mail tentado nem qualquer dado da pessoa existente
- **AND** a mensagem não afirma nem sugere que o e-mail já está cadastrado

### Requirement: Endpoint de login expõe o SignInUseCase

O sistema SHALL expor a operação de login por um endpoint HTTP `POST /sign-in` que aceita um corpo JSON com
`email` e `password`. O endpoint SHALL delegar a decisão de negócio ao `SignInUseCase` — construindo um
`SignInCommand` a partir do corpo — e SHALL NOT reimplementar nenhuma regra de autenticação na camada HTTP.

#### Scenario: Login bem-sucedido responde 200

- **WHEN** o endpoint recebe um corpo com as credenciais de uma pessoa ativa e senha correta
- **THEN** o `SignInUseCase` é invocado com um `SignInCommand` correspondente ao corpo
- **AND** o sistema responde `200 OK` com o corpo de sessão criada

#### Scenario: A controller não decide autenticação

- **WHEN** o corpo é estruturalmente válido (campos presentes)
- **THEN** a controller repassa os valores ao `SignInUseCase` sem verificar existência de conta, senha ou status
- **AND** qualquer recusa vem do resultado do use case, não da camada HTTP

### Requirement: Validação de borda do login é apenas de presença

O sistema SHALL validar o corpo do login na borda **apenas quanto à presença** dos campos `email` e
`password` (`@NotBlank`), recusando com `400 Bad Request` no corpo de erro compartilhado um corpo ausente,
não-JSON, ou com campo ausente/vazio, **sem** invocar o `SignInUseCase`. A borda do login SHALL NOT aplicar
regras de política (formato de e-mail, tamanho, força de senha): validar política aqui travaria um usuário
legítimo diante de uma mudança de política e divergiria o sinal do `401` de credenciais inválidas.

#### Scenario: Corpo ausente ou não-JSON

- **WHEN** o endpoint recebe uma requisição sem corpo ou com JSON inválido
- **THEN** o sistema responde `400 Bad Request` no corpo compartilhado
- **AND** o `SignInUseCase` não é invocado

#### Scenario: Campo ausente ou vazio

- **WHEN** o corpo não contém `email` ou `password`, ou um deles é vazio
- **THEN** o sistema responde `400 Bad Request`
- **AND** o `SignInUseCase` não é invocado

#### Scenario: A borda não aplica política de senha

- **WHEN** o corpo traz uma senha presente porém curta ou um e-mail presente porém mal-formatado
- **THEN** a borda **não** recusa por essas regras — ela repassa ao `SignInUseCase`
- **AND** a recusa, se houver, é o `401` genérico de credenciais inválidas, não um `400` por campo

### Requirement: Resposta de sucesso do login devolve o token e a expiração

O sistema SHALL responder um login bem-sucedido com um corpo contendo o **token opaco** em claro e o
instante de **expiração** da sessão (`{ token, expiresAt }`). A resposta SHALL NOT conter a senha digitada,
o hash da senha, nem o hash do token.

#### Scenario: Corpo de sucesso traz token e expiração

- **WHEN** o login é bem-sucedido e o sistema serializa a sessão criada
- **THEN** o corpo contém o token opaco em claro e o instante de expiração
- **AND** o corpo não contém a senha, o hash da senha, nem o hash do token

### Requirement: Credenciais inválidas respondem 401 neutro

O sistema SHALL ramificar exaustivamente sobre o `SignInResult` (um tipo `sealed`) sem depender de
exceções, e SHALL mapear `InvalidCredentials` para o **`401` neutro compartilhado** (code `UNAUTHENTICATED`)
definido pela capability `http-error-handling`. Essa resposta SHALL ser **indistinguível** da rejeição de
uma rota protegida acessada sem sessão, e SHALL NOT revelar qual fator falhou (senha, e-mail inexistente ou
status), nem ecoar o e-mail tentado.

#### Scenario: Recusa de login responde 401 genérico

- **WHEN** o `SignInUseCase` retorna `InvalidCredentials`
- **THEN** o sistema responde `401` no corpo de erro compartilhado com code `UNAUTHENTICATED`
- **AND** a mensagem é genérica e não indica qual fator falhou

#### Scenario: A resposta não vaza a existência de conta

- **WHEN** o login é recusado
- **THEN** o corpo não ecoa o e-mail tentado nem qualquer dado de pessoa
- **AND** a resposta é indistinguível entre e-mail inexistente, senha incorreta e pessoa não-ativa

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

### Requirement: Resposta de sucesso da pessoa autenticada não vaza a senha

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

