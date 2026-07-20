> **Nota de revisão:** esta mudança foi reescrita para tornar a listagem **cursor-paginada** e **cacheada
> (Valkey)** — obrigatórios. A implementação anterior (lista completa, array nu, sem cache) foi commitada na
> branch e agora é **retrabalhada** para casar com as specs revistas; as tasks abaixo refletem o escopo novo.

## 1. Kernel de cache no core (`cache-valkey`)

- [x] 1.1 `build.gradle.kts`: adicionar o cliente Valkey/Redis (Lettuce, resolvível pela BOM Micronaut) como `implementation`, pinado como as demais libs.
- [x] 1.2 `core/application/driven/ports/CachePort.kt`: contrato puro — `get(key): String?`, `set(key, value, ttl: Duration)`, `increment(key): Long`. Sem tipo de cliente na assinatura; sem anotação de DI.
- [x] 1.3 `core/infrastructure/.../cache/ValkeyCacheAdapter.kt`: implementa o `CachePort` sobre o cliente Lettuce (único lugar em que o tipo do cliente aparece); falhas do cliente propagam para o chamador decidir (o decorator do expense as trata como miss).
- [x] 1.4 Config `valkey.host`/`valkey.port` em `application.properties`; wiring no `CoreFactory` (`@Singleton CachePort` + conexão Lettuce a partir da config), regra "um `@Factory` por pacote".
- [x] 1.5 Serviço `valkey` no `compose.yml` (imagem Valkey) + variáveis no `.env.example` + alvos `valkey-up`/`down`/`logs` no `Makefile` (e `run` sobe o Valkey junto do Postgres).
- [x] 1.6 Teste de integração do adapter com Testcontainers (imagem Valkey, `support/ValkeyHarness.kt` espelhando o `PostgresHarness`): `set`+`get`, expiração por TTL, ausência de chave, `increment` atômico começando de zero. Pula (abort) sem Docker.

## 2. Domínio do expense — cursor e página

- [x] 2.1 `domain/value_objects/ExpenseCursorValueObject.kt`: `data class (spentOn: LocalDate, id: String)` imutável com `of(spentOn, id)` (dois campos → não é `@JvmInline`). Representa a posição de keyset; a codificação opaca **não** vive aqui.
- [x] 2.2 `domain/virtual_objects/ExpensePageVirtualObject.kt`: `data class (items: List<ExpenseEntity>, nextCursor: ExpenseCursorValueObject?)` — projeção de leitura, sem identidade, nunca persistida; `nextCursor == null` ⟺ última página.

## 3. Persistência keyset + decorator de cache

- [x] 3.1 Port: trocar `ExpenseRepository.findByPerson(personId)` por `findByPerson(personId: String, after: ExpenseCursorValueObject?, limit: Int): List<ExpenseEntity>`.
- [x] 3.2 `PersistenceExpenseRepository`: query keyset — `where(PERSON_ID.eq(personId))` + (quando `after != null`) `.and(row(SPENT_ON, ID).lessThan(row(after.spentOn, after.id)))`, `.orderBy(SPENT_ON.desc(), ID.desc()).limit(limit)`. Sem migração nova.
- [x] 3.3 `CachingExpenseRepository(persistence, cache, clock)` (infrastructure) implementando `ExpenseRepository`: `findByPerson` read-through com chave `expenses:{personId}:v{gen}:{cursorToken}:{limit}` (gen via `CachePort.get`/`0`; cursorToken `"first"`/opaco), serializando/desserializando `List<ExpenseEntity>` em JSON de infra, TTL por config, **falha de cache = miss** (log + segue ao persistence); `create` delega e depois `invalidate(personId)` = `increment("expenses:{personId}:gen")`. Um único ponto de invalidação (helper `invalidate(personId)` que `update`/`delete` reusam quando existirem).
- [x] 3.4 Testes: (a) persistence keyset com `PostgresHarness` — primeira fatia ordenada/limitada, continuação estritamente após o cursor, recorte por dono, vazio/cursor esgotado; (b) `CachingExpenseRepository` com um `FakeCachePort` (em `core/factories/`) — read-through popula+reusa, `create` invalida (bump de geração ⇒ próxima leitura é miss), escopo por pessoa (bump de A não afeta B), cache indisponível degrada para o persistence.

