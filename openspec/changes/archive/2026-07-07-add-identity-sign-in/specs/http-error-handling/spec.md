## ADDED Requirements

### Requirement: Rejeição de autenticação responde 401 neutro compartilhado

O sistema SHALL prover, no contrato de erro compartilhado do `core`, uma forma de rejeição de autenticação
`401` no mesmo `ErrorResponse` compartilhado, via um builder `unauthorized(code, message)` (irmão de
`unprocessable`/`badRequest`). Essa resposta SHALL ser **escalar** (um `code` estável `UNAUTHENTICATED` e
uma `message` genérica, sem lista de erros por campo) e SHALL NOT incluir o header `WWW-Authenticate`. Toda
falha de autenticação — credenciais de login inválidas ou rota protegida acessada sem sessão viva — SHALL
resolver nessa **mesma** resposta, de modo que nem o corpo, nem o code, nem o status distingam a causa.

#### Scenario: Falha de autenticação usa o 401 neutro

- **WHEN** uma borda precisa recusar por autenticação (login inválido ou rota protegida sem sessão)
- **THEN** o sistema responde `401` no corpo compartilhado com code `UNAUTHENTICATED` e mensagem genérica
- **AND** a resposta é escalar (sem lista de erros por campo)

#### Scenario: O 401 não carrega WWW-Authenticate nem detalhe da causa

- **WHEN** o sistema serializa uma rejeição de autenticação
- **THEN** a resposta não inclui o header `WWW-Authenticate`
- **AND** a mensagem não revela se o e-mail existe, se a senha falhou, ou se a sessão expirou/foi revogada

#### Scenario: Login inválido e rota protegida sem sessão são indistinguíveis

- **WHEN** o login recusa por `InvalidCredentials` e, separadamente, uma rota protegida é acessada sem sessão viva
- **THEN** ambas respondem `401` com o mesmo code `UNAUTHENTICATED` e o mesmo shape neutro
