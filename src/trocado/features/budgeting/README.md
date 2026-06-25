# `budgeting/` — o orçamento

O orçamento é um **teto planejado** sobre um intervalo de datas inclusivo, de uma pessoa. O gasto e o
saldo **não são guardados** — são derivados em tempo de leitura a partir dos expenses que caem no
intervalo. É o módulo onde o princípio *derive, don't store* aparece com mais força.

## Responsabilidade

- **Criar** um orçamento (`create-budget`), respeitando o invariante de **não-sobreposição**.
- **Derivar** o orçamento ativo enriquecido (`active-budget`): o budget vivo cujo intervalo contém o dia,
  somado ao spend e com o `remaining` calculado.

### O que ele deliberadamente NÃO faz

- **Não guarda lista de expenses.** Um budget não tem coleção de gastos; o spend é computado por
  contenção de data. Editar datas ou apagar um budget nunca reescreve nada nos gastos.
- **Não importa o módulo de expenses.** Ele pede spend nos seus **próprios termos** por uma porta
  (`SpendReaderInterface`, que devolve um total, nunca um gasto). Depende só dessa abstração e do core.
- **Não persiste objetos virtuais.** O orçamento ativo, o "No budget" e o orçamento de casal são
  projeções de leitura — nunca viram linha no banco.

## Vocabulário

| Termo | É | Significa |
|---|---|---|
| `BudgetEntity` | entidade | Teto por intervalo `[start_date, end_date]` **inclusivo nas duas pontas**, sem hora. Igualdade por `id`. `amount` > 0; `start ≤ end`. |
| Invariante de não-sobreposição | regra de domínio | Dois budgets **vivos** da mesma pessoa não compartilham nenhum dia, nem o de fronteira (termina dia 15, próximo começa dia 16 ✅; começa dia 15 ❌). É o que torna "o orçamento ativo" inequívoco. |
| `ActiveBudgetVirtualObject` | **virtual object** | Compõe um `BudgetEntity` vivo + `total_spent` e deriva `remaining = amount − total_spent` (negativo se estourou). Nem entidade nem value object — referencia uma entidade e nada valida. Nunca persistido. |
| `SpendReaderInterface` | porta (gateway) | `async total_spent(person_id, start, end) -> MoneyValueObject`. Lê dado que budgeting não possui; é gateway, não repository. |
| Default budget ("No budget") | virtual object (planejado) | Balde fabricado para agrupar gastos que não caem em budget real. |
| Couple budget | virtual object (planejado) | Lente combinada do par — `[min(starts), max(ends)]`, soma de valores e gastos. Aproximada de propósito. |

## Mapa do módulo

| Camada | Arquivo | Papel |
|---|---|---|
| domain / entities | `budget_entity.py` | O teto; factory `create(...)`, método `overlaps(...)`. |
| domain / virtual_objects | `active_budget_virtual_object.py` | Projeção enriquecida; `remaining` é regra de domínio. |
| domain / errors | `invalid_budget_amount_error.py` · `invalid_budget_range_error.py` · `overlapping_budget_error.py` | Recusas de valor, intervalo e sobreposição. |
| application / data | `create_budget_data.py` (comando) · `budget_data.py` · `active_budget_data.py` (read-models) | Entrada/saída. |
| application / interfaces | `budget_repository_interface.py` · `spend_reader_interface.py` | Portas ABC. |
| application / use_cases | `create_budget_use_case.py` · `get_active_budget_use_case.py` | Criar (com checagem de overlap) e derivar o ativo. |
| application / mappers | `budget_data_mapper.py` · `active_budget_data_mapper.py` | `Entity/VO → Data`. |
| infrastructure / repositories | `budget_repository.py` | Adapter in-memory; reads só de budgets **vivos**. |

## Detalhes de orquestração

- **Criar:** monta o `MoneyValueObject`, pega `id`/`created_at` via `asyncio.gather`, nasce a entidade,
  lista os budgets vivos da pessoa e recusa com `OverlappingBudgetError` se qualquer um sobrepõe; só então
  persiste.
- **Ativo:** `find_active_for_person(person, day)` devolve no máximo um budget (graças à não-sobreposição);
  o use case soma o spend pela porta e devolve o virtual object mapeado — ou `None` se não há ativo.

## Estado atual vs. deferido

Vertical slice in-memory: `budget_repository.py` é em memória; o `SpendReader` é ligado no composition
root. **Deferido:** `BudgetModel`/`BudgetModelMapper` (ORM), o **default budget** e o **couple budget**
(virtual objects ainda não modelados), e o soft-delete como caso de uso (`deleted_at` já existe).

## Onde aprofundar

- **Convenções** → [`../../../../CLAUDE.md`](../../../../CLAUDE.md) (entidade *Budget*, *Virtual objects*)
- **Comportamento** → `openspec/specs/create-budget/spec.md` · `openspec/specs/active-budget/spec.md`
