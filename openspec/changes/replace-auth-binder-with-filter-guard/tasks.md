## 1. Anotação e reagrupamento físico

- [ ] 1.1 Criar `core/infrastructure/http/authentication/Authenticated.kt`: anotação marcadora `@Authenticated` (`@Retention(RUNTIME)`, `@Target(CLASS, FUNCTION)`), KDoc explicando que declara a rota como protegida
- [ ] 1.2 Mover `AuthenticatedPersonId.kt` de `http/` para `http/authentication/` (ajustar package + imports)
- [ ] 1.3 Mover `BearerToken.kt` de `http/` para `http/authentication/` (ajustar package + imports; segue `internal fun bearerToken`)
- [ ] 1.4 Mover `AuthenticatedPersonIdArgumentBinder.kt` de `http/binders/` para `http/authentication/` e remover a pasta `binders/` vazia

## 2. Filtro de autenticação (guard)

- [ ] 2.1 Criar `http/authentication/AuthenticationServerFilter.kt` como `@ServerFilter`: injeta `ClockPort` e `BeanProvider<SessionRepository>` (resolução lazy, para não realizar o DataSource no boot — mesma razão do binder atual)
- [ ] 2.2 No filtro, ler a `RouteMatch` (`HttpAttributes.ROUTE_MATCH`) e prosseguir sem tocar sessão quando a rota **não** carrega `@Authenticated` (rota aberta)
- [ ] 2.3 Numa rota `@Authenticated`: extrair o Bearer via `bearerToken`, resolver `findActiveByToken(token, clock.now())`; sessão viva → gravar o id no request attribute e seguir a cadeia
- [ ] 2.4 Numa rota `@Authenticated` sem sessão viva (ausente/malformado/expirado/revogado): lançar `UnauthenticatedException` para o handler compartilhado renderizar o `401` neutro (`UNAUTHENTICATED`, sem `WWW-Authenticate`). Se a exceção do filtro não for roteada ao handler, emitir a resposta direto via o builder `unauthorized(...)` (fallback da Decisão 4)

## 3. Binder honesto e limpeza do mecanismo antigo

- [ ] 3.1 Reduzir `AuthenticatedPersonIdArgumentBinder` a **apenas ler** o request attribute populado pelo filtro: sem `SessionRepository`, sem `ClockPort`, sem lançar exceção; attribute ausente → `BindingResult` não-satisfeito
- [ ] 3.2 Confirmar que `UnauthenticatedException` deixou de ser lançada pelo binder e agora só vem do filtro; manter a classe e o `UnauthenticatedExceptionHandler` em `errors/`
- [ ] 3.3 Garantir que o `SessionController` (sign-out, `DELETE /sessions`) continua lendo o Bearer direto via `bearerToken` e **não** recebe `@Authenticated` (rota aberta e idempotente por contrato)

## 4. Testes

- [ ] 4.1 Reescrever `AuthenticatedPersonIdBinderTest` (renomear para refletir o filtro, ex.: `AuthenticationServerFilterTest`) com um probe controller: uma rota `@Authenticated` e uma aberta
- [ ] 4.2 Casos: token válido → handler recebe o `AuthenticatedPersonId` (id certo); sem token na rota protegida → `401` `UNAUTHENTICATED` na forma compartilhada; token irresolvível → `401`; rota aberta sem token → segue `200`
- [ ] 4.3 Caso non-leak: token ausente, expirado e revogado produzem status e corpo idênticos (sem `WWW-Authenticate`, sem indicar a causa)
- [ ] 4.4 Manter o `FakeSessionRepository` (`@Replaces` do `SessionRepository`) pré-carregado; nenhum PostgreSQL/relógio global

## 5. Documentação e verificação

- [ ] 5.1 Atualizar a seção de autenticação do `CLAUDE.md`: substituir a descrição do binder opt-in pelo guard declarativo (`@Authenticated` + `@ServerFilter`, ator tipado via attribute, `401` neutro do filtro)
- [ ] 5.2 Rodar `./gradlew compileKotlin compileTestKotlin` e `./gradlew test` (inclui o teste de arquitetura Konsist); ajustar o Konsist se ele afirmar algo sobre o pacote/nome do mecanismo antigo
