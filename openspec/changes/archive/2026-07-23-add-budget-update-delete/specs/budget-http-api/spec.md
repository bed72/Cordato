## ADDED Requirements

### Requirement: PATCH /budgets/{id} edita um orçamento vivo do ator autenticado

O sistema SHALL expor `PATCH /budgets/{id}` como rota **protegida** (anotada com `@Authenticated`), de
modo que uma requisição sem sessão viva SHALL ser recusada pelo guard de autenticação do `core` com o
`401` neutro, antes de o handler rodar. Em uma requisição autenticada e válida, o controller SHALL
delegar ao `UpdateBudgetUseCase`, derivando o `id` do orçamento do caminho da URL e o dono da checagem do
`AuthenticatedActor` (nunca do corpo), e em caso de sucesso SHALL responder `200 OK` com a visão pública
do orçamento atualizado.

#### Scenario: Edição autenticada bem-sucedida retorna 200

- **WHEN** uma requisição autenticada válida chega a `PATCH /budgets/{id}` para um orçamento vivo do ator
- **THEN** o sistema atualiza o orçamento
- **AND** responde `200 OK` com a visão pública do orçamento (id, valor em centavos, data de início, data
  de fim, anotação opcional)

#### Scenario: Requisição sem sessão viva é recusada com 401 neutro

- **WHEN** uma requisição sem token válido/sessão viva chega a `PATCH /budgets/{id}`
- **THEN** o guard de autenticação recusa com o `401` neutro do `core`, sem alcançar o handler
- **AND** nenhum orçamento é atualizado

### Requirement: DELETE /budgets/{id} remove (soft-delete) um orçamento vivo do ator autenticado

O sistema SHALL expor `DELETE /budgets/{id}` como rota **protegida** (anotada com `@Authenticated`), de
modo que uma requisição sem sessão viva SHALL ser recusada pelo guard de autenticação do `core` com o
`401` neutro, antes de o handler rodar. Em uma requisição autenticada e válida, o controller SHALL
delegar ao `DeleteBudgetUseCase`, derivando o `id` do orçamento do caminho da URL e o dono da checagem do
`AuthenticatedActor`, e em caso de sucesso SHALL responder `200 OK` com a visão pública do orçamento já no
estado removido.

#### Scenario: Remoção autenticada bem-sucedida retorna 200

- **WHEN** uma requisição autenticada válida chega a `DELETE /budgets/{id}` para um orçamento vivo do
  ator
- **THEN** o sistema remove (soft-delete) o orçamento
- **AND** responde `200 OK` com a visão pública do orçamento, já no estado removido

#### Scenario: Requisição sem sessão viva é recusada com 401 neutro

- **WHEN** uma requisição sem token válido/sessão viva chega a `DELETE /budgets/{id}`
- **THEN** o guard de autenticação recusa com o `401` neutro do `core`, sem alcançar o handler
- **AND** nenhum orçamento é alterado

### Requirement: Orçamento não encontrado (inexistente, removido ou de outra pessoa) retorna 404 escalar

O sistema SHALL mapear o erro de domínio "orçamento não encontrado" — comum às rotas `PATCH /budgets/{id}`
e `DELETE /budgets/{id}` — para um `404` escalar, via um builder `notFound` do `core` (irmão de
`unprocessable`/`unauthorized`), através do error mapper próprio do contexto `budget`. Um `404` SHALL NOT
ser emitido como `FieldErrorResponse` — é uma rejeição escalar, assim como o `422` de domínio.

#### Scenario: id inexistente retorna 404

- **WHEN** `PATCH /budgets/{id}` ou `DELETE /budgets/{id}` recebe um `id` que não corresponde a nenhum
  orçamento
- **THEN** o sistema responde `404` escalar com o código e a mensagem (por i18n) do erro "orçamento não
  encontrado"

#### Scenario: id de orçamento de outra pessoa retorna o mesmo 404

- **WHEN** `PATCH /budgets/{id}` ou `DELETE /budgets/{id}` recebe o `id` de um orçamento vivo pertencente
  a outra pessoa
- **THEN** o sistema responde o **mesmo** `404` escalar que um `id` inexistente produziria

### Requirement: Rejeição de domínio na edição retorna 422 escalar

O sistema SHALL mapear cada `UpdateBudgetError` de validação (valor inválido, intervalo inválido, anotação
inválida, sobreposição) para um `422` escalar, via o builder `unprocessable` do `core`, através do error
mapper próprio do contexto `budget`. O mapper SHALL resolver a mensagem por chave i18n e SHALL manter o
`code` como constante inline.

#### Scenario: Sobreposição na edição retorna 422

- **WHEN** o caso de uso de edição retorna um erro de sobreposição com outro orçamento vivo da mesma
  pessoa (excluindo o próprio orçamento editado)
- **THEN** o sistema responde `422` escalar com o código e a mensagem (por i18n) daquele erro

## MODIFIED Requirements

### Requirement: Mensagens por chave i18n e documentação OpenAPI

Todo texto de resposta legível do `budget` SHALL ser resolvido por chave do bundle de mensagens
compartilhado (pt-BR default), nunca inline; o `code` de erro SHALL permanecer constante inline. Cada rota
SHALL ser documentada em compile-time via o `BudgetControllerDoc` (interface com as anotações
`@Operation`/`@ApiResponse`/`@Tag`) que o `BudgetController` implementa, mantendo as anotações de
documentação fora do controller; o método de sucesso da criação SHALL declarar
`@Status(HttpStatus.CREATED)` para que o gerador documente `201`; os métodos de edição e remoção SHALL
documentar `200` de sucesso e `404` entre as respostas de erro possíveis, além de `400`/`401`/`422`/`500`.

#### Scenario: Toda mensagem vem do bundle

- **WHEN** qualquer resposta de erro ou sucesso do `budget` produz texto legível
- **THEN** esse texto é resolvido por chave do bundle compartilhado, com fallback para a chave

#### Scenario: OpenAPI documenta a rota via a interface Doc

- **WHEN** o documento OpenAPI é gerado no build
- **THEN** `POST /budgets` aparece documentado com `201` de sucesso e as respostas de erro
  (`ErrorResponse`) a partir das anotações do `BudgetControllerDoc`

#### Scenario: OpenAPI documenta edição e remoção com 404

- **WHEN** o documento OpenAPI é gerado no build
- **THEN** `PATCH /budgets/{id}` e `DELETE /budgets/{id}` aparecem documentados com `200` de sucesso e as
  respostas de erro (`ErrorResponse`), incluindo `404`, a partir das anotações do `BudgetControllerDoc`
