## Context

`expense` é um bounded context novo — hoje só existe o `README.md` do domínio, sem código. Ele é o **fato
atômico** do sistema e a verdade-base de todo número derivado (spent/remaining de orçamento, panorama do
casal), então precisa nascer antes de `budget` e `couple`. Esta mudança entrega apenas a primeira fatia:
registrar um gasto (`POST /expenses`).

O projeto já tem uma fatia de referência madura e em produção: `identity/SignUp` (+ as edições de perfil).
Ela materializa exatamente os padrões que esta mudança segue — camadas hexagonais com sufixos de
categoria, `application/` agrupada por direção (`driving/`/`driven/`), value objects `of()`-anuláveis,
erros de domínio selados, use case puro, port + adapter jOOQ, slice HTTP (controller + `<Controller>Doc`,
request/response `@Serdeable`, error mapper, i18n por chave, OpenAPI), wiring por `@Factory` no `main/` do
pacote, e o guard de autenticação de edge do `core`. O `PersonController` já expõe rotas `@Authenticated`
lendo o `AuthenticatedActor`, que é o molde direto para o `ExpenseController`.

Restrições herdadas (não decididas aqui, apenas obedecidas): money é BRL-only em centavos inteiros;
domínio/aplicação nunca importam Micronaut/jOOQ; erros de domínio são resultados selados, não exceções; o
contrato de erro HTTP (`400`/`422`/`500`) e o bundle i18n vivem no `core`; o prefixo `/v1` vem de config.

## Goals / Non-Goals

**Goals:**
- Estrear o pacote `features/expense/` com as três camadas + `main/ExpenseFactory.kt`.
- Registrar um gasto do ator autenticado via `POST /expenses`, com as regras: valor > 0 (centavos), data
  opcional (default hoje, futuro recusado), descrição opcional (trim, blank→ausente, máx. limitado).
