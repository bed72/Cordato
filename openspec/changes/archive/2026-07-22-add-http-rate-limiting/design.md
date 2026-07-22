## Context

`core/infrastructure/http/` já tem dois filtros cross-cutting descobertos por anotação, sem entrada em
`CoreFactory`: `HttpRequestLoggingFilter` (`Ordered.HIGHEST_PRECEDENCE`, envolve tudo, inclusive o filtro de
autenticação) e `AuthenticatedFilter` (decide se uma rota exige sessão consultando o route match via
`RouteAttributes.getRouteMatch(request)`, e responde `401` neutro retornando — nunca lançando). `CachePort`
já expõe `get`/`set` com TTL e `increment` atômico sobre Valkey (via Lettuce), usado hoje pela invalidação
por geração de `expense`. O contrato de erro (`http-error-handling`/`http-response-envelope`) já define como
um builder de recusa de borda (`unauthorized`) compõe o envelope `errors` e o padrão de neutralidade que uma
nova recusa (429) precisa seguir.

## Goals / Non-Goals

**Goals:**
- Um filtro de rate limiting no mesmo molde arquitetural dos dois filtros existentes.
- Dois níveis de limite por IP: geral (toda rota) e apertado (rotas sem `@Authenticated`), reaproveitando a
  mesma checagem de anotação que `AuthenticatedFilter` já faz, para que a classificação nunca precise ser
  mantida em duas listas.
- Contador em janela fixa sobre Valkey, reaproveitando `CachePort`.
- Resposta `429` neutra e consistente com o padrão de não-vazamento já estabelecido pelo `401`.
- Limites configuráveis por `application.properties`, seguindo a convenção já usada por
  `expense.cache.list-ttl-seconds`.

**Non-Goals:**
- Limite por pessoa autenticada (`AuthenticatedActor.personId`) — adiado; nesta mudança, mesmo uma rota
  `@Authenticated` só é limitada pelo nível geral por IP.
- Janela deslizante ou token bucket — fica fixa nesta mudança.
- Limite configurável por rota individual além da distinção geral/aberta — adiado.
- Extração de IP atrás de proxy/load balancer (`X-Forwarded-For`) — nesta mudança usa-se o IP remoto direto
  da conexão; um ambiente atrás de proxy fica fora do escopo (ver Riscos).

## Decisions

### O filtro roda depois do logging, mas antes da resolução de autenticação

`HttpRequestLoggingFilter` continua envolvendo tudo (`HIGHEST_PRECEDENCE`), para que mesmo uma requisição
barrada por rate limit seja logada. O novo `RateLimitingFilter` roda **antes** de `AuthenticatedFilter`: uma
requisição que estoura o limite nunca deveria pagar o custo de resolver sessão. Sua ordem é
`Ordered.HIGHEST_PRECEDENCE + 100` (mais alta que `AuthenticatedFilter`, mais baixa que o logging), um
número explícito e comentado em vez de uma constante nova em `Ordered`, mesma convenção que
`HttpRequestLoggingFilter` já usa.

**Alternativa considerada**: rodar depois da autenticação, para limitar por `personId` nas rotas protegidas.
Rejeitada nesta mudança porque limite por pessoa é um Non-Goal explícito; rodar antes mantém o filtro
simples (só IP, sem depender do resultado do filtro de autenticação) e barra o abuso mais cedo.

### Reaproveitar a checagem de `@Authenticated` para classificar a rota, não uma lista de paths

Em vez de manter uma lista de paths "abertos" hardcoded, o filtro lê o mesmo route match
(`RouteAttributes.getRouteMatch(request)`) que `AuthenticatedFilter` já usa e verifica a ausência da
anotação `@Authenticated` na rota resolvida. Uma rota sem a anotação usa o limite apertado; uma rota com a
anotação usa apenas o limite geral. Isso garante que qualquer rota aberta futura (ex.: resgate de convite de
`couple`) herda automaticamente o limite apertado, sem exigir uma segunda lista mantida em sincronia com o
guard de autenticação.

