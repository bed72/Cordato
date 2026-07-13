# expense-http-api

## ADDED Requirements

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
