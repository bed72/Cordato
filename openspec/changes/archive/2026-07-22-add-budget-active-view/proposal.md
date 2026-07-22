## Why

Depois de `budget-create`, uma pessoa consegue criar um orçamento mas não tem nenhuma forma de perguntar
"qual é o meu orçamento de hoje, e quanto já gastei nele?" — a visão mais usada do dia a dia, segundo o
README do contexto (`src/main/kotlin/com/bed/cordato/features/budget/README.md`). Essa visão é sempre
derivada (nunca armazenada): o orçamento vivo cujo intervalo cobre a data de hoje, mais o gasto somado e o
restante calculados na hora a partir dos gastos daquele intervalo. Sem esse endpoint, o dado mais
importante do domínio de orçamento continua inacessível pela API.

## What Changes

- Adiciona `GET /budgets/active`: rota autenticada que devolve o orçamento vivo do ator cujo intervalo
  cobre a data de hoje, com `spentInCents` e `remainingInCents` derivados (nunca persistidos).
- Ausência de orçamento ativo (nenhum orçamento vivo cobre hoje) **não é erro**: `200 OK` com `data: null`,
  simétrico ao "página vazia" já usado em `GET /expenses` para "nada aqui agora" sem virar `404`.
- Introduz, no contexto `expense`, uma consulta somada por intervalo de datas para uma pessoa (o único tipo
  de pergunta que `expense` aceita de fora sobre seus próprios dados — nunca um gasto individual nem a
  lista deles, conforme o README de `budget`) — não expõe endpoint HTTP novo, é consumida in-process por
  `budget` via um port próprio (ADR 0013: Anti-Corruption Layer, `budget` define o port na própria
  linguagem, `expense` nunca conhece `budget`).

## Capabilities

### New Capabilities
- `budget-active-view`: a leitura `GET /budgets/active` — orçamento vivo de hoje + gasto somado + restante
  derivados, incluindo o caso "sem orçamento ativo".
- `expense-amount-query`: a consulta cross-context, somente leitura, do total gasto por uma pessoa num
  intervalo de datas — o contrato que `expense` expõe para outros contextos perguntarem por um total
  agregado, nunca por gastos individuais.

### Modified Capabilities
_(nenhuma — este change não altera requisitos já existentes de `budget-http-api`, `budget-persistence`,
`expense-http-api`, `expense-persistence` ou `http-response-envelope`; apenas os consome.)_

## Impact

- Novo `features/budget/application/driving/use_cases/GetActiveBudgetUseCase.kt` (ou nome equivalente) e
  seu command/result.
- Novo port `budget/application/driven/ports/ExpenseSpentAmountPort.kt` (ACL, ADR 0013) e o adapter
  correspondente em `budget/infrastructure/adapters/`.
- Novo `BudgetRepository.findLiveBudgetCovering(personId, date)` (ou equivalente) no port já existente do
  `budget`.
- Novo use case em `expense` (ex.: `SumExpensesInRangeUseCase`) e a consulta de soma no
  `ExpenseRepository` (adapter jOOQ com `SUM` no banco, não em memória).
- Nova rota `GET /budgets/active` em `BudgetController`/`BudgetControllerDoc`, novo response
  (`ActiveBudgetResponse` ou equivalente) e mapper.
- Nenhuma migração de schema nova — reusa as tabelas `budget` (V4) e `expense` (V3) existentes.
