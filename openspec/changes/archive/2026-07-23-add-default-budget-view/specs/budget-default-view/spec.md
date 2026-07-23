## ADDED Requirements

### Requirement: GET /budgets/default retorna o gasto somado fora de qualquer orçamento vivo do ator autenticado

O sistema SHALL expor `GET /budgets/default` como rota **protegida** (anotada com `@Authenticated`), de
modo que uma requisição sem sessão viva SHALL ser recusada pelo guard de autenticação do `core` com o
`401` neutro, antes de o handler rodar. Em uma requisição autenticada, o controller SHALL delegar ao
`GetDefaultBudgetUseCase`, derivando o dono consultado do `AuthenticatedActor` (nunca de
parâmetro/corpo). O sistema SHALL responder `200 OK` com o envelope de sucesso do
`http-response-envelope`, contendo em `data` um agrupamento fabricado — nunca um orçamento real — com
`spentInCents`: a soma, em centavos, de todos os gastos do ator cuja data **não** cai dentro do
intervalo de nenhum orçamento **vivo** dele. O valor SHALL ser **recalculado a cada requisição** e
**nunca persistido**.

#### Scenario: Requisição autenticada com gastos fora de orçamento retorna 200 com o total

- **WHEN** uma requisição autenticada chega a `GET /budgets/default` e o ator tem gastos cuja data não
  cai dentro do intervalo de nenhum orçamento vivo dele
- **THEN** o sistema responde `200 OK` com `data.spentInCents` igual à soma exata, em centavos, desses
  gastos

#### Scenario: Requisição sem sessão viva é recusada com 401 neutro

- **WHEN** uma requisição sem token válido/sessão viva chega a `GET /budgets/default`
- **THEN** o guard de autenticação recusa com o `401` neutro do `core`, sem alcançar o handler
- **AND** o `GetDefaultBudgetUseCase` não é invocado

### Requirement: Ausência de gasto fora de orçamento é sempre 200 com spentInCents zero, nunca 404 ou data nulo

O sistema SHALL tratar o orçamento padrão como um agrupamento que sempre existe — ao contrário de
`budget-active-view` (onde a ausência de orçamento vivo cobrindo hoje é modelada como `data: null`), aqui
não há uma entidade sendo procurada, então não há "ausência" a representar. Quando todos os gastos do
ator caem dentro de algum orçamento vivo dele (ou quando o ator não tem nenhum gasto), o sistema SHALL
responder `200 OK` com `data.spentInCents` igual a `0` — nunca `404`, nunca `data: null`.

#### Scenario: Todos os gastos cobertos por orçamentos vivos produz spentInCents zero

- **WHEN** uma requisição autenticada chega a `GET /budgets/default` e todo gasto do ator cai dentro do
  intervalo de algum orçamento vivo dele
- **THEN** o sistema responde `200 OK` com `data.spentInCents` igual a `0`

#### Scenario: Sem nenhum gasto registrado produz spentInCents zero

- **WHEN** uma requisição autenticada chega a `GET /budgets/default` e o ator não tem nenhum gasto
  registrado
- **THEN** o sistema responde `200 OK` com `data.spentInCents` igual a `0`

### Requirement: O cálculo nunca conta um gasto de um orçamento vivo, mesmo com múltiplos orçamentos vivos ao longo do tempo

O sistema SHALL calcular `spentInCents` como o total geral de gastos do ator menos a soma dos gastos
dentro do intervalo de cada orçamento **vivo** do ator — nunca incluindo, na soma final, um gasto cuja
data cai dentro do intervalo de qualquer orçamento vivo dele. Um orçamento removido (não vivo) SHALL NOT
ser descontado do total: os gastos que caíam no intervalo de um orçamento removido voltam a contar como
"fora de orçamento".

#### Scenario: Gasto dentro de um orçamento vivo não entra no total

- **WHEN** o ator tem um orçamento vivo cobrindo um intervalo e um gasto com data dentro desse intervalo
- **THEN** esse gasto não entra em `data.spentInCents`

#### Scenario: Gasto dentro do intervalo de um orçamento removido volta a contar como fora de orçamento

- **WHEN** o ator tinha um orçamento cobrindo um intervalo com um gasto dentro dele, e esse orçamento foi
  removido (deixou de ser vivo)
- **THEN** esse gasto passa a entrar em `data.spentInCents`

#### Scenario: Gastos com data fora de qualquer orçamento vivo entram integralmente no total

- **WHEN** o ator tem gastos com data que não cai dentro do intervalo de nenhum orçamento vivo dele
- **THEN** esses gastos entram, integralmente, em `data.spentInCents`

### Requirement: Mensagens por chave i18n e documentação OpenAPI

Todo texto de resposta legível de `GET /budgets/default` SHALL ser resolvido por chave do bundle de
mensagens compartilhado (pt-BR default), nunca inline. A rota SHALL ser documentada em compile-time via o
`BudgetControllerDoc` existente, mantendo as anotações de documentação fora do controller; o método de
sucesso SHALL declarar `@Status(HttpStatus.OK)`, e o schema de sucesso SHALL declarar o corpo de `data`
como sempre presente (não nulável).

#### Scenario: OpenAPI documenta a rota via a interface Doc

- **WHEN** o documento OpenAPI é gerado no build
- **THEN** `GET /budgets/default` aparece documentado com `200` de sucesso cujo corpo é o envelope de
  sucesso (`data.spentInCents`, não nulável) e as respostas de erro no envelope `errors`, a partir das
  anotações do `BudgetControllerDoc`
