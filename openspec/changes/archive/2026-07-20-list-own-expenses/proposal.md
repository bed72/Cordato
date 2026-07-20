## Why

O contexto `expense` já registra o fato bruto (`POST /expenses`), mas hoje um gasto registrado
**desaparece**: não há como o dono voltar e ver seus próprios gastos. Um `create` sem `read` é um beco
sem saída para o usuário. Esta fatia entrega a leitura mínima — **listar os próprios gastos** — fechando
o loop de expense e pavimentando o lado de consulta que `budget`/`couple` vão derivar depois.

## What Changes

- Adiciona **`GET /expenses`** (rota protegida, exige sessão viva): retorna os gastos do ator autenticado,
  e somente dele, **paginados por cursor (keyset)** e servidos **através de um cache distribuído (Valkey)**.
- Regras de leitura:
  - a página contém **apenas** os gastos cujo dono é o ator autenticado — nunca os de outra pessoa; o dono
    consultado vem sempre do `AuthenticatedActor`, nunca de parâmetro/corpo;
  - a ordem é **determinística**: por data do gasto (`spent_on`) decrescente — o gasto mais recente
    primeiro — com desempate estável por `id`; essa dupla `(spent_on, id)` **é** a base do cursor;
  - uma pessoa **sem nenhum gasto** recebe `200` com uma **página vazia** (`items: []`, sem próximo
    cursor), nunca `404`;
  - cada item expõe a mesma visão pública já usada no create (`id`, valor em centavos, data, descrição
    opcional) — sem qualquer referência a orçamento.
- **Paginação cursor-based (keyset), obrigatória:**
  - a rota aceita `limit` (opcional, **default 20**, **máx 100**) e `cursor` (opcional, string opaca) como
    query params — campos de **puro transporte**, validados **só no edge**;
  - o `cursor` codifica de forma opaca a posição de keyset `(spent_on, id)` do último item da página
    anterior; um `cursor` malformado responde `400 MALFORMED_REQUEST` (escalar, contrato de erro do core);
  - a resposta é um **envelope** `{ items: [...], next_cursor: "<opaco>"|null }` — `next_cursor` é `null`
    na última página. Isto **substitui** o array nu que a versão anterior desta mudança devolvia (decisão
    revista antes do release — ver design; a paginação era Open Question desta própria mudança).
- **Cache distribuído (Valkey), obrigatório:**
  - a listagem é servida **read-through** por um cache Valkey (Redis-compatível), compartilhado entre
    instâncias; a chave é escopada por pessoa + posição de página (`cursor`) + `limit`;
  - a invalidação é por **geração por pessoa**: registrar um gasto (`POST /expenses`) incrementa o contador
    de geração daquela pessoa, aposentando de uma vez todas as suas páginas em cache (as chaves antigas
    expiram por TTL) — sem varredura de chaves;
  - o cache é uma preocupação de **infraestrutura**: o `application`/`domain` do expense permanecem
    inconscientes dele (ver design — decorator de repositório, não cache-aside no use case).
- Introduz, no `application` do `expense`: `ListExpensesCommand(personId, limit, after: cursor?)` e o
  `ListExpensesUseCase`, que retorna um **`ExpensePageVirtualObject`** (itens + próximo cursor) — uma
  projeção de leitura (virtual object), não um `Result`/`Error` selado (listar sempre sucede).
- Estende a persistência: `ExpenseRepository.findByPerson(personId, after, limit)` (keyset) e sua
  implementação jOOQ (`where person_id = ? and (spent_on, id) < (?, ?) order by spent_on desc, id desc
  limit ?`). Sem migração nova — reusa a tabela `expense` e o índice por `person_id` da V3.
- Estende a slice HTTP: `@Get` `@Authenticated` `@Status(OK)` no `ExpenseController` retornando `200` com
  o envelope; `ExpenseControllerDoc` documenta os params `limit`/`cursor` e o corpo `ExpensePageResponse`.

Escopo desta mudança é **listar os próprios gastos, paginado por cursor e cacheado**. Filtro por intervalo
de datas, editar e apagar gasto, e qualquer visão derivada (orçamento ativo, "sem orçamento", casal) ficam
de fora.

## Capabilities

### New Capabilities
- `expense-list`: a leitura **paginada por cursor** da lista dos próprios gastos do ator autenticado — só
  os do dono, ordenados por data decrescente com desempate estável (base do cursor), página vazia quando
  não há gastos, cada item com a visão pública do gasto sem vínculo a orçamento; o resultado é um
  `ExpensePageVirtualObject` (itens + próximo cursor).
- `cache-valkey`: um cache distribuído transversal no `core` — um `CachePort` (application/driven) e um
  adapter Valkey (infrastructure) com TTL e invalidação por geração de chave, mais a config e o serviço
  Valkey local (`compose.yml`). É o kernel de cache que features consomem; nasce servindo a `expense-list`.

### Modified Capabilities
- `expense-http-api`: adiciona a rota `GET /expenses` (protegida, **cursor-paginada**) ao contrato HTTP —
  `200` com o envelope `{ items, next_cursor }`, `limit`/`cursor` como query params validados no edge,
  `cursor` malformado → `400 MALFORMED_REQUEST`, `401` neutro sem sessão viva — e sua documentação OpenAPI.
  Nenhum requisito existente do `POST /expenses` muda.
- `expense-persistence`: adiciona a consulta `findByPerson` **keyset** (por `person_id`, após um cursor,
  com `limit`) ao port e ao adapter jOOQ, e um **decorator de cache** do repositório que serve a leitura
  pelo Valkey e invalida (por geração) no `create`. Sem nova migração.

## Impact

- **Pacote `features/expense/`**: `application/driving/commands/ListExpensesCommand.kt` (com `limit` +
  `after`), `application/driving/use_cases/ListExpensesUseCase.kt` (retorna `ExpensePageVirtualObject`),
  `domain/virtual_objects/ExpensePageVirtualObject.kt`, `domain/value_objects/ExpenseCursorValueObject.kt`;
  `findByPerson(personId, after, limit)` no port e no adapter jOOQ; `CachingExpenseRepository` (decorator,
  infrastructure); `list` no `ExpenseController`/`ExpenseControllerDoc` com params + envelope
  `ExpensePageResponse`; mappers de cursor (encode/decode, HTTP) e de página (`toResponse`).
- **Pacote `core/`**: `application/driven/ports/CachePort.kt` + `infrastructure/.../ValkeyCacheAdapter.kt`
  (cliente Lettuce), wiring no `CoreFactory`; config Valkey em `application.properties`.
- **DI**: `listExpensesUseCase` no `ExpenseFactory` passa a receber o repositório **decorado por cache**;
  o `CachePort` vem do `CoreFactory` (kernel).
- **Build/infra**: nova dependência do cliente Valkey/Redis (Lettuce, via BOM Micronaut); serviço `valkey`
  no `compose.yml` + alvos no `Makefile`/`.env.example`; imagem Valkey no Testcontainers para o teste de
  integração do adapter.
- **Banco**: **sem** migração nova — reusa a tabela `expense` e o índice por `person_id` da `V3`.
- **i18n**: nenhuma chave de erro de domínio nova (listar não falha por domínio); `cursor` malformado
  reusa o `MALFORMED_REQUEST` já existente do core; só descrições OpenAPI novas.
- **API pública**: nova rota `GET /v1/expenses` (envelope cursor-paginado).
- **Sem breaking changes** para o já liberado: `POST /expenses`, identity e core mantêm seus contratos (o
  envelope vs. array é uma revisão **interna** desta mudança ainda não liberada, não um breaking de release).
