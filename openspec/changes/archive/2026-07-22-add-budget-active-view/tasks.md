## 1. Persistência — soma de gastos por intervalo (`expense`)

- [x] 1.1 Adicionar `ExpenseRepository.sumAmountInRange(personId, startDate, endDate): Long` (port em
      `features/expense/application/driven/repositories/ExpenseRepository.kt`), resolvido inteiramente no
      banco (`SUM(amount_cents)` com `COALESCE(..., 0)`), reusando a tabela `expense` existente (V3), sem
      nova migração.
- [x] 1.2 Implementar a consulta no `PersistenceExpenseRepository` (jOOQ), filtrando por `person_id` e por
      `spent_on BETWEEN startDate AND endDate` (inclusivo).
- [x] 1.3 Teste de integração da consulta na harness Postgres: soma correta dentro do intervalo, `0` sem
      gastos, gastos fora do intervalo e de outra pessoa não entram na soma.

## 2. Aplicação — `SumExpensesInRangeUseCase` (`expense`)

- [x] 2.1 Criar `features/expense/application/driving/commands/SumExpensesInRangeCommand.kt`
      (`personId`, `startDate: LocalDate`, `endDate: LocalDate`).
- [x] 2.2 Criar `features/expense/application/driving/use_cases/SumExpensesInRangeUseCase.kt`:
      `operator fun invoke(command): Long` direto (sem `Result` selado — somar não tem falha de domínio
      honesta, mesma postura de `ListExpensesUseCase`), delegando ao `ExpenseRepository.sumAmountInRange`.
- [x] 2.3 Registrar o bean em `ExpenseFactory` (`@Factory`).
- [x] 2.4 Testes do use case com fake `ExpenseRepository` (convenções de `factories/`): soma correta, `0`
      sem gastos.

## 3. Persistência — orçamento vivo cobrindo uma data (`budget`)

- [x] 3.1 Adicionar `BudgetRepository.findLiveBudgetCovering(personId, date): BudgetEntity?` (port em
      `features/budget/application/driven/repositories/BudgetRepository.kt`), resolvido inteiramente no
      banco (`WHERE person_id = ? AND status = LIVE AND start_date <= ? AND end_date >= ?`), reusando a
      tabela `budget` existente (V4), sem nova migração.
- [x] 3.2 Implementar a consulta no `PersistenceBudgetRepository` (jOOQ), mapeando o record de volta para
      `BudgetEntity` via o mapper existente; retorna `null` quando nenhum orçamento vivo cobre a data.
- [x] 3.3 Teste de integração da consulta na harness Postgres: encontra o orçamento vivo cobrindo hoje,
      `null` sem orçamento vivo cobrindo a data, orçamento removido nunca é retornado.

## 4. Domínio — `ActiveBudgetVirtualObject` (`budget`)

- [x] 4.1 Criar `features/budget/domain/virtual_objects/ActiveBudgetVirtualObject.kt` (ADR 0001): `data
      class` com o `BudgetEntity` vivo mais `spentInCents: Long` e `remainingInCents: Long` — nunca
      `MoneyValueObject` para esses dois (podem ser `0`/negativo).
- [x] 4.2 Teste de domínio: `remainingInCents` calculado como `amountInCents - spentInCents`, incluindo o
      caso estourado (negativo).

## 5. ACL cross-context — `budget` pergunta a `expense`

- [x] 5.1 Criar `features/budget/application/driven/ports/ExpenseSpentAmountPort.kt` (`fun interface`, no
      vocabulário do `budget`: `operator fun invoke(personId, startDate, endDate): Long`).
- [x] 5.2 Criar `features/budget/infrastructure/adapters/ExpenseSpentAmountAdapter.kt`, implementando o
      port por chamada in-process ao `SumExpensesInRangeUseCase` de `expense` (injetado via construtor),
      traduzindo comando/resultado para o vocabulário do `budget`. Confirmar que `budget/domain` e
      `budget/application` não importam nenhum tipo de `expense` além deste port.
- [x] 5.3 Teste do adapter com fake/mock do `SumExpensesInRangeUseCase` (ou instância real com fake
      repository) confirmando a tradução de parâmetros e retorno.

