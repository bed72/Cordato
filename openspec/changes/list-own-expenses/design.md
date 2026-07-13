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
- `GET /expenses` retorna todos e somente os gastos do ator autenticado, ordenados de forma determinística.
- Pessoa sem gastos recebe `200` com lista vazia (nunca `404`).
- Reusar `ExpenseEntity`, `ExpenseResponse` e o mapper de resposta existentes; adicionar só o que falta.
- Estender o `ExpenseRepository`/adapter com uma consulta por pessoa, sem migração nova.

**Non-Goals:**
- **Paginação** e **filtro por intervalo de datas** — deliberadamente fora desta fatia (ver Open Questions).
- Editar/apagar gasto; qualquer visão derivada (orçamento ativo, "sem orçamento", casal) — pertence a
  `budget`/`couple`.
- Consulta por **intervalo de datas** que `budget`/`couple` vão precisar: é uma query diferente
  (soma/recorte por range), fatia futura própria; esta entrega só a listagem completa do dono.
- Ordenação configurável pelo cliente (sort params) — a ordem é fixa e determinística.

## Decisions

### Sem `ListExpensesResult`/`ListExpensesError` — o use case devolve `List<ExpenseEntity>` direto

Listar os próprios gastos **não tem ramo de falha de domínio honesto**: o resultado é sempre uma lista
(possivelmente vazia). Diferente de `MeUseCase`, que tem `PersonNotFound` (a pessoa pode ter sumido numa
corrida com exclusão), aqui uma pessoa sem gastos é um sucesso com zero itens, não um "não encontrado".
- **Decisão**: `ListExpensesUseCase.invoke(command: ListExpensesCommand): List<ExpenseEntity>`, retornando
  a lista direto. Nenhum `sealed` `Result`, nenhum `Error`. Mesmo princípio já aplicado no
  `ExpenseRepository.create` (devolve `Unit`, sem `Outcome`): não inventar distinção que não existe.
- **`ListExpensesCommand(personId: String)`**: mantido por simetria com `MeCommand`/`CreateExpenseCommand`
  e para deixar o contrato do driving-side explícito; hoje carrega só o `personId`. Se filtros vierem
  depois, o command cresce; o retorno continua uma lista.
- **Alternativa considerada**: um `ListExpensesResult.Success(list)` selado "para simetria". Rejeitada —
  um `sealed` de um caso só é cerimônia sem valor; CLAUDE.md reserva os tipos selados para ramos que
  divergem de fato.
- **Não checar status ativo da pessoa** dentro do use case: a rota já é gated pela sessão viva do guard do
  `core` (mesma postura da fatia de create); a corrida com exclusão de conta é concern de `identity`.

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

### Persistência: `findByPerson` no port e adapter, sem migração

- **Port**: `ExpenseRepository.findByPerson(personId: String): List<ExpenseEntity>` — devolve `List`
  (nunca `null`; vazio quando não há gastos).
- **Adapter** (`PersistenceExpenseRepository`): `dsl.selectFrom(EXPENSE).where(PERSON_ID.eq(personId))
  .orderBy(SPENT_ON.desc(), ID.desc()).fetch { it.toEntity() }`. Reusa o índice por `person_id` já criado
  na `V3`. O mapper `toEntity` (record → `ExpenseEntity`) é o par do `toRecord` já existente — hoje só há
  `toRecord`, então **adiciona-se o `toEntity`** no mesmo `ExpenseRecordMapper` (`internal`), espelhando o
  `PersonRecordMapper` que tem os dois sentidos.
- **Sem migração nova**: `V3` já basta.

### Slice HTTP: novo `@Get` no `ExpenseController` existente

- Adiciona `list(actor: AuthenticatedActor): HttpResponse<*>` com `@Get` `@Authenticated`
  `@Status(HttpStatus.OK)`, injetando o `ListExpensesUseCase` já no construtor. Retorna
  `HttpResponse.ok(useCase(ListExpensesCommand(actor.personId)).toResponse())`. Sem ramo de erro (o use
  case não falha); o único `4xx` é o `401` que o guard emite antes do handler.
- **Reusa `ExpenseResponse`** (`id`, `amountInCents`, `date`, `description?`) — a visão pública de um item
  é idêntica à do create. Adiciona um mapper `List<ExpenseEntity>.toResponse(): List<ExpenseResponse>`
  (extension em `mappers/responses/`, sobre o `ExpenseEntity.toResponse()` já existente).
- **`ExpenseControllerDoc`**: novo método `list` com `@Operation`/`@Tag` e
  `@ApiResponse(responseCode = "200", content = @Content(array = @ArraySchema(schema = @Schema(implementation = ExpenseResponse::class))))`,
  mais `401`/`500` → `ErrorResponse`. O controller implementa; `@Status(OK)` documenta o `200`.
- **i18n**: nenhuma chave de mensagem nova (não há erro de domínio); só as descrições OpenAPI nas anotações.

### DI: um binding a mais no `ExpenseFactory`

`@Singleton listExpensesUseCase(repository: ExpenseRepository): ListExpensesUseCase =
ListExpensesUseCase(repository)`. O repositório já é ligado pelo factory; nenhum port novo do kernel.

## Risks / Trade-offs

- **Lista sem paginação cresce sem limite** → uma pessoa com milhares de gastos recebe tudo numa resposta.
  Mitigação: aceitável para a primeira fatia (mesmo espírito incremental do create); paginação é Open
  Question e entra numa fatia própria antes de o volume ser real. O recorte por intervalo que `budget`
  vai usar é uma query diferente, não esta.
- **Response como array JSON nu (`[...]`)** → se paginação vier depois, o corpo vira um envelope
  (`{ items, next }`), um breaking change sob `/v1`. Trade-off aceito conscientemente: a fatia é mínima e
  revisável antes do apply; se paginação for desejada já, a decisão muda o shape agora (por isso está como
  Open Question destacada).
- **Ordenar por `spent_on` sem `created_at`** → dois gastos no mesmo dia se ordenam por `id` (sem
  significado temporal). Mitigação: é só um desempate estável; a ordem primária (data) é a que importa ao
  usuário.
- **`toEntity` estreia agora** → primeiro uso da direção record→domínio no `expense`; risco baixo, o
  `PersonRecordMapper` já é o molde.

## Open Questions

- **Paginação**: incluir já (envelope + params de página validados no edge) ou manter a lista completa e
  paginar quando o volume exigir? Proposto: **manter simples agora**, paginar em fatia futura. Muda o
  shape da resposta — decidir antes do apply se o produto já quer.
- **Filtro por intervalo de datas** no próprio `GET /expenses` (ex.: `?from=&to=`) vs. deixar a query por
  range exclusiva do consumo interno de `budget`/`couple`. Proposto: fora desta fatia.
- **Ordem por data-que-aconteceu (`spent_on`) vs. ordem de registro**: precisaria de `created_at` +
  migração. Proposto: `spent_on` desc, fiel ao domínio; revisitar se o produto pedir ordem de digitação.
