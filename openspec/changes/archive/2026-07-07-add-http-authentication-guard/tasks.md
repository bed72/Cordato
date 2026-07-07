## 1. Ator, anotação e chave de attribute

- [x] 1.1 Criar `core/infrastructure/http/authentication/Authenticated.kt`: anotação marcadora (`@Retention(RUNTIME)`, `@Target(CLASS, FUNCTION)`), KDoc explicando que declara a rota como protegida
- [x] 1.2 Criar `AuthenticatedPersonId.kt`: **`data class`** (não value class — pitfall de binding) carregando **só** o id, **mais** a `internal const AUTHENTICATED_PERSON_ID_ATTRIBUTE` (a chave do request attribute que carrega esse id) co-localizada com o tipo que ela transporta

## 2. Filtro de autenticação (guard)

- [x] 2.1 Criar `AuthenticationServerFilter.kt` como `@ServerFilter`: injeta `ClockPort`, `MessagePort` e `BeanProvider<SessionRepository>` (lazy, para não realizar o DataSource no wiring); `bearerToken()` fica como `private fun` extension **no próprio arquivo** (único consumidor — não vira arquivo à parte)
- [x] 2.2 Ler a `RouteMatch` (`RouteAttributes.getRouteMatch(request)` — o accessor não-deprecated do MN4, em vez do `HttpAttributes.ROUTE_MATCH` deprecated); rota que **não** carrega `@Authenticated` (ou sem match) → seguir a cadeia sem tocar sessão
- [x] 2.3 Rota `@Authenticated`: extrair o Bearer, resolver `findActiveByToken(token, clock())`; sessão viva → gravar o `personId` no request attribute e seguir
- [x] 2.4 Rota `@Authenticated` sem sessão viva (ausente/malformado/expirado/revogado, indistinguíveis) → **retornar** `unauthorized("UNAUTHENTICATED", messages("error.authentication.message"))` (sem `WWW-Authenticate`, sem ecoar o token). Sem exceção nem handler

## 3. Ator tipado (binder honesto) + wiring

- [x] 3.1 Criar `AuthenticatedPersonIdArgumentBinder.kt`: `TypedRequestArgumentBinder<AuthenticatedPersonId>` que **apenas lê** o request attribute; ausente → `BindingResult` não-satisfeito; sem `SessionRepository`, sem `ClockPort`, sem lançar
- [x] 3.2 Wire no `CoreFactory`: `@Singleton fun …(): TypedRequestArgumentBinder<AuthenticatedPersonId> = AuthenticatedPersonIdArgumentBinder()` (annotation-free; o filtro é a peça anotada-descoberta, o binder não)

## 4. i18n

- [x] 4.1 Adicionar `error.authentication.message` ao `src/main/resources/i18n/messages.properties` (genérica, não-vazante), junto das demais chaves cross-cutting (`error.validation`/`error.malformed`/`error.internal`)

## 5. Documentação e verificação

- [x] 5.1 Adicionar ao `CLAUDE.md` a seção de autenticação de borda (hoje inexistente): `@Authenticated` + `@ServerFilter` como a exceção anotada-descoberta (junto de controllers/handlers), ator tipado via attribute + binder honesto factory-wired, e o `401` neutro **retornado** pelo filtro reusando o builder compartilhado
- [x] 5.2 Rodar `./gradlew compileKotlin compileTestKotlin` (garante que compila e que o binder/filtro casam com a API do Micronaut 4)

## 6. Testes — ADIADOS (feitos numa etapa posterior, fora desta change)

> Deliberadamente fora de escopo agora, por decisão do autor. Quando forem escritos, cobrir: rota `@Authenticated` com token válido → handler recebe o `AuthenticatedPersonId`; sem token → `401 UNAUTHENTICATED`; token irresolvível → `401`; rota aberta sem token → segue; e non-leak (ausente/expirado/revogado com status+corpo idênticos, sem `WWW-Authenticate`). Doubles: `FakeSessionRepository` (`@Replaces`) + `ClockPort` fixo, sem PostgreSQL.
