# http-response-envelope

## Purpose

O envelope JSON:API-style compartilhado por toda borda HTTP do sistema: sucesso sempre em `data` (mais
`meta`/`links` opcionais), falha sempre em `errors`, nunca as duas juntas. Sendo cross-cutting (nenhum
contexto o conhece), reside no núcleo compartilhado (`core`), e é a casca estrutural sobre a qual
`http-error-handling` e cada `<context>-http-api` constroem suas respostas.

## Requirements

### Requirement: Toda resposta de sucesso vem envelopada em `data`

O sistema SHALL envelopar toda resposta HTTP de sucesso (qualquer status `2xx` com corpo) em um objeto de
topo com a propriedade `data`. Quando o sucesso representa um único recurso, `data` SHALL ser um objeto;
quando representa uma coleção, `data` SHALL ser um array. Nenhum endpoint SHALL devolver o objeto ou array
de domínio diretamente como corpo de topo — o corpo de topo SHALL ser sempre um objeto contendo `data`.

#### Scenario: Sucesso de item único é envelopado

- **WHEN** um endpoint responde com sucesso um único recurso (ex.: a pessoa criada, o gasto registrado)
- **THEN** o corpo de topo é um objeto com a propriedade `data`
- **AND** `data` contém o recurso, no mesmo shape que a resposta pública já usava antes do envelope

#### Scenario: Sucesso de coleção é envelopado como array em `data`

- **WHEN** um endpoint responde com sucesso uma coleção de recursos (ex.: a página de gastos)
- **THEN** o corpo de topo é um objeto com a propriedade `data`
- **AND** `data` é um array com os itens da coleção, na mesma ordem que a resposta pública já usava

#### Scenario: Nenhum endpoint devolve corpo cru

- **WHEN** qualquer endpoint HTTP do sistema responde com sucesso e corpo
- **THEN** o corpo nunca é um objeto ou array solto no nível de topo — é sempre `{ "data": ... }`

### Requirement: `meta` e `links` são opcionais e só aparecem quando há conteúdo

O sistema SHALL prover, no mesmo envelope de sucesso, duas propriedades de topo opcionais: `meta` (metadado
adicional — hoje, paginação por cursor) e `links` (navegação relacionada ao recurso). Nenhuma das duas SHALL
ser incluída no corpo quando não houver conteúdo real para carregar — o sistema SHALL NOT serializar `meta`
ou `links` como objeto vazio, `null`, ou com todas as sub-propriedades ausentes.

#### Scenario: Endpoint sem paginação nem navegação omite meta e links

- **WHEN** um endpoint de sucesso não tem metadado nem link de navegação a expor (ex.: `POST /sign-up`)
- **THEN** o corpo de sucesso contém apenas `data`, sem as propriedades `meta` ou `links`

#### Scenario: Coleção paginada expõe meta e links de navegação

- **WHEN** um endpoint responde uma coleção paginada por cursor com uma próxima página disponível
- **THEN** o corpo contém `meta.pagination.next_cursor` com o cursor opaco da próxima página
- **AND** o corpo contém `links.self` (a página atual) e `links.next` (a URL da próxima página)

#### Scenario: Última página da coleção paginada omite o próximo link

- **WHEN** um endpoint responde a última página de uma coleção paginada por cursor (sem próxima página)
- **THEN** `meta.pagination.next_cursor` está ausente
- **AND** `links.next` é `null`
- **AND** `links.self` continua presente

### Requirement: Toda resposta de falha vem envelopada em `errors`, nunca em `data`

O sistema SHALL envelopar toda resposta HTTP de falha em um objeto de topo com a propriedade `errors`, um
array com um ou mais itens de erro. Uma resposta de falha SHALL NOT conter a propriedade `data`, e uma
resposta de sucesso SHALL NOT conter a propriedade `errors` — as duas propriedades são mutuamente
exclusivas em qualquer resposta.

#### Scenario: Falha nunca carrega data

- **WHEN** qualquer endpoint HTTP do sistema recusa uma requisição (borda, autenticação, domínio, ou falha
  inesperada)
- **THEN** o corpo de topo contém `errors`, um array
- **AND** o corpo de topo não contém a propriedade `data`

#### Scenario: Sucesso nunca carrega errors

- **WHEN** qualquer endpoint HTTP do sistema responde com sucesso
- **THEN** o corpo de topo não contém a propriedade `errors`

### Requirement: Cada item de `errors` carrega status, code, message e, quando aplicável, source

O sistema SHALL representar cada item do array `errors` com `status` (o código de status HTTP como string,
redundante com o header por convenção), `code` (o token estável legível por máquina), `message` (o texto
curado e legível). Quando o erro é atribuível a um campo específico do request, o item SHALL incluir
`source.field` com o nome final do campo; quando o erro é escalar (não atribuível a um campo), o item SHALL
NOT incluir `source`.

#### Scenario: Item de erro escalar não tem source

- **WHEN** o sistema serializa um item de erro escalar (recusa de domínio, autenticação, corpo malformado,
  falha inesperada)
- **THEN** o item contém `status`, `code` e `message`
- **AND** o item não contém a propriedade `source`

#### Scenario: Item de erro de campo carrega source.field

- **WHEN** o sistema serializa um item de erro de violação de campo na borda
- **THEN** o item contém `status`, `code`, `message` e `source.field` com o nome do campo violado
