# `expenses/` — o gasto

O gasto é o **fato atômico** do domínio: quem gastou, quanto, em que dia. Nada mais. É a verdade-base de
onde todos os agregados de orçamento são derivados.

## Responsabilidade

- **Registrar** um gasto (`record-expense`).
- Ser a fonte que **deriva** o pertencimento a budget: `find_in_range(person, start, end)` soma os gastos
  de uma pessoa num intervalo — é assim que budgeting calcula spend, **sem foreign key**.

### O que ele deliberadamente NÃO faz

- **Zero link a Budget.** Um gasto **não aponta** para orçamento nenhum. O pertencimento é puramente por
  contenção de data, calculado em tempo de leitura. Editar/apagar/criar um budget nunca toca um gasto.
- **Um gasto é um fato, não um arquivamento.** O spend aconteceu numa data, por um valor, por alguém —
  verdade independente de como os orçamentos são fatiados depois. Sem órfãos, sem link pendurado, sem
  contagem dupla.

> O campo do dia chama-se `occurred_on` (não `date`): revela a intenção e evita sombrear o tipo `date`.

## Vocabulário

| Termo | É | Significa |
|---|---|---|
| `ExpenseEntity` | entidade | O fato atômico. Igualdade por `id`. `amount` deve ser > 0. |
| `occurred_on` | `date` | O dia do gasto — sem hora; **a única base** do pertencimento a budget. |
| `find_in_range` | método de porta | A query que **deriva** expense→budget sem FK. |

## Mapa do módulo

| Camada | Arquivo | Papel |
|---|---|---|
| domain / entities | `expense_entity.py` | O gasto; factory `create(...)` recusa valor ≤ 0. |
| domain / errors | `invalid_amount_error.py` | Recusa de valor não-positivo. |
| application / data | `create_expense_data.py` (comando) · `expense_data.py` (read-model) | Entrada/saída. |
| application / interfaces | `expense_repository_interface.py` | Porta: `create` + `find_in_range`. |
| application / use_cases | `create_expense_use_case.py` | Orquestra: monta o `MoneyValueObject`, nasce a entidade, persiste. |
| application / mappers | `expense_data_mapper.py` | `Entity → Data`. |
| infrastructure / repositories | `expense_repository.py` | Adapter in-memory (por enquanto). |

## A ponte com budgeting (sem acoplamento)

Budgeting precisa de spend mas não importa expenses. Ele declara a necessidade nos **seus próprios
termos** via `SpendReaderInterface` (devolve um total, nunca uma lista de gastos). O adapter que soma o
ledger vive **fora** do domínio/application de budgeting — hoje no composition root, amanhã uma query de
banco compartilhado. `find_in_range` deste módulo é o que alimenta esse leitor.

## Estado atual vs. deferido

Vertical slice in-memory: `expense_repository.py` é em memória. **Deferido:** `ExpenseModel`/
`ExpenseModelMapper` (entram com o ORM) e o **soft-delete** efetivo (`deleted_at` já existe na entidade;
a exclusão como caso de uso ainda não foi modelada).

## Onde aprofundar

- **Convenções** → [`../../../../CLAUDE.md`](../../../../CLAUDE.md) (entidade *Expense*, *derive, don't store*)
- **Comportamento** → `openspec/specs/record-expense/spec.md`
