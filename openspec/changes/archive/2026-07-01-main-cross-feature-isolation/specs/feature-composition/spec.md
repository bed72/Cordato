## MODIFIED Requirements

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
