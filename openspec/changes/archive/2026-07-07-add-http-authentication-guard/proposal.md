## Why

O sign-in já é o lado **produtor** da sessão: autentica, abre uma `SessionEntity` e devolve o token opaco.
A infraestrutura de consumo já está meio pronta em `core`: `SessionRepository.findActiveByToken(token, now)`
resolve a sessão viva e **colapsa** ausente/desconhecido/expirado/(depois) revogado num único `null`; o
builder de resposta `unauthorized(code, message)` e o code `UNAUTHENTICATED` já existem — hoje usados só
pelo mapper do sign-in (`SignInError.InvalidCredentials → 401 UNAUTHENTICATED`).

O que falta é o lado **consumidor na borda HTTP**: hoje **nenhuma rota consegue exigir uma sessão**. Não há
como ler o `Authorization: Bearer` de uma requisição, resolver a pessoa e barrar quem não está autenticado.
Sem esse guard, `GET /me`, os `PATCH` de perfil e o `DELETE` de conta não têm como existir — é o gargalo
que destrava a auto-gestão da pessoa.

Não existe **nada** de autenticação de borda no código hoje: sem filtro, sem binder, sem anotação, sem tipo
de ator, sem `UnauthenticatedException`. Portanto esta é uma **introdução greenfield**, não um refactor de um
mecanismo existente. (Uma versão anterior desta change foi redigida como "substituir um
`AuthenticatedPersonIdArgumentBinder` por um filtro"; esse binder nunca foi para o código, então o
enquadramento de refactor era falso e foi corrigido aqui.)

## What Changes

- Introduz a anotação marcadora **`@Authenticated`** (alvo classe ou método) — o guard **declarativo**: a
  presença dela na rota, e não a assinatura do handler, é o que exige sessão. Rotas sem a anotação
  (`POST /sign-up`, `POST /sign-in`) permanecem abertas.
- Introduz um **`@ServerFilter`** que, quando a `RouteMatch` carrega `@Authenticated`, lê o Bearer, resolve a
  sessão viva via `SessionRepository.findActiveByToken(token, clock())` e:
  - **injeta o id da pessoa como request attribute** e deixa a requisição seguir; ou
  - **devolve diretamente o `401` neutro** pelo builder compartilhado `unauthorized("UNAUTHENTICATED", …)`
    (mesmo `ErrorResponse`, sem header `WWW-Authenticate`) quando o token está ausente, malformado, expirado
    ou revogado — sem invocar a lógica da rota. **Não** há exceção nem handler novos: o filtro retorna a
    resposta, espelhando o que o mapper do sign-in já faz.
- Introduz o ator tipado **`AuthenticatedPersonId`** e um **`TypedRequestArgumentBinder` honesto** que apenas
  **lê** o attribute populado pelo filtro (sem lookup, sem barrar). Assim um handler recebe um tipo de domínio
  de borda, e "proteger a rota" fica desacoplado de "consumir o id".
- Nova chave i18n **`error.authentication.message`** (genérica, não-vazante) no bundle compartilhado; o code
  `UNAUTHENTICATED` continua inline como contrato de máquina.
- **Sem dependência nova** (nada de `micronaut-security`), zero reflection, compile-time — coerente com o
  contrato de erro HTTP neutro que já existe.
- **Nenhuma rota de produção é protegida** nesta change: o probe é um controller de teste. Proteger
  `GET /me`/`PATCH`/`DELETE` fica para a change de auto-gestão da pessoa.

## Capabilities

### New Capabilities
- `http-authentication-guard`: o mecanismo cross-cutting de `core` que protege rotas HTTP por um guard
  declarativo (`@Authenticated`) + filtro que resolve a sessão pelo Bearer, disponibiliza a pessoa
  autenticada ao handler como ator tipado, e recusa com o `401` neutro compartilhado — sem vazar a causa.

## Impact

- **Código novo (`core/infrastructure/http/authentication/`):** `Authenticated` (anotação),
  `AuthenticatedPersonId` (ator tipado), `BearerToken` (`internal fun bearerToken` + const do attribute),
  `AuthenticationServerFilter` (`@ServerFilter`), `AuthenticatedPersonIdArgumentBinder` (leitor honesto).
- **`CoreFactory`:** ganha o wiring do binder (`@Singleton TypedRequestArgumentBinder<AuthenticatedPersonId>`),
  annotation-free como os demais adapters; o filtro é discovered pela anotação (a mesma exceção
  anotada-descoberta que controllers e `ExceptionHandler`s).
- **Contrato de erro:** inalterado na forma — reusa o builder `unauthorized(...)` e o code `UNAUTHENTICATED`
  já existentes; invariante de não-vazamento preservada (mesma resposta para ausente/expirado/revogado, sem
  `WWW-Authenticate`, sem ecoar o token).
- **i18n:** uma chave nova, `error.authentication.message`.
- **Testes:** `AuthenticationServerFilterTest` com um probe controller (rota `@Authenticated` vs. aberta) sobre
  um `FakeSessionRepository` (`@Replaces`); nenhum PostgreSQL, relógio fixo.
- **Documentação:** o `CLAUDE.md` **não descreve** autenticação de borda hoje; ganha uma seção nova (guard
  declarativo + filtro como exceção anotada-descoberta, ator tipado via attribute, 401 neutro do filtro).
- **Dependências:** nenhuma adicionada ou removida.
