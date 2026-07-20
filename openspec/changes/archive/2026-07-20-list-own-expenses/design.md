## Context

O contexto `expense` já entregou o registro (`POST /expenses`): domínio (`ExpenseEntity`, value objects,
`MoneyValueObject` no `core`), aplicação (`CreateExpenseUseCase`, `ExpenseRepository` port), persistência
jOOQ (`PersistenceExpenseRepository`, tabela `expense` da `V3`) e a slice HTTP completa (`ExpenseController`
+ `ExpenseControllerDoc`, `ExpenseResponse`, error mapper, OpenAPI). Falta o lado de leitura: hoje um gasto
registrado não pode ser visto de volta pelo dono.

Esta mudança adiciona a leitura mínima — **listar os próprios gastos** — reusando ao máximo o que a fatia
de create já montou. O molde de leitura autenticada mais próximo é `identity`'s `GET /persons/me`
(`MeUseCase` + `PersonController.me`): rota `@Authenticated`, `personId` vindo do `AuthenticatedActor`,
resultado traduzido para `200`.

Restrições herdadas (obedecidas, não decididas aqui): domínio/aplicação nunca importam Micronaut/jOOQ; o
`personId` do dono vem sempre do ator autenticado, nunca do corpo/parâmetro; o contrato de erro e o guard
de auth vivem no `core`; o prefixo `/v1` vem de config; texto de resposta por chave i18n.

## Goals / Non-Goals

**Goals:**
- `GET /expenses` retorna os gastos do ator autenticado, e só dele, **paginados por cursor (keyset)** e
  ordenados de forma determinística — a dupla `(spent_on, id)` é a base do cursor.
- Pessoa sem gastos recebe `200` com página vazia (`items: []`, sem próximo cursor), nunca `404`.
- A listagem é servida **read-through** por um **cache distribuído (Valkey)**, invalidado por geração no
  `create`, sem que `application`/`domain` do expense saibam do cache.
- Reusar `ExpenseEntity`, `ExpenseResponse` e o mapper de item existentes; adicionar só o que falta.
- Estender o `ExpenseRepository`/adapter com uma consulta keyset por pessoa, sem migração nova.

**Non-Goals:**
- **Filtro por intervalo de datas** — query diferente (soma/recorte por range) que `budget`/`couple` vão
  precisar; fatia futura própria.
- Editar/apagar gasto; qualquer visão derivada (orçamento ativo, "sem orçamento", casal) — pertence a
  `budget`/`couple`.
- Ordenação configurável pelo cliente (sort params) — a ordem é fixa e determinística (e é a base do
  cursor; torná-la configurável mudaria o cursor).
- Paginação **por offset** (`OFFSET/LIMIT`) — rejeitada em favor de keyset (ver decisão).
- Cache **HTTP** (ETag/Cache-Control) ou **in-memory** por instância — a decisão é cache distribuído
  Valkey, compartilhado entre instâncias (ver decisão).

## Decisions

### Sem `ListExpensesResult`/`ListExpensesError` — o use case devolve um `ExpensePageVirtualObject`

Listar os próprios gastos **não tem ramo de falha de domínio honesto**: o resultado é sempre uma página
(possivelmente vazia). Diferente de `MeUseCase`, que tem `PersonNotFound` (a pessoa pode ter sumido numa
corrida com exclusão), aqui uma pessoa sem gastos é um sucesso com zero itens, não um "não encontrado".
- **Decisão**: `ListExpensesUseCase.invoke(command): ExpensePageVirtualObject`. Nenhum `sealed`
  `Result`/`Error`. Mesmo princípio do `ExpenseRepository.create` (devolve `Unit`): não inventar distinção
  que não existe.
- **`ExpensePageVirtualObject(items: List<ExpenseEntity>, nextCursor: ExpenseCursorValueObject?)`** vive em
  `domain/virtual_objects/`. É o encaixe perfeito da categoria Virtual Object do CLAUDE.md: uma **projeção
  de leitura** montada na hora a partir de entidades reais, sem identidade própria, nunca persistida. Um
  `data class` sem cerimônia. `nextCursor == null` ⟺ última página.
