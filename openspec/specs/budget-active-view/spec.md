# budget-active-view Specification

## Purpose
TBD - created by archiving change add-budget-active-view. Update Purpose after archive.
## Requirements
### Requirement: GET /budgets/active retorna o orçamento vivo de hoje do ator autenticado

O sistema SHALL expor `GET /budgets/active` como rota **protegida** (anotada com `@Authenticated`), de modo
que uma requisição sem sessão viva SHALL ser recusada pelo guard de autenticação do `core` com o `401`
neutro, antes de o handler rodar. Em uma requisição autenticada, o controller SHALL delegar ao
`GetActiveBudgetUseCase`, derivando o dono consultado do `AuthenticatedActor` (nunca de parâmetro/corpo). O
sistema SHALL responder `200 OK` com o envelope de sucesso do `http-response-envelope`, contendo em `data`
o orçamento **vivo** da pessoa cujo intervalo cobre a data de hoje — comparação por data **inclusiva** de
fronteira — acompanhado do valor gasto e do valor restante, ambos **recalculados a cada requisição** e
**nunca persistidos**.

#### Scenario: Requisição autenticada com orçamento ativo retorna 200 com o orçamento

- **WHEN** uma requisição autenticada chega a `GET /budgets/active` e o ator tem um orçamento vivo cujo
  intervalo cobre a data de hoje
- **THEN** o sistema responde `200 OK` com `data` contendo aquele orçamento (id, valor em centavos, data
  de início, data de fim, anotação opcional), o gasto somado e o restante

#### Scenario: Requisição sem sessão viva é recusada com 401 neutro

- **WHEN** uma requisição sem token válido/sessão viva chega a `GET /budgets/active`
- **THEN** o guard de autenticação recusa com o `401` neutro do `core`, sem alcançar o handler
- **AND** o `GetActiveBudgetUseCase` não é invocado

### Requirement: Gasto e restante são derivados, nunca armazenados

O sistema SHALL calcular `spentInCents` como a soma, em centavos, de todos os gastos do mesmo ator cuja
data cai dentro do intervalo `[startDate, endDate]` (ambos incluídos) do orçamento ativo — consultada via a
capability `expense-amount-query`, nunca por acesso direto a dados de `expense`. O sistema SHALL calcular
`remainingInCents` como `amountInCents - spentInCents`. Nenhum dos dois valores SHALL ser lido de uma
coluna armazenada — ambos SHALL ser recomputados em toda leitura, a partir do orçamento vivo e da soma
corrente de gastos daquele intervalo.

#### Scenario: Gasto somado reflete os gastos do intervalo

- **WHEN** o ator tem gastos registrados com data dentro do intervalo do orçamento ativo
- **THEN** `spentInCents` é a soma exata, em centavos, desses gastos
- **AND** gastos com data fora do intervalo do orçamento ativo não entram na soma

#### Scenario: Sem gastos no intervalo, o gasto somado é zero

- **WHEN** o ator não tem nenhum gasto com data dentro do intervalo do orçamento ativo
- **THEN** `spentInCents` é `0`
- **AND** `remainingInCents` é igual a `amountInCents`

#### Scenario: Orçamento estourado produz um restante negativo

- **WHEN** a soma dos gastos do intervalo é maior que o valor do orçamento ativo
- **THEN** `remainingInCents` é um valor negativo
- **AND** o sistema responde `200 OK` normalmente — um restante negativo não é um erro

### Requirement: Ausência de orçamento ativo responde 200 com data nulo, nunca 404

O sistema SHALL tratar a ausência de um orçamento vivo cobrindo a data de hoje como um resultado de
**sucesso**, não como um erro de rota. Quando o ator autenticado não tem nenhum orçamento vivo cujo
intervalo cubra hoje, o sistema SHALL responder `200 OK` com `data` igual a `null` (serializado
explicitamente como `"data": null`, nunca omitido) — simétrico à página vazia de `GET /expenses` para "nada
aqui agora".

#### Scenario: Sem orçamento ativo responde 200 com data null

- **WHEN** uma requisição autenticada chega a `GET /budgets/active` e o ator não tem nenhum orçamento vivo
  cujo intervalo cubra a data de hoje
- **THEN** o sistema responde `200 OK` com `data` igual a `null`
- **AND** a resposta não é `404`

### Requirement: Mensagens por chave i18n e documentação OpenAPI

Todo texto de resposta legível de `GET /budgets/active` SHALL ser resolvido por chave do bundle de
mensagens compartilhado (pt-BR default), nunca inline. A rota SHALL ser documentada em compile-time via o
`BudgetControllerDoc` existente (interface com as anotações `@Operation`/`@ApiResponse`/`@Tag`) que o
`BudgetController` implementa, mantendo as anotações de documentação fora do controller; o método de
sucesso SHALL declarar `@Status(HttpStatus.OK)`, e o schema de sucesso SHALL declarar o corpo de `data`
como `nullable = true`.

#### Scenario: OpenAPI documenta a rota via a interface Doc, incluindo o caso nulo

- **WHEN** o documento OpenAPI é gerado no build
- **THEN** `GET /budgets/active` aparece documentado com `200` de sucesso cujo corpo é o envelope de
  sucesso (`data` nulável com a visão do orçamento ativo) e as respostas de erro no envelope `errors`, a
  partir das anotações do `BudgetControllerDoc`
