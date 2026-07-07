## ADDED Requirements

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
