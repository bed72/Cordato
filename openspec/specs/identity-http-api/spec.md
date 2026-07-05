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
requisição que falhe qualquer uma dessas checagens SHALL ser recusada com `400 Bad Request`, no mesmo
corpo `ErrorResponse` das demais falhas, **sem** invocar o `SignUpUseCase`.

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
- **THEN** o sistema responde `400 Bad Request` com um corpo `ErrorResponse`
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
