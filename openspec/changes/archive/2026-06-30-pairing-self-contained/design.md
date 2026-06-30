## Context

Os gateways em `pairing/infrastructure/gateways/` importam diretamente interfaces de outros feature modules, violando o isolamento de módulos. A regra é absoluta: nenhum arquivo fora de `main/` importa de outro feature module.

Dois problemas distintos:

1. **SpendReaderInterface e SpendReader estão no module errado.** São usados por budgeting (`get_active_budget_use_case`) e pairing (`PartnerBudgetReader`). Pertencem ao `core/`.

2. **Os gateways cross-feature de pairing recebem tipos de outros features no construtor.** `PersonDirectory(PersonRepositoryInterface)`, `PartnerExpenseReader(ExpenseRepositoryInterface)`, `PartnerBudgetReader(BudgetRepositoryInterface, SpendReaderInterface)` — todos importam de outros modules.

## Goals / Non-Goals

**Goals:**
- Zero imports cross-feature fora de `main/`
- `SpendReaderInterface` e `SpendReader` em `core/` — shared kernel
- Gateways de pairing recebem apenas tipos do próprio `pairing/` ou do `core/` — nunca de outros features
- Todo mapeamento cross-feature fica nos composition roots (`main/`)

**Non-Goals:**
- Criar novas ABCs em `core/` que repliquem conceitos de outros features — isso seria duplicação
- Resolver o isolamento pré-ORM (stores em memória separados) — aceito como trade-off
- Alterar qualquer comportamento HTTP, domínio ou contrato de API

## Decisions

### SpendReaderInterface e SpendReader vão para core/

`SpendReaderInterface` usa apenas `MoneyValueObject` do core — zero dependência de feature. `SpendReader` implementa essa interface; para não criar dependência de `core/` em `expenses/`, recebe um `Callable[[str, date, date], Awaitable[list[Decimal]]]`. O callable é fornecido pelo composition root de cada feature consumidora. Nenhum conceito de expenses entra no core; nenhuma ABC nova é criada.

### Gateways de pairing recebem Callables com tipos de pairing

Os três gateways cross-feature implementam ports definidos em `pairing/application/interfaces/`. Seus construtores passam a receber Callables cujas assinaturas usam apenas tipos já em `pairing/` ou primitivos:

| Gateway | Callable recebido | Tipo de retorno |
|---|---|---|
| `PersonDirectory` | `Callable[[str], Awaitable[PartnerProfileData \| None]]` | tipo de pairing |
| `PartnerExpenseReader` | `Callable[[str], Awaitable[list[PartnerExpenseData]]]` | tipo de pairing |
| `PartnerBudgetReader` | `Callable[[str, date], Awaitable[PartnerActiveBudgetData \| None]]` | tipo de pairing |

Os gateways tornam-se adaptadores thin — delegam inteiramente ao callable. Não há ABCs novas em `core/`; não há conceitos de outros features duplicados.

### O composition root (pairing_route.py) faz o mapeamento cross-feature

`pairing_route.py` é o único arquivo permitido a importar de múltiplos features. Ele instancia `PersonRepository`, `ExpenseRepository`, `BudgetRepository`, `SpendReader` e constrói funções async que mapeiam entidades para DTOs de pairing, por exemplo:

```python
expense_repo = ExpenseRepository()

async def _list_partner_expenses(person_id: str) -> list[PartnerExpenseData]:
    expenses = await expense_repo.list_live_for_person(person_id)
    return [PartnerExpenseData(id=e.id, ...) for e in expenses]

partner_expense_reader = PartnerExpenseReader(list_expenses=_list_partner_expenses)
```

### gateways/ nunca importa de outro feature — sem exceções

A decisão anterior ("importar de outro feature dentro de `gateways/` é o único ponto sancionado") estava errada. O único ponto sancionado é `main/`. `gateways/`, `repositories/`, `domain/`, `application/` são todos isolados entre features.

## Risks / Trade-offs

**Gateways thin:** `PartnerBudgetReader`, por exemplo, passa a ser uma classe de 4 linhas que apenas chama o callable. A lógica de compor `BudgetRepository + SpendReader` move para o composition root como uma função async. Aceitável — a função no composition root é testável e a classe mantém a interface tipada.

**Callables em vez de ABCs para dependências de gateway:** Não cria nova ABC em core — o callable é suficientemente tipado com `Callable[..., Awaitable[...]]`. Se no futuro a dependência crescer (ex: dois métodos), converte em ABC no próprio `pairing/application/interfaces/` sem tocar core.

**Isolamento em memória pré-ORM:** Aceito como limitação temporária — resolvido naturalmente quando o ORM chegar.
