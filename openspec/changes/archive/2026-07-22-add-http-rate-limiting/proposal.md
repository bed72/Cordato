## Why

O sistema não tem nenhuma proteção contra abuso de taxa: qualquer rota, autenticada ou não, aceita volume
ilimitado de requisições da mesma origem. As rotas abertas (hoje `POST /sign-up` e `POST /sign-in`; no
futuro qualquer rota sem `@Authenticated`, como o resgate de convite de `couple` quando essa feature ganhar
sua própria camada HTTP) são as mais expostas — não exigem sessão, então ficam disponíveis para
brute-force de credenciais ou enumeração de convites sem nenhum atrito. Cordato já tem toda a
infraestrutura para resolver
isso a baixo custo: `CachePort` já expõe um incremento atômico sobre Valkey (o mesmo primitivo que já serve
a invalidação por geração do cache de `expense`), e o padrão de filtro cross-cutting (`@ServerFilter`
descoberto por anotação, sem entrada no `CoreFactory`) já está estabelecido por `AuthenticatedFilter` e
`HttpRequestLoggingFilter`. Rate limiting é o próximo guard de borda no mesmo molde.

## What Changes

- Novo filtro `@ServerFilter(MATCH_ALL_PATTERN)` em `core/infrastructure/http/ratelimiting/`, que conta
  requisições por chave (IP de origem) numa janela fixa e recusa com `429 Too Many Requests` quando o limite
  da janela é excedido.
- Dois níveis de limite, ambos por IP nesta mudança:
  - um limite geral, aplicado a toda rota, como rede de segurança;
  - um limite mais apertado, aplicado a toda rota sem `@Authenticated` (hoje `POST /sign-up` e
    `POST /sign-in`), para conter brute-force sem exigir sessão prévia — a mesma classificação que já
    decide se `AuthenticatedFilter` resolve sessão, então cobre automaticamente qualquer rota aberta
    futura, sem lista mantida à mão.
  - Limite por pessoa autenticada (`AuthenticatedActor.personId`) fica fora do escopo desta mudança — ver
    Impact.
- `CachePort` ganha uma operação atômica de incremento **com TTL na primeira chamada** (janela fixa), que
  `CacheAdapter`/Valkey implementam via `INCR` + `EXPIRE` condicional. Sem isso, um contador incrementado
  via `increment()` hoje nunca expira sozinho.
- Novo builder `tooManyRequests(code, message, retryAfter)` em `core/infrastructure/http/responses/`,
  irmão de `badRequest`/`unauthorized`/`unprocessable`, produzindo o envelope `errors` já existente
  (`http-response-envelope`) com um único item escalar, mais o header `Retry-After` (segundos até a janela
  reabrir).
- A resposta `429` segue o mesmo princípio de não-vazamento do `401`: o corpo não distingue "IP no limite
  geral" de "IP no limite mais apertado de autenticação" — mesmo `code` estável, mesma `message` genérica.
- Limites (contagem e duração da janela, para o geral e para o de autenticação) configuráveis via
  `application.yml`, nunca hardcoded.

## Capabilities

### New Capabilities
- `http-rate-limiting`: filtro de borda que limita taxa de requisições por IP, em janela fixa, com dois
  níveis (geral e rotas sem `@Authenticated`), respondendo `429` com `Retry-After` quando excedido.

### Modified Capabilities
- `cache-valkey`: `CachePort` ganha uma operação de incremento atômico com TTL na primeira chamada da
  janela (contador de rate limiting), além do `increment()` sem TTL já existente para invalidação por
  geração.
- `http-error-handling`: o envelope `errors` compartilhado ganha uma nova forma escalar de recusa, `429`
  com `Retry-After`, seguindo o mesmo padrão de neutralidade já estabelecido pelo `401`.

## Impact

- Código afetado: `core/application/driven/ports/CachePort.kt`, `core/infrastructure/adapters/cache/`,
  novo pacote `core/infrastructure/http/ratelimiting/`, `core/infrastructure/http/responses/`,
  `application.yml`.
- Nenhuma rota de feature muda de assinatura ou contrato de sucesso; o impacto é só no caminho de recusa.
- Fora do escopo desta mudança (deferido): limite por pessoa autenticada (`AuthenticatedActor.personId`),
  janela deslizante ou token bucket (fica fixa nesta mudança), e limites por rota individual além da
  distinção geral/autenticação aberta.
