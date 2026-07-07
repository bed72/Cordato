# http-authentication-guard Specification

## Purpose
TBD - created by archiving change add-http-authentication-guard. Update Purpose after archive.
## Requirements
### Requirement: Rota exige autenticação por anotação declarativa

O sistema SHALL prover uma anotação marcadora (`@Authenticated`) que, aplicada a uma rota HTTP (controller
ou método handler), declara que aquela rota exige uma pessoa autenticada. A exigência SHALL ser determinada
pela presença dessa anotação na rota — não pela assinatura do handler. Rotas que não carregam a anotação
(como cadastro e login) SHALL permanecer abertas: a ausência de `Authorization` SHALL NOT impedir seu
processamento.

#### Scenario: Rota anotada é protegida

- **WHEN** uma rota carrega `@Authenticated`
- **THEN** o sistema exige um token que resolva uma sessão viva antes de invocar a lógica da rota

#### Scenario: Rota sem a anotação permanece aberta

- **WHEN** uma requisição chega a uma rota que não carrega `@Authenticated` (ex.: `POST /sign-up`, `POST /sign-in`)
- **THEN** a ausência de `Authorization` não impede o processamento
- **AND** nenhuma resolução de sessão é executada para essa rota

### Requirement: Filtro resolve a sessão e barra antes do handler

O sistema SHALL interceptar, por um filtro de servidor HTTP, toda requisição destinada a uma rota
`@Authenticated`, **antes** de a lógica da rota executar. O filtro SHALL extrair o token do cabeçalho
`Authorization` no esquema `Bearer` e resolver a sessão viva por esse token, consultando o repositório de
sessões contra o relógio injetado. Quando o token resolve uma sessão viva, o filtro SHALL disponibilizar o
identificador da pessoa autenticada ao handler e permitir que a requisição prossiga. Em rotas não anotadas,
o filtro SHALL NOT resolver sessão nem barrar a requisição.

#### Scenario: Token válido disponibiliza o ator e segue

- **WHEN** uma requisição a uma rota `@Authenticated` apresenta um `Authorization: Bearer <token>` que resolve uma sessão viva
- **THEN** o identificador da pessoa autenticada é disponibilizado ao handler da rota
- **AND** a lógica da rota é invocada

#### Scenario: Resolução ocorre antes do handler

- **WHEN** uma requisição a uma rota `@Authenticated` é recusada por falta de sessão viva
- **THEN** a lógica da rota não é invocada

### Requirement: Recusa de autenticação responde 401 neutro e não-vazante

Numa rota `@Authenticated`, um token ausente, malformado, expirado ou revogado SHALL resultar em
`401 Unauthorized` no corpo de erro compartilhado (`ErrorResponse`), com code `UNAUTHENTICATED` e mensagem
genérica resolvida por chave i18n. Essas causas SHALL ser indistinguíveis: o status e o corpo SHALL NOT
revelar qual precondição falhou. A resposta SHALL NOT incluir o cabeçalho `WWW-Authenticate` nem qualquer
outro dado que sinalize o esquema ou a causa. O corpo SHALL NOT ecoar o token apresentado.

#### Scenario: Token ausente responde 401 neutro

- **WHEN** uma requisição a uma rota `@Authenticated` chega sem `Authorization`
- **THEN** o sistema responde `401 Unauthorized` com code `UNAUTHENTICATED` no corpo de erro compartilhado
- **AND** a resposta não inclui o cabeçalho `WWW-Authenticate`

#### Scenario: Ausente, expirado e revogado compartilham a mesma resposta

- **WHEN** uma rota `@Authenticated` recebe, em requisições distintas, um token ausente, um expirado e um revogado
- **THEN** as respostas têm o mesmo status `401` e o mesmo corpo de erro
- **AND** nenhuma delas indica qual causa ocorreu

### Requirement: Ator autenticado tipado disponível ao handler

O sistema SHALL disponibilizar a pessoa autenticada ao handler como um tipo de borda dedicado
(`AuthenticatedActor`), e não como uma estrutura genérica de framework. O mecanismo que popula esse tipo
SHALL apenas ler o identificador já resolvido pelo filtro (sem consultar a sessão novamente e sem barrar a
requisição). O tipo SHALL carregar somente o identificador da pessoa — nunca o token nem outros dados da
pessoa.

#### Scenario: Handler recebe o ator tipado

- **WHEN** uma rota `@Authenticated` declara um parâmetro do tipo `AuthenticatedActor` e a requisição passou pelo filtro com sessão viva
- **THEN** o parâmetro é preenchido com o identificador da pessoa autenticada resolvido pelo filtro
- **AND** nenhuma nova consulta de sessão é feita para preencher o parâmetro
