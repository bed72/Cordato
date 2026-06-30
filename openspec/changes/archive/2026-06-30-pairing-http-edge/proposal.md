## Why

O contexto `pairing` tem domínio e application completos — sete use cases implementados — mas zero exposição HTTP. Um cliente não consegue criar ou aceitar convites, ver o par atual, dissolver o casal nem consumir as visões compartilhadas. Esta change completa a superfície HTTP do pairing expondo todos os use cases existentes.

## What Changes

- Expor `POST /v1/invites` — criar invite code para a pessoa atuante, respondendo **201 Created**.
- Expor `DELETE /v1/invites/{code}` — revogar o próprio invite code pelo token, respondendo **204 No Content**.
- Expor `POST /v1/invites/{code}/accept` — aceitar um invite code, formando o par, respondendo **201 Created** com os dados do par criado.
- Expor `GET /v1/pair` — retornar o par atual da pessoa atuante; **404** quando não há par vivo.
- Expor `DELETE /v1/pair` — dissolver o par atual, respondendo **204 No Content**.
- Expor `GET /v1/pair/budget` — retornar a visão de orçamento do casal para hoje; **404** quando não está em par ou quando nenhum parceiro tem orçamento ativo.
- Expor `GET /v1/pair/expenses` — retornar a união das despesas do casal; **404** quando não está em par.
- Criar toda a infraestrutura HTTP do contexto: dois controllers (`InviteController`, `PairController`), DTOs Pydantic v2, mappers de request/response, tabela de erros `PAIRING_STATUS_ERROR`, e router scoped `register_pairing_router()`.
- Escrever testes de integração HTTP e cenário Locust para o fluxo de pairing.

## Capabilities

### New Capabilities

_(nenhuma — todos os use cases já existem; esta change adiciona requisitos HTTP a cada spec)_

### Modified Capabilities

- `create-invite-code`: adicionar requisito HTTP — `POST /v1/invites`, `201 Created`, autenticado.
- `revoke-invite-code`: adicionar requisito HTTP — `DELETE /v1/invites/{code}`, `204 No Content`, autenticado.
- `accept-invite-code`: adicionar requisito HTTP — `POST /v1/invites/{code}/accept`, `201 Created`, autenticado.
- `current-pair`: adicionar requisito HTTP — `GET /v1/pair`, `200 OK` com dados do par; `404` quando não está em par.
- `dissolve-pair`: adicionar requisito HTTP — `DELETE /v1/pair`, `204 No Content`, autenticado; `404` quando não está em par.
- `couple-budget`: adicionar requisito HTTP — `GET /v1/pair/budget`, `200 OK` com a visão; `404` quando não está em par ou nenhum parceiro tem orçamento ativo.
- `couple-expenses`: adicionar requisito HTTP — `GET /v1/pair/expenses`, `200 OK` com a união; `404` quando não está em par.

## Impact

- **Novos arquivos** sob `features/pairing/infrastructure/http/`:
  - `controllers/invite_controller.py` — handlers para create, revoke, accept.
  - `controllers/pair_controller.py` — handlers para get current pair, dissolve, couple budget, couple expenses.
  - `errors/lookups/pairing_status_error.py` — tabela `PAIRING_STATUS_ERROR` cobrindo todos os erros do domínio pairing.
  - `requests/` — `accept_invite_request.py` (body com `code`).
  - `responses/` — `invite_code_response.py`, `pair_response.py`, `couple_budget_response.py`, `couple_expense_response.py`.
  - `mappers/requests/` — `accept_invite_request_mapper.py`.
  - `mappers/responses/` — mappers para cada response.
- **Novo arquivo** `features/pairing/main/pairing_route.py` — router com DI scoped para todos os use cases de pairing.
- **Modificado** `core/infrastructure/http/app.py` — montar o pairing router sob `/v1`.
- **Novos testes** `tests/pairing/integrations/http/` — testes HTTP de integração.
- **Novo cenário** `tests/stress/test_pairing.py` — Locust HttpUser para o fluxo invite → accept → par.
- Nenhuma alteração em `domain/` ou `application/` — use cases, ports e repositórios intactos.
- Nenhuma nova dependência de runtime.
