## 1. `CachePort` — incremento atômico com TTL

- [ ] 1.1 Adicionar `incrementWithTtl(key: String, ttl: Duration): Long` a
      `core/application/driven/ports/CachePort.kt`, documentando que o TTL só se aplica na primeira
      chamada da janela (contador ainda não existente), igual ao `increment()` existente mas com expiração.
- [ ] 1.2 Implementar em `core/infrastructure/adapters/cache/CacheAdapter.kt` via Lettuce: `INCR` seguido de
      `EXPIRE key ttl NX` (expira só se a chave ainda não tiver TTL), para que incrementos subsequentes na
      mesma janela não estendam a expiração.
- [ ] 1.3 Teste do adapter contra Valkey real (`support/` harness já usado pelos outros testes de cache):
      primeira chamada retorna `1` e aplica TTL; chamadas subsequentes acumulam sem renovar o TTL; após
      expirar, a chamada seguinte reinicia do zero.

## 2. Configuração dos limites

- [ ] 2.1 Adicionar a `application.properties` as chaves de contagem máxima e duração da janela para os
      dois níveis, seguindo a convenção de `expense.cache.list-ttl-seconds` (ex.:
      `rate-limit.general.max-requests`, `rate-limit.general.window-seconds`,
      `rate-limit.auth.max-requests`, `rate-limit.auth.window-seconds`).
- [ ] 2.2 Expor essas propriedades como `@Value`/`@ConfigurationProperties` no ponto onde o filtro as
      consome (ver Seção 3), nunca como literal no código.

## 3. Filtro de rate limiting

- [ ] 3.1 Criar `core/infrastructure/http/ratelimiting/RateLimitingFilter.kt`: `@ServerFilter
      (ServerFilter.MATCH_ALL_PATTERN)` com `@Order(Ordered.HIGHEST_PRECEDENCE + 100)` (depois do logging,
      antes de `AuthenticatedFilter`), mesmo padrão de descoberta por anotação, sem entrada em
      `CoreFactory`.
- [ ] 3.2 No `@RequestFilter`, obter o IP remoto da requisição, montar as chaves
      `ratelimit:general:<ip>:<janela>` e, quando a rota resolvida não carrega `@Authenticated` (via
      `RouteAttributes.getRouteMatch(request)`, mesma leitura que `AuthenticatedFilter` já faz),
      `ratelimit:auth:<ip>:<janela>`.
- [ ] 3.3 Incrementar o(s) contador(es) aplicáveis via `CachePort.incrementWithTtl`; se qualquer um exceder
      seu limite configurado, responder `429` imediatamente (retornar, não lançar — mesmo padrão de
      `AuthenticatedFilter`), sem invocar a lógica da rota.
- [ ] 3.4 Calcular `Retry-After` a partir do TTL restante da chave que estourou o limite.

## 4. Contrato de erro `429`

- [ ] 4.1 Adicionar `tooManyRequests(code: String, message: String, retryAfterSeconds: Long):
      HttpResponse<ErrorsResponse>` em `core/infrastructure/http/responses/`, irmão de `badRequest`/
      `unauthorized`/`unprocessable`, compondo `ErrorsResponse` com um único item escalar e setando o
      header `Retry-After`.
- [ ] 4.2 Adicionar a chave i18n `error.rate_limit.message` em `src/main/resources/i18n/messages.properties`
      (mensagem genérica, sem detalhe de qual limite foi excedido), e usá-la no filtro.
- [ ] 4.3 `RateLimitingFilter` usa `tooManyRequests` para montar a resposta de recusa (Seção 3.3), com code
      `RATE_LIMITED`.

## 5. Testes de integração

- [ ] 5.1 Teste HTTP fim a fim (mesmo padrão do `AuthenticatedFilterTest`, com `support/AuthProbeController`
      ou equivalente): excedendo o limite geral numa rota aberta e numa autenticada, ambas respondem `429`
      com o mesmo corpo.
- [ ] 5.2 Teste HTTP: excedendo apenas o limite apertado (rota sem `@Authenticated`, ex. `POST /sign-up`)
      antes de atingir o limite geral, responde `429`.
- [ ] 5.3 Teste HTTP: uma rota `@Authenticated` sob o mesmo volume que estouraria o limite apertado, mas
      dentro do limite geral, prossegue normalmente (não é afetada pelo nível apertado).
- [ ] 5.4 Teste HTTP: resposta `429` inclui o header `Retry-After` com um valor numérico positivo.
- [ ] 5.5 Atualizar `ArchitectureTest` (Konsist) se necessário para cobrir o novo pacote
      `core/infrastructure/http/ratelimiting/` nas mesmas regras de camada já aplicadas aos filtros
      existentes.

## 6. Documentação

- [ ] 6.1 Rodar `/opsx:sync` para reconciliar `openspec/specs/http-rate-limiting/`,
      `openspec/specs/cache-valkey/` e `openspec/specs/http-error-handling/` com o comportamento
      implementado.
- [ ] 6.2 Arquivar a mudança com `/opsx:archive` após a sincronização.
