## 1. Persistência — soma total de gastos, sem intervalo (`expense`)

- [x] 1.1 Adicionar `ExpenseRepository.sumAmount(personId): Long` (port em
      `features/expense/application/driven/repositories/ExpenseRepository.kt`), resolvido inteiramente no
      banco (`SUM(amount_cents)` com `COALESCE(..., 0)`), sem filtro de data, reusando a tabela `expense`
      existente (V3), sem nova migração.
- [x] 1.2 Implementar a consulta no `PersistenceExpenseRepository` (jOOQ), filtrando só por `person_id`.
- [x] 1.3 Teste de integração da consulta na harness Postgres: soma correta de todos os gastos da pessoa,
      `0` sem gastos, gastos de outra pessoa não entram na soma.

## 2. Aplicação — `SumAllExpensesUseCase` (`expense`)

- [x] 2.1 Criar `features/expense/application/driving/commands/SumAllExpensesCommand.kt` (`personId`).
- [x] 2.2 Criar `features/expense/application/driving/use_cases/SumAllExpensesUseCase.kt`:
      `operator fun invoke(command): Long` direto (sem `Result` selado — somar não tem falha de domínio
      honesta, mesma postura de `SumExpensesInRangeUseCase`), delegando ao
      `ExpenseRepository.sumAmount`.
- [x] 2.3 Registrar o bean em `ExpenseFactory` (`@Factory`).
- [x] 2.4 Testes do use case com fake `ExpenseRepository` (convenções de `factories/`): soma correta, `0`
      sem gastos.

## 3. Persistência — todos os orçamentos vivos de uma pessoa (`budget`)

- [x] 3.1 Adicionar `BudgetRepository.findAllLiveBudgets(personId): List<BudgetEntity>` (port em
      `features/budget/application/driven/repositories/BudgetRepository.kt`), resolvido inteiramente no
      banco (`WHERE person_id = ? AND status = LIVE`), reusando a tabela `budget` existente (V4), sem
      nova migração.
- [x] 3.2 Implementar a consulta no `PersistenceBudgetRepository` (jOOQ), mapeando os records de volta
      para `BudgetEntity` via o mapper existente; lista vazia quando a pessoa não tem orçamento vivo.
- [x] 3.3 Teste de integração da consulta na harness Postgres: encontra todos os orçamentos vivos da
      pessoa, lista vazia sem orçamento vivo, orçamento removido nunca aparece na lista, orçamentos de
      outra pessoa nunca aparecem.

## 4. ACL cross-context — `budget` pergunta a `expense` pelo total geral

- [x] 4.1 Criar `features/budget/application/driven/ports/ExpenseTotalSpentPort.kt` (`fun interface`, no
      vocabulário do `budget`: `operator fun invoke(personId): Long`).
- [x] 4.2 Criar `features/budget/infrastructure/adapters/ExpenseTotalSpentAdapter.kt`, implementando o
      port por chamada in-process ao `SumAllExpensesUseCase` de `expense` (injetado via construtor).
      Confirmar que `budget/domain` e `budget/application` não importam nenhum tipo de `expense` além
      deste port e do `ExpenseSpentAmountPort` já existente.
- [x] 4.3 Teste do adapter com fake/mock do `SumAllExpensesUseCase` confirmando a tradução de parâmetros
      e retorno.

## 5. Aplicação — `GetDefaultBudgetUseCase` (`budget`)

- [x] 5.1 Criar `features/budget/application/driving/commands/GetDefaultBudgetCommand.kt` (`personId`).
- [x] 5.2 Criar `features/budget/application/driving/use_cases/GetDefaultBudgetUseCase.kt`:
      `operator fun invoke(command): Long` direto (sem `Result` selado nem virtual object — não há
      entidade nenhuma por trás, só o número). Busca o total geral via `ExpenseTotalSpentPort`, busca
      todos os orçamentos vivos via `BudgetRepository.findAllLiveBudgets`, soma o gasto de cada um via
      `ExpenseSpentAmountPort` (já existente) e subtrai do total geral.