## 6. Aplicação — `GetActiveBudgetUseCase` (`budget`)

- [x] 6.1 Criar `features/budget/application/driving/commands/GetActiveBudgetCommand.kt` (`personId`).
- [x] 6.2 Criar `features/budget/application/driving/use_cases/GetActiveBudgetUseCase.kt`:
      `operator fun invoke(command): ActiveBudgetVirtualObject?` direto (sem `Result` selado — ausência de
      orçamento ativo não é falha de domínio). Deriva "hoje" via `ClockPort` em `ZoneOffset.UTC` (mesmo
      padrão de `CreateExpenseUseCase`), busca o orçamento vivo via `BudgetRepository`, `null` → retorna
      `null`; achado → consulta `ExpenseSpentAmountPort` para o intervalo do orçamento e monta o virtual
      object.
- [x] 6.3 Testes do use case com fakes de `BudgetRepository`/`ExpenseSpentAmountPort` e clock fixo: com
      orçamento ativo e gastos, com orçamento ativo sem gastos (`spentInCents = 0`), sem orçamento ativo
      (`null`), orçamento estourado (`remainingInCents` negativo).

## 7. Slice HTTP do orçamento ativo (`budget`)

- [x] 7.1 Criar `features/budget/infrastructure/http/responses/ActiveBudgetResponse.kt` (`@Serdeable`,
      `@Schema`; `id`, `amountInCents`, `spentInCents`, `remainingInCents`, `startDate`, `endDate`,
      `note?`).
- [x] 7.2 Criar o mapper `mappers/responses/` (`ActiveBudgetVirtualObject.toResponse()`).
- [x] 7.3 Adicionar `@Get("/active")` `@Authenticated` em `BudgetController`, lendo o `AuthenticatedActor`,
      chamando `GetActiveBudgetUseCase`, respondendo `ok(response)` do `core` — `response` nulável quando o
      use case retorna `null` (o builder `ok<T>` já aceita `T` nulável sem mudança no `core`).
- [x] 7.4 Atualizar `BudgetControllerDoc`: `@Operation`/`@ApiResponse` para `200` (schema de sucesso com
      `data` `nullable = true`) e as respostas de erro (`401`/`500`) no envelope `errors`.
- [x] 7.5 Adicionar as chaves i18n necessárias (se alguma mensagem legível for introduzida) em
      `src/main/resources/i18n/messages.properties`.

## 8. Fiação (DI)

- [x] 8.1 Atualizar `BudgetFactory` (`@Factory`): publicar `expenseSpentAmountPort` (o adapter do item 5.2,
      injetando o `SumExpensesInRangeUseCase` de `expense`) e `getActiveBudgetUseCase` (clock, repository,
      port).
- [x] 8.2 Confirmar que `ExpenseFactory` já publica `SumExpensesInRangeUseCase` como bean consumível por
      `BudgetFactory`.

## 9. Testes de integração e fechamento

- [x] 9.1 Teste end-to-end HTTP de `GET /v1/budgets/active`: `200` com orçamento + gasto + restante quando
      há orçamento vivo cobrindo hoje e gastos no intervalo; `200` com `spentInCents = 0` quando não há
      gastos; `200` com `data: null` quando não há orçamento vivo cobrindo hoje; `200` com
      `remainingInCents` negativo quando o orçamento está estourado; `401` sem sessão — usando a harness
      Postgres e os fixtures de auth.
- [x] 9.2 Teste end-to-end confirmando que um gasto fora do intervalo do orçamento ativo não entra no
      `spentInCents`, e que um orçamento **removido** nunca aparece como ativo mesmo cobrindo hoje.
- [x] 9.3 Rodar `arch-review` sobre o diff (camadas/naming/HTTP), com atenção especial à direção da
      dependência cross-context (`budget → expense`, nunca o inverso) — confirmar que nenhum tipo de
      `expense` vaza para fora do adapter do item 5.2.
- [x] 9.4 `./gradlew build` e `./gradlew test` verdes.
- [x] 9.5 Atualizar o `README.md` do contexto `budget` se necessário e reconciliar specs (`/opsx:sync`)
      antes de arquivar.
