## Context

`budget` hoje só tem `POST /budgets` (criação) e as duas leituras derivadas (`GET /budgets/active`,
`GET /budgets/default`) — ver `add-budget-create`, `add-budget-active-view`, `add-default-budget-view`.
`BudgetStatusEnum` já modela `LIVE`/`DELETED` desde a criação (a invariante de não-sobreposição já filtra
por `LIVE`), mas nenhuma rota escreve `DELETED` ainda — a coluna existe só para a checagem funcionar desde
o primeiro dia. Esta mudança entrega as duas operações que faltam para o CRUD do orçamento: editar
(`PATCH /budgets/{id}`) e remover de forma recuperável (`DELETE /budgets/{id}`).

É também a primeira vez que uma rota do `budget` (e da API como um todo) precisa resolver um recurso por
`id` vindo da URL e checar se ele pertence ao ator autenticado — as rotas existentes ou criam (dono vem do
ator) ou leem por `personId` (sem `id` de recurso). Isso introduz duas decisões novas: o que fazer quando o
`id` não é do ator, e que status HTTP usar quando o recurso simplesmente não existe.

Restrições herdadas (não decididas aqui, apenas obedecidas): erros de domínio são resultados selados, não
exceções; o contrato de erro HTTP compartilhado vive no `core`; um novo status "slota" no builder
compartilhado quando um caller real precisa dele (comentário em `ErrorResponse.kt`); a checagem de
sobreposição já aceita uma corrida (TOCTOU) como trade-off (`add-budget-create`), não fechada por uma
constraint de banco (DDL precisa continuar dialeto-portável para o codegen jOOQ/H2).

## Goals / Non-Goals

**Goals:**
- `PATCH /budgets/{id}`: editar valor, intervalo de datas e anotação de um orçamento **vivo** do ator
  autenticado, revalidando as mesmas regras da criação e a invariante de não-sobreposição contra os
  **demais** orçamentos vivos da pessoa (excluindo o próprio orçamento editado).
- `DELETE /budgets/{id}`: soft-delete de um orçamento vivo do ator autenticado — `status` vira `DELETED`;
  o orçamento some da checagem de não-sobreposição e das visões ativa/`default` a partir daí.
- Unificar em um único `404` os três casos "não posso editar/remover isso": `id` nunca existiu, já está
  `DELETED`, ou pertence a outra pessoa — nenhum dos três é distinguível de fora.
- Estender `BudgetRepository` com o mínimo necessário (`findById`, `update`, `delete`, `excludeId` na
  consulta de sobreposição) sem tocar as operações existentes (`create`, `findLiveBudgetCovering`,
  `findAllLiveBudgets`).

**Non-Goals:**
- Edição parcial campo-a-campo (ex.: só o valor, só a anotação) — fica para uma fatia futura, se um caso
  de uso real pedir; esta fatia reedita os três campos mutáveis juntos, mesmo formato do `POST`.
- Fechar a corrida (TOCTOU) da checagem de sobreposição — já aceita como trade-off em
  `add-budget-create`; esta mudança só estende a mesma consulta com `excludeId`, sem alterar sua garantia.
- Hard-delete, undelete/restauração, ou qualquer histórico de auditoria da edição/remoção.
- Qualquer visão derivada nova ou mudança em `expense`/`identity`/`couple`.

## Decisions

### Uma única rota de edição full-fields, não PATCH parcial por campo

