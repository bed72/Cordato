## Why

O contexto `expense` — o **fato atômico** do domínio (quem gastou, quanto, quando) e a verdade-base de
onde todo número derivado de orçamento e de casal nasce — ainda não existe em código. Nada pode ser
derivado antes que o fato bruto possa ser registrado, então a primeira fatia a construir é o **registro
de um gasto**. Ela também estreia o `MoneyValueObject` (valor exato em centavos) no `core`, peça que
`budget` vai reutilizar depois.

## What Changes

- Introduz o bounded context `features/expense/` com as três camadas (`domain`/`application`/
  `infrastructure`) e o wiring próprio em `expense/main/ExpenseFactory.kt`, seguindo a arquitetura
  hexagonal e os sufixos de categoria do projeto — espelhando a fatia `identity/SignUp`.
- Adiciona **`POST /expenses`** (rota protegida, exige sessão viva): registra um gasto do ator
  autenticado a partir de um valor (centavos), uma data opcional e uma descrição opcional.
- Introduz o `MoneyValueObject` no `core` (shared kernel — "exact money arithmetic"): valor em centavos,
  inteiro, sempre **maior que zero**; sem `Double`, BRL-only.
- Introduz, no `domain` do `expense`: `ExpenseEntity`, os value objects próprios (data do gasto,
  descrição), o `CreateExpenseError` (hierarquia selada) e o caso de uso `CreateExpenseUseCase` com seu
  `CreateExpenseCommand`/`CreateExpenseResult`.
- Regras de domínio do registro:
  - o gasto pertence a **exatamente uma pessoa** — o ator autenticado; nunca se registra gasto para
    outra pessoa;
  - o **valor** é exato, em centavos, e **sempre > 0** (zero ou negativo é recusado);
  - a **data** é opcional: omitida, assume a data de criação (**hoje**, via `ClockPort`); informada, pode
    ser hoje ou no passado, mas **nunca no futuro** (data futura é recusada);
  - a **descrição** é opcional, aparada (trim); em branco após o trim vira ausente; limitada a um
    comprimento máximo;
  - o gasto **nunca referencia orçamento** — registra só o fato bruto (quem, quanto, quando, descrição).
- Adiciona a slice HTTP do `expense`: `ExpenseController` + `ExpenseControllerDoc`, request/response
  `@Serdeable`, o error mapper próprio do contexto (mapeando `CreateExpenseError` → `422` via o builder
  `unprocessable` do `core`), mensagens por chave i18n e documentação OpenAPI em compile-time.
- Adiciona a persistência jOOQ do gasto: migração Flyway `V3__expense.sql`, `ExpenseRepository` (port
  driven) + `PersistenceExpenseRepository` (adapter) + record mapper.

Escopo desta mudança é **apenas o create/POST**. Listar, editar e apagar gasto ficam de fora.

## Capabilities

### New Capabilities
- `expense-create`: registro de um novo gasto (o fato atômico) para o ator autenticado — validação de
  valor (> 0), data (opcional, default hoje, futuro recusado) e descrição (opcional, limitada); criação
  e persistência do gasto sem qualquer referência a orçamento.
- `expense-http-api`: a slice HTTP do contexto `expense` — `POST /expenses`, rota protegida, request/
  response DTOs, mapeamento de `CreateExpenseError` para o contrato de erro do `core` (`400`/`422`/`500`),
  i18n por chave e OpenAPI.
- `expense-persistence`: o esquema (`expense`) e o repositório jOOQ do gasto — migração Flyway,
  `ExpenseRepository` e seu adapter de persistência.

### Modified Capabilities
<!-- Nenhuma capability existente muda de requisito: expense é um contexto novo. -->

## Impact

- **Novo pacote**: `src/main/kotlin/com/bed/cordato/features/expense/**` (todas as camadas + `main/`).
- **`core` (shared kernel)**: novo `core/domain/value_objects/MoneyValueObject.kt` (primeiro uso de
  dinheiro; `budget` reutiliza depois). Nenhuma mudança de comportamento em código existente do `core`.
- **Migração de banco**: nova `src/main/resources/db/migration/V3__expense.sql`; o jOOQ regenera os
  models (tabela `EXPENSE`) a partir do DDL Flyway no build.
- **i18n**: novas chaves em `src/main/resources/i18n/messages.properties` para as mensagens do `expense`
  (edge Bean Validation + erros de domínio).
- **DI**: novo `ExpenseFactory` descoberto pelo `ApplicationContext` junto às demais factories; herda o
  `DSLContext`, `ClockPort` e `IdGeneratorPort` do `CoreFactory`.
- **API pública**: nova rota `POST /v1/expenses` (o prefixo `/v1` vem da config global).
- **Sem breaking changes**: nada de identity/core/existente muda de contrato.