**Alternativa considerada**: lista explícita de paths sensíveis (`/sign-up`, `/sign-in`, ...) em
`application.properties`. Rejeitada porque duplica uma decisão que `@Authenticated` já registra
declarativamente por rota, e cria risco de a lista ficar desatualizada quando uma rota aberta nova é
adicionada.

### `CachePort` ganha `incrementWithTtl`, não vira um `RateLimiterPort` dedicado

`increment()` já é o primitivo certo (contador atômico em Valkey), mas não expira sozinho — hoje ele serve
invalidação por geração, onde isso é aceitável. Rate limiting em janela fixa precisa que a **primeira**
chamada da janela grave um TTL (comando Valkey: `INCR` seguido de `EXPIRE key ttl NX` — expira só se a chave
ainda não tiver TTL, para não estender a janela a cada requisição). Isso vira um método novo no port,
`incrementWithTtl(key: String, ttl: Duration): Long`, ao lado do `increment()` existente — não uma
substituição, já que a invalidação por geração continua sem precisar de TTL.

**Alternativa considerada**: um `RateLimiterPort` dedicado em vez de estender `CachePort`. Rejeitada porque
rate limiting é, estruturalmente, "incrementar um contador com expiração automática" — o mesmo tipo de
operação que `CachePort` já modela, sem nenhum conceito novo (chave, valor, TTL) que justifique um port
separado; um port novo só para isso duplicaria o contrato existente.

### O contador é chaveado por `"ratelimit:<nível>:<ip>:<janela atual>"`

A chave inclui o identificador da janela (ex. o timestamp truncado no início do período) para que, ao virar
a janela, uma chave nova comece do zero automaticamente via `incrementWithTtl`, sem lógica extra de reset.
`<nível>` é `general` ou `auth`, para que os dois contadores (geral e apertado) nunca colidam no mesmo IP.

### Resposta `429` usa o builder `tooManyRequests`, espelhando `unauthorized`

Mesma forma que o `401`: um único item escalar no envelope `errors`, `code` estável (`RATE_LIMITED`),
`message` genérica por chave i18n, mais o header `Retry-After` (segundos restantes até a janela atual
expirar, obtido do TTL restante da chave). O corpo/`code`/`message` são os mesmos independentemente de qual
dos dois níveis (geral ou apertado) foi excedido — só o header `Retry-After` varia, porque é informação
operacional (quando tentar de novo), não uma pista sobre qual regra foi violada.

## Risks / Trade-offs

- [IP remoto atrás de proxy/load balancer em produção seria o IP do proxy, não do cliente real, colapsando
  todos os clientes num único contador] → Fora do escopo desta mudança (Non-Goal); documentado aqui para que
  a extensão a `X-Forwarded-For`/`Forwarded` seja uma mudança futura deliberada, não uma surpresa em
  produção.
- [Falha do Valkey (conexão indisponível) durante o incremento propaga como exceção, já que `CachePort` não
  tem opinião sobre degradar para miss] → Igual à política já aceita para o cache de `expense`: uma falha
  genuína do cliente vira `500` pelo handler genérico (`http-error-handling`), nunca abre passagem
  silenciosa. Não é uma regressão introduzida por esta mudança.
- [Janela fixa tem um efeito de borda conhecido (rajada dobrada exatamente na virada da janela)] → Aceito
  deliberadamente: é a limitação padrão de janela fixa, e trocá-la por sliding window/token bucket é um
  Non-Goal explícito desta mudança.

## Migration Plan

Aditivo e sem estado a migrar: nenhuma tabela, nenhum dado existente muda de forma. `incrementWithTtl` é um
método novo no port (implementação nova no adapter), o filtro é novo, o builder é novo. Rollback é reverter
o commit/desligar o filtro; não há dado persistido que precise ser desfeito (contadores em Valkey expiram
sozinhos pelo TTL da janela).

## Open Questions

Nenhuma pendente — os pontos levantados na proposta inicial (janela fixa vs. deslizante, escopo do limite
por pessoa, onde vive a extensão do `CachePort`) foram resolvidos acima e registrados como Non-Goals onde
aplicável.
