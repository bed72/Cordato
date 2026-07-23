## Context

`budget-active-view` (arquivado) cobre "qual é o meu orçamento de hoje", e deliberadamente adiou o caso
complementar: quando **não** há orçamento vivo cobrindo uma data, os gastos daquele período (e de
qualquer outro período sem orçamento vivo) ficam sem nenhuma leitura própria na API — apesar de o README
do contexto já nomear essa visão como "orçamento padrão" e explicar seu papel ("para que nenhum gasto
fique sem lugar nenhum para aparecer nas telas da pessoa"). Este design cobre como expor essa leitura sem
violar a mesma fronteira já estabelecida (`budget → expense`, unidirecional, ACL via ADR 0013) nem a
invariante derive-don't-store.

O README é explícito que o orçamento padrão é "um agrupamento fabricado, não um orçamento de verdade" —
não tem `id`, `amountInCents` nem `note`; a única coisa que faz sentido nele é o total gasto.

## Goals / Non-Goals

**Goals:**
- `GET /budgets/default` retorna `spentInCents`: a soma, em centavos, de todos os gastos vivos do ator
  que não caem em nenhum orçamento vivo dele, recalculada a cada leitura.
- Sempre `200 OK` — o agrupamento fabricado sempre "existe", mesmo que o total seja `0`. Não há um
  conceito de "ausência" aqui como havia em `budget-active-view` (`data: null`), porque não há uma
  entidade sendo procurada — é sempre um número.
- `expense` ganha uma segunda pergunta pública agregada (soma total, sem intervalo) sem que `budget`
  acesse o `ExpenseRepository` ou qualquer tipo interno de `expense`.

**Non-Goals:**
- Listar os próprios gastos órfãos (quais gastos, individualmente, caíram fora de orçamento) fica fora de
  escopo — o endpoint devolve só o total, no mesmo espírito de `budget-active-view` devolver
  `spentInCents` sem listar os gastos que compõem a soma. Quem precisar da lista bruta já tem
  `GET /expenses`.
- Orçamento do casal continua fora de escopo (depende do contexto `couple`, ainda inexistente).
- Nenhuma migração de schema nova.

## Decisions

### 1. Cálculo por subtração: total geral menos a soma de cada orçamento vivo

A alternativa mais direta seria pedir a `expense` uma soma "excluindo estes intervalos" — mas isso
obrigaria `expense` a entender o conceito de "lista de intervalos a excluir", que é vocabulário de
`budget` (a lista de orçamentos vivos de uma pessoa) vazando para dentro de um contexto que o README
proíbe explicitamente de conhecer orçamentos. Em vez disso, `budget` calcula:

```
spentInCents = totalSpent(pessoa) - Σ spentInRange(pessoa, orçamento.período) para cada orçamento vivo
```

`totalSpent` é a nova pergunta (soma sem intervalo); `spentInRange` já existe (`ExpenseSpentAmountPort`,
de `budget-active-view`). Como a invariante de não-sobreposição de `budget-create` garante que os
orçamentos vivos de uma pessoa nunca compartilham nem um dia de fronteira, somar cada intervalo
separadamente e subtrair do total nunca conta o mesmo gasto duas vezes e nunca deixa de descontar um
gasto que pertence a um orçamento.

**Alternativa considerada e rejeitada:** uma única consulta SQL com `NOT (data BETWEEN ... OR data
BETWEEN ...)` para todos os intervalos de uma vez, resolvendo tudo em uma soma só. Seria mais eficiente
(uma query em vez de N+1), mas exigiria que `expense` recebesse e entendesse uma lista de intervalos
vindos de fora —o mesmo vazamento de vocabulário do parágrafo anterior. Como o número de orçamentos
vivos de uma pessoa é sempre pequeno (a invariante de não-sobreposição impede acumular dezenas de
orçamentos simultâneos), o custo de N+1 chamadas in-process (nunca chamadas de rede — é tudo no mesmo
processo) é desprezível; a pureza da fronteira venceu a otimização.

### 2. Nova pergunta pública em `expense`: `SumAllExpensesUseCase`, sem intervalo

Mesmo padrão de `SumExpensesInRangeUseCase`: `operator fun invoke(command): Long` direto, sem `Result`
selado (somar não tem falha de domínio honesta). Result do repositório via `ExpenseRepository.sumAmount
(personId): Long`, resolvido no banco (`COALESCE(SUM(amount_cents), 0)`), nunca carregando gastos para
somar em memória — mesmo espírito de `sumAmountInRange`. A capability `expense-amount-query` passa a
cobrir as duas perguntas (com intervalo e sem intervalo), ambas agregadas, nenhuma expondo gasto
individual.

### 3. `BudgetRepository.findAllLiveBudgets(personId): List<BudgetEntity>`

Novo método no port já existente, resolvido inteiramente no banco (`WHERE person_id = ? AND status =
LIVE`), sem `ORDER BY` exigido (a soma é comutativa, a ordem não importa). Reaproveita a tabela `budget`
existente.

### 4. ACL: `budget` define `ExpenseTotalSpentPort`, novo adapter

```
budget/application/driven/ports/ExpenseTotalSpentPort.kt   (fun interface: operator fun invoke(personId): Long)
budget/infrastructure/adapters/ExpenseTotalSpentAdapter.kt  (chama SumAllExpensesUseCase de expense in-process)
```

Mesmo padrão de `ExpenseSpentAmountPort`/`ExpenseSpentAmountAdapter` já existentes — `budget/domain` e
`budget/application` nunca importam nada de `expense` além dos dois ports; `expense` nunca importa nada
de `budget`.

### 5. `GetDefaultBudgetUseCase` retorna `Long` direto, sem `Result` selado nem virtual object

Diferente de `ActiveBudgetVirtualObject` (que enriquece uma entidade real com valores derivados), aqui não
há entidade nenhuma — é sempre só o número. Um virtual object de um único campo não agregaria nada; o
use case devolve `Long` diretamente, mesma postura de `SumExpensesInRangeUseCase`/`SumAllExpensesUseCase`
(somar não tem falha de domínio honesta, e o "não existir" não se aplica aqui — é sempre uma soma, mesmo
que `0`).

### 6. Resposta HTTP sempre `200`, nunca `data: null`

Ao contrário de `GET /budgets/active` (onde a ausência de orçamento ativo é modelada como `data: null`),
aqui `data` é sempre um objeto presente com `spentInCents` — não há "ausência" a modelar, porque o
agrupamento é fabricado e sempre "existe". `DefaultBudgetResponse(spentInCents: Long)` é o único campo,
sem `id`/`amountInCents`/`note` (não há orçamento real por trás).

## Risks / Trade-offs

- **[Risco]** N+1 chamadas in-process (uma por orçamento vivo da pessoa) em vez de uma única query
  agregada → **Mitigação:** aceito deliberadamente (Decisão 1) porque o volume de orçamentos vivos
  simultâneos de uma pessoa é sempre pequeno (a invariante de não-sobreposição impede acúmulo), e
  chamadas in-process não pagam custo de rede — o ganho de manter `expense` alheio ao vocabulário de
  `budget` supera o custo.
- **[Risco]** Se a invariante de não-sobreposição de `budget-create` for violada por um bug futuro, a
  subtração passaria a contar gastos de orçamentos sobrepostos mais de uma vez, produzindo
  `spentInCents` menor do que o real (podendo até ficar negativo) → **Mitigação:** a invariante já é
  reforçada no `create` e teria de ser quebrada por um bug em outro caminho para este risco se
  materializar; mesma dependência que `budget-active-view`'s `findLiveBudgetCovering` já assume e aceita.

## Open Questions

_(nenhuma pendente — as decisões acima cobrem o shape da resposta e o contrato cross-context.)_
