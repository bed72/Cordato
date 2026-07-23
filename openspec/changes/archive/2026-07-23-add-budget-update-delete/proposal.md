## Why

O contexto `budget` hoje só sabe criar (`POST /budgets`) e ler (`GET /budgets/active`, `GET /budgets/
default`) — não existe caminho nenhum para corrigir um orçamento lançado com dados errados nem para
removê-lo. Sem isso, um erro de digitação no valor ou no intervalo de datas é permanente, e um orçamento
que deixou de fazer sentido não pode sair do caminho da invariante de não-sobreposição a não ser
recriando o banco manualmente. É a peça que faltava para o CRUD do orçamento ser utilizável no dia a dia.

## What Changes

- Adiciona **`PATCH /budgets/{id}`** (rota protegida): edita o valor, o intervalo de datas e a anotação de
  um orçamento **vivo** do ator autenticado. Reaplica, nessa ordem, as mesmas validações da criação (valor
  > 0, intervalo com fim ≥ início, anotação opcional/aparada/limitada) e a invariante de não-sobreposição
  contra os **demais** orçamentos vivos da mesma pessoa (o próprio orçamento sendo editado nunca compete
  contra si mesmo). Os três campos mutáveis são sempre reenviados juntos (mesmo formato do `POST`, mais o
  `id` na URL) — não há edição parcial de um campo isolado.
- Adiciona **`DELETE /budgets/{id}`** (rota protegida): remove de forma **recuperável** (soft-delete) um
  orçamento vivo do ator autenticado — o orçamento passa para o estado `DELETED` (já modelado desde
  `add-budget-create`, sem consumidor de escrita até agora) e deixa de competir na invariante de
  não-sobreposição e de aparecer nas visões ativa/`default`. Nenhum gasto é tocado (a relação
  gasto↔orçamento continua sendo derivada em tempo de leitura).
- **Not-found unificado por dono**: em ambas as rotas, um `id` que não existe, que já está removido, ou
  que pertence a **outra** pessoa, produzem a **mesma** resposta `404` — o sistema nunca revela, a quem
  não é dono, se um determinado `id` de orçamento existe. Introduz o primeiro `404` da API (builder
  `notFound` no contrato de erro compartilhado do `core`, ao lado de `unprocessable`/`unauthorized`).
- Estende `BudgetRepository` (port): `findById(id)`, `update(budget)`, `delete(id, personId): Boolean`
  (soft-delete idempotente-seguro), e adiciona um parâmetro de exclusão (`excludeId`) a
  `hasOverlappingLiveBudget` para a checagem de sobreposição da edição ignorar o próprio orçamento.
- Adiciona a slice HTTP correspondente: requests/responses `@Serdeable`, o error mapper do contexto
  (`UpdateBudgetError`/`DeleteBudgetError` → `422`/`404`), chaves i18n e documentação OpenAPI via
  `BudgetControllerDoc`.

Fora de escopo: qualquer visão derivada nova, a corrida (TOCTOU) já aceita como trade-off em
`add-budget-create` (aqui só estendida, não fechada), e qualquer mudança em `expense`/`identity`/`couple`.

## Capabilities

### New Capabilities
- `budget-update`: edição de valor/intervalo/anotação de um orçamento vivo do ator autenticado —
  revalida as mesmas regras da criação e a invariante de não-sobreposição excluindo o próprio orçamento;
  um `id` inexistente, removido ou de outra pessoa é um `404` uniforme.
- `budget-delete`: remoção recuperável (soft-delete) de um orçamento vivo do ator autenticado — o
  orçamento passa a `DELETED`, deixa de competir na não-sobreposição e de aparecer nas visões derivadas;
  mesmo `404` uniforme para `id` inexistente, já removido ou de outra pessoa.

### Modified Capabilities
- `budget-http-api`: adiciona `PATCH /budgets/{id}` e `DELETE /budgets/{id}` à slice HTTP existente, e
  introduz o primeiro `404` escalar da API (builder `notFound` no contrato de erro do `core`).
- `budget-persistence`: `BudgetRepository` ganha `findById`, `update`, `delete`, e
  `hasOverlappingLiveBudget` ganha o parâmetro `excludeId` para a edição não colidir consigo mesma.

## Impact

- **`features/budget/**`**: novos use cases/comandos/resultados/erros de update e delete; port e adapter
  de persistência estendidos; novos requests/responses/mappers/rotas no `BudgetController`.
- **`core/infrastructure/http/responses/ErrorResponse.kt`**: novo builder `notFound(code, message)` —
  primeiro `404` do contrato de erro compartilhado.
- **i18n**: novas chaves para `updateBudget.*`/`deleteBudget.*` em
  `src/main/resources/i18n/messages.properties`.
- **Sem migração nova**: a coluna `status` (`LIVE`/`DELETED`) já existe desde `V4__budget.sql`; esta
  mudança é a primeira a de fato escrever `DELETED`.
- **Sem breaking changes**: `POST /budgets`, `GET /budgets/active`, `GET /budgets/default` e todo
  `identity`/`expense`/`core` existente permanecem inalterados.
