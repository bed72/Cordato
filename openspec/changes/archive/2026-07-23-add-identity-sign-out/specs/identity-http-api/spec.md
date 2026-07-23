## ADDED Requirements

### Requirement: Rota protegida encerra a sessão atual (logout)

O sistema SHALL expor o encerramento da própria sessão por um endpoint HTTP **`POST
/authentication/sign-out`**, declarado **protegido** (`@Authenticated`), que SHALL exigir uma sessão viva
antes de executar o handler. O endpoint SHALL delegar ao `SignOutUseCase`, construindo o comando a partir
do `sessionId` já resolvido pelo guard (o mesmo `AuthenticatedActor` que as demais rotas protegidas
consomem) — SHALL NOT aceitar ou exigir qualquer identificador de sessão vindo do corpo da requisição ou de
parâmetros. O endpoint SHALL NOT ler nem exigir corpo de requisição.

#### Scenario: Logout autenticado responde 204

- **WHEN** o endpoint recebe uma requisição autenticada por uma sessão viva
- **THEN** o `SignOutUseCase` é invocado com o `sessionId` daquela sessão
- **AND** o sistema responde `204 No Content`
- **AND** a sessão deixa de ser resolvível por `findActiveByToken`

#### Scenario: Requisição sem sessão viva é recusada pelo guard

- **WHEN** a requisição não traz um token válido de sessão viva
- **THEN** o guard recusa antes do handler, com o mesmo `401` neutro (code `UNAUTHENTICATED`) que as
  demais rotas protegidas usam
- **AND** o `SignOutUseCase` não é invocado

### Requirement: Logout é idempotente e não vaza estado da sessão

O sistema SHALL tratar o encerramento de uma sessão como uma operação sem casos de erro de domínio: a
sessão que autenticou a requisição já foi validada como viva pelo guard antes do handler ser alcançado, e
uma corrida (a mesma sessão sendo encerrada por duas chamadas concorrentes) SHALL resultar no mesmo `204`
para ambas as chamadas, sem expor qual delas "de fato" revogou a sessão.

#### Scenario: Chamada repetida de logout com o mesmo token expirado responde 401, não 204

- **WHEN** o token de uma sessão já encerrada é usado em uma nova requisição a `POST
  /authentication/sign-out`
- **THEN** o guard recusa essa segunda chamada com o `401` neutro, pois a sessão não está mais viva para
  autenticá-la — não chega a existir uma segunda invocação do `SignOutUseCase`
