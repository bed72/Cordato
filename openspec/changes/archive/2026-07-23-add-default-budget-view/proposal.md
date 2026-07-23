## Why

Depois de `budget-active-view`, uma pessoa sem orçamento vivo cobrindo hoje recebe `data: null` em
`GET /budgets/active` e fica sem nenhuma forma de perguntar "quanto eu gastei fora de qualquer orçamento
meu?" — o README do contexto (`src/main/kotlin/com/bed/cordato/features/budget/README.md`) chama essa
visão de **orçamento padrão** ("sem orçamento"): um agrupamento fabricado, não um orçamento de verdade,
que reúne os gastos de uma pessoa que não caem em nenhum orçamento real e vivo dela. Esse design já havia
sido explicitamente adiado no design de `budget-active-view` ("Orçamento padrão... fica para outro
change — depende desta leitura mas não faz parte do escopo"). Sem esse endpoint, todo gasto feito fora de
um período planejado permanece invisível na API, mesmo existindo no banco.

## What Changes

- Adiciona `GET /budgets/default`: rota autenticada que devolve `spentInCents` — a soma, em centavos, dos
  gastos do ator que não caem em nenhum orçamento **vivo** dele. Sempre `200 OK` (nunca `404`): o
  agrupamento é fabricado e sempre "existe", mesmo que o valor seja `0`.
- Estende a capability `expense-amount-query` com uma segunda pergunta agregada pública: a soma, em
  centavos, de **todos** os gastos de uma pessoa (sem limite de intervalo) — usada para derivar o total
  fora de orçamento por subtração, já que `budget` nunca sabe listar gastos individuais nem pode pedir a
  `expense` uma soma "excluindo intervalos" (isso vazaria vocabulário de `budget` para dentro de
  `expense`).
- `budget` ganha `BudgetRepository.findAllLiveBudgets(personId)`, para somar o gasto de cada orçamento
  vivo da pessoa e subtrair do total — os orçamentos de uma pessoa nunca se sobrepõem (invariante já
  garantida por `budget-create`), então a subtração não corre risco de contar duas vezes o mesmo gasto.

## Capabilities

### New Capabilities
- `budget-default-view`: a leitura `GET /budgets/default` — o gasto somado, derivado e nunca persistido,
  de todos os gastos vivos de uma pessoa que não caem em nenhum orçamento real e vivo dela.

### Modified Capabilities
- `expense-amount-query`: ganha uma segunda pergunta agregada — soma total (sem intervalo) dos gastos de
  uma pessoa — mantendo a mesma postura de "nunca um gasto individual, nunca a lista deles".

## Impact

- Novo `features/budget/application/driving/use_cases/GetDefaultBudgetUseCase.kt` (ou nome equivalente) +
  command.
- Novo port `budget/application/driven/ports/ExpenseTotalSpentPort.kt` (ACL, ADR 0013) + adapter
  correspondente.
- Novo método `BudgetRepository.findAllLiveBudgets(personId): List<BudgetEntity>`.
- Novo caso de uso público em `expense` (ex.: `SumAllExpensesUseCase`) + método
  `ExpenseRepository.sumAmount(personId): Long` (soma no banco, sem intervalo).
- Nova rota `GET /budgets/default` em `BudgetController`/`BudgetControllerDoc`, novo response
  (`DefaultBudgetResponse` ou equivalente, apenas `spentInCents`) e mapper.
- Nenhuma migração de schema nova — reusa as tabelas `budget` (V4) e `expense` (V3) existentes.
