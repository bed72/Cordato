# expense-http-api Specification

## Purpose
TBD - created by archiving change add-expense-create. Update Purpose after archive.
## Requirements
### Requirement: POST /expenses registra um gasto do ator autenticado

O sistema SHALL expor `POST /expenses` como rota **protegida** (anotada com `@Authenticated`), de modo que
uma requisição sem sessão viva SHALL ser recusada pelo guard de autenticação do `core` com o `401` neutro,
antes de o handler rodar. Em uma requisição autenticada e válida, o controller SHALL delegar ao
`CreateExpenseUseCase`, derivando o dono do gasto do `AuthenticatedActor` (nunca do corpo), e em caso de
sucesso SHALL responder `201 Created` com a visão pública do gasto criado.

#### Scenario: Registro autenticado bem-sucedido retorna 201

- **WHEN** uma requisição autenticada válida chega a `POST /expenses`
- **THEN** o sistema registra o gasto do ator autenticado
- **AND** responde `201 Created` com a visão pública do gasto (id, valor em centavos, data, descrição)

#### Scenario: Requisição sem sessão viva é recusada com 401 neutro

- **WHEN** uma requisição sem token válido/sessão viva chega a `POST /expenses`
- **THEN** o guard de autenticação recusa com o `401` neutro do `core`, sem alcançar o handler
- **AND** nenhum gasto é registrado

### Requirement: Corpo malformado ou inválido no edge retorna 400

O sistema SHALL validar a forma do corpo no edge com Bean Validation antes do caso de uso. Cada restrição
que espelhe uma regra de domínio SHALL referenciar a definição do value object correspondente (o `const`
de comprimento máximo da descrição, o mínimo do valor), nunca um literal copiado. Uma violação de
restrição SHALL produzir um `400` com um `FieldErrorResponse` por campo violado; um corpo ilegível
(JSON inválido, forma indeserializável, corpo ausente) SHALL produzir um `400` escalar `MALFORMED_REQUEST`
— ambos via os handlers e o contrato de erro compartilhados do `core`.

#### Scenario: Campo inválido no edge retorna 400 por campo

- **WHEN** o corpo viola uma restrição de edge (ex.: valor ausente, descrição acima do máximo)
- **THEN** o sistema responde `400` com um `FieldErrorResponse` por campo violado

#### Scenario: Corpo malformado retorna 400 escalar

- **WHEN** o corpo é JSON inválido, tem forma indeserializável ou está ausente
- **THEN** o sistema responde `400` escalar com código `MALFORMED_REQUEST`

### Requirement: Rejeição de domínio retorna 422 escalar

O sistema SHALL mapear cada `CreateExpenseError` (valor inválido, data futura, descrição inválida) para um
`422` escalar, via o builder `unprocessable` do `core`, através do error mapper próprio do contexto
`expense`. O mapper SHALL resolver a mensagem por chave i18n e SHALL manter o `code` como constante inline
(contrato de máquina, não localizado). Um `422` SHALL NOT ser emitido como `FieldErrorResponse` — a
rejeição de domínio é fail-fast e escalar.

#### Scenario: Valor inválido rejeitado pelo domínio retorna 422

- **WHEN** o caso de uso retorna um erro de valor inválido (valor ≤ 0 que passou o edge)
- **THEN** o sistema responde `422` escalar com o código e a mensagem (por i18n) daquele erro

#### Scenario: Data futura rejeitada pelo domínio retorna 422

- **WHEN** o caso de uso retorna um erro de data futura
- **THEN** o sistema responde `422` escalar com o código e a mensagem (por i18n) daquele erro

### Requirement: Mensagens por chave i18n e documentação OpenAPI

Todo texto de resposta legível do `expense` SHALL ser resolvido por chave do bundle de mensagens
compartilhado (pt-BR default), nunca inline; o `code` de erro SHALL permanecer constante inline. A rota
SHALL ser documentada em compile-time via um `ExpenseControllerDoc` (interface com as anotações
`@Operation`/`@ApiResponse`/`@Tag`) que o `ExpenseController` implementa, mantendo as anotações de
documentação fora do controller; o método de sucesso SHALL declarar `@Status(HttpStatus.CREATED)` para que
o gerador documente `201`.

#### Scenario: Toda mensagem vem do bundle

- **WHEN** qualquer resposta de erro ou sucesso do `expense` produz texto legível
- **THEN** esse texto é resolvido por chave do bundle compartilhado, com fallback para a chave

#### Scenario: OpenAPI documenta a rota via a interface Doc

- **WHEN** o documento OpenAPI é gerado no build
- **THEN** `POST /expenses` aparece documentado com `201` de sucesso e as respostas de erro (`ErrorResponse`)
  a partir das anotações do `ExpenseControllerDoc`

### Requirement: GET /expenses lista os gastos do ator autenticado

O sistema SHALL expor `GET /expenses` como rota **protegida** (anotada com `@Authenticated`), de modo que
uma requisição sem sessão viva SHALL ser recusada pelo guard de autenticação do `core` com o `401` neutro,
antes de o handler rodar. Em uma requisição autenticada, o controller SHALL delegar ao
`ListExpensesUseCase`, derivando o dono consultado do `AuthenticatedActor` (nunca de parâmetro/corpo), e
SHALL responder `200 OK` com a lista dos gastos daquele ator como um array JSON, cada item na visão
pública do gasto (`id`, valor em centavos, data, descrição opcional). Uma pessoa sem gastos SHALL receber
`200` com um array **vazio**, nunca `404`.

#### Scenario: Listagem autenticada retorna 200 com o array de gastos

- **WHEN** uma requisição autenticada chega a `GET /expenses` e o ator possui gastos
- **THEN** o sistema responde `200 OK` com um array dos gastos do ator, cada item na visão pública
  (id, valor em centavos, data, descrição)

#### Scenario: Ator sem gastos retorna 200 com array vazio

- **WHEN** uma requisição autenticada chega a `GET /expenses` e o ator não possui nenhum gasto
- **THEN** o sistema responde `200 OK` com um array vazio, não `404`

#### Scenario: Requisição sem sessão viva é recusada com 401 neutro

- **WHEN** uma requisição sem token válido/sessão viva chega a `GET /expenses`
- **THEN** o guard de autenticação recusa com o `401` neutro do `core`, sem alcançar o handler
- **AND** nenhum gasto é retornado

### Requirement: GET /expenses é documentado via a interface Doc

O sistema SHALL documentar `GET /expenses` em compile-time via o `ExpenseControllerDoc` (interface com as
anotações `@Operation`/`@ApiResponse`/`@Tag`) que o `ExpenseController` implementa, mantendo as anotações
de documentação fora do controller. O método SHALL declarar `@Status(HttpStatus.OK)` para que o gerador
documente `200` como sucesso, com o corpo declarado como um **array** de `ExpenseResponse`, e as respostas
de erro (`401`/`500`) como `ErrorResponse`.

#### Scenario: OpenAPI documenta a rota de listagem via a interface Doc

- **WHEN** o documento OpenAPI é gerado no build
- **THEN** `GET /expenses` aparece documentado com `200` de sucesso cujo corpo é um array de
  `ExpenseResponse`
- **AND** as respostas de erro aparecem como `ErrorResponse`, a partir das anotações do
  `ExpenseControllerDoc`