> **Nota de implementação (3.3):** o `clock` do desenho original não tinha uso funcional (TTL já é relativo,
> não uma data absoluta) — implementado como `CachingExpenseRepository(repository, cache, ttl: Duration)`
> em vez de `(persistence, cache, clock)`; o `ttl` vem de config (`expense.cache.list-ttl-seconds`, default
> 60s) via `ExpenseFactory`, mantendo "TTL por config" do design. Desvio estrutural, sem mudança de
> comportamento — coberto pelo `arch-review` (6.3).

## 4. Aplicação do expense

- [x] 4.1 `ListExpensesCommand.kt`: `(personId: String, limit: Int, after: ExpenseCursorValueObject?)`.
- [x] 4.2 `ListExpensesUseCase.kt`: `invoke(command): ExpensePageVirtualObject` — busca `findByPerson(personId, after, limit + 1)`; se vierem `> limit`, corta para `limit` e `nextCursor = (spentOn, id)` do último item mantido; senão `nextCursor = null`. Sem `Result`/`Error`.
- [x] 4.3 Testes do use case com `FakeExpenseRepository` (ajustado ao novo port): página respeita `limit` e oferece `nextCursor`; última página sem `nextCursor`; página vazia; recorte por dono; o `limit + 1` de sondagem não vaza para os itens retornados.

## 5. Slice HTTP do expense

- [x] 5.1 `infrastructure/http/responses/ExpensePageResponse.kt` (`@Serdeable`): `(items: List<ExpenseResponse>, nextCursor: String?)` — serializa `next_cursor` (snake_case pela política global); `@Schema` com exemplos.
- [x] 5.2 Mapper request `mappers/requests/`: `String? -> ExpenseCursorValueObject?` (decode base64-url `spent_on|id`); um cursor ilegível é sinalizado como malformado (sem exceção não tratada).
- [x] 5.3 Mapper response `mappers/responses/`: `ExpensePageVirtualObject.toResponse(): ExpensePageResponse` reusando `ExpenseEntity.toResponse()` por item e **codificando** o `nextCursor` de volta à string opaca (`null` na última página). (Remove o `List<ExpenseEntity>.toResponse()` da versão anterior.)
- [x] 5.4 `ExpenseController.list(actor, @QueryValue @Positive @Max(100) limit: Int?, @QueryValue cursor: String?)`: `@Get @Authenticated @Status(OK)`; `limit ?: DEFAULT_LIMIT (20)`; cursor decodificado (malformado → `400 MALFORMED_REQUEST` pelo builder do core); responde `HttpResponse.ok(useCase(command).toResponse())`.
- [x] 5.5 `ExpenseControllerDoc.list`: `@Operation` + `@Parameter` para `limit`/`cursor`, `@ApiResponse` `200` com corpo `ExpensePageResponse`, `400`/`401`/`500` → `ErrorResponse`.
- [x] 5.6 DI: `ExpenseFactory.expenseRepository(dsl, cache, clock)` passa a devolver o `CachingExpenseRepository` embrulhando o `PersistenceExpenseRepository`; `listExpensesUseCase(repository)` e `createExpenseUseCase(...)` recebem o repositório decorado (cache vem do `CoreFactory`).

## 6. Testes de integração e fechamento

- [x] 6.1 e2e HTTP `GET /v1/expenses` (`@MicronautTest` + auth fixtures, `CachePort` fake global): `200` com envelope + `next_cursor`; seguir o `next_cursor` traz a próxima fatia sem sobreposição; página vazia; `limit` acima de 100 → `400`; cursor malformado → `400 MALFORMED_REQUEST`; recorte por dono; `401` sem sessão.
- [x] 6.2 Teste de invalidação (freshness): registrar um gasto do ator invalida a listagem cacheada dele — uma listagem após o `create` reflete o novo gasto; a invalidação de uma pessoa não afeta a página cacheada de outra.
- [x] 6.3 Rodar `arch-review` sobre o diff (camadas/naming/HTTP, cache no `core`, decorator na infra) e corrigir desvios estruturais.
- [x] 6.4 `./gradlew build` e `./gradlew test` verdes.
- [x] 6.5 Atualizar o `README.md` do contexto `expense` (paginação/cache em linguagem de negócio) e reconciliar specs (`/opsx:sync`) antes de arquivar.
