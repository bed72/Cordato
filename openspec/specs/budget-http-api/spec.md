# budget-http-api Specification

## Purpose
TBD - created by archiving change add-budget-create. Update Purpose after archive.
## Requirements
### Requirement: POST /budgets cria um orçamento do ator autenticado

O sistema SHALL expor `POST /budgets` como rota **protegida** (anotada com `@Authenticated`), de modo que
uma requisição sem sessão viva SHALL ser recusada pelo guard de autenticação do `core` com o `401` neutro,
antes de o handler rodar. Em uma requisição autenticada e válida, o controller SHALL delegar ao
`CreateBudgetUseCase`, derivando o dono do orçamento do `AuthenticatedActor` (nunca do corpo), e em caso de
sucesso SHALL responder `201 Created` com a visão pública do orçamento criado.

#### Scenario: Criação autenticada bem-sucedida retorna 201

- **WHEN** uma requisição autenticada válida chega a `POST /budgets`
- **THEN** o sistema cria o orçamento do ator autenticado
- **AND** responde `201 Created` com a visão pública do orçamento (id, valor em centavos, data de início,
  data de fim, anotação opcional)

#### Scenario: Requisição sem sessão viva é recusada com 401 neutro

- **WHEN** uma requisição sem token válido/sessão viva chega a `POST /budgets`
- **THEN** o guard de autenticação recusa com o `401` neutro do `core`, sem alcançar o handler
- **AND** nenhum orçamento é criado

### Requirement: Corpo malformado ou inválido no edge retorna 400

O sistema SHALL validar a forma do corpo no edge com Bean Validation antes do caso de uso. Cada restrição
que espelhe uma regra de domínio SHALL referenciar a definição do value object correspondente (o `const`
de comprimento máximo da anotação, o mínimo do valor), nunca um literal copiado. Uma violação de
restrição SHALL produzir um `400` com um `FieldErrorResponse` por campo violado; um corpo ilegível (JSON
inválido, forma indeserializável, corpo ausente) SHALL produzir um `400` escalar `MALFORMED_REQUEST` —
ambos via os handlers e o contrato de erro compartilhados do `core`.

#### Scenario: Campo inválido no edge retorna 400 por campo

- **WHEN** o corpo viola uma restrição de edge (ex.: valor ausente, anotação acima do máximo, data
  ausente)
- **THEN** o sistema responde `400` com um `FieldErrorResponse` por campo violado

#### Scenario: Corpo malformado retorna 400 escalar

- **WHEN** o corpo é JSON inválido, tem forma indeserializável ou está ausente
- **THEN** o sistema responde `400` escalar com código `MALFORMED_REQUEST`

### Requirement: Rejeição de domínio retorna 422 escalar

O sistema SHALL mapear cada `CreateBudgetError` (valor inválido, intervalo inválido, anotação inválida,
sobreposição) para um `422` escalar, via o builder `unprocessable` do `core`, através do error mapper
próprio do contexto `budget`. O mapper SHALL resolver a mensagem por chave i18n e SHALL manter o `code`
como constante inline (contrato de máquina, não localizado). Um `422` SHALL NOT ser emitido como
`FieldErrorResponse` — a rejeição de domínio é fail-fast e escalar.

#### Scenario: Valor inválido rejeitado pelo domínio retorna 422

- **WHEN** o caso de uso retorna um erro de valor inválido (valor ≤ 0 que passou o edge)
- **THEN** o sistema responde `422` escalar com o código e a mensagem (por i18n) daquele erro

#### Scenario: Intervalo inválido rejeitado pelo domínio retorna 422

- **WHEN** o caso de uso retorna um erro de intervalo inválido (fim antes do início)
- **THEN** o sistema responde `422` escalar com o código e a mensagem (por i18n) daquele erro

#### Scenario: Sobreposição rejeitada pelo domínio retorna 422

- **WHEN** o caso de uso retorna um erro de sobreposição com outro orçamento vivo da mesma pessoa
- **THEN** o sistema responde `422` escalar com o código e a mensagem (por i18n) daquele erro

### Requirement: Mensagens por chave i18n e documentação OpenAPI

Todo texto de resposta legível do `budget` SHALL ser resolvido por chave do bundle de mensagens
compartilhado (pt-BR default), nunca inline; o `code` de erro SHALL permanecer constante inline. A rota
SHALL ser documentada em compile-time via um `BudgetControllerDoc` (interface com as anotações
`@Operation`/`@ApiResponse`/`@Tag`) que o `BudgetController` implementa, mantendo as anotações de
documentação fora do controller; o método de sucesso SHALL declarar `@Status(HttpStatus.CREATED)` para que
o gerador documente `201`.

#### Scenario: Toda mensagem vem do bundle

- **WHEN** qualquer resposta de erro ou sucesso do `budget` produz texto legível
- **THEN** esse texto é resolvido por chave do bundle compartilhado, com fallback para a chave

#### Scenario: OpenAPI documenta a rota via a interface Doc

- **WHEN** o documento OpenAPI é gerado no build
- **THEN** `POST /budgets` aparece documentado com `201` de sucesso e as respostas de erro
  (`ErrorResponse`) a partir das anotações do `BudgetControllerDoc`