- [x] 5.3 Testes do use case com fakes de `BudgetRepository`/`ExpenseTotalSpentPort`/
      `ExpenseSpentAmountPort`: sem orçamento vivo (retorna o total geral integralmente), com um
      orçamento vivo cobrindo parte dos gastos (retorna só o restante), com múltiplos orçamentos vivos
      não sobrepostos, sem nenhum gasto (retorna `0`), todos os gastos cobertos por orçamentos vivos
      (retorna `0`).

## 6. Slice HTTP do orçamento padrão (`budget`)

- [x] 6.1 Criar `features/budget/infrastructure/http/responses/DefaultBudgetResponse.kt` (`@Serdeable`,
      `@Schema`; único campo `spentInCents`).
- [x] 6.2 Criar o mapper `mappers/responses/` (`Long.toDefaultBudgetResponse()` ou equivalente).
- [x] 6.3 Adicionar `@Get("/default")` `@Authenticated` em `BudgetController`, lendo o
      `AuthenticatedActor`, chamando `GetDefaultBudgetUseCase`, respondendo `ok(response)` do `core` —
      sempre não-nulo (nunca `data: null`, ao contrário de `/active`).
- [x] 6.4 Atualizar `BudgetControllerDoc`: `@Operation`/`@ApiResponse` para `200` (schema de sucesso com
      `data` não nulável) e as respostas de erro (`401`/`500`) no envelope `errors`.
- [x] 6.5 Adicionar as chaves i18n necessárias (se alguma mensagem legível for introduzida) em
      `src/main/resources/i18n/messages.properties`. (N/A: nenhuma mensagem legível nova foi introduzida —
      a rota nunca falha por regra de domínio.)

## 7. Fiação (DI)

- [x] 7.1 Atualizar `BudgetFactory` (`@Factory`): publicar `expenseTotalSpentPort` (o adapter do item
      4.2, injetando o `SumAllExpensesUseCase` de `expense`) e `getDefaultBudgetUseCase` (repository,
      `ExpenseTotalSpentPort`, `ExpenseSpentAmountPort`).
- [x] 7.2 Confirmar que `ExpenseFactory` já publica `SumAllExpensesUseCase` como bean consumível por
      `BudgetFactory`.

## 8. Testes de integração e fechamento

- [x] 8.1 Teste end-to-end HTTP de `GET /v1/budgets/default`: `200` com `spentInCents` correto quando há
      gastos fora de qualquer orçamento vivo; `200` com `spentInCents = 0` quando todos os gastos estão
      cobertos por orçamentos vivos; `200` com `spentInCents = 0` sem nenhum gasto registrado; `401` sem
      sessão — usando a harness Postgres e os fixtures de auth.
- [x] 8.2 Teste end-to-end confirmando que um gasto que caía no intervalo de um orçamento **removido**
      volta a contar em `spentInCents`, e que orçamentos/gastos de outra pessoa nunca entram no cálculo.
- [x] 8.3 Rodar `arch-review` sobre o diff (camadas/naming/HTTP), com atenção especial à direção da
      dependência cross-context (`budget → expense`, nunca o inverso) — confirmar que nenhum tipo de
      `expense` vaza para fora dos adapters dos itens 4.2 e o já existente `ExpenseSpentAmountAdapter`.
      (2 violações de ordenação de imports corrigidas em `BudgetFactory.kt`/`ExpenseFactory.kt`/
      `SumAllExpensesUseCase.kt`; nada mais encontrado.)
- [x] 8.4 `./gradlew build` e `./gradlew test` verdes.
- [x] 8.5 Atualizar o `README.md` do contexto `budget` se necessário e reconciliar specs (`/opsx:sync`)
      antes de arquivar. (README já descrevia o orçamento padrão corretamente, sem alterações
      necessárias; specs sincronizadas: novo `openspec/specs/budget-default-view/spec.md` e
      `expense-amount-query` atualizado com a segunda pergunta agregada.)
