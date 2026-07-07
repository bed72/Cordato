## Why

A autenticação de borda hoje é feita por um `AuthenticatedPersonIdArgumentBinder` — um `ArgumentBinder` do
Micronaut que faz as vezes de guard. Isso é torto: um binder existe para *converter um parâmetro*, não para
*barrar uma requisição*. A "proteção" vira efeito colateral de o handler pedir `actor: AuthenticatedPersonId`
(não é declarativo, não protege uma rota que não precise do id, e ainda espalha três arquivos soltos na raiz
de `core/infrastructure/http/`). O jeito idiomático do Micronaut para isso é um **guard declarativo + um
filtro (middleware)**. Como **nenhuma rota de produção está protegida ainda** (o binder só é exercitado por
teste), é o momento certo para trocar o mecanismo sem custo de migração.

## What Changes

- **BREAKING (mecanismo interno):** o `AuthenticatedPersonIdArgumentBinder` deixa de resolver a sessão e de
  barrar a requisição. A resolução/rejeição migra para um `@ServerFilter`.
- Introduz uma anotação marcadora **`@Authenticated`** aplicada à rota (controller ou método): é o guard
  declarativo, lido na assinatura como um `@Secured` seria.
- Introduz um **`@ServerFilter`** que, quando a `RouteMatch` carrega `@Authenticated`, lê o Bearer
  (`bearerToken`), resolve a sessão viva via `SessionRepository.findActiveByToken(token, clock.now())` e:
  - **curto-circuita com o `401` neutro compartilhado** (code `UNAUTHENTICATED`, mesmo `ErrorResponse`, sem
    header `WWW-Authenticate`) quando o token está ausente, malformado, expirado ou revogado — sem invocar
    a lógica da rota; ou
  - **injeta o id da pessoa como request attribute** e deixa a requisição seguir.
- **Mantém o ator tipado `AuthenticatedPersonId`:** o binder passa a ser honesto — apenas LÊ o request
  attribute que o filtro populou (sem lookup, sem lançar exceção). Um handler continua recebendo um tipo de
  domínio de borda, não um `Authentication` cru.
- **Remove** a `UnauthenticatedException` lançada pelo binder; o filtro passa a ser a única origem do `401`
  de rota protegida. (O `UnauthenticatedExceptionHandler`/`UNAUTHENTICATED` do contrato de erro
  compartilhado permanece a forma da resposta.)
- **Sem dependência nova** (nada de `micronaut-security`), zero reflection, compile-time — coerente com a
  postura do projeto e com o contrato de erro HTTP neutro que já existe.
- **Arruma o espalhamento:** agrupa as peças de autenticação de borda numa subpasta coesa
  (`core/infrastructure/http/authentication/`) em vez de arquivos soltos na raiz de `http/`.
- **NÃO muda** o modelo de token opaco, a revogação imediata server-side, nem o `hashToken` — só muda o
  mecanismo de guarda.

## Capabilities

### New Capabilities
- `http-authentication-guard`: o mecanismo cross-cutting de `core` que protege rotas HTTP por um guard
  declarativo (`@Authenticated`) + filtro que resolve a sessão pelo Bearer, disponibiliza a pessoa
  autenticada ao handler como ator tipado, e recusa com o `401` neutro compartilhado — sem vazar a causa.

### Modified Capabilities
<!-- Nenhuma capability nos specs principais (openspec/specs/) muda: a requirement equivalente ("Resolução
     do ator autenticado na borda") ainda vive na change em voo add-identity-authentication e é realocada
     por esta change (ver Impact). -->

## Impact

- **Código (`core/infrastructure/http/`):** novo `@ServerFilter` de autenticação e a anotação
  `@Authenticated`; `AuthenticatedPersonIdArgumentBinder` reduzido a leitor de request attribute;
  `UnauthenticatedException` (lançada pelo binder) removida. Arquivos de auth reagrupados sob
  `http/authentication/` (`AuthenticatedPersonId`, `BearerToken`, o filtro, a anotação, o binder).
- **Contrato de erro:** inalterado na forma — `401` com code `UNAUTHENTICATED` no `ErrorResponse`
  compartilhado; invariante de não-vazamento (mesma resposta para ausente/expirado/revogado, sem
  `WWW-Authenticate`) preservada.
- **Testes:** `AuthenticatedPersonIdBinderTest` reescrito para exercitar o filtro (rota `@Authenticated`
  protegida vs. rota aberta), mantendo os quatro casos (token válido → id; sem token → `401`; token
  irresolvível → `401`; rota aberta → passa).
- **Coordenação com `add-identity-authentication` (change em voo, não arquivada):** a requirement
  "Resolução do ator autenticado na borda" hoje empacotada em `identity-http-authentication` é
  **realocada** para a nova capability `http-authentication-guard` (é um concern de `core`, não de
  identity). Ao integrar/sincronizar, aquela requirement deve sair de `identity-http-authentication`.
- **Documentação:** o `CLAUDE.md` descreve hoje o binder opt-in como decisão de design; esta change o
  **contradiz deliberadamente** e o `CLAUDE.md` é atualizado para o guard declarativo como parte da change.
- **Dependências:** nenhuma adicionada ou removida.