- **`ExpenseCursorValueObject(spentOn: LocalDate, id: String)`** vive em `domain/value_objects/` — a posição
  de keyset (a dupla que a ordem determinística já define). Note que **não** é `@JvmInline value class`
  (carrega dois campos), então é um `data class` imutável com um `of(spentOn, id)`; a *codificação* opaca
  (base64) desse cursor **não** é domínio — é um mapper HTTP (ver slice HTTP).
- **`ListExpensesCommand(personId: String, limit: Int, after: ExpenseCursorValueObject?)`**: cresce para
  carregar a página pedida. O `personId` vem do ator; `limit`/`after` vêm dos query params (já validados e
  decodificados no edge).
- **Não checar status ativo da pessoa** dentro do use case: a rota já é gated pela sessão viva do guard do
  `core` (mesma postura da fatia de create); a corrida com exclusão de conta é concern de `identity`.

### Paginação **cursor-based (keyset)**, não offset

- **Decisão**: keyset pagination sobre a chave de ordenação `(spent_on, id)`. A página pede `limit` itens;
  o repositório busca `limit + 1` para saber se há próxima página **sem um `COUNT` extra**. Se vierem
  `limit + 1`, corta para `limit` e o `nextCursor` é o `(spent_on, id)` do **último item mantido**; senão
  `nextCursor = null`.
- **Predicado keyset** sob `ORDER BY spent_on DESC, id DESC`: "depois do cursor" é
  `(spent_on, id) < (cursor.spentOn, cursor.id)` — em jOOQ, `row(SPENT_ON, ID).lessThan(row(date, id))`,
  que o Postgres avalia como comparação lexicográfica de tupla, casando exatamente a ordem. `LIMIT ?` no
  banco.
- **`limit`**: default **20**, máximo **100** (um teto que impede uma página gigante); é puro transporte,
  validado só no edge (`@Positive` + `@Max(100)`), sem value object.
- **`cursor`**: string **opaca** (base64-url de `"<spent_on ISO>|<id>"`). Opaca de propósito — o cliente
  não deve construí-la nem depender do formato; só devolve o `next_cursor` que recebeu. Decodificação e
  validação ficam no mapper HTTP: um cursor ilegível → `400 MALFORMED_REQUEST` (escalar, contrato do core),
  nunca um `500`.
- **Por que keyset e não offset**: `OFFSET n` relê e descarta `n` linhas (degrada com a profundidade) e
  *escorrega* quando linhas são inseridas entre as leituras (um novo gasto empurraria itens de página). O
  keyset é estável sob inserção e O(página), e a chave de ordenação já existe indexável.
- **Envelope de resposta** `{ items: [...], next_cursor: "<opaco>"|null }`: a paginação exige um envelope,
  não dá para carregar o `next_cursor` num array nu. Isto **substitui** o array que a versão anterior desta
  mudança (ainda não liberada) devolvia — revisão consciente antes do release, era a Open Question desta
  própria mudança.

### Cache distribuído (Valkey) **atrás da fronteira do repositório**, não no use case

O requisito é cache compartilhado entre instâncias → Valkey (Redis-compatível). A questão de arquitetura é
*onde* ele entra sem contaminar as camadas puras.
- **Decisão**: o cache é uma preocupação de **infraestrutura/persistência**, invisível para
  `application`/`domain`. Um **decorator** `CachingExpenseRepository(persistence, cache, clock)` implementa
  o mesmo port `ExpenseRepository` e embrulha o `PersistenceExpenseRepository`:
  - `findByPerson(personId, after, limit)` é **read-through**: monta a chave, tenta o Valkey, e no miss
    delega ao persistence e popula o cache (com TTL).
  - `create(expense)` delega ao persistence e então **invalida** as páginas daquela pessoa.
  - O `ExpenseFactory` passa a injetar no `ListExpensesUseCase`/`CreateExpenseUseCase` o repositório
    **decorado**; o use case continua vendo só o port `ExpenseRepository` — **cache-agnóstico**.
- **Alternativa rejeitada — cache-aside no use case via `CachePort`**: o use case é `application`
  (framework-agnóstico) e um `CachePort` puro até poderia morar lá, mas isso mistura "o quê" (listar) com
  "como acelerar" (cache) na camada de política, e força a serialização (uma preocupação de infra) para
  perto do domínio. O decorator mantém a separação limpa: política no use case, performance na borda.
