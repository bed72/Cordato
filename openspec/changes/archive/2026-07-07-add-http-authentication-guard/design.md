## Context

O sign-in já abre sessão e devolve o token opaco. Em `core` o consumo está meio pronto:
`SessionRepository.findActiveByToken(token, now)` resolve a sessão viva e colapsa ausente/desconhecido/
expirado/(depois) revogado num único `null` (o doc do método já diz "for the edge guard to consume"); o
builder `unauthorized(code, message)` e o code `UNAUTHENTICATED` já existem em
`core/infrastructure/http/responses/`, e o KDoc do builder afirma que "invalid sign-in credentials **or a
protected route reached without a live session**" resolvem para a mesma forma. Hoje só o mapper do sign-in
usa esse `401`.

**Falta a borda HTTP que consome o token.** Não há filtro, anotação, ator tipado nem binder — nenhuma rota
consegue exigir sessão. Esta change introduz esse mecanismo do zero (greenfield). Nenhuma rota de produção
está protegida ainda, então não há migração de endpoint.

Restrições que **não** mudam: token opaco resolvido server-side, revogação server-side, `hashToken`
(SHA-256), e o contrato de erro HTTP neutro/não-vazante (`ErrorResponse`, `401`/`UNAUTHENTICATED`, sem
`WWW-Authenticate`, indistinguível entre ausente/expirado/revogado). Postura do projeto: compile-time, sem
reflection, poucas dependências, "nós somos donos do nosso contrato de erro HTTP".

## Goals / Non-Goals

**Goals:**
- Guard **declarativo** na rota: `@Authenticated` diz "esta rota exige sessão", lido na assinatura como um
  `@Secured` seria.
- Um `@ServerFilter` (middleware) resolve a sessão **antes** do handler e é a única origem da recusa `401` de
  rota protegida.
- Ator **tipado** `AuthenticatedPersonId` disponível ao handler (não uma estrutura crua de framework).
- Preservar bit-a-bit o contrato de erro neutro/não-vazante e o modelo de token opaco.
- Reunir as peças de auth de borda em `core/infrastructure/http/authentication/`.

**Non-Goals:**
- **Não** adotar `micronaut-security` (nem qualquer dependência nova).
- **Não** mexer no token opaco, na revogação, no `hashToken`, nem no `SessionRepository`.
- **Não** introduzir papéis/escopos/`roles` — só "autenticado ou não".
- **Não** implementar `sign-out`/revogação de sessão — é change à parte.
- **Não** proteger nenhuma rota de produção.
- **Não** escrever os testes automatizados nesta etapa — adiados para depois (decisão do autor); ver `tasks.md` §6.

## Decisions

### 1. `@ServerFilter` + anotação `@Authenticated`, e não `micronaut-security`

O jeito idiomático do Micronaut para "guard" é `@Secured` + `SecurityFilter` do `micronaut-security`.
**Rejeitado** porque os defaults do módulo brigam com o contrato já construído: emite
`WWW-Authenticate: Bearer` (vaza o esquema), tem JSON de `401`/`403` próprio e assume fluxo login/JWT — seria
preciso *desligar* framework (`@Replaces` no handler default, suprimir header, desabilitar módulos) e ainda
perder o ator tipado (`Authentication` é stringly-typed). Um `@ServerFilter` próprio dá o mesmo guard
declarativo com controle nativo da resposta (non-leak trivial), sem dependência, mantendo o tipo de borda.
Trade-off aceito: reimplementamos o pedacinho "quais rotas são protegidas" — barato (uma anotação + uma
checagem na `RouteMatch`).

### 2. Opt-in por anotação na rota, não pela assinatura nem por path

A exigência de auth é a presença de `@Authenticated` na `RouteMatch` (controller ou método), lida pelo filtro
via `AnnotationMetadata`. **Alternativa rejeitada:** casar por padrão de path no filtro
(`@ServerFilter("/protected/**")`) — duplica conhecimento de rota e é frágil. A anotação fica co-localizada
com a rota, auto-documentável, e **desacopla "proteger" de "usar o ator"**: uma rota pode exigir sessão sem
consumir o id.

### 3. O ator tipado vive via request attribute + binder honesto

Ao resolver uma sessão viva, o filtro grava o `personId` num request attribute. O
`AuthenticatedPersonIdArgumentBinder` (`TypedRequestArgumentBinder<AuthenticatedPersonId>`) **apenas lê** esse
attribute — sem lookup, sem tocar o `SessionRepository`, sem lançar. O handler recebe `AuthenticatedPersonId`
(tipo de borda). Se um handler declarar `AuthenticatedPersonId` numa rota **sem** `@Authenticated` (erro do
dev), o attribute está ausente e o parâmetro fica não-satisfeito — falha de programação, não caminho de
request legítimo.

`AuthenticatedPersonId` é uma **`data class` de um campo, não uma value class** — o binding de argumento por
tipo tem um pitfall conhecido com value classes no projeto; uma `data class` evita isso e carrega só o id.

