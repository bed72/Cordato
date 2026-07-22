## Context

`budget-create` (arquivado) só cobre a escrita. O README de `budget` descreve a leitura mais usada do
dia a dia — o "orçamento ativo": o orçamento vivo cujo intervalo cobre hoje, com gasto e restante
derivados — e é explícito que `budget` "não sabe nada sobre gastos individuais. Pede apenas um total
somado, num intervalo, de uma pessoa". Este design cobre como expor essa leitura sem violar a fronteira
`expense`↔`budget` (unidirecional: `budget` pergunta a `expense`, nunca o contrário; `expense` nunca
conhece `budget`) nem a invariante derive-don't-store (nada disso é persistido).

`ADR 0013` (Cross-context communication) já define o padrão geral para esse tipo de leitura — foi escrito
pensando em `couple`, mas o mesmo padrão (ACL, consumidor define o port, chamada in-process ao use case
público do produtor) se aplica igualmente a `budget → expense`.

## Goals / Non-Goals

**Goals:**
- `GET /budgets/active` retorna o orçamento vivo de hoje do ator + `spentInCents` + `remainingInCents`,
  sempre recalculados na leitura.
- Ausência de orçamento ativo é modelada como sucesso, não erro.
- `expense` ganha uma nova pergunta pública — soma por intervalo de uma pessoa — sem que `budget` acesse o
  `ExpenseRepository` ou qualquer tipo interno de `expense` diretamente.

**Non-Goals:**
- Orçamento padrão ("sem orçamento") e orçamento do casal ficam para outro change — dependem desta leitura
  mas não fazem parte do escopo.
- Listagem geral de orçamentos (`GET /budgets`) fica para outro change.
- Nenhuma migração de schema nova.

## Decisions

### 1. `ActiveBudgetVirtualObject`, não uma extensão de `BudgetEntity`

`spentInCents`/`remainingInCents` nunca são `MoneyValueObject` (que exige `> 0` — `remaining` pode ser
negativo, `spent` pode ser `0`). Conforme ADR 0001, essa projeção enriquecida (entidade real + valores
derivados, sem identidade própria) é exatamente o exemplo dado pelo ADR ("the enriched active budget") —
vai em `budget/domain/virtual_objects/ActiveBudgetVirtualObject.kt`, um `data class` simples que compõe o
`BudgetEntity` vivo mais os dois `Long` derivados.

### 2. `GetActiveBudgetUseCase` retorna `ActiveBudgetVirtualObject?` direto, sem `Result` selado

Mesma postura que `ListExpensesUseCase` (que devolve `ExpensePageVirtualObject` direto, sem
`Result`/`Error`): "não ter orçamento ativo hoje" não é uma falha de domínio honesta — é uma resposta
válida e comum, análoga a "página vazia". Um `Result` selado inventaria uma distinção sucesso/falha que não
existe; a ausência já é representável pelo próprio tipo de retorno (`null`).

### 3. `BudgetRepository.findLiveBudgetCovering(personId, date): BudgetEntity?`

Novo método no port já existente (mesmo estilo de `hasOverlappingLiveBudget`): resolvido inteiramente no
banco (`WHERE person_id = ? AND status = LIVE AND start_date <= ? AND end_date >= ?`), nunca carregando
linhas para filtrar em memória. A invariante de não-sobreposição do `budget` já garante que, para uma
pessoa, no máximo um orçamento vivo cobre qualquer data — a consulta pode assumir cardinalidade 0 ou 1 sem
precisar de `ORDER BY`/`LIMIT` para desempate.

### 4. A pergunta cross-context é um novo use case público em `expense`, não uma nova rota HTTP

`ADR 0013` diz que o adapter do consumidor chama "o use case público existente" do produtor. Hoje `expense`
não expõe nenhum que resuma um total — então este change adiciona um (`SumExpensesInRangeUseCase`), no
mesmo padrão de `ListExpensesUseCase`: `operator fun invoke(command): Long` direto, sem `Result` (somar não
tem falha de domínio honesta; "zero gastos" é `0L`, não erro). É a única pergunta que `expense` responde a
quem está de fora sobre os próprios dados: um total agregado por intervalo, nunca um gasto individual nem a
lista deles — reforçando o README de `expense` ("Não conhece orçamentos... o relacionamento é
unidirecional").

A soma em si SHALL ser resolvida no banco (`SUM(amount_cents)` com `COALESCE(..., 0)`), nunca carregando
gastos para somar em memória — mesmo espírito de "resolvido inteiramente no datastore" já aplicado em
`hasOverlappingLiveBudget`.

### 5. ACL: `budget` define `ExpenseSpentAmountPort`, `budget/infrastructure/adapters/` chama o use case de `expense` in-process

```
budget/application/driven/ports/ExpenseSpentAmountPort.kt   (fun interface, vocabulário do budget)
budget/infrastructure/adapters/ExpenseSpentAmountAdapter.kt (implementa o port; injeta SumExpensesInRangeUseCase de expense)
```

`budget/domain` e `budget/application` nunca importam nada de `expense` além do port. `expense` nunca
importa nada de `budget` — a dependência é estritamente `budget → expense`, mantendo o `expense` alheio à
existência de orçamentos, exatamente como o README exige. `BudgetFactory` (`@Factory`) monta o adapter
injetando o bean `SumExpensesInRangeUseCase` que `ExpenseFactory` já publica — chamada in-process, sem HTTP
interno, como o ADR prescreve.

### 6. Ausência de orçamento ativo responde `200` com `data: null`, nunca `404`

Simétrico à decisão já tomada em `expense-list` (pessoa sem gastos → `200` com página vazia, não `404`): a
ausência de um orçamento ativo hoje é um estado normal do domínio ("é aí que a visão de orçamento padrão
entra"), não um erro de rota. `DataResponse<T>.data` já é `@JsonInclude(ALWAYS)` (para páginas vazias);
`ok<ActiveBudgetResponse?>(null)` reutiliza o builder existente sem qualquer mudança em `core` — `T` sendo
um tipo nulável é só um argumento de tipo diferente, o envelope já serializa `"data": null` corretamente. O
Doc anota o schema de sucesso como `nullable = true`.

### 7. `spentInCents`/`remainingInCents` na resposta HTTP são `Long` crus, não aninhados

Mantém o mesmo estilo já usado por `BudgetResponse.amountInCents` (plano, sem VO na borda). O novo
`ActiveBudgetResponse` estende esse padrão: `id`, `amountInCents`, `spentInCents`, `remainingInCents`,
`startDate`, `endDate`, `note?`.

## Risks / Trade-offs

- **[Risco]** Uma nova pergunta pública em `expense` (`SumExpensesInRangeUseCase`) amplia levemente a
  superfície pública desse contexto → **Mitigação:** ela responde só a um total agregado por intervalo,
  nunca a um gasto individual — o README de `budget` já antecipa exatamente esse contrato ("pede apenas um
  total somado"), então não é uma superfície nova e sim a que o domínio já previa.
- **[Risco]** `findLiveBudgetCovering` assume no máximo um resultado vivo por pessoa/data, dependendo
  inteiramente da invariante de não-sobreposição de `budget-create` continuar valendo → **Mitigação:** a
  invariante já é reforçada no `create`; se algum dia for violada por um bug em outro caminho, a consulta
  deve preferir determinismo (ex.: `LIMIT 1` ordenado) a lançar erro — decisão que fica registrada aqui para
  não ser esquecida na implementação.

## Open Questions

_(nenhuma pendente — as decisões acima cobrem os pontos que a proposta deixou em aberto: shape da ausência
de orçamento ativo e o contrato cross-context.)_
