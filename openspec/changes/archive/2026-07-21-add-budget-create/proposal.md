## Why

O contexto `budget` — o teto planejado por intervalo de datas, e a peça que faltava para as visões
derivadas (orçamento ativo, "sem orçamento", panorama do casal) — ainda não existe em código, só o
`README.md` do domínio. `expense` (o fato atômico) e a autenticação já existem prontos para serem
consultados; a próxima fatia possível é registrar o próprio orçamento. Sem ele, nenhuma das visões
derivadas descritas no README tem o que derivar.

## What Changes

- Introduz o bounded context `features/budget/` com as três camadas (`domain`/`application`/
  `infrastructure`) e o wiring próprio em `budget/main/BudgetFactory.kt`, seguindo a arquitetura hexagonal
  e os sufixos de categoria do projeto — espelhando a fatia `expense/CreateExpense`.
- Adiciona **`POST /budgets`** (rota protegida, exige sessão viva): cria um orçamento do ator autenticado
  a partir de um valor (centavos), uma data de início, uma data de fim e uma anotação opcional.
- Regras de domínio da criação:
  - o orçamento pertence a **exatamente uma pessoa** — o ator autenticado; nunca se cria orçamento para
    outra pessoa;
  - o **valor** é exato, em centavos (reusa `MoneyValueObject` do `core`), e sempre **maior que zero**;
  - o **intervalo de datas** tem início e fim, ambos incluídos, sem hora envolvida; o fim SHALL NOT ser
    anterior ao início;
  - a **anotação** é opcional, aparada (trim); em branco após o trim vira ausente; limitada a um
    comprimento máximo;
  - **invariante de não-sobreposição**: a mesma pessoa nunca pode ter dois orçamentos **vivos** que
    compartilhem sequer um dia, nem mesmo um dia de fronteira (terminar dia 15 e outro começar dia 15 é
    sobreposição; terminar dia 15 e outro começar dia 16 coexiste); apenas orçamentos vivos (não
    removidos) disputam essa checagem; uma tentativa de criação que sobreponha é recusada como erro de
    domínio;
  - o orçamento **nunca referencia gastos** — não guarda lista de gastos nem valores derivados
    (spent/remaining ficam para uma fatia futura de leitura).
- Adiciona a slice HTTP do `budget`: `BudgetController` + `BudgetControllerDoc`, request/response
  `@Serdeable`, o error mapper próprio do contexto (mapeando `CreateBudgetError` → `422` via o builder
  `unprocessable` do `core`), mensagens por chave i18n e documentação OpenAPI em compile-time.
- Adiciona a persistência jOOQ do orçamento: migração Flyway `V4__budget.sql` (incluindo a coluna de
  status vivo/removido necessária para a checagem de não-sobreposição), `BudgetRepository` (port driven)
  + `PersistenceBudgetRepository` (adapter) + record mapper.

Escopo desta mudança é **apenas o create/POST** e a invariante de não-sobreposição que o acompanha.
Listar, editar, apagar orçamento e as visões derivadas (ativo, "sem orçamento", casal) ficam de fora.

## Capabilities

### New Capabilities
- `budget-create`: criação de um novo orçamento para o ator autenticado — validação de valor (> 0),
  intervalo de datas (fim ≥ início) e anotação (opcional, limitada); enforcement da invariante de
  não-sobreposição contra os demais orçamentos vivos da mesma pessoa; criação e persistência do
  orçamento sem qualquer referência a gastos.
- `budget-http-api`: a slice HTTP do contexto `budget` — `POST /budgets`, rota protegida, request/
  response DTOs, mapeamento de `CreateBudgetError` para o contrato de erro do `core` (`400`/`422`/`500`),
  i18n por chave e OpenAPI.
- `budget-persistence`: o esquema (`budget`) e o repositório jOOQ do orçamento — migração Flyway,
  `BudgetRepository` e seu adapter de persistência, incluindo a consulta de sobreposição por pessoa.

### Modified Capabilities
<!-- Nenhuma capability existente muda de requisito: budget é um contexto novo; expense/identity não mudam. -->

## Impact

- **Novo pacote**: `src/main/kotlin/com/bed/cordato/features/budget/**` (todas as camadas + `main/`).
- **`core` (shared kernel)**: nenhuma mudança — `MoneyValueObject`, `ClockPort` e `IdGeneratorPort` já
  existem e são reutilizados como estão.
- **Migração de banco**: nova `src/main/resources/db/migration/V4__budget.sql`; o jOOQ regenera os
  models (tabela `BUDGET`) a partir do DDL Flyway no build.
- **i18n**: novas chaves em `src/main/resources/i18n/messages.properties` para as mensagens do `budget`
  (edge Bean Validation + erros de domínio, incluindo a sobreposição).
- **DI**: novo `BudgetFactory` descoberto pelo `ApplicationContext` junto às demais factories; herda o
  `DSLContext`, `ClockPort` e `IdGeneratorPort` do `CoreFactory`.
- **API pública**: nova rota `POST /v1/budgets` (o prefixo `/v1` vem da config global).
- **Sem breaking changes**: nada de identity/expense/core existente muda de contrato.