O binder é **annotation-free e wired no `CoreFactory`** (como os demais adapters). O `@ServerFilter`, ao
contrário, é discovered pela anotação — a mesma exceção anotada-descoberta que controllers e
`ExceptionHandler`s, pela qual não há caminho de `@Factory`.

### 4. O filtro **devolve** o `401` diretamente; sem `UnauthenticatedException` nem handler

Numa rota `@Authenticated` sem sessão viva (token ausente/malformado/expirado/revogado — indistinguíveis), o
filtro **retorna** `unauthorized("UNAUTHENTICATED", messages("error.authentication.message"))` — o builder
compartilhado que já é dono da forma. **Não** se introduz `UnauthenticatedException` nem um handler.

Justificativa:
- **É o padrão que o projeto já pratica.** O `SignInErrorResponseMapper` já **retorna**
  `unauthorized("UNAUTHENTICATED", …)` para `InvalidCredentials` — não lança. O guard produz a mesma forma
  pelo mesmo builder, então retornar não espalha conhecimento de forma nenhum.
- **Coerência "quem lança vs quem retorna".** O resto do contrato usa `throw`+`ExceptionHandler` apenas para o
  que o framework *genuinamente lança* (`ConstraintViolationException`, corpo malformado, `Throwable`
  inesperado). O `401` do guard é política nossa, num ponto em que seguramos a request — retornar é o
  consistente.
- **Elimina um risco.** Some a incerteza de o Micronaut 4 rotear (ou não) uma exceção lançada dentro de um
  `@ServerFilter` até um `@Produces ExceptionHandler`.

A mensagem vem da chave i18n nova `error.authentication.message`, resolvida pelo `MessagePort` injetado
(request-aware por `Accept-Language`). O code `UNAUTHENTICATED` fica inline (contrato de máquina). Distinta da
mensagem do sign-in (`signin.error.invalidCredentials`) porque são situações diferentes ("não autenticado" vs
"login recusado"), mas **ambas** genéricas e no mesmo `401`/forma — não formam oráculo entre si.

### 5. Reagrupamento físico — 4 arquivos, uma responsabilidade cada

Novo pacote `core/infrastructure/http/authentication/`, espelhando como `http/` já se organiza (`responses/`,
`errors/handlers/`, `openapi/`), com **4** arquivos e nenhum helper solto:
- `Authenticated.kt` — a anotação-guard.
- `AuthenticatedPersonId.kt` — o ator tipado **+** a `internal const AUTHENTICATED_PERSON_ID_ATTRIBUTE`,
  co-localizada com o tipo que ela transporta (a chave não vira um terceiro tipo de nomenclatura).
- `AuthenticationServerFilter.kt` — o `@ServerFilter`, com `bearerToken()` como `private fun` extension **no
  próprio arquivo** (único consumidor; não vira arquivo à parte).
- `AuthenticatedPersonIdArgumentBinder.kt` — o binder honesto.

## Risks / Trade-offs

- **Disponibilidade da `RouteMatch` no filtro de request** (timing de roteamento vs. filtro no Micronaut 4). →
  *Mitigação:* ler `HttpAttributes.ROUTE_MATCH`; o router resolve a rota antes da cadeia de filtros, então a
  anotação está acessível. `RouteMatch` ausente (ex.: 404) → tratar como rota aberta e deixar seguir; o
  downstream responde. Coberto por teste de borda.
- **`micronaut-openapi` KSP roda sobre o `@Controller` de teste** (o probe `@Authenticated`), podendo emitir um
  segundo documento OpenAPI no classpath de teste. → *Mitigação:* manter a exclusão de `META-INF/swagger/**`
  em `processTestResources`.
- **Pitfall de value class no binding.** → *Mitigação:* `AuthenticatedPersonId` é `data class`, não value class.
- **Teste de arquitetura (Konsist).** O filtro/binder ficam em `infrastructure` e importam Micronaut (permitido
  lá); `@Authenticated` é anotação de infra, nunca importada por `domain`/`application`. → *Mitigação:* rodar o
  Konsist; ajustar se ele afirmar algo sobre o pacote.

## Implementation Plan

1. Criar `@Authenticated` e `AuthenticatedPersonId` (com a `const` do attribute).
2. Criar o `AuthenticationServerFilter` (com `bearerToken()` privado): ler `ROUTE_MATCH`, gate por
   `@Authenticated`, resolver sessão, gravar attribute ou retornar `401`.
3. Criar o `AuthenticatedPersonIdArgumentBinder` (só lê o attribute) e wire no `CoreFactory`.
4. Adicionar `error.authentication.message` ao `messages.properties`.
5. Documentar no `CLAUDE.md` a autenticação de borda; `./gradlew compileKotlin compileTestKotlin`. Testes
   automatizados **adiados** (ver `tasks.md` §6).
6. **Rollback:** sem endpoint de produção protegido, reverter é remover filtro/anotação/binder — sem impacto em
   contrato público.
