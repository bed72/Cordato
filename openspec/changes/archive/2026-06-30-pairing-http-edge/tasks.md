## 1. Adaptadores cross-module em core/infrastructure/gateways/

- [x] 1.1 Criar `core/infrastructure/gateways/person_directory.py` — implementa `PersonDirectoryInterface` via `PersonRepositoryInterface` de identity; métodos `is_active` e `find_active_profile` mapeando para `PartnerProfileData`
- [x] 1.2 Criar `core/infrastructure/gateways/partner_expense_reader.py` — implementa `PartnerExpenseReaderInterface` via `ExpenseRepositoryInterface` de expenses; método `list_for_person` retornando despesas vivas mapeadas para `PartnerExpenseData`
- [x] 1.3 Criar `core/infrastructure/gateways/partner_budget_reader.py` — implementa `PartnerBudgetReaderInterface` via `BudgetRepositoryInterface` + `SpendReaderInterface` de budgeting; método `active_for_person` mapeando para `PartnerActiveBudgetData`

## 2. DTOs e mappers de response

- [x] 2.1 Criar `features/pairing/infrastructure/http/responses/invite_code_response.py` — `InviteCodeResponse` (id, code, creator_id, created_at, expires_at, consumed_at)
- [x] 2.2 Criar `features/pairing/infrastructure/http/responses/pair_response.py` — `PairResponse` (pair_id, partner_id, partner_name, paired_since)
- [x] 2.3 Criar `features/pairing/infrastructure/http/responses/couple_budget_response.py` — `CoupleBudgetResponse` (start_date, end_date, amount, total_spent, remaining)
- [x] 2.4 Criar `features/pairing/infrastructure/http/responses/couple_expense_response.py` — `CoupleExpenseResponse` (id, person_id, amount, occurred_on, description, created_at, perspective)
- [x] 2.5 Criar `features/pairing/infrastructure/http/mappers/responses/invite_code_response_mapper.py` — `InviteCodeResponseMapper.to_response(InviteCodeData) -> InviteCodeResponse`
- [x] 2.6 Criar `features/pairing/infrastructure/http/mappers/responses/pair_response_mapper.py` — `PairResponseMapper.to_response(PairData) -> PairResponse`
- [x] 2.7 Criar `features/pairing/infrastructure/http/mappers/responses/couple_budget_response_mapper.py` — `CoupleBudgetResponseMapper.to_response(CoupleBudgetData) -> CoupleBudgetResponse`
- [x] 2.8 Criar `features/pairing/infrastructure/http/mappers/responses/couple_expense_response_mapper.py` — `CoupleExpenseResponseMapper.to_response(CoupleExpenseData) -> CoupleExpenseResponse`

## 3. Tabela de erros

- [x] 3.1 Criar `features/pairing/infrastructure/http/errors/lookups/pairing_status_error.py` — `PAIRING_STATUS_ERROR: dict[type[Exception], int]` cobrindo todos os erros de domínio de pairing (NotPairedError → 404, InviteCodeNotFoundError → 404, InviteCodeExpiredError → 409, InviteCodeAlreadyConsumedError → 409, InviteCodeRevokedError → 409, AlreadyPairedError → 409, SelfPairingError → 409, PersonNotActiveError → 409)

## 4. Controllers

- [x] 4.1 Criar `features/pairing/infrastructure/http/controllers/invite_controller.py` — `InviteController(path="/invites")` com: `POST /` (create → 201 InviteCodeResponse), `DELETE /{code}` (revoke → 204), `POST /{code}/accept` (accept → 201 PairResponse)
- [x] 4.2 Criar `features/pairing/infrastructure/http/controllers/pair_controller.py` — `PairController(path="/pair")` com: `GET /` (get current pair → 200 PairResponse, None → raise NotPairedError → 404), `DELETE /` (dissolve → 204), `GET /budget` (couple budget → 200 CoupleBudgetResponse | None), `GET /expenses` (couple expenses → 200 list[CoupleExpenseResponse])

## 5. Router e wiring

- [x] 5.1 Criar `features/pairing/main/pairing_route.py` — `register_pairing_router(person_directory, partner_budget_reader, partner_expense_reader) -> Router` com DI scoped para todos os sete use cases, tabela `PAIRING_STATUS_ERROR`
- [x] 5.2 Atualizar `core/infrastructure/http/app.py` — instanciar os três adaptadores, montar `register_pairing_router()` sob `/v1`, adicionar tag `Pairing` ao OpenAPI

## 6. Testes de unidade

- [x] 6.1 Criar `tests/pairing/infrastructure/http/errors/test_pairing_status_error.py` — verificar que cada erro de domínio mapeia para o status correto (puro Python, sem framework)

## 7. Testes de integração HTTP

- [x] 7.1 Criar `tests/pairing/integrations/http/test_invite_http.py` — ciclo completo: sign-up de dois usuários, create invite, accept invite, verificar par criado; cenários de erro (token inválido, invite expirado, já emparelhado)
- [x] 7.2 Criar `tests/pairing/integrations/http/test_pair_http.py` — get current pair (204 quando não emparelhado), dissolve pair, couple budget (200 null quando sem orçamento ativo), couple expenses

## 8. Cenário Locust

- [x] 8.1 Criar `tests/stress/test_pairing.py` — `HttpUser` com fluxo: sign-up de dois usuários, create invite, accept invite, get pair, dissolve pair
