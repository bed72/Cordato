## Context

O contexto `pairing` tem domínio e application completos — sete use cases, dois repositórios em memória,
e um gateway de token — mas zero infraestrutura HTTP. As três mudanças anteriores similares
(`2026-06-29-identity-http-edge`, `2026-06-30-budgeting-http-edge`, `2026-06-30-expenses-http-edge`) estabeleceram
o padrão que esta change segue: criar a pasta `infrastructure/http/`, dois controllers de classe,
um router scoped, uma tabela de erros, e montar tudo em `app.py`.

Uma complicação específica de pairing: três dos use cases dependem de portas cross-module
(`PartnerBudgetReaderInterface`, `PartnerExpenseReaderInterface`, `PersonDirectoryInterface`) que
ainda não têm adaptadores concretos. Fakes existem nos testes mas não em `src/`. Esta change
introduz os três adaptadores em `core/infrastructure/gateways/`, seguindo o mesmo padrão de
`SpendReader`.

## Goals / Non-Goals

**Goals:**
- Expor todos os sete use cases de pairing via HTTP (`/v1/invites` e `/v1/pair`).
- Criar os três adaptadores cross-module em `core/infrastructure/gateways/`.
- Montar o pairing router em `app.py`.
- HTTP integration tests e cenário Locust para o fluxo invite → accept → pair.

**Non-Goals:**
- Auditoria de invite codes (`GET /v1/invites`) — nenhum use case existe para isso ainda.
- Endpoints de identidade (`PATCH /me`, `DELETE /me`) — change separada.
- ORM/persistência.
- Nenhuma mudança em `domain/` ou `application/`.

## Decisions

### D1 — Dois controllers: `InviteController` e `PairController`

`InviteController(path="/invites")` agrupa as três operações de invite (create, revoke, accept). `PairController(path="/pair")` agrupa as quatro operações de par (get, dissolve, couple budget, couple expenses). Um único controller seria longo demais e misturaria dois recursos semânticos distintos. Os dois são montados no mesmo `register_pairing_router()`.

### D2 — `GET /v1/pair` → `NotPairedError` quando não está em par (404)

`GetCurrentPairUseCase.execute()` retorna `None` quando não há par vivo — por design (status read, não erro). O controller converte `None` em `raise NotPairedError()`, que a tabela `PAIRING_STATUS_ERROR` mapeia para 404. `NotPairedError` é a semântica correta: "o recurso `/pair` não existe" e "você não está em um par" são a mesma coisa neste contexto.

### D3 — `GET /v1/pair/budget` → `None` retorna 200 com `null`, `NotPairedError` retorna 404

Há dois estados distintos para o cliente distinguir:
- **Não está em par** (`NotPairedError` → 404) — o casal não existe, sem panorama possível.
- **Está em par, mas nenhum parceiro tem orçamento ativo hoje** (use case retorna `None`) — o casal existe, o orçamento simplesmente não existe hoje. Retorna `200 OK` com corpo `null`.

Retornar 404 para ambos colapsaria estados semanticamente diferentes e forçaria o cliente a deduzir o motivo. A resposta `null` é o encoding HTTP do "nenhum panorama" da spec — análogo à lista vazia de despesas do casal.

O tipo de retorno do handler é `CoupleBudgetResponse | None`; Litestar serializa `None` como `null`.

### D4 — Três adaptadores cross-module em `core/infrastructure/gateways/`

`PartnerBudgetReaderInterface`, `PartnerExpenseReaderInterface`, e `PersonDirectoryInterface` precisam de adaptadores concretos. O padrão estabelecido é `core/infrastructure/gateways/` (onde `spend_reader.py` já vive): o único lugar que pode importar dois módulos simultaneamente. Os três adaptadores são instanciados em `app.py` e injetados no `register_pairing_router()`.

- `partner_budget_reader.py` — recebe `BudgetRepositoryInterface` e `SpendReaderInterface`; implementa `active_for_person(person_id, day)` delegando ao mesmo fluxo de `GetActiveBudgetUseCase` e mapeando `ActiveBudgetData → PartnerActiveBudgetData`.
- `partner_expense_reader.py` — recebe `ExpenseRepositoryInterface`; implementa `list_for_person(person_id)` retornando as despesas vivas mapeadas para `PartnerExpenseData`.
- `person_directory.py` — recebe `PersonRepositoryInterface` de identity; implementa `is_active(person_id)` e `find_active_profile(person_id)` mapeando para `PartnerProfileData`.

### D5 — `PAIRING_STATUS_ERROR` cobre todos os erros de domínio de pairing

A tabela mapeia todos os erros alcançáveis nos handlers:

| Erro | Status |
|---|---|
| `NotPairedError` | 404 |
| `InviteCodeNotFoundError` | 404 |
| `InviteCodeExpiredError` | 409 |
| `InviteCodeAlreadyConsumedError` | 409 |
| `InviteCodeRevokedError` | 409 |
| `AlreadyPairedError` | 409 |
| `SelfPairingError` | 409 |
| `PersonNotActiveError` | 409 |

### D6 — `accept invite` retorna `PairResponse` com 201

`AcceptInviteCodeUseCase` retorna `PairData`. O body do request de accept é `{"code": "..."}` — um único campo. O handler é `POST /invites/{code}/accept` onde `{code}` já está na URL (não há body redundante) — apenas o `code` é necessário para o use case, derivado do path param.

**Decisão: `{code}` no path, sem body.** `DELETE /invites/{code}` (revoke) também usa o code no path. Consistente e RESTful. Nenhum `AcceptInviteRequest` Pydantic é necessário — apenas o path param.

### D7 — Sem alterações em `domain/` ou `application/`

Os sete use cases, todos os ports, e os repositórios em memória ficam intactos. O HTTP edge é puramente aditivo: infraestrutura + gateways.

## Risks / Trade-offs

- **[Três novos adaptadores cross-module]** → `app.py` ficará mais longo. Mitigação: cada adaptador é um único arquivo pequeno em `core/infrastructure/gateways/`; o `app.py` já tem esse padrão com `SpendReader`.
- **[`partner_budget_reader` duplica lógica de `GetActiveBudgetUseCase`]** → O adaptador precisa computar `total_spent`, exigindo acesso ao `SpendReaderInterface`. Alternativa: wrappear o use case diretamente. Risco: acoplamento mais profundo. Decisão: duplicar o fluxo no adaptador, que é simples (find active budget + compute spend).
- **[200 com null para couple budget]** → Alguns clientes podem não esperar null em 200. Mitigação: documentar no OpenAPI (exemplo explícito de null); o código distingue claramente os dois estados.
- **[In-memory store]** → Dados perdidos no restart. Restrição transitória esperada.
