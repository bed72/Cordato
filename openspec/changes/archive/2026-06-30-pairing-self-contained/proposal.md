## Why

Os gateways em `pairing/infrastructure/gateways/` importam diretamente interfaces de outros feature modules (`ExpenseRepositoryInterface` de expenses, `BudgetRepositoryInterface` e `SpendReaderInterface` de budgeting, `PersonRepositoryInterface` de identity). A regra é absoluta: nenhum arquivo fora de `main/` importa de outro feature module. O único ponto de cruzamento sancionado é `main/`.

`SpendReaderInterface` e `SpendReader` aparecem em dois features (budgeting e pairing): pertencem ao `core/`.

## What Changes

- `SpendReaderInterface` move de `budgeting/application/interfaces/` para `core/application/interfaces/`
- `SpendReader` move para `core/infrastructure/gateways/`; seu construtor passa a receber `Callable[[str, date, date], Awaitable[list[Decimal]]]` em vez de `ExpenseRepositoryInterface` — sem cross-feature import, sem conceitos de expenses no core
- `PersonDirectory` permanece em `pairing/infrastructure/gateways/`; construtor passa a receber `Callable[[str], Awaitable[PartnerProfileData | None]]` em vez de `PersonRepositoryInterface`
- `PartnerExpenseReader` permanece em `pairing/infrastructure/gateways/`; construtor passa a receber `Callable[[str], Awaitable[list[PartnerExpenseData]]]` em vez de `ExpenseRepositoryInterface`
- `PartnerBudgetReader` permanece em `pairing/infrastructure/gateways/`; construtor passa a receber `Callable[[str, date], Awaitable[PartnerActiveBudgetData | None]]` em vez de `BudgetRepositoryInterface` + `SpendReaderInterface`
- `budgeting_route.py` instancia `SpendReader` passando um callable async que chama `ExpenseRepository.find_in_range` e extrai os amounts (cross-feature mapping inline no composition root)
- `pairing_route.py` instancia todos os gateways passando callables construídos internamente a partir de `PersonRepository`, `ExpenseRepository`, `BudgetRepository` e `SpendReader`; é o único arquivo que importa de múltiplos features
- Nenhum arquivo em `gateways/`, `repositories/`, `domain/` ou `application/` de qualquer feature importa de outro feature

## Capabilities

### New Capabilities

(nenhuma — refactor puro de isolamento de módulos)

### Modified Capabilities

(nenhuma — nenhuma regra de domínio, contrato HTTP ou comportamento observável muda)

## Impact

- Todos os imports cross-feature ficam confinados nos `main/` de cada feature
- `core/application/interfaces/` passa a conter `spend_reader_interface.py` — interface genuinamente compartilhada entre budgeting e pairing
- `core/infrastructure/gateways/` fica com `clock.py`, `identifier_provider.py` e `spend_reader.py`
- Os gateways em `pairing/gateways/` tornam-se adaptadores thin (delegam inteiramente ao callable injetado)
- O mapeamento de entidades de outros features para DTOs de pairing (ex: `ExpenseEntity → PartnerExpenseData`) fica no composition root de pairing
- Testes de gateways passam a usar callables simples em vez de Fake\<Repository\>
