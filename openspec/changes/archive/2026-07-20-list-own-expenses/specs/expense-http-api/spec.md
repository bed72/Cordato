# expense-http-api

## ADDED Requirements

### Requirement: GET /expenses lista os gastos do ator autenticado, paginado por cursor

O sistema SHALL expor `GET /expenses` como rota **protegida** (anotada com `@Authenticated`), de modo que
uma requisição sem sessão viva SHALL ser recusada pelo guard de autenticação do `core` com o `401` neutro,
antes de o handler rodar. Em uma requisição autenticada, o controller SHALL delegar ao `ListExpensesUseCase`,
derivando o dono consultado do `AuthenticatedActor` (nunca de parâmetro/corpo), e SHALL responder `200 OK`
com uma **página** dos gastos daquele ator: um **envelope** contendo os itens (cada um na visão pública do
gasto — `id`, valor em centavos, data, descrição opcional) e um **próximo cursor** (ou a sua ausência na
última página). A rota SHALL aceitar dois query params de puro transporte: `limit` (opcional; um **default**
quando ausente, recusado no edge acima de um **teto máximo**) e `cursor` (opcional; string opaca). Uma
pessoa sem gastos SHALL receber `200` com uma página **vazia** (sem itens, sem próximo cursor), nunca `404`.

#### Scenario: Listagem autenticada retorna 200 com a página de gastos

- **WHEN** uma requisição autenticada chega a `GET /expenses` e o ator possui gastos
- **THEN** o sistema responde `200 OK` com um envelope contendo os itens do ator (id, valor em centavos,
  data, descrição) e um próximo cursor quando há continuação

#### Scenario: Seguir o próximo cursor retorna a próxima página

- **WHEN** uma requisição autenticada chega a `GET /expenses?cursor=<opaco>` com o cursor de uma página anterior
- **THEN** o sistema responde `200 OK` com os gastos seguintes àquela posição, sem repetir os já retornados

#### Scenario: Ator sem gastos retorna 200 com página vazia

- **WHEN** uma requisição autenticada chega a `GET /expenses` e o ator não possui nenhum gasto
- **THEN** o sistema responde `200 OK` com uma página vazia (sem itens, sem próximo cursor), não `404`

#### Scenario: limit acima do teto é recusado no edge com 400

- **WHEN** uma requisição autenticada chega a `GET /expenses?limit=<acima-do-teto>`
- **THEN** o sistema recusa no edge com `400` (o `limit` viola a restrição de borda), sem servir a página

#### Scenario: Cursor malformado é recusado com 400 escalar

- **WHEN** uma requisição autenticada chega a `GET /expenses?cursor=<ilegível>`
- **THEN** o sistema responde `400` escalar com código `MALFORMED_REQUEST`, sem alcançar a consulta
- **AND** a resposta não vaza detalhes internos (não é um `500`)

#### Scenario: Requisição sem sessão viva é recusada com 401 neutro

- **WHEN** uma requisição sem token válido/sessão viva chega a `GET /expenses`
- **THEN** o guard de autenticação recusa com o `401` neutro do `core`, sem alcançar o handler
- **AND** nenhum gasto é retornado

### Requirement: GET /expenses é documentado via a interface Doc

O sistema SHALL documentar `GET /expenses` em compile-time via o `ExpenseControllerDoc` (interface com as
anotações `@Operation`/`@ApiResponse`/`@Tag`) que o `ExpenseController` implementa, mantendo as anotações
de documentação fora do controller. O método SHALL declarar `@Status(HttpStatus.OK)` para que o gerador
documente `200` como sucesso, com o corpo declarado como o **envelope de página** (`ExpensePageResponse`:
itens de `ExpenseResponse` mais o próximo cursor). Os query params `limit`/`cursor` SHALL ser documentados
(`@Parameter`), e as respostas de erro (`400`/`401`/`500`) SHALL ser documentadas como `ErrorResponse`.

#### Scenario: OpenAPI documenta a rota de listagem via a interface Doc

- **WHEN** o documento OpenAPI é gerado no build
- **THEN** `GET /expenses` aparece documentado com `200` de sucesso cujo corpo é o envelope de página
  (itens de `ExpenseResponse` mais o próximo cursor) e com os query params `limit`/`cursor`
- **AND** as respostas de erro (`400`/`401`/`500`) aparecem como `ErrorResponse`, a partir das anotações do
  `ExpenseControllerDoc`
