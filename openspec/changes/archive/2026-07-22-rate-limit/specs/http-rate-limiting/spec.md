## ADDED Requirements

### Requirement: Toda rota é limitada por padrão, com dois níveis configuráveis

O sistema SHALL aplicar um limite de requisições por janela fixa de tempo a **toda** rota HTTP, via um
`@ServerFilter` cross-cutting no `core`. SHALL existir dois níveis (`general` e `sensitive`), cada um com
seu próprio limite numérico e duração de janela, ambos vindos de configuração externa
(`application.properties`), nunca de literais no código. Uma rota SHALL usar o nível `sensitive` apenas
quando seu handler estiver explicitamente anotado (marcador dedicado, análogo a `@Authenticated`); toda rota
sem essa anotação SHALL cair no nível `general` — de modo que nenhuma rota fica sem limite algum por
ausência de anotação.

#### Scenario: Rota sem anotação usa o nível geral

- **WHEN** uma requisição chega a uma rota cujo handler não carrega o marcador de nível sensível
- **THEN** o sistema conta essa requisição contra o limite e a janela configurados para `general`

#### Scenario: Rota anotada usa o nível sensível

- **WHEN** uma requisição chega a uma rota cujo handler carrega o marcador de nível sensível
- **THEN** o sistema conta essa requisição contra o limite e a janela configurados para `sensitive`, tipicamente
  mais restritivos que `general`

### Requirement: Janela fixa por contador atômico no Valkey

O sistema SHALL implementar o limite como uma **janela fixa**: cada requisição incrementa atomicamente um
contador associado à combinação (nível, identidade do cliente, início da janela corrente), via o `CachePort`
da capability `cache-valkey`. O início da janela SHALL ser derivado do relógio determinístico do sistema
(`ClockPort`), truncado para múltiplos da duração da janela — nunca de `System.currentTimeMillis()` direto.
Quando o contador da requisição corrente excede o limite configurado para aquele nível, o sistema SHALL
recusar a requisição **antes** dela alcançar o handler; abaixo do limite, a requisição prossegue normalmente.

#### Scenario: Requisições dentro do limite prosseguem

- **WHEN** o contador da janela corrente, após incrementado pela requisição, é menor ou igual ao limite do
  nível daquela rota
- **THEN** a requisição prossegue ao handler normalmente, sem alteração de resposta

#### Scenario: Requisição que excede o limite é recusada antes do handler

- **WHEN** o contador da janela corrente, após incrementado pela requisição, excede o limite do nível
  daquela rota
- **THEN** o sistema recusa a requisição com `429 Too Many Requests`
- **AND** o handler da rota não é invocado

#### Scenario: Nova janela reinicia a contagem

- **WHEN** o tempo avança para além do fim da janela corrente e uma nova requisição chega
- **THEN** o contador dessa nova janela começa do zero, independente da contagem da janela anterior

### Requirement: Identidade do cliente é o IP, decidida antes da resolução de sessão

O sistema SHALL identificar o cliente pelo endereço IP remoto da requisição (`remoteAddress`) para o
propósito de rate limiting, em **toda** rota — inclusive rotas protegidas por sessão. O filtro de rate limit
SHALL executar antes do guard de autenticação do `core` (a mesma ordem relativa que garante que uma
enxurrada de tokens inválidos contra uma rota protegida seja limitada antes de disparar uma consulta de
sessão), de modo que a identidade da pessoa autenticada nunca está disponível no momento da decisão — a
chave SHALL ser sempre o IP, nunca o id da pessoa, nesta versão.

#### Scenario: Rota pública é limitada por IP

- **WHEN** requisições anônimas repetidas chegam de um mesmo IP a uma rota pública (ex.: `sign-up`)
- **THEN** todas contam contra o mesmo contador daquele IP

#### Scenario: Rota protegida com token inválido ainda é limitada

- **WHEN** requisições repetidas chegam de um mesmo IP a uma rota protegida, cada uma com um token
  ausente, malformado ou inválido
- **THEN** todas contam contra o contador de rate limit daquele IP, antes de qualquer consulta de sessão
- **AND**, ao exceder o limite, a rejeição por rate limit `429` ocorre antes da rejeição de autenticação `401`

### Requirement: Filtro precede o guard de autenticação na cadeia

O `RateLimitFilter` SHALL ser ordenado, na cadeia de `@ServerFilter`, depois do `HttpRequestLoggingFilter`
(que continua envolvendo toda a cadeia) e antes do guard de autenticação — de modo que toda requisição,
autenticada ou não, passa pela decisão de rate limit antes de qualquer outro processamento além do log.

#### Scenario: Requisição recusada por rate limit ainda é logada com correlation id

- **WHEN** uma requisição é recusada com `429`
- **THEN** a resposta ainda carrega o header de correlation id do `HttpRequestLoggingFilter`
- **AND** o log de requisição/resposta cross-cutting registra o `429` normalmente

### Requirement: Resposta 429 usa o envelope de erro compartilhado com Retry-After

Ao recusar uma requisição por rate limit, o sistema SHALL responder `429 Too Many Requests` usando o mesmo
envelope de erro compartilhado (`errors`) da capability `http-error-handling`, como um item escalar (sem
`source`) com um código estável de máquina. A resposta SHALL carregar um header `Retry-After` com os
segundos restantes até o fim da janela corrente, derivados do mesmo início de janela usado para a chave do
contador — nunca um valor fixo hardcoded.

#### Scenario: Corpo da recusa segue o envelope compartilhado

- **WHEN** uma requisição é recusada por exceder o limite
- **THEN** o corpo é `{ "errors": [...] }` com exatamente um item, sem `source`
- **AND** esse item carrega `status: "429"`, um `code` estável e uma `message` legível

#### Scenario: Retry-After reflete o tempo restante da janela

- **WHEN** uma requisição é recusada faltando N segundos para o fim da janela corrente
- **THEN** o header `Retry-After` da resposta carrega N segundos