- **Invalidação por geração (sem varredura)**: manter, para cada pessoa, um contador `gen` no Valkey
  (`expenses:{personId}:gen`). A chave de página embute a geração:
  `expenses:{personId}:v{gen}:{cursorToken}:{limit}` (cursorToken = `"first"` na primeira página, senão o
  cursor opaco). Invalidar é `INCR expenses:{personId}:gen` → toda página em cache da versão antiga fica
  órfã e **expira sozinha por TTL** (nunca é lida de novo). Evita `KEYS`/`SCAN` (proibitivos em produção) e
  é atômico. Um `gen` ausente é lido como `0`.

- **Regras de invalidação (contrato — muito importante)**: **toda escrita que muda o conjunto de gastos de
  uma pessoa invalida a listagem cacheada daquela pessoa**, imediatamente após a escrita persistir. A regra
  é definida por *mutação*, não por rota:
  - **Criar** um gasto (`POST /expenses`, o único write que existe hoje) → invalida a geração do **dono**.
  - **Editar** um gasto (quando existir) → invalida a geração do **dono**. Se um dia a edição puder
    transferir dono (não é o caso no modelo — um gasto pertence a uma pessoa e não muda de dono), invalidaria
    **ambos**; hoje é sempre um só.
  - **Apagar** um gasto (quando existir) → invalida a geração do **dono**.
  - Regra geral, à prova de esquecimento: *qualquer* operação que insira, altere ou remova uma linha de
    `expense` de uma pessoa DEVE invalidar aquela pessoa. Como todas essas operações passam pelo
    `ExpenseRepository`, a invalidação vive **num único ponto — o `CachingExpenseRepository`** — no caminho
    de escrita de cada método de mutação (`create` hoje; `update`/`delete` reusam o mesmo helper quando
    forem specados). Nenhum use case invalida cache à mão; nenhuma mutação futura pode "esquecer", porque o
    seam é o próprio repositório decorado.
  - **Escopo mínimo**: invalida-se por **pessoa** (bump da geração dela), nunca o cache inteiro — a escrita
    de uma pessoa jamais mexe nas páginas de outra.
  - **Ordem**: persiste primeiro, invalida depois. Se o `INCR` falhar (Valkey indisponível), a escrita no
    Postgres **não** é desfeita; o TTL curto garante que a página obsoleta caduque em segundos como piso de
    correção, e a falha é logada. (Persistir-e-depois-invalidar pode, numa janela de milissegundos, servir
    a geração antiga a uma leitura concorrente; aceito e coberto pelo TTL — ver "Consistência aceita".)
- **Hoje só o `create` existe** no expense, então só ele fica de fato ligado à invalidação nesta mudança;
  `update`/`delete` **não** são implementados aqui (exigiriam suas próprias specs SDD). O que esta mudança
  entrega é o **seam** e a **regra**, já desenhados para que edição/exclusão, quando chegarem, só chamem o
  mesmo `invalidate(personId)` — não um mecanismo de invalidação a ser reinventado por feature.
- **TTL**: um TTL curto (proposto **60 s**) como rede de segurança contra chaves órfãs e qualquer
  invalidação perdida; a correção primária vem da geração, o TTL é defesa em profundidade. Config, não
  literal.
- **O que é cacheado**: o retorno bruto do `findByPerson` daquela chave (a lista de até `limit + 1`
  `ExpenseEntity`), serializado. O `ListExpensesUseCase` continua computando o `ExpensePageVirtualObject`
  (corte + `nextCursor`) por cima — cachear o dado cru, não a projeção, mantém o cache burro e a política
  fora dele. Serialização: JSON compacto via um serializador de infra (não vaza para `domain`).
- **Consistência aceita**: entre instâncias, a janela é a de uma leitura read-through normal; como o dono é
  o único que escreve **e** lê os próprios gastos, e o `create` invalida logo após persistir, uma leitura
  do próprio dono após criar já vê a geração nova. Uma corrida teórica (ler no exato instante entre o
  persist e o `INCR`) só serve dado no máximo 1 geração atrás e é coberta pelo TTL.

