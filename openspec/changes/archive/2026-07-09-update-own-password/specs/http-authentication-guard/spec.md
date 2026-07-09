## MODIFIED Requirements

### Requirement: Ator autenticado tipado disponível ao handler

O sistema SHALL disponibilizar a pessoa autenticada ao handler como um tipo de borda dedicado
(`AuthenticatedActor`), e não como uma estrutura genérica de framework. O mecanismo que popula esse tipo
SHALL apenas ler os valores já resolvidos pelo filtro (sem consultar a sessão novamente e sem barrar a
requisição). O tipo SHALL carregar o identificador da pessoa **e o identificador da sessão viva atual** — o
`sessionId`, necessário para operações de escopo de sessão (por exemplo, revogar as demais sessões da pessoa
mantendo a atual) —, mas **nunca** o token nem outros dados da pessoa. O filtro, que já resolve a sessão
viva, SHALL guardar tanto o identificador da pessoa quanto o da sessão para o mecanismo ler de volta.

#### Scenario: Handler recebe o ator tipado com pessoa e sessão

- **WHEN** uma rota `@Authenticated` declara um parâmetro do tipo `AuthenticatedActor` e a requisição passou pelo filtro com sessão viva
- **THEN** o parâmetro é preenchido com o identificador da pessoa **e** o identificador da sessão viva resolvidos pelo filtro
- **AND** nenhuma nova consulta de sessão é feita para preencher o parâmetro

#### Scenario: O ator não carrega o token nem outros dados da pessoa

- **WHEN** o ator tipado é preenchido
- **THEN** ele carrega apenas o identificador da pessoa e o identificador da sessão
- **AND** não carrega o token nem qualquer outro dado da pessoa
