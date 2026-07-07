## Context

Hoje a autenticação de borda do `core` é um `AuthenticatedPersonIdArgumentBinder`
(`TypedRequestArgumentBinder<AuthenticatedPersonId>`): ele lê o `Authorization: Bearer`, resolve a sessão
(`SessionRepository.findActiveByToken(token, clock.now())`) e, quando falha, lança `UnauthenticatedException`
— que o `UnauthenticatedExceptionHandler` renderiza como `401` neutro (code `UNAUTHENTICATED`, sem
`WWW-Authenticate`). A rota "opta" por proteção declarando o parâmetro `AuthenticatedPersonId`.

Isso mistura papéis: um `ArgumentBinder` existe para *converter um parâmetro*, não para *barrar uma
requisição*. Efeitos: a proteção é implícita (só protege quem pede o id), não é declarativa/auto-documentável,
e as peças (`AuthenticatedPersonId`, `BearerToken`, o binder) ficam soltas na raiz de
`core/infrastructure/http/`.

Restrições que **não** mudam: token opaco resolvido server-side, revogação imediata, `hashToken` (SHA-256),
e o contrato de erro HTTP neutro/não-vazante (`ErrorResponse`, mesmo `401`/`UNAUTHENTICATED`, sem
`WWW-Authenticate`, indistinguível entre ausente/expirado/revogado). Postura do projeto: compile-time, sem
reflection, poucas dependências, e "nós somos donos do nosso contrato de erro HTTP".

Fato relevante: **nenhuma rota de produção está protegida hoje** — o binder só é exercitado por teste. A troca
é limpa, sem migração de endpoints.

## Goals / Non-Goals

**Goals:**
- Guard **declarativo** na rota: uma anotação `@Authenticated` diz "esta rota exige sessão", lida na
  assinatura como um `@Secured` seria.
- Um `@ServerFilter` (middleware) é a **única origem** da recusa `401` de rota protegida, resolvendo a sessão
  **antes** do handler.
- Manter o **ator tipado** `AuthenticatedPersonId` disponível ao handler (não `Authentication` cru).
- Preservar bit-a-bit o contrato de erro neutro/não-vazante e o modelo de token opaco/revogação.
- Reagrupar as peças de auth de borda em `core/infrastructure/http/authentication/`.

**Non-Goals:**
- **Não** adotar `micronaut-security` (nem qualquer dependência nova).
- **Não** mexer no token opaco, na revogação imediata, no `hashToken`, nem no `SessionRepository`.
- **Não** introduzir papéis/escopos/`roles` — só "autenticado ou não".
- **Não** proteger nenhuma rota de produção nesta change (continua sem endpoint protegido; a rota de teste é o
  probe).

## Decisions

### 1. `@ServerFilter` + anotação `@Authenticated`, e não `micronaut-security`

O jeito idiomático do Micronaut para "guard" é `@Secured` + `SecurityFilter` do `micronaut-security`.
**Rejeitado** aqui porque os defaults do módulo brigam com o contrato já construído: ele emite
`WWW-Authenticate: Bearer` (vaza o esquema), tem JSON de `401`/`403` próprio e assume fluxo de login/JWT —
seria preciso gastar esforço *desligando* framework (`@Replaces` no `DefaultAuthorizationExceptionHandler`,
suprimir header, desabilitar módulos) e ainda perder o ator tipado (`Authentication` é stringly-typed). Um
`@ServerFilter` próprio dá o mesmo guard declarativo com **controle nativo da resposta** (non-leak trivial),
**sem dependência** e mantendo o tipo de domínio de borda. Trade-off aceito: reimplementamos o pedacinho
"quais rotas são protegidas" — que é barato (uma anotação + uma checagem na `RouteMatch`).

### 2. Opt-in por anotação na rota, não pela assinatura do handler

A exigência de auth passa a ser a presença de `@Authenticated` na `RouteMatch` (controller ou método), lida
pelo filtro via `AnnotationMetadata`. **Alternativa rejeitada:** casar por padrão de path no próprio filtro
(`@ServerFilter("/protected/**")`) — duplica conhecimento de rota e é frágil. A anotação fica co-localizada
com a rota e é auto-documentável. Uma rota protegida **não precisa** consumir o id (pode só exigir sessão),
desacoplando "proteger" de "usar o ator" — o que o binder não permitia.

### 3. O ator tipado sobrevive como binder honesto sobre request attribute

O filtro, ao resolver uma sessão viva, grava o id num request attribute
(`AuthenticatedPersonId` ou uma chave dedicada). O `AuthenticatedPersonIdArgumentBinder` deixa de resolver
sessão e passa a **apenas ler** esse attribute — sem lookup, sem lançar exceção, sem tocar o
`SessionRepository`. Assim o handler continua recebendo `AuthenticatedPersonId` (tipo de borda), mas o binder
volta a ser só um conversor honesto. Se um handler declarar `AuthenticatedPersonId` numa rota **sem**
`@Authenticated` (erro do dev), o attribute estará ausente e o parâmetro fica não-satisfeito — falha de
programação, não caminho de request legítimo.

