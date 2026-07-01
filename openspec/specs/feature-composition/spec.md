# feature-composition Specification

## Purpose
Cada feature module do projeto é isolado — nenhum arquivo (domain/, application/, infrastructure/, main/) importa de outro feature module; o único cruzamento sancionado é o shared kernel em core/. Quando um módulo precisa ler dado de outro, ele ganha seu próprio gateway de leitura local (interface ABC + adaptador), nunca um import direto do repositório/entidade produtora.
## Requirements
### Requirement: Zero imports cross-feature fora de main/
Nenhum arquivo de qualquer feature module SHALL importar de outro feature module — sem exceção de camada, **incluindo `main/`**. Isso inclui `domain/`, `application/`, `infrastructure/` (`gateways/`, `repositories/`, `http/`) e o composition root de cada feature (`main/`). O único cruzamento tolerado é a importação de `core/`, o shared kernel.

#### Scenario: gateways de pairing não importam de outros features
- **WHEN** qualquer arquivo em `pairing/infrastructure/gateways/` é lido
- **THEN** nenhum import referencia `trocado.features.expenses`, `trocado.features.budgeting` ou `trocado.features.identity`

#### Scenario: gateways de budgeting não importam de outros features
- **WHEN** qualquer arquivo em `budgeting/infrastructure/gateways/` é lido
- **THEN** nenhum import referencia `trocado.features.expenses`, `trocado.features.pairing` ou `trocado.features.identity`

#### Scenario: main/ de budgeting não importa de outros features
- **WHEN** `budgeting/main/budgeting_route.py` é lido
- **THEN** nenhum import referencia `trocado.features.expenses`, `trocado.features.pairing` ou `trocado.features.identity`

#### Scenario: main/ de pairing não importa de outros features
- **WHEN** `pairing/main/pairing_route.py` é lido
- **THEN** nenhum import referencia `trocado.features.expenses`, `trocado.features.budgeting` ou `trocado.features.identity`

### Requirement: SpendReaderInterface e SpendReader residem em core/
`SpendReaderInterface` SHALL residir em `core/`, por ser usada tanto por budgeting quanto por pairing — pertence ao kernel compartilhado. `SpendReader` SHALL implementar essa interface sem importar de nenhum feature module; recebe um callable cujo conteúdo é fornecido pelo composition root.

#### Scenario: SpendReaderInterface em core
- **WHEN** o código é lido
- **THEN** `SpendReaderInterface` reside em `core/application/interfaces/spend_reader_interface.py`
- **AND** não existe em `budgeting/application/interfaces/`

#### Scenario: SpendReader em core sem dependência de feature
- **WHEN** `core/infrastructure/gateways/spend_reader.py` é lido
- **THEN** nenhum import referencia qualquer `trocado.features.*`
- **AND** o construtor recebe `fetch_amounts: Callable[[str, date, date], Awaitable[list[Decimal]]]`

### Requirement: Gateways de pairing recebem Callables com tipos de pairing
Os gateways cross-feature de pairing SHALL receber Callables cujas assinaturas usam apenas tipos de `pairing/` ou primitivos — nunca tipos de outros features.

#### Scenario: PersonDirectory sem dependência cross-feature
- **WHEN** `pairing/infrastructure/gateways/person_directory.py` é lido
- **THEN** nenhum import referencia `trocado.features.identity`
- **AND** o construtor recebe `fetch_profile: Callable[[str], Awaitable[PartnerProfileData | None]]`

#### Scenario: PartnerExpenseReader sem dependência cross-feature
- **WHEN** `pairing/infrastructure/gateways/partner_expense_reader.py` é lido
- **THEN** nenhum import referencia `trocado.features.expenses`
- **AND** o construtor recebe `list_expenses: Callable[[str], Awaitable[list[PartnerExpenseData]]]`

#### Scenario: PartnerBudgetReader sem dependência cross-feature
- **WHEN** `pairing/infrastructure/gateways/partner_budget_reader.py` é lido
- **THEN** nenhum import referencia `trocado.features.budgeting`
- **AND** o construtor recebe `find_active_budget: Callable[[str, date], Awaitable[PartnerActiveBudgetData | None]]`

### Requirement: pairing_route.py é o único detentor do mapeamento cross-feature
Todo mapeamento de entidades de outros features para DTOs de pairing SHALL residir em `pairing/main/pairing_route.py`. Os callables são funções async definidas dentro de `register_pairing_router()`.

#### Scenario: composição de PartnerExpenseReader em pairing_route
- **WHEN** `register_pairing_router()` é chamada
- **THEN** uma função async `_list_partner_expenses(person_id)` é construída internamente mapeando `ExpenseEntity → PartnerExpenseData`
- **AND** essa função é passada a `PartnerExpenseReader` na construção

#### Scenario: composição de SpendReader em budgeting_route
- **WHEN** `register_budgeting_router()` é chamada
- **THEN** uma função async `_fetch_amounts(person_id, start, end)` é construída internamente extraindo `[e.amount.value for e in expenses]`
- **AND** essa função é passada a `SpendReader` na construção

### Requirement: core/infrastructure/gateways/ contém apenas adaptadores do kernel
O diretório `core/infrastructure/gateways/` SHALL conter apenas `clock.py`, `identifier_provider.py`, `spend_reader.py` e `__init__.py`. Nenhum outro adaptador SHALL residir aqui.

#### Scenario: core/gateways/ com SpendReader
- **WHEN** o diretório `core/infrastructure/gateways/` é listado
- **THEN** contém `clock.py`, `identifier_provider.py`, `spend_reader.py` e `__init__.py`
- **AND** nenhum outro arquivo está presente

