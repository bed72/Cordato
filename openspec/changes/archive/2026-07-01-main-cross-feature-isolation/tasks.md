## 1. budgeting — gateway local de amounts

- [x] 1.1 Criar `budgeting/application/interfaces/expense_amount_reader_interface.py` (`ExpenseAmountReaderInterface`), `budgeting/infrastructure/gateways/rows/expense_amount_row.py` (`ExpenseAmountRow`) e `budgeting/infrastructure/gateways/expense_amount_reader.py` (`ExpenseAmountReader`), duplicando o filtro de `ExpenseRepository.find_in_range` sobre um armazenamento local mínimo (sem importar `trocado.features.expenses`)
- [x] 1.2 Criar `tests/budgeting/infrastructure/gateways/test_expense_amount_reader.py` cobrindo: filtro por `person_id`, exclusão de itens fora do range, exclusão de itens soft-deleted
- [x] 1.3 Atualizar `src/trocado/features/budgeting/main/budgeting_route.py`: remover `from trocado.features.expenses.infrastructure.repositories.expense_repository import ExpenseRepository`; instanciar `ExpenseAmountReader` (tipado por `ExpenseAmountReaderInterface`) e passar `reader.find_amounts_in_range` para `SpendReader`
- [x] 1.4 Atualizar a docstring de `register_budgeting_router()` para refletir o gateway local em vez do `ExpenseRepository` importado

## 2. pairing — gateways locais de despesas, orçamentos e perfis

- [x] 2.1 Criar `pairing/application/interfaces/expense_reader_interface.py` (`ExpenseReaderInterface`), `pairing/infrastructure/gateways/rows/expense_row.py` (`ExpenseRow`) e `pairing/infrastructure/gateways/expense_reader.py` (`ExpenseReader`) com `find_amounts_in_range` e `list_live_for_person -> list[PartnerExpenseData]`, duplicando `ExpenseRepository.find_in_range` / `list_live_for_person` sobre armazenamento local (sem importar `trocado.features.expenses`)
- [x] 2.2 Criar `pairing/application/data/active_budget_reading_data.py` (`ActiveBudgetReadingData`), `pairing/application/interfaces/budget_reader_interface.py` (`BudgetReaderInterface`), `pairing/infrastructure/gateways/rows/budget_row.py` (`BudgetRow`) e `pairing/infrastructure/gateways/budget_reader.py` (`BudgetReader`), duplicando `BudgetRepository.find_active_for_person` (sem importar `trocado.features.budgeting`)
- [x] 2.3 Criar `pairing/application/interfaces/person_reader_interface.py` (`PersonReaderInterface`), `pairing/infrastructure/gateways/rows/person_row.py` (`PersonRow`) e `pairing/infrastructure/gateways/person_reader.py` (`PersonReader`) com `find_active_profile(person_id) -> PartnerProfileData | None`, duplicando `PersonRepository.find_active_by_id` + extração de `name` (sem importar `trocado.features.identity`)
- [x] 2.4 Criar `tests/pairing/infrastructure/gateways/test_expense_reader.py`, `test_budget_reader.py`, `test_person_reader.py` cobrindo os mesmos casos de filtro que os repositórios originais já cobrem (range, soft-delete, pessoa ativa/inexistente)
- [x] 2.5 Atualizar `src/trocado/features/pairing/main/pairing_route.py`: remover os imports de `ExpenseRepository`, `BudgetRepository`/`BudgetRepositoryInterface`, `PersonRepository`/`PersonRepositoryInterface`; instanciar `ExpenseReader`, `BudgetReader`, `PersonReader` (tipados por suas interfaces) e recompor `person_directory`, `partner_expense_reader`, `_find_active_partner_budget` sobre eles
- [x] 2.6 Atualizar a docstring de `register_pairing_router()` para refletir os gateways locais em vez dos repositórios importados

## 3. Regra de composição

- [x] 3.1 Sincronizar `openspec/specs/feature-composition/spec.md` com o delta MODIFIED desta mudança (regra sem exceção de `main/`) — feito no arquivamento (`openspec archive`)
- [x] 3.2 Rodar `grep -rn "from trocado.features\." src/trocado/features/*/main/*.py` e confirmar que nenhuma linha referencia um feature module diferente do próprio arquivo

## 4. Verificação

- [x] 4.1 `uv run poe check` (format, lint, mypy --strict, pytest) passando
- [x] 4.2 Rodar os testes de integração HTTP de `budgeting` e `pairing` (`tests/budgeting/integrations/http/`, `tests/pairing/integrations/http/`) e confirmar que nenhum contrato de resposta mudou
- [x] 4.3 Rodar a skill `architecture-guard` sobre o diff final — encontrou e corrigiu 2 violações (bucket `infrastructure/readers/` inválido; múltiplas classes por arquivo); reexecutado até PASS