`identity` tem uma rota por campo (`PATCH /me/name`, `/me/email`, `/me/password`) porque cada campo tem
uma política de sensibilidade própria (nome é trivial, e-mail/senha exigem step-up). Em `budget`, os três
campos mutáveis (`amount`, `period`, `note`) não têm essa diferença de sensibilidade entre si, e `period`
carrega uma invariante (fim ≥ início) que depende dos **dois** lados — uma edição parcial de só
`startDate` obrigaria ler o `endDate` atual do banco para revalidar o intervalo, ou aceitar um estado
intermediário inválido. Uma única rota que sempre recebe os três campos (mesmo formato do
`CreateBudgetRequest`, mais o `id` na URL) revalida com o mesmo código do `CreateBudgetUseCase`, sem
ambiguidade sobre "o que não foi enviado".
- **Alternativa considerada**: `PATCH` com todos os campos opcionais, mesclando com o estado atual antes
  de validar. Rejeitada — introduziria uma segunda leitura implícita e uma lógica de merge que nenhuma
  outra rota do projeto tem; o ganho (evitar reenviar campos inalterados) não paga o custo de ambiguidade
  numa fatia que ainda não tem um consumidor real pedindo edição parcial.

### `id` inexistente, removido, ou de outra pessoa: sempre o mesmo 404

Um `id` de orçamento que não existe, que já foi removido, ou que pertence a outra pessoa são,
propositalmente, a **mesma** resposta: `404` com um código neutro (`BUDGET_NOT_FOUND`). Isso estende ao
`budget` o mesmo princípio de não-vazamento que `identity` já aplica a conta/e-mail (ADR 0008): distinguir
os três casos (por um `403` na hipótese "existe mas não é seu", por exemplo) revelaria a quem não é dono
se um `id` específico existe e pertence a alguém — o mesmo tipo de oráculo, só que por recurso em vez de
por conta. Não há nenhum caso de uso legítimo em que o ator autenticado precise distinguir "esse orçamento
não existe" de "esse orçamento não é seu".
- **Alternativa considerada**: `403 Forbidden` quando o `id` existe mas pertence a outra pessoa, `404`
  apenas quando realmente não existe. Rejeitada — o `403` por si só já vaza a existência do recurso (o
  status muda dependendo de quem é o dono), o oráculo exato que se quer evitar.

### Primeiro `404` do contrato de erro compartilhado

`core/infrastructure/http/responses/ErrorResponse.kt` já comenta que "novos status (404/409…) slotam do
mesmo jeito quando um caller real precisar" — este é esse caller. Adiciona
`notFound(code, message): HttpResponse<ErrorsResponse>`, irmã de `unauthorized`/`unprocessable`/
`internalError`: mesmo formato escalar (um único `ErrorItemResponse`, sem `source`), só que com
`status/HttpStatus.NOT_FOUND`. Não é uma mudança na *forma* do envelope (`ErrorsResponse` já é genérico o
bastante), só mais um builder de conveniência — não modifica `http-error-handling` como capability
(mesmo precedente do `422`, que também nunca entrou nessa spec compartilhada; `422`/`404` são política por
contexto, documentados na spec HTTP de cada contexto, não na spec cross-cutting).

### `UpdateBudgetError`/`DeleteBudgetError`: erro de domínio dedicado por operação, não reaproveitar `CreateBudgetError`

```kotlin
sealed interface UpdateBudgetError {
    data object InvalidAmount : UpdateBudgetError
    data object InvalidPeriod : UpdateBudgetError
    data object InvalidNote : UpdateBudgetError
    data object OverlappingBudget : UpdateBudgetError
    data object BudgetNotFound : UpdateBudgetError
}

sealed interface DeleteBudgetError {
    data object BudgetNotFound : DeleteBudgetError
}
```
`UpdateBudgetError` repete as quatro variantes de `CreateBudgetError` porque a *mensagem* i18n de cada uma
é idêntica em espírito, mas o tipo é novo (não um alias) para que o mapper HTTP de update possa também
tratar `BudgetNotFound` sem um `when` não-exaustivo forçar um `else` "pra sempre" em `CreateBudgetError`
(que nunca terá esse caso). `DeleteBudgetError` tem uma única variante — mesmo padrão de `MeError` em
`identity` (`sealed interface` com um caso solitário, não um `object` solto, para que o resultado
continue ramificando de forma exaustiva e um segundo motivo só possa ser adicionado deliberadamente).
Os quatro primeiros de `UpdateBudgetError` mapeiam para `422`; `BudgetNotFound` (em ambos os erros) mapeia
para `404`.
- **Alternativa considerada**: um `BudgetError` único compartilhado entre create/update/delete.
  Rejeitada — `CreateBudgetError` nunca terá `BudgetNotFound` (criação não busca por `id`), e um tipo
  guarda-chuva obrigaria todo mapper a tratar casos que sua própria operação nunca produz.