### `core` ganha um kernel de cache (`CachePort` + adapter Valkey)

Cache é transversal (como o contrato de erro e o guard de auth), então mora no `core`, não no `expense`.
- **`CachePort`** em `core/application/driven/ports/` — contrato puro e mínimo que o app precisa do cache:
  `get(key): String?`, `set(key, value, ttl)`, `increment(key): Long`. Sem tipos Redis na assinatura —
  strings e um `Duration`, para o port ficar agnóstico do cliente.
- **`ValkeyCacheAdapter`** em `core/infrastructure/.../cache/` — implementa o port sobre um cliente
  **Lettuce** (Redis-compatível, já resolvível pela BOM Micronaut). Só aqui aparece o tipo do cliente.
- **Wiring no `CoreFactory`** (um `@Singleton CachePort` + o cliente/conexão), seguindo a regra "um
  `@Factory` por pacote"; `application`/`domain` nunca importam o cliente nem anotação de DI.
- **Config** em `application.properties` (`valkey.host`/`valkey.port`), com serviço `valkey` no
  `compose.yml` e `.env.example`/`Makefile` para o dev local; o teste de integração do adapter usa a
  imagem Valkey no Testcontainers (mesmo padrão do `PostgresHarness`).

### Ordenação determinística: `spent_on` desc, desempate por `id`

A lista precisa de ordem estável para ser testável e previsível. A tabela `expense` (`id`, `person_id`,
`amount_cents`, `spent_on`, `description`) **não tem `created_at`**, então não há como ordenar por "ordem
de registro".
- **Decisão**: ordenar por `spent_on` **decrescente** (o gasto mais recente no mundo real primeiro — a
  leitura mais útil no dia a dia), com desempate por `id` decrescente (estável e determinístico, ainda que
  o `id` não tenha significado temporal). Ordenação feita no banco (`ORDER BY spent_on DESC, id DESC`),
  não em memória.
- **Alternativa considerada**: adicionar `created_at` na tabela para ordenar por ordem de digitação.
  Rejeitada por ora — exigiria migração e o README define a data-que-aconteceu como a data canônica; a
  ordem por `spent_on` é a mais fiel ao domínio. Fica anotável se o produto pedir "ordem de registro".

### Persistência: `findByPerson` keyset no port e adapter, sem migração

- **Port**: `ExpenseRepository.findByPerson(personId: String, after: ExpenseCursorValueObject?, limit: Int):
  List<ExpenseEntity>` — devolve `List` (nunca `null`; vazio quando não há gastos após o cursor). O use case
  passa `limit + 1` para descobrir se há próxima página; o próprio port não conhece cursor opaco nem
  envelope, só a posição de keyset tipada e o limite.
- **Adapter** (`PersistenceExpenseRepository`): `dsl.selectFrom(EXPENSE).where(PERSON_ID.eq(personId))`,
  mais — quando `after != null` — `.and(row(SPENT_ON, ID).lessThan(row(after.spentOn, after.id)))`,
  `.orderBy(SPENT_ON.desc(), ID.desc()).limit(limit).fetch { it.toEntity() }`. Reusa o índice por
  `person_id` da `V3` (a ordenação/keyset por `(spent_on, id)` é servida ordenando o subconjunto do dono).
  O mapper `toEntity` já existe.
- **Sem migração nova**: `V3` já basta. (Se o `EXPLAIN` mostrar a ordenação custando caro em volume real,
  um índice composto `(person_id, spent_on desc, id desc)` é um follow-up de performance — anotado, fora
  do escopo.)

### Slice HTTP: `@Get` cursor-paginado + envelope

- Adiciona `list(actor, limit: Int?, cursor: String?): HttpResponse<*>` com `@Get` `@Authenticated`
  `@Status(HttpStatus.OK)`. `limit`/`cursor` são `@QueryValue` de **puro transporte**, validados **só no
  edge**: `@Positive @Max(100)` no `limit` (default 20 quando ausente), `cursor` opcional. Injeta o
  `ListExpensesUseCase` no construtor.
