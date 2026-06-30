## 1. Mover SpendReaderInterface para core/

- [x] 1.1 Criar `src/trocado/core/application/interfaces/spend_reader_interface.py` com o conteúdo de `budgeting/application/interfaces/spend_reader_interface.py` (sem alteração de lógica)
- [x] 1.2 Deletar `src/trocado/features/budgeting/application/interfaces/spend_reader_interface.py`
- [x] 1.3 Atualizar todos os imports de `SpendReaderInterface`: `budgeting/application/use_cases/get_active_budget_use_case.py`, `budgeting/main/budgeting_route.py`, `pairing/infrastructure/gateways/partner_budget_reader.py`, `pairing/main/pairing_route.py` e testes

## 2. Mover SpendReader para core/ sem dependência cross-feature

- [x] 2.1 Criar `src/trocado/core/infrastructure/gateways/spend_reader.py`; construtor recebe `fetch_amounts: Callable[[str, date, date], Awaitable[list[Decimal]]]`; `total_spent` chama `fetch_amounts` e devolve `MoneyValueObject(sum(amounts, Decimal("0.00")))`; zero imports de `trocado.features.*`
- [x] 2.2 Deletar `src/trocado/features/budgeting/infrastructure/gateways/spend_reader.py`
- [x] 2.3 Em `budgeting_route.py`: instanciar `SpendReader` passando uma função async `_fetch_amounts(person_id, start, end)` que chama `expense_repository.find_in_range` e retorna `[e.amount.value for e in expenses]`
- [x] 2.4 Em `pairing_route.py`: instanciar `SpendReader` da mesma forma (com seu próprio `expense_repository`)

## 3. Eliminar dependência cross-feature de PersonDirectory

- [x] 3.1 Alterar `pairing/infrastructure/gateways/person_directory.py`: construtor recebe `fetch_profile: Callable[[str], Awaitable[PartnerProfileData | None]]`; remover import de `trocado.features.identity`; `is_active` retorna `await self._fetch_profile(person_id) is not None`; `find_active_profile` delega ao callable
- [x] 3.2 Em `pairing_route.py`: definir função async `_fetch_person_profile(person_id)` que chama `PersonRepository.find_active_by_id` e mapeia `person → PartnerProfileData(id=person.id, name=person.name.value)`; passar a `PersonDirectory`

## 4. Eliminar dependência cross-feature de PartnerExpenseReader

- [x] 4.1 Alterar `pairing/infrastructure/gateways/partner_expense_reader.py`: construtor recebe `list_expenses: Callable[[str], Awaitable[list[PartnerExpenseData]]]`; remover import de `trocado.features.expenses`; `list_for_person` delega ao callable
- [x] 4.2 Em `pairing_route.py`: definir função async `_list_partner_expenses(person_id)` que chama `ExpenseRepository.list_live_for_person` e mapeia cada `ExpenseEntity → PartnerExpenseData`; passar a `PartnerExpenseReader`

## 5. Eliminar dependência cross-feature de PartnerBudgetReader

- [x] 5.1 Alterar `pairing/infrastructure/gateways/partner_budget_reader.py`: construtor recebe `find_active_budget: Callable[[str, date], Awaitable[PartnerActiveBudgetData | None]]`; remover imports de `trocado.features.budgeting`; `active_for_person` delega ao callable
- [x] 5.2 Em `pairing_route.py`: definir função async `_find_active_partner_budget(person_id, day)` que chama `BudgetRepository.find_active_for_person` e, se encontrou budget, chama `spend_reader.total_spent` para montar `PartnerActiveBudgetData`; passar a `PartnerBudgetReader`

## 6. Atualizar testes

- [x] 6.1 Mover `tests/budgeting/infrastructure/gateways/test_spend_reader.py` para `tests/core/infrastructure/gateways/test_spend_reader.py`; ajustar import para `core/infrastructure/gateways/spend_reader.py` e construção (passar callable fake que retorna `list[Decimal]`)
- [x] 6.2 Atualizar testes de `PersonDirectory`: substituir `FakePersonRepository` por um callable `async def fake_fetch(person_id) -> PartnerProfileData | None`
- [x] 6.3 Atualizar testes de `PartnerExpenseReader`: substituir `FakeExpenseRepository` por um callable `async def fake_list(person_id) -> list[PartnerExpenseData]`
- [x] 6.4 Atualizar testes de `PartnerBudgetReader`: substituir fakes de repositório e spend reader por um callable `async def fake_find(person_id, day) -> PartnerActiveBudgetData | None`
- [x] 6.5 Verificar e atualizar qualquer outro arquivo de teste com imports antigos de `SpendReader` ou `SpendReaderInterface`

## 7. Verificação final

- [x] 7.1 Confirmar que nenhum arquivo em `gateways/`, `repositories/`, `domain/` ou `application/` de qualquer feature importa de outro feature: `grep -rn "from trocado.features" src/trocado/features/*/infrastructure/gateways/ src/trocado/features/*/infrastructure/repositories/ src/trocado/features/*/domain/ src/trocado/features/*/application/`
- [x] 7.2 Confirmar que `core/infrastructure/gateways/` contém apenas `clock.py`, `identifier_provider.py`, `spend_reader.py`, `__init__.py`
- [x] 7.3 Rodar `uv run poe check` (format-check → lint → mypy → pytest) com todos os gates passando