### `BudgetRepository`: três métodos novos, um parâmetro novo — nenhum dos existentes muda de assinatura

```kotlin
interface BudgetRepository {
    fun create(budget: BudgetEntity)
    fun update(budget: BudgetEntity)
    fun delete(id: String, personId: String): Boolean

    fun findById(id: String): BudgetEntity?
    fun findAllLiveBudgets(personId: String): List<BudgetEntity>
    fun findLiveBudgetCovering(personId: String, date: LocalDate): BudgetEntity?

    fun hasOverlappingLiveBudget(
        personId: String,
        startDate: LocalDate,
        endDate: LocalDate,
        excludeId: String? = null,
    ): Boolean
}
```
- `findById(id)` **não** filtra por `personId` nem por `status` — devolve o que existir, dono de
  quem for, vivo ou removido. A checagem de dono/vivacidade é do use case (mesmo padrão de
  `PersonRepository.findById` em `identity`, que também devolve sem filtrar por "quem está perguntando");
  isso mantém o port simples (uma consulta, um significado) e a política de "quem pode ver o quê" inteira
  na `application`.
- `update(budget)` recebe a entidade já validada e persiste por `id` — `Unit`, mesmo racional de `create`
  (ADR: não há outcome divergente caller-relevante aqui; o use case já garantiu vivacidade/dono antes de
  chamar). Uma corrida em que o orçamento foi removido entre o `findById` e o `update` é aceita como o
  mesmo tipo de trade-off já registrado para a sobreposição em `add-budget-create` — não fechada nesta
  fatia.
- `delete(id, personId): Boolean` **filtra por `personId` e por `status = LIVE`** na própria query
  (`UPDATE budget SET status = 'DELETED' WHERE id = ? AND person_id = ? AND status = 'LIVE'`), e devolve
  se alguma linha foi afetada. Duas saídas caller-relevantes (removeu / não removeu) — um `Boolean` basta
  (ADR 0003: não manufaturar `Outcome` para um resultado de dois estados). Filtrar por dono e vivacidade
  na própria instrução (não em duas etapas) fecha, para o delete especificamente, a mesma janela de corrida
  que o update aceita — não há necessidade de um `findById` prévio para o delete.
- `hasOverlappingLiveBudget` ganha `excludeId: String? = null` (default preserva a chamada existente do
  `CreateBudgetUseCase`, que nunca precisa excluir nada): a consulta SQL adiciona `AND id <> :excludeId`
  quando presente, para a edição não colidir com o próprio orçamento sendo editado.

### Fluxo do `UpdateBudgetUseCase` (mesma ordem fail-fast da criação, mais duas etapas)

`UpdateBudgetUseCase(repository).invoke(command)`:
1. `MoneyValueObject.of(command.amountInCents)` → `null` ⇒ `InvalidAmount`.
2. `BudgetPeriodValueObject.of(command.startDate, command.endDate)` → `null` ⇒ `InvalidPeriod`.
3. Resolver anotação (raw nulo/blank ⇒ ausente; senão `NoteValueObject.of(raw)` → `null` ⇒ `InvalidNote`).
4. `repository.findById(command.budgetId)` → `null`, ou `.personId != command.personId`, ou
   `.status != LIVE` ⇒ `BudgetNotFound` (as três condições colapsam na mesma variante).
5. `repository.hasOverlappingLiveBudget(command.personId, period.startDate, period.endDate,
   excludeId = command.budgetId)` → `true` ⇒ `OverlappingBudget`.
