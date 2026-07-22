## Context

Hoje `core/infrastructure/http/responses/` define o único corpo de erro compartilhado (`ErrorResponse(code,
message, errors: List<FieldErrorResponse>)`) e os builders que o produzem por status
(`badRequest`/`unauthorized`/`unprocessable`/`internalError`, em `ErrorResponses.kt`). O sucesso não tem
nenhum tijolo compartilhado — cada controller devolve seu `*Response` (`ExpenseResponse`, `PersonResponse`,
`SignInResponse`, `ExpensePageResponse`) direto via `HttpResponse.ok(...)`/`HttpResponse.created(...)`.
`ExpensePageResponse` carrega `items` + `nextCursor` no mesmo corpo. Nenhum consumidor externo existe ainda
(projeto em estágio de design, ADR 0011 não usa `@Version`/negociação — só um `/v1` fixo), então não há
necessidade de servir dois formatos em paralelo.

## Goals / Non-Goals

**Goals:**
- Um envelope de sucesso único e reutilizável (`data` + `meta`/`links` opcionais) que todo controller
  compõe, do mesmo jeito que hoje compõe `badRequest`/`unprocessable`.
- Um envelope de erro único (`errors: [...]`) que preserva byte-a-byte a política de status/oráculo já
  testada pela ADR 0008 — só a casca estrutural muda (objeto → array de um ou mais itens).
- Corte único e completo: todo controller e todo teste de borda migram juntos, sem bandeira de feature nem
  formato duplo transitório (não há consumidor externo a proteger).

**Non-Goals:**
- Não perseguir conformidade estrita com a spec JSON:API (sem `type`/`id` como resource identifier object,
  sem `title`+`detail` separados, sem `source.pointer` como JSON Pointer). Já decidido na conversa que
  originou esta mudança.
- Não introduzir paginação `page`/`total_pages` — a paginação de `expense` continua por cursor/keyset;
  `meta.pagination` carrega só o que já existe (`next_cursor`).
- Não adicionar `meta`/`links` a rotas que não têm hoje conteúdo para eles (ex.: `POST /sign-up` não ganha
  `links` artificial).

## Decisions

### 1. Dois DTOs cross-cutting novos em `core/infrastructure/http/responses/`, espelhando o par
`ErrorResponse`/`FieldErrorResponse` que já existe

- `DataResponse<T>(data: T, meta: MetaResponse? = null, links: LinksResponse? = null)` — o envelope de
  sucesso. `T` é `*Response` para item único, `List<*Response>` para coleção; nenhuma feature precisa de um
  tipo próprio de envelope (mata a necessidade de `ExpensePageResponse` como está hoje — ver decisão 3).
- `ErrorsResponse(errors: List<ErrorItemResponse>)` como o novo corpo de topo; `ErrorItemResponse(status:
  String, code: String, message: String, source: ErrorSourceResponse? = null)` substitui o atual
  `ErrorResponse` como item de lista; `ErrorSourceResponse(field: String)` substitui `FieldErrorResponse`
  (mesmo campo, nome de tipo alinhado ao vocabulário do envelope).
- `MetaResponse(pagination: PaginationMetaResponse? = null)` e `PaginationMetaResponse(nextCursor: String?)`
  — `meta` é aditivo: outros usos futuros (`requestId`, `timestamp`) entram como novos campos opcionais do
  mesmo `MetaResponse`, nunca um tipo de meta por feature.
- `LinksResponse(self: String, next: String? = null)` — só os dois links que `expense` usa hoje; `prev`/
  `last` ficam de fora (não-goal: cursor pagination não tem essas noções).

Alternativa considerada e descartada: um envelope genérico único `Envelope<T>(data: T?, errors:
List<ErrorItemResponse>?, meta, links)` que serve sucesso e erro na mesma classe. Rejeitada porque violaria
a regra "Errors MUST NEVER use `data`" só por convenção de código (nada impediria preencher os dois campos
ao mesmo tempo); dois tipos fechados tornam o estado inválido irrepresentável.

### 2. Builders compartilhados em `core`, no mesmo arquivo/padrão de `ErrorResponses.kt`

Novo `DataResponses.kt` com `ok(item: T, meta: MetaResponse? = null, links: LinksResponse? = null):
HttpResponse<DataResponse<T>>` e `created(item: T): HttpResponse<DataResponse<T>>` — os controllers trocam
`HttpResponse.ok(expense.toResponse())` por `ok(expense.toResponse())` (mesmo padrão de import estático que
já usam para `badRequest`). `ErrorResponses.kt` é reescrito: `badRequest`/`unauthorized`/`unprocessable`/
`internalError` passam a montar `ErrorsResponse(listOf(ErrorItemResponse(...)))`; a assinatura pública dos
builders **não muda** (mesmos parâmetros `code`/`message`/`errors: List<FieldErrorResponse>` → `source`
list), então nenhum error mapper de feature precisa saber que o corpo agora é um array — só o tipo de
retorno (`HttpResponse<ErrorsResponse>`) muda.

