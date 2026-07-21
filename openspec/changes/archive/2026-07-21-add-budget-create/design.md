## Context

`budget` é um bounded context novo — hoje só existe o `README.md` do domínio, sem código. É o **teto
planejado** por intervalo de datas; `expense` (o fato atômico) já existe e persiste gastos sem nenhuma
referência a orçamento (derive-don't-store), então `budget` pode nascer sem tocar `expense`. Esta mudança
entrega apenas a primeira fatia: criar um orçamento (`POST /budgets`), incluindo a invariante de
não-sobreposição que o README declara.

O projeto tem duas fatias de referência maduras: `identity/SignUp` (camadas, sufixos, DI, slice HTTP) e,
mais próxima em forma, `expense/CreateExpense` (primeiro contexto novo desde o zero: value objects
`of()`-anuláveis, erro selado, use case puro, port + adapter jOOQ, migração Flyway própria). Esta mudança
segue o mesmo molde.

Restrições herdadas (não decididas aqui, apenas obedecidas): money é BRL-only em centavos inteiros
(`MoneyValueObject` do `core`, já existe); domínio/aplicação nunca importam Micronaut/jOOQ; erros de
domínio são resultados selados, não exceções; o contrato de erro HTTP (`400`/`422`/`500`) e o bundle i18n
vivem no `core`; o prefixo `/v1` vem de config; a migração Flyway roda contra Postgres em runtime **mas** o
jOOQ regenera os models simulando o DDL num H2 no build (comentário em `V3__expense.sql`) — logo o DDL
precisa continuar dialeto-portável, sem features Postgres-only (extensões, `EXCLUDE USING gist`, etc.).

## Goals / Non-Goals

**Goals:**
- Estrear o pacote `features/budget/` com as três camadas + `main/BudgetFactory.kt`.
- Criar um orçamento do ator autenticado via `POST /budgets`, com as regras: valor > 0 (centavos,
  `MoneyValueObject` reusado), intervalo de datas (fim ≥ início), anotação opcional (trim, blank→ausente,
  máx. limitado).
- Impor a invariante de não-sobreposição: recusar a criação quando a pessoa já tem outro orçamento
  **vivo** cujo intervalo compartilha qualquer dia (incluindo fronteira) com o novo.
- Persistir o orçamento em PostgreSQL via jOOQ, com migração `V4__budget.sql`, incluindo uma coluna de
  status (vivo/removido) — necessária desde já porque a invariante de não-sobreposição já fala em
  "orçamentos vivos", mesmo a operação de remover ficando fora desta fatia.
- Manter o orçamento **sem qualquer referência a gastos** (derive-don't-store, espelhando `expense`).

**Non-Goals:**
- Listar, editar ou remover orçamento (fatias futuras) — a coluna de status existe só para a invariante
  de não-sobreposição já operar corretamente desde a criação; nenhuma rota de remoção nasce aqui.
- Qualquer visão derivada (orçamento ativo, "sem orçamento", panorama do casal, spent/remaining) —
  pertence a uma fatia de leitura futura de `budget`/`couple`.
- Qualquer consulta a `expense` — `budget` não sabe quanto foi gasto nesta fatia.
- Fechar a corrida (TOCTOU) entre checar a sobreposição e inserir (ver Risks) — mitigar isso é fora do
  escopo desta fatia.

## Decisions

### Intervalo de datas como um único `BudgetPeriodValueObject`, não dois campos soltos

O intervalo (início/fim) carrega uma invariante própria (fim ≥ início) que é intrínseca ao próprio valor,
não dependente de nada externo (ao contrário da checagem "não-futura" do `expense`, que depende do
`ClockPort`) — então cabe inteira num value object puro, sem tocar o use case.
- **Forma**: `data class BudgetPeriodValueObject private constructor(val startDate: LocalDate, val
  endDate: LocalDate)` com `of(startDate: LocalDate, endDate: LocalDate): BudgetPeriodValueObject?`
  retornando `null` quando `endDate < startDate`.
- **Alternativa considerada**: dois value objects independentes (`StartDateValueObject`/
  `EndDateValueObject`) e a checagem `fim >= início` no use case. Rejeitada — espalharia uma invariante
  intrínseca do intervalo para fora do tipo que a representa, e um `BudgetEntity` com dois `LocalDate`
  soltos permitiria construir um intervalo inválido em qualquer outro lugar do código.
- **Alternativa considerada**: `virtual_objects/`. Rejeitada — ADR 0001 reserva Virtual Object para
  projeções computadas a partir de entidades (orçamento ativo, panorama do casal); o período é um campo
  intrínseco de uma única entidade nova, não uma projeção sobre entidades existentes.

### `NoteValueObject`, mesma forma de `DescriptionValueObject`

- `NoteValueObject` (`domain/value_objects/`): `of(raw): NoteValueObject?` faz trim e valida `length <=
  MAX_LENGTH` (**255**, `const` exportado, mesmo valor de `DescriptionValueObject` do `expense` por
  consistência). Blank→ausente é decisão do use case (raw nulo/blank vira ausente antes de chamar `of`),
  não do value object — mesmo racional do `expense`.
- **Alternativa considerada**: reusar `DescriptionValueObject` do `expense` diretamente. Rejeitada —
  cruzaria `budget → expense` só por um tipo, e CLAUDE.md não permite dependência entre esses dois
  contextos nessa direção (nem em nenhuma, hoje); tipos com o mesmo formato em contextos diferentes
  duplicam de propósito, não compartilham.

### `BudgetStatusEnum` (LIVE/DELETED), espelhando `PersonStatusEnum`

A invariante de não-sobreposição do README já fala em "orçamentos vivos" disputando espaço, então o
schema e a entidade precisam expressar esse estado desde a criação, mesmo sem uma rota de remoção ainda.
- `enum class BudgetStatusEnum { LIVE, DELETED }` em `domain/enums/`. Todo orçamento nasce `LIVE`; não há
  caminho para `DELETED` nesta fatia (fica pronto para a fatia futura de remoção).
- **Alternativa considerada**: omitir o status agora e adicionar numa migração futura junto com a fatia
  de remoção. Rejeitada — a invariante de não-sobreposição *desta* fatia já precisa filtrar por "vivo"
  (mesmo que hoje `DELETED` seja inatingível); adicionar a coluna depois exigiria uma segunda migração e,
  pior, uma janela em que a checagem de sobreposição estaria incompleta.

### `CreateBudgetError` selado + `CreateBudgetResult`

Seguindo `CreateExpenseError`/`CreateExpenseResult`:
- `sealed interface CreateBudgetError { data object InvalidAmount; data object InvalidPeriod; data
  object InvalidNote; data object OverlappingBudget }` — todos mapeiam para `422`.
- `sealed interface CreateBudgetResult { data class Failure(error); data class Success(budget) }`.
- Sem `Outcome` de port (ADR 0003): a checagem de sobreposição é uma **consulta** separada da escrita
  (`hasOverlappingLiveBudget`, um `Boolean`), e a criação em si tem só dois estados (inseriu ou não) — não
  há 3+ resultados divergentes que justifiquem um `Outcome`.

### Fluxo do use case (ordem deliberada)

`CreateBudgetUseCase(generator, repository).invoke(command)`:
1. `MoneyValueObject.of(command.amountInCents)` → `null` ⇒ `InvalidAmount`.
2. `BudgetPeriodValueObject.of(command.startDate, command.endDate)` → `null` ⇒ `InvalidPeriod`.
3. Resolver anotação: raw nulo/blank ⇒ ausente; senão `NoteValueObject.of(raw)` → `null` ⇒ `InvalidNote`.
4. `repository.hasOverlappingLiveBudget(command.personId, period.startDate, period.endDate)` → `true` ⇒
   `OverlappingBudget`.
5. Construir `BudgetEntity(id = generator(), personId = command.personId, amount, period, note?, status =
   BudgetStatusEnum.LIVE)`.
6. `repository.create(budget)`; retornar `Success(budget)`.
O `command.personId` vem do `AuthenticatedActor.personId` no controller — nunca do corpo, mesmo padrão do
`expense`. Sem `ClockPort`: início e fim são sempre informados, não há default "hoje" nesta fatia.

### Consulta de sobreposição: comparação inclusiva de fronteira

A invariante do README é explícita: "terminar dia 15 e outro começar dia 15" é sobreposição; "terminar dia
15 e outro começar dia 16" não é. Isso é exatamente a condição clássica de intersecção de intervalos
fechados: existe sobreposição contra um orçamento vivo existente quando `novo.startDate <=
existente.endDate AND existente.startDate <= novo.endDate` (ambos os lados com `<=`, nunca `<`).
`BudgetRepository.hasOverlappingLiveBudget(personId, startDate, endDate): Boolean` traduz essa condição
para uma única query (`EXISTS`), filtrando por `person_id` e `status = LIVE`.

### Slice HTTP: novo `BudgetController`, não estender expense

- `BudgetController(@Controller("/budgets"))` com um único `@Post` `@Authenticated`
  `@Status(HttpStatus.CREATED)`, injetando `MessagePort` + `CreateBudgetUseCase`, lendo
  `AuthenticatedActor`, ramificando o resultado selado: `Success` → `201` com `BudgetResponse`; `Failure`
  → `error.toResponse(messages)` (o error mapper do `budget`, `422` via `unprocessable`).
- `CreateBudgetRequest` (`@Serdeable`): `amountInCents: Long` (edge `@Positive`), `startDate: LocalDate`,
  `endDate: LocalDate` (ambos obrigatórios; `fim >= início` é regra de domínio, fica no `422`, não no
  edge), `note: String?` (`@Size(max = NoteValueObject.MAX_LENGTH)`).
- `BudgetResponse` (`@Serdeable`): `id`, `amountInCents`, `startDate`, `endDate`, `note?`.
- `BudgetControllerDoc` com `@Operation`/`@ApiResponse`(`201` → `BudgetResponse`;
  `400`/`401`/`422`/`500` → `ErrorResponse`)/`@Tag`; o controller implementa.
- Mappers HTTP: `requests/` (`toCommand(personId)`), `responses/` (`toResponse()`), `errors/`
  (`CreateBudgetError.toResponse(messages)`), como no `expense`.

### Persistência: `V4__budget.sql` + adapter jOOQ

- Migração cria `budget(id varchar not null, person_id varchar not null, amount_cents bigint not null,
  start_date date not null, end_date date not null, note varchar, status varchar not null)`, mesmo estilo
  dialeto-portável de V1/V2/V3 (sem FK cruzada, `varchar` em vez de `text`). Índice por `(person_id,
  status)` para servir a consulta de sobreposição.
- A checagem de sobreposição roda como `SELECT EXISTS(...)` sobre esse índice — nenhuma constraint de
  banco garante a invariante (ver Risks); a garantia vive inteiramente na `application`.
- jOOQ regenera `Tables.BUDGET` a partir do DDL Flyway (mesmo `packageName` compartilhado dos demais
  contextos).
- `BudgetRepository` (port) + `PersistenceBudgetRepository` (adapter) + `BudgetRecordMapper`
  (`toRecord`/`toEntity`, `internal`), espelhando `PersistenceExpenseRepository`.

### DI: `BudgetFactory` herda o kernel

`features/budget/main/BudgetFactory.kt` (`@Factory`): `@Singleton` para `budgetRepository(dslContext)` e
`createBudgetUseCase(generator, repository)`. `DSLContext` e `IdGeneratorPort` vêm do `CoreFactory` como
parâmetros — nunca redeclarados. Descoberto pelo `ApplicationContext` sem tocar `Main`.

## Risks / Trade-offs

- **Corrida (TOCTOU) entre checar sobreposição e inserir** → duas criações concorrentes da mesma pessoa,
  com intervalos que se sobrepõem entre si, podem ambas passar pela checagem antes de qualquer uma
  inserir, resultando em dois orçamentos vivos sobrepostos. Diferente do e-mail (que fecha a corrida com
  `UNIQUE` no banco), uma exclusão por intervalo (`EXCLUDE USING gist`) é Postgres-only e não sobrevive à
  simulação H2 do jOOQ (ver Context) — não dá para fechar a invariante no schema sem quebrar o codegen.
  Mitigação aceita por ora: baixa probabilidade (mesma pessoa criando dois orçamentos sobrepostos ao mesmo
  tempo), sem dado financeiro sensível em jogo (é só um teto, não uma transação); registrado como Open
  Question para endurecer depois (lock consultivo por `person_id`, ou isolamento serializable na
  transação de criação).
- **Sem FK `budget.person_id → person`** → mesmo risco/mitigação já aceitos em `expense`: o `personId`
  vem sempre de um ator autenticado (sessão viva ⇒ pessoa existente); consistente com o estilo atual de
  migrações.
- **Coluna `status` sem consumidor de escrita nesta fatia** (nenhuma rota leva a `DELETED` ainda) → custo
  de schema mínimo; antecipa a fatia futura de remoção e evita uma segunda migração. Trade-off aceito.
- **Índice em `(person_id, status)` sem medição de custo real** → custo de escrita mínimo; acelera tanto a
  consulta de sobreposição quanto listagens futuras por pessoa. Trade-off aceito.

## Open Questions

- **Fechar a corrida de sobreposição**: aceitar o risco por ora (ver Risks) ou já introduzir um lock
  consultivo (`pg_advisory_xact_lock` por hash do `personId`) na criação? Proposto aceitar por ora; a
  fatia de remoção é o próximo ponto natural para revisitar, já que ela mexe no mesmo espaço de invariante.
- **Nome da coluna/enum de status**: `LIVE`/`DELETED` (espelhando `PersonStatusEnum` que usa
  `ACTIVE`/`DELETED`) vs. um nome mais específico do domínio de orçamento. Proposto `LIVE`/`DELETED` por
  ser o termo que o próprio README do domínio já usa ("orçamento vivo").