### 4. O filtro é a única origem do `401`; a *forma* continua no handler compartilhado

Numa rota `@Authenticated` sem sessão viva (token ausente/malformado/expirado/revogado — indistinguíveis), o
filtro lança `UnauthenticatedException`, e o `UnauthenticatedExceptionHandler` existente a renderiza como o
`401` neutro (code `UNAUTHENTICATED`, i18n por chave, sem `WWW-Authenticate`). Mantém a divisão que o projeto
já pratica — *o handler é dono da forma, o filtro é dono da política*. `UnauthenticatedException` deixa de ser
lançada pelo binder e passa a ser lançada pelo filtro (relocação, não exclusão); o handler e o code
permanecem. **Alternativa considerada:** o filtro montar a resposta direto via o builder `unauthorized(...)`.
Evita depender do roteamento de exceção-lançada-em-filtro, mas espalha o conhecimento da forma do erro para
dentro do filtro — contra o espírito "uma peça é dona da forma". Ficamos com lançar-e-renderizar; ver Riscos
para o fallback caso o Micronaut não roteie a exceção do filtro ao handler.

### 5. Reagrupamento físico

Novo pacote `core/infrastructure/http/authentication/` reúne: `Authenticated` (anotação, `@Retention(RUNTIME)`,
alvo classe+função), `AuthenticationServerFilter` (o `@ServerFilter`), `AuthenticatedPersonId` (movido),
`BearerToken` (movido), e o `AuthenticatedPersonIdArgumentBinder` honesto (movido de `binders/`).
`UnauthenticatedException` e seu handler permanecem em `errors/`/`errors/handlers/` (fazem parte do contrato
de erro compartilhado, cross-cutting além de auth). Some a pasta `binders/` e somem os arquivos soltos na raiz
de `http/`.

## Risks / Trade-offs

- **Exceção lançada de dentro de um `@ServerFilter` pode não ser roteada ao `ExceptionHandler`** (varia por
  versão/ordem de filtro no Micronaut 4). → *Mitigação:* se na implementação a `UnauthenticatedException` não
  cair no `UnauthenticatedExceptionHandler`, o filtro emite a resposta diretamente com o builder
  compartilhado `unauthorized("UNAUTHENTICATED", messages(...))` (mesma forma/code/chave i18n) — a Decisão 4
  degrada para a alternativa sem perder o contrato.
- **Disponibilidade da `RouteMatch` no filtro de request** (timing de roteamento vs. filtro). → *Mitigação:*
  ler `HttpAttributes.ROUTE_MATCH` do request; o router do Micronaut resolve a rota antes da cadeia de
  filtros, então a anotação está acessível. Coberto por teste de borda.
- **`micronaut-openapi` KSP roda sobre `@Controller` de teste** (o probe `@Authenticated`), podendo emitir um
  segundo documento OpenAPI no classpath de teste. → *Mitigação:* já existe exclusão de
  `META-INF/swagger/**` em `processTestResources`; manter.
- **Teste de arquitetura (Konsist) e o `CLAUDE.md`** descrevem o binder opt-in. → *Mitigação:* o `CLAUDE.md`
  é atualizado nesta change (decisão de design nova); se o Konsist tiver asserção sobre o pacote/nome, ajustar
  junto.
- **Declarar `AuthenticatedPersonId` sem `@Authenticated`** vira parâmetro não-satisfeito. → *Mitigação:*
  aceito como erro de programação; documentado; sem caminho de request legítimo que dependa disso.

## Migration Plan

1. Criar `@Authenticated`, o `AuthenticationServerFilter`, e mover as peças para `http/authentication/`;
   reduzir o binder a leitor de attribute.
2. Ajustar o `SessionController` (sign-out ainda lê o Bearer direto via `bearerToken`, sem `@Authenticated` —
   a rota é aberta por contrato); nenhuma rota de produção passa a exigir o ator.
3. Reescrever `AuthenticatedPersonIdBinderTest` como teste do filtro: rota `@Authenticated` protegida vs. rota
   aberta; manter os quatro casos (token válido → id no handler; sem token → `401`; token irresolvível →
   `401`; rota aberta → passa).
4. Atualizar o `CLAUDE.md` (seção de auth) para o guard declarativo.
5. `./gradlew compileKotlin compileTestKotlin` e `./gradlew test`.
6. **Rollback:** como não há endpoint de produção protegido, reverter é remover o filtro/anotação e restaurar
   o binder resolvente — sem impacto em contrato público.