- **Decodificação do cursor** num mapper HTTP (`mappers/requests/`): `String? -> ExpenseCursorValueObject?`
  (base64-url → `spent_on|id`). Um cursor ilegível **não** é `500`: o mapper sinaliza malformado e o
  controller responde `400 MALFORMED_REQUEST` pelo builder do core — mesma família do corpo malformado do
  create. (Como é o único `4xx` de política desta rota além do `401`, resolver isso no mapper mantém o
  handler fino.)
- Monta `ListExpensesCommand(actor.personId, limit ?: DEFAULT_LIMIT, after)` e responde
  `HttpResponse.ok(useCase(command).toResponse())`.
- **Envelope** `ExpensePageResponse(items: List<ExpenseResponse>, nextCursor: String?)` (`@Serdeable`;
  serializa `next_cursor` snake_case pela política global). O mapper de página
  `ExpensePageVirtualObject.toResponse()` reusa o `ExpenseEntity.toResponse()` por item e **codifica** o
  `nextCursor` de volta para a string opaca (`null` na última página).
- **Reusa `ExpenseResponse`** (item idêntico ao do create).
- **`ExpenseControllerDoc`**: método `list` com `@Operation`/`@Parameter` (documentando `limit`/`cursor`) e
  `@ApiResponse` `200` com corpo `ExpensePageResponse`, mais `400`/`401`/`500` → `ErrorResponse`. O
  controller implementa; `@Status(OK)` documenta o `200`.
- **i18n**: nenhuma chave de erro de domínio nova; o `400` do cursor reusa `MALFORMED_REQUEST`. Só
  descrições OpenAPI.

### DI: repositório decorado por cache no `ExpenseFactory`

- O `ExpenseFactory` liga o `PersistenceExpenseRepository` e o embrulha:
  `@Singleton expenseRepository(dsl, cache, clock): ExpenseRepository =
  CachingExpenseRepository(PersistenceExpenseRepository(dsl), cache, clock)`. O `CachePort` vem do
  `CoreFactory` (kernel). Os dois use cases (`list`/`create`) recebem esse `ExpenseRepository` decorado sem
  saber que há cache.
- Nada de anotação de DI em `application`/`domain`; o decorator é `infrastructure`, o port do cache é puro.

## Risks / Trade-offs

- **Nova dependência de infra (Valkey) no caminho da listagem** → se o Valkey cair, a leitura não pode
  simplesmente falhar. Mitigação: o decorator trata falha do cache como **miss** (log + segue para o
  persistence) — o cache acelera, não é fonte da verdade; o Postgres sempre responde.
- **Invalidação por geração deixa chaves órfãs** no Valkey até expirarem → uso de memória transitório.
  Mitigação: o TTL curto limpa; o `INCR` é O(1) e não varre. Aceito.
- **Cursor opaco acoplado à ordem `(spent_on, id)`** → mudar a ordenação invalida cursores em trânsito.
  Mitigação: a ordem é fixa e não configurável por design; se algum dia mudar, é um versionamento de cursor
  consciente.
- **Ordenar por `spent_on` sem `created_at`** → dois gastos no mesmo dia se ordenam por `id` (sem
  significado temporal), o que também define o desempate do cursor. Mitigação: é um desempate estável e
  determinístico; a ordem primária (data) é a que importa ao usuário.
- **Serialização do `ExpenseEntity` para o cache** → um formato que precisa sobreviver a mudanças do
  entity. Mitigação: a geração/TTL faz o cache ser sempre reconstruível a partir do Postgres; um formato
  ilegível é tratado como miss.

## Open Questions

- **Filtro por intervalo de datas** no próprio `GET /expenses` (ex.: `?from=&to=`) vs. deixar a query por
  range exclusiva do consumo interno de `budget`/`couple`. Proposto: fora desta fatia.
- **Índice composto `(person_id, spent_on desc, id desc)`** para a ordenação keyset em volume real:
  incluir já ou deixar como follow-up guiado por `EXPLAIN`? Proposto: follow-up, o índice por `person_id`
  da V3 basta para o volume atual.
- **TTL do cache (60 s proposto) e `limit` default/máx (20/100 propostos)**: confirmar os números como
  contrato antes do apply.