- Introduzir `MoneyValueObject` no `core` como shared kernel reutilizável por `budget`.
- Persistir o gasto em PostgreSQL via jOOQ, com migração `V3__expense.sql`.
- Manter o gasto **sem qualquer referência a orçamento** (derive-don't-store desde a origem).

**Non-Goals:**
- Listar, editar ou apagar gasto (fatias futuras).
- Qualquer derivação (spent/remaining, "sem orçamento", visões de casal) — pertence a `budget`/`couple`.
- Multi-moeda, formatação de exibição de dinheiro (`R$ 1.234,56`) — apresentação, fora do value object.
- Checar status ativo da pessoa dentro de `expense`: a rota já é gated pela sessão viva do guard do
  `core`; a corrida com exclusão de conta é concern de `identity`, e nem `budget`/`expense`/`delete`
  existem ainda para exercê-la.

## Decisions

### `MoneyValueObject` no `core`, não no `expense`

CLAUDE.md nomeia explicitamente "exact money arithmetic" como algo do shared kernel (`core`). `budget`
também precisará de money (teto, spent, remaining). Então o value object nasce em
`core/domain/value_objects/MoneyValueObject.kt`, não no `expense`.
- **Forma**: `@JvmInline value class MoneyValueObject private constructor(val cents: Long)` com
  `of(cents: Long): MoneyValueObject?` retornando `null` quando `cents <= 0` (mesmo padrão anulável do
  `NameValueObject`). `Long` (não `Int`) para não estourar em somas de orçamento no futuro.
- **Alternativa considerada**: `BigDecimal` de escala fixa. Rejeitada por ora — centavos inteiros são mais
  simples, exatos e suficientes; a nota de CLAUDE.md permite qualquer um dos dois.
- **Alternativa considerada**: pôr no `expense`. Rejeitada: duplicaria em `budget` ou forçaria
  `budget → expense` só por um tipo compartilhado, violando o papel do `core`.

### Value objects próprios do `expense`: data e descrição

- `ExpenseDateValueObject` (`domain/value_objects/`): envolve `java.time.LocalDate`. A validação
  "não-futura" depende de **hoje**, que vem do `ClockPort` — então a checagem de futuro **não** cabe no
  `of(raw)` puro do value object (ele não conhece o relógio). Decisão: o value object valida só o que é
  intrínseco (uma data válida); a regra "não pode ser futura" é aplicada **no use case**, comparando com
  `clock()` convertido para `LocalDate`. O default "ausente → hoje" também é do use case (ele tem o clock).
- `DescriptionValueObject` (`domain/value_objects/`): `of(raw): DescriptionValueObject?` faz trim e valida
  `length <= MAX_LENGTH` (**255**, `const` exportado). Blank→ausente **não** é o value object retornando
  `null` de erro; é o use case decidindo não construir descrição quando o raw aparado é vazio. Para não
  confundir "vazio (ausente, ok)" com "muito longo (erro)", o use case trata `null`/blank como ausente
  *antes* de chamar `of`, e só um raw não-vazio que exceda o máximo vira erro.
- **Alternativa considerada**: mover a checagem de futuro para dentro do value object passando o clock.
  Rejeitada — poluiria o value object puro com uma dependência de determinismo; o use case é o lugar certo.

### Fuso da comparação "não-futura"

`clock()` devolve `Instant`; "hoje" precisa de um fuso. Decisão: usar `ZoneOffset.UTC` para derivar o
`LocalDate` de hoje no use case, mantendo determinismo e evitando um segundo port de timezone agora.
Registrado como **Open Question** para quando o produto definir o fuso do usuário — troca localizada no
use case, sem efeito no domínio nem no esquema.

### `CreateExpenseError` selado + `CreateExpenseResult`

Seguindo `SignUpError`/`SignUpResult`:
- `sealed interface CreateExpenseError { data object InvalidAmount; data object FutureDate; data object
  InvalidDescription }` — todos mapeiam para `422`.
- `sealed interface CreateExpenseResult { data class Failure(error); data class Success(expense) }`.
- Sem `Outcome` de port: a criação tem só dois estados (inseriu ou não) e não há colisão de unicidade —
  o `ExpenseRepository.create(...)` pode ser `Unit`/`Boolean`, não precisa de um tipo `Outcome` (que
  CLAUDE.md reserva para 3+ resultados divergentes).

### Fluxo do use case (ordem deliberada)

`CreateExpenseUseCase(clock, generator, repository).invoke(command)`:
1. `MoneyValueObject.of(command.amountInCents)` → `null` ⇒ `InvalidAmount`.
2. Resolver data: se `command.date == null` ⇒ hoje (via clock); senão `ExpenseDateValueObject.of` e
   rejeitar se `> hoje` ⇒ `FutureDate`.
3. Resolver descrição: raw nulo/blank ⇒ ausente; senão `DescriptionValueObject.of` → `null` ⇒
   `InvalidDescription`.
4. Construir `ExpenseEntity(id = generator(), personId = command.personId, amount, date, description?)`.
5. `repository.create(expense)`; retornar `Success(expense)`.
O `command.personId` vem do `AuthenticatedActor.personId` no controller — nunca do corpo.

### Slice HTTP: novo `ExpenseController`, não estender identity

- `ExpenseController(@Controller("/expenses"))` com um único `@Post` `@Authenticated`
  `@Status(HttpStatus.CREATED)`, injetando `MessagePort` + `CreateExpenseUseCase`, lendo
  `AuthenticatedActor`, ramificando o resultado selado: `Success` → `201` com `ExpenseResponse`;
  `Failure` → `error.toResponse(messages)` (o error mapper do `expense`, `422` via `unprocessable`).
- `CreateExpenseRequest` (`@Serdeable`): `amountInCents: Long` (edge `@Positive`/`@Min` referenciando a
  regra do money), `date: LocalDate?` (opcional; sem VO transporte-puro, então validação só do parser de
  data — futuro é regra de domínio, fica no `422`, não no edge), `description: String?`
  (`@Size(max = DescriptionValueObject.MAX_LENGTH)`).
- `ExpenseResponse` (`@Serdeable`): `id`, `amountInCents`, `date`, `description?`.
- `ExpenseControllerDoc` com `@Operation`/`@ApiResponse`(`201` → `ExpenseResponse`; `400`/`401`/`422`/`500`
  → `ErrorResponse`)/`@Tag`; o controller implementa.
- Mappers HTTP: `requests/` (`toCommand(personId)`), `responses/` (`toResponse()`), `errors/`
  (`CreateExpenseError.toResponse(messages)`), como na identity.

### Persistência: `V3__expense.sql` + adapter jOOQ

- Migração cria `expense(id text pk, person_id text not null, amount_cents bigint not null, spent_on date
  not null, description text null)`. Sem FK a orçamento (não existe) e — decisão — **sem** FK a `person`
  por ora, seguindo o estilo das migrações existentes (não vi FK cruzada; confirmar em V1/V2 na
  implementação e manter consistência). Índice por `person_id` (e talvez `spent_on`) para as queries
  futuras de `budget`; incluir já é barato e antecipa o consumo por date-range.
- jOOQ regenera `Tables.EXPENSE` a partir do DDL Flyway (packageName já é
  `core.infrastructure.persistence.models` — models de todos os contextos vivem sob `core`, ok).
- `ExpenseRepository` (port) + `PersistenceExpenseRepository` (adapter) + `ExpenseRecordMapper`
  (`toRecord`/`toEntity`, `internal`), espelhando `PersistencePersonRepository`.

### DI: `ExpenseFactory` herda o kernel

`features/expense/main/ExpenseFactory.kt` (`@Factory`): `@Singleton` para `expenseRepository(dslContext)` e
`createExpenseUseCase(clock, generator, repository)`. `DSLContext`, `ClockPort`, `IdGeneratorPort` vêm do
`CoreFactory` como parâmetros — nunca redeclarados. Descoberto pelo `ApplicationContext` sem tocar `Main`.

## Risks / Trade-offs

- **Fuso fixo em UTC para "hoje"** → gasto perto da meia-noite pode cair no dia "errado" para o usuário.
  Mitigação: localizado no use case, trocável quando houver fuso de usuário; sem impacto em domínio/schema.
  Registrado como Open Question.
- **Sem FK `expense.person_id → person`** → risco de gasto órfão por bug. Mitigação: o `personId` vem
  sempre de um ator autenticado (sessão viva ⇒ pessoa existente); manter consistente com o estilo atual de
  migrações. Revisitar quando a exclusão de conta (que apaga gastos) for implementada.
- **`MoneyValueObject` estreando no `core` sem consumidor em `budget` ainda** → risco de moldar cedo
  demais. Mitigação: superfície mínima (`of`/`cents`), sem aritmética especulativa; adiciona-se soma/subtração
  quando `budget` precisar.
- **Índice em `spent_on` especulativo** (nenhuma query o usa nesta fatia) → custo de escrita mínimo;
  antecipa o consumo por date-range de `budget`. Trade-off aceito; pode sair se preferirmos YAGNI estrito.
- **Data como `LocalDate` no request** → depende do parser de data do Micronaut/serde; uma data
  sintaticamente inválida cai no `400` `MALFORMED_REQUEST` (contrato de edge existente), não no `422`.
  Comportamento desejado.

## Open Questions

- **Fuso da regra "não-futura" / da data default**: UTC por ora. Qual fuso quando houver preferência de
  usuário? Troca localizada no use case.
- **Índice `spent_on`**: incluir já (antecipa `budget`) ou esperar (YAGNI)? Proposto incluir; barato.
- **FK `expense.person_id → person`**: adicionar agora ou manter o estilo sem-FK das migrações atuais?
  Proposto manter consistência com V1/V2 (confirmar na implementação).
