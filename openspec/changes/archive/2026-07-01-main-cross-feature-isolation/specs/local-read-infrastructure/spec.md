## ADDED Requirements

### Requirement: budgeting possui um gateway local para amounts de despesas
`budgeting/application/interfaces/expense_amount_reader_interface.py` SHALL definir `ExpenseAmountReaderInterface(ABC)` com `async def find_amounts_in_range(self, person_id: str, start: date, end: date) -> list[Decimal]`. `budgeting/infrastructure/gateways/expense_amount_reader.py` SHALL definir `ExpenseAmountReader(ExpenseAmountReaderInterface)`, implementando localmente a mesma lógica de filtro hoje presente em `ExpenseRepository.find_in_range` — sem importar `trocado.features.expenses`.

#### Scenario: ExpenseAmountReader sem dependência cross-feature
- **WHEN** `budgeting/infrastructure/gateways/expense_amount_reader.py` é lido
- **THEN** nenhum import referencia `trocado.features.expenses`
- **AND** `ExpenseAmountReader.find_amounts_in_range` retorna `list[Decimal]`

#### Scenario: budgeting_route.py usa o gateway local para o SpendReader
- **WHEN** `register_budgeting_router()` é chamada
- **THEN** uma instância de `ExpenseAmountReader` é criada
- **AND** `reader.find_amounts_in_range` é passado como o callable `fetch_amounts` de `SpendReader`

### Requirement: pairing possui gateways locais para despesas, orçamentos e perfis de parceiro
`pairing/infrastructure/gateways/` SHALL conter três gateways concretos (`ExpenseReader`, `BudgetReader`, `PersonReader`), cada um implementando uma interface própria em `pairing/application/interfaces/` e a lógica de query hoje presente no repositório do feature produtor correspondente, retornando apenas tipos já definidos em `pairing/` — sem importar `trocado.features.expenses`, `trocado.features.budgeting` ou `trocado.features.identity`.

#### Scenario: ExpenseReader sem dependência cross-feature
- **WHEN** `pairing/infrastructure/gateways/expense_reader.py` é lido
- **THEN** nenhum import referencia `trocado.features.expenses`
- **AND** `ExpenseReader` implementa `ExpenseReaderInterface`
- **AND** `ExpenseReader.find_amounts_in_range` retorna `list[Decimal]`
- **AND** `ExpenseReader.list_live_for_person` retorna `list[PartnerExpenseData]`

#### Scenario: BudgetReader sem dependência cross-feature
- **WHEN** `pairing/infrastructure/gateways/budget_reader.py` é lido
- **THEN** nenhum import referencia `trocado.features.budgeting`
- **AND** `BudgetReader` implementa `BudgetReaderInterface`
- **AND** `BudgetReader.find_active_for_person` retorna `ActiveBudgetReadingData | None`

#### Scenario: PersonReader sem dependência cross-feature
- **WHEN** `pairing/infrastructure/gateways/person_reader.py` é lido
- **THEN** nenhum import referencia `trocado.features.identity`
- **AND** `PersonReader` implementa `PersonReaderInterface`
- **AND** `PersonReader.find_active_profile` retorna `PartnerProfileData | None`

#### Scenario: pairing_route.py usa os gateways locais para compor os adapters existentes
- **WHEN** `register_pairing_router()` é chamada
- **THEN** instâncias de `ExpenseReader`, `BudgetReader` e `PersonReader` são criadas
- **AND** seus métodos alimentam, diretamente ou via closure, os Callables passados a `SpendReader`, `PartnerExpenseReader`, `PartnerBudgetReader` e `PersonDirectory`

### Requirement: cada reader segue o padrão de todo gateway do projeto — ABC + adaptador, sem bucket novo
Cada reader SHALL ter uma interface `abc.ABC` própria em `application/interfaces/` do seu módulo e um adaptador concreto em `infrastructure/gateways/` — nunca uma pasta nova como `infrastructure/readers/`. Cada reader SHALL manter sua própria linha de armazenamento local mínima, em seu próprio arquivo dentro de `infrastructure/gateways/rows/`, independente do armazenamento do repositório original — a duplicação é intencional e documentada, garantindo que a evolução de um módulo não force mudança em outro.

#### Scenario: infrastructure/ de budgeting e pairing tem só as duas buckets
- **WHEN** `budgeting/infrastructure/` ou `pairing/infrastructure/` é listado
- **THEN** só existem as pastas `repositories/`, `gateways/`, `http/` (e `__init__.py`) — nenhuma pasta `readers/`

#### Scenario: linhas de armazenamento local vivem em gateways/rows/
- **WHEN** `budgeting/infrastructure/gateways/` ou `pairing/infrastructure/gateways/` é listado
- **THEN** as classes `*Row` (ex. `ExpenseAmountRow`, `ExpenseRow`, `BudgetRow`, `PersonRow`) estão em um arquivo próprio dentro do subdiretório `rows/`, nunca soltas ao lado dos readers nem bundladas na mesma classe do reader

#### Scenario: reader não referencia entidade de outro feature
- **WHEN** qualquer arquivo em `budgeting/infrastructure/gateways/` ou `pairing/infrastructure/gateways/` relacionado aos novos readers é lido
- **THEN** nenhum import referencia `domain.entities` de outro feature module

#### Scenario: um conceito por arquivo
- **WHEN** qualquer arquivo novo desta mudança em `application/interfaces/`, `application/data/`, `infrastructure/gateways/` ou `infrastructure/gateways/rows/` é lido
- **THEN** contém exatamente uma classe
