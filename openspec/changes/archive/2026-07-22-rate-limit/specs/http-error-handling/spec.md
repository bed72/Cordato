## ADDED Requirements

### Requirement: Recusa por limite de requisições responde 429 no envelope compartilhado

O sistema SHALL tratar uma recusa por limite de requisições excedido (rate limit) como `429 Too Many
Requests` no envelope `errors` compartilhado, seguindo o mesmo formato escalar (exatamente um item, sem
`source`) já usado para as demais falhas escalares (`400` de corpo malformado, `401`, `500`). A resposta
SHALL carregar adicionalmente um header `Retry-After`, fora do corpo — a mesma convenção de "metadado vai no
header, não no envelope" já usada pelo `Correlation-Id`.

#### Scenario: Falha por rate limit produz um único item sem source

- **WHEN** uma requisição é recusada por exceder o limite de taxa
- **THEN** o corpo de erro é `{ "errors": [...] }` com exatamente um item
- **AND** esse item carrega `status: "429"`, `code` e `message`, sem a propriedade `source`

#### Scenario: A resposta carrega Retry-After fora do envelope

- **WHEN** uma requisição é recusada por exceder o limite de taxa
- **THEN** a resposta HTTP carrega um header `Retry-After` com os segundos até a próxima janela
- **AND** esse valor não aparece em nenhum campo do corpo `errors`