6. Construir o `BudgetEntity` atualizado (mesmo `id`/`personId`/`status = LIVE`, novo `amount`/`period`/
   `note`); `repository.update(budget)`; retornar `Success(budget)`.

A ordem do passo 4 (buscar o orçamento) *depois* de validar os campos do corpo, mas *antes* da checagem de
sobreposição, espelha `UpdateEmailUseCase`: validar o formato da entrada primeiro (barato, não toca
banco), só then resolver o recurso (uma consulta), só then a checagem que também toca banco
(sobreposição). `command.personId` vem do `AuthenticatedActor`, nunca do corpo — mesmo padrão de todas as
rotas autenticadas do projeto.

### Fluxo do `DeleteBudgetUseCase`

`DeleteBudgetUseCase(repository).invoke(command)`: `repository.delete(command.budgetId,
command.personId)` → `false` ⇒ `Failure(BudgetNotFound)`; `true` ⇒ `Success(Unit)`. Sem passo de
`findById` prévio — o próprio `delete` já resolve dono+vivacidade na query (ver decisão acima), então o
use case não precisa de uma segunda leitura só para checar o que a escrita já vai checar.

### Resposta HTTP: `200 OK` em ambas, nunca `204 No Content`

Toda rota de sucesso do projeto hoje responde `200`/`201` com corpo (nenhuma usa `204`). `PATCH
/budgets/{id}` responde `200` com a visão pública do orçamento editado (mesmo `BudgetResponse` do
`POST`). `DELETE /budgets/{id}` também responde `200`, com a visão pública do orçamento já no estado
removido — dá ao chamador a confirmação do estado final sem precisar de uma segunda chamada, e mantém o
único formato de sucesso (`DataResponse` com `data` sempre presente) em vez de introduzir a primeira
resposta vazia da API.
- **Alternativa considerada**: `204 No Content` no delete (convenção REST comum). Rejeitada — quebraria o
  invariante "toda resposta de sucesso carrega `DataResponse.data`" que todo outro endpoint (e o teste de
  arquitetura/HTTP, se existir) já assume; o ganho semântico do `204` não paga essa inconsistência isolada
  para uma única rota.

## Risks / Trade-offs

- **Corrida entre `findById` e `update` no `UpdateBudgetUseCase`** → um delete concorrente entre a leitura
  e a escrita deixaria o `update` reviver um orçamento removido (a query de `update` não tem o mesmo `AND
  status = 'LIVE'` que o `delete` tem). Mitigação: aplicar a mesma cláusula defensiva no `update`
  (`WHERE id = ? AND person_id = ? AND status = 'LIVE'`) mesmo sem checar o número de linhas afetadas no
  use case — o pior caso vira um no-op silencioso (a edição não pega), não uma reversão de estado
  inconsistente. Registrado como acréscimo ao mesmo trade-off já aceito para a sobreposição em
  `add-budget-create`.
- **`findById` sem filtro de dono** → qualquer chamador interno de `BudgetRepository.findById` que
  esqueça de checar `personId` vazaria dados de outra pessoa. Mitigação: é um port `internal`-ao-módulo
  (só `use_cases/` do próprio `budget` o chamam), e o único consumidor desta fatia (`UpdateBudgetUseCase`)
  já checa o dono explicitamente antes de qualquer outro uso do resultado.
- **`excludeId` opcional com default `null`** → uma futura chamada que esqueça de passar `excludeId` numa
  nova operação de edição gastaria a mesma sobreposição contra si mesma indevidamente. Custo aceito: hoje
  só `create` (sempre `null`, correto) e `update` (sempre o próprio `id`) chamam este método.

## Open Questions

- Nenhuma pendente para esta fatia — as decisões acima cobrem o mínimo necessário para editar e remover;
  fechar a corrida de sobreposição/edição-concorrente com um lock consultivo continua registrado como
  Open Question de `add-budget-create`, não duplicado aqui.
