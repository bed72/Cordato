## Why

O contexto `expense` já registra o fato bruto (`POST /expenses`), mas hoje um gasto registrado
**desaparece**: não há como o dono voltar e ver seus próprios gastos. Um `create` sem `read` é um beco
sem saída para o usuário. Esta fatia entrega a leitura mínima — **listar os próprios gastos** — fechando
o loop de expense e pavimentando o lado de consulta que `budget`/`couple` vão derivar depois.

## What Changes

- Adiciona **`GET /expenses`** (rota protegida, exige sessão viva): retorna **todos os gastos do ator
  autenticado**, e somente dele, como uma lista.
- Regras de leitura:
  - a lista contém **apenas** os gastos cujo dono é o ator autenticado — nunca os de outra pessoa; o dono
    consultado vem sempre do `AuthenticatedActor`, nunca de parâmetro/corpo;
  - a lista é **ordenada de forma determinística**: por data do gasto (`spent_on`) decrescente — o gasto
    mais recente primeiro — com desempate estável por `id`;
  - uma pessoa **sem nenhum gasto** recebe `200` com uma **lista vazia**, nunca `404`;
  - cada item expõe a mesma visão pública já usada no create (`id`, valor em centavos, data, descrição
    opcional) — sem qualquer referência a orçamento.
- Introduz, no `application` do `expense`: o `ListExpensesCommand` (só o `personId`) e o
  `ListExpensesUseCase`, que retorna **diretamente** `List<ExpenseEntity>` (possivelmente vazia). Não há
  ramo de falha honesto aqui — listar os próprios gastos sempre sucede —, então **não** se cria um
  `ListExpensesResult` selado nem um `ListExpensesError` (não inventar distinção que não existe, mesmo
  princípio do `ExpenseRepository.create` que devolve `Unit`).
- Estende a persistência: novo `ExpenseRepository.findByPerson(personId): List<ExpenseEntity>` (port) e
  sua implementação jOOQ no `PersistenceExpenseRepository` (`select … where person_id = ? order by
  spent_on desc, id desc`). Sem migração nova — reusa a tabela `expense` da V3.
- Estende a slice HTTP: novo `@Get` `@Authenticated` `@Status(OK)` no `ExpenseController` retornando
  `200` com `List<ExpenseResponse>`; a interface `ExpenseControllerDoc` ganha o `@Operation`/`@ApiResponse`
  correspondente (`200` → array de `ExpenseResponse`; `401` → `ErrorResponse`). Reusa o `ExpenseResponse`
  existente e o mapper de resposta.

Escopo desta mudança é **apenas listar os próprios gastos**. Paginação, filtro por intervalo de datas,
editar e apagar gasto, e qualquer visão derivada (orçamento ativo, "sem orçamento", casal) ficam de fora.

## Capabilities

### New Capabilities
- `expense-list`: a leitura da lista dos próprios gastos do ator autenticado — só os do dono, ordenados
  por data decrescente com desempate estável, lista vazia quando não há gastos, cada item com a visão
  pública do gasto sem vínculo a orçamento.

### Modified Capabilities
- `expense-http-api`: adiciona a rota `GET /expenses` (protegida) ao contrato HTTP do contexto — `200`
  com a lista, `401` neutro sem sessão viva — e sua documentação OpenAPI. Nenhum requisito existente do
  `POST /expenses` muda.
- `expense-persistence`: adiciona a consulta `findByPerson` ao port e ao adapter jOOQ do gasto (query por
  `person_id`, ordenada). Nenhum requisito existente muda; sem nova migração.

## Impact

- **Pacote `features/expense/`**: novos `application/driving/commands/ListExpensesCommand.kt` e
  `application/driving/use_cases/ListExpensesUseCase.kt`; método novo no port
  `application/driven/repositories/ExpenseRepository.kt` e no adapter
  `infrastructure/repositories/PersistenceExpenseRepository.kt`; método `list` novo no
  `ExpenseController` e no `ExpenseControllerDoc`; mapper de resposta para `List<ExpenseEntity>`.
- **DI**: novo `@Singleton listExpensesUseCase(repository)` no `ExpenseFactory` (herda o repositório já
  ligado; nenhum port novo do kernel).
- **Banco**: **sem** migração nova — reusa a tabela `expense` da `V3`. A query se beneficia do índice por
  `person_id` já criado na V3.
- **i18n**: nenhuma chave de erro nova (não há erro de domínio no listar); só descrições OpenAPI.
- **API pública**: nova rota `GET /v1/expenses`.
- **Sem breaking changes**: `POST /expenses`, identity e core mantêm seus contratos.