### 3. `ExpensePageResponse` é removido; a página vira `DataResponse<List<ExpenseResponse>>` com `meta`/`links` compostos no controller

O mapper `ExpensePageVirtualObject.toResponse()` para de devolver um envelope próprio e passa a devolver só
`List<ExpenseResponse>`; o `ExpenseController.page(...)` compõe o `DataResponse` chamando o builder `ok`
com `meta`/`links` construídos ali (o `nextCursor` codificado, o `self` a partir do request, o `next` só
quando há `nextCursor`). Alternativa considerada: manter `ExpensePageResponse` e envelopar em cima
(`DataResponse<ExpensePageResponse>`) — rejeitada porque duplicaria `nextCursor` em dois lugares (dentro do
`ExpensePageResponse` e de novo em `meta.pagination`), reabrindo a inconsistência que a mudança existe para
fechar.

### 4. `ConstraintViolationException` handler emite um `ErrorItemResponse` por campo, com `source`

O handler genérico de `core/infrastructure/http/errors/handlers/` (hoje monta `List<FieldErrorResponse>`)
passa a montar `List<ErrorItemResponse>` diretamente, cada um com `status = "400"`, `code =
"INVALID_REQUEST"` (mesmo code de hoje), `message` curada, `source = ErrorSourceResponse(field)`. Erros
escalares (malformado, `422`, `500`, `401`) continuam produzindo uma lista de **um único item**, sem
`source` — não há mudança de política, só de casca.

### 5. Corte único, sem formato duplo

Todo controller, mapper, `*ControllerDoc` e teste de HTTP migra na mesma leva de tasks. Não há
`@Version`/negociação de content-type para servir os dois formatos (ADR 0011 já deliberadamente não usa
isso), e não há consumidor externo hoje que justifique o custo de manter os dois em paralelo.

## Risks / Trade-offs

- **[Risco] Um `HttpResponse<*>` de retorno genérico nos controllers dificulta a tipagem exata do
  `DataResponse<T>`.** → Mitigação: manter o retorno de método como `HttpResponse<*>` (como já é hoje em
  `ExpenseController`/`AuthenticationController`), só o corpo interno muda de tipo; a tipagem forte fica no
  builder (`ok<T>(item: T): HttpResponse<DataResponse<T>>`), não na assinatura do método do controller.
- **[Risco] Reescrever `ErrorResponses.kt` é o ponto de maior risco de regressão silenciosa no invariante de
  não-vazamento da ADR 0008** (ex.: acidentalmente emitir um item por `CreateExpenseError` em vez de um
  único item genérico). → Mitigação: os testes que já cobrem o invariante (`EmailAlreadyInUse` indistinguível
  de `InvalidEmail`, `InvalidCredentials` indistinguível de sessão órfã) são portados para o novo shape
  primeiro, antes de qualquer refino de builder — ver tasks.
- **[Trade-off] `ErrorItemResponse` carrega `status` como string redundante com o header HTTP.** Aceito
  deliberadamente (convenção JSON:API, decidido na conversa) — custo é só um campo a mais serializado,
  sem lógica adicional.
- **[Risco] `openapi-documentation` (ADR 0010) gera schema errado se algum `*ControllerDoc` não for
  atualizado.** → Mitigação: task explícita de build (`./gradlew build`) validando que o doc gerado reflete
  `DataResponse`/`ErrorsResponse` para toda rota, não só compilação.

## Migration Plan

Sem *rollout* gradual — é um corte de contrato único dentro desta change (ver Decisão 5). Ordem de
implementação (detalhada em `tasks.md`): (1) os novos DTOs de envelope em `core`, (2) os builders de
sucesso/erro em `core`, (3) o handler de `ConstraintViolationException`, (4) `identity` (controllers +
mappers + docs + testes), (5) `expense` (controllers + mappers + docs + testes, incluindo a remoção de
`ExpensePageResponse`), (6) ADR nova substituindo a 0008, (7) sync dos specs modificados via `/opsx:sync`.
Rollback é reverter o commit/branch da change inteira — não há estado persistido migrado (o envelope é
puramente de borda HTTP, não toca banco).

## Open Questions

Nenhuma em aberto — todas as decisões de forma (message vs. title/detail, source.field vs.
source.pointer, um item genérico por família de rejeição 422/500/401) já foram fechadas na conversa que
originou esta proposta.
