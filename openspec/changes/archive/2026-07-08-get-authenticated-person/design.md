## Context

O `feat/http-authentication-guard` já entregou o lado consumidor da sessão: `AuthenticatedFilter`
(`@ServerFilter`) resolve o Bearer numa sessão viva via `SessionRepository.findActiveByToken`, guarda o
`personId` num request-attribute, e o `AuthenticatedActorArgumentBinder` (wired no `CoreFactory`) o entrega
como `AuthenticatedActor(personId)`. Nenhuma rota `@Authenticated` real existe ainda — só o probe de teste
em `support/`. Sign-in *minta* a sessão; falta a primeira rota que *consome* o ator e devolve dados.

O `AuthenticationController` já documenta, em KDoc, a fronteira que esta change respeita: operações sobre a
pessoa já autenticada (`GET`/`PATCH`/`DELETE`) pertencem a um `PersonController` separado, apartado dos
fluxos abertos de mint. `identity` guarda a `PersonEntity` e sua `PersonResponse`/`toResponse` (sem material
de senha) já prontas para reuso.

## Goals / Non-Goals

**Goals:**
- Entregar `GET /persons/me` protegido, consumindo o `AuthenticatedActor` e devolvendo a visão pública da
  pessoa dona da sessão.
- Fechar o ciclo mint→consume exercitando filtro + binder por uma rota real, ponta a ponta.
- Preservar o invariante de não-vazamento: sessão órfã e token inválido colapsam num único `401` neutro.

**Non-Goals:**
- `PATCH`/`DELETE` da pessoa (deleção de conta é a operação destrutiva atômica; fica para outra change).
- Qualquer dado além de id/nome/e-mail (nada de status, timestamps, ou dados financeiros).
- Introduzir `core/` como dono do conceito de sessão/token (segue como está); mudar o guard de borda.
- Endpoints do casal/orçamento/despesa.

## Decisions

### 1. `MeUseCase` recebe `personId`, não relê sessão nem token
O guard de borda é a **única** autoridade sobre "quem chama". O use case recebe o `personId` já resolvido
(via `MeCommand`) e apenas resolve a pessoa ativa por id. Alternativa rejeitada: o use case receber o token
e reabrir a sessão — duplicaria a lógica do filtro, arrastaria `SessionRepository` para dentro de identity e
quebraria a separação driving-side já estabelecida.

### 2. Sessão órfã → `MeError.PersonNotFound` → `401` neutro (não `404`, não `500`)
Uma sessão viva cuja pessoa não está mais ativa só ocorre numa corrida com a deleção de conta (que, quando
existir, invalidará a sessão atomicamente). Modelamos como **falha de domínio** no `sealed MeResult`, e o
mapper de erro a colapsa no **mesmo** `401 UNAUTHENTICATED` do guard/sign-in, reusando a chave i18n
`error.authentication.message`. Assim a resposta é indistinguível de token inválido — nenhuma chave nova.
Alternativas rejeitadas: `404` (revelaria que a sessão existia mas a pessoa não — oráculo, e status
odd-one-out que o CLAUDE.md proíbe); `500` (não é erro do servidor, e vazaria "algo estranho aconteceu");
`PersonEntity` non-null com `!!` (sem rede na corrida — perde o caminho neutro).

### 3. Reuso do `PersonRepository` com um novo `findById` ativo-only
`findById(id): PersonEntity?` espelha exatamente o `findByEmail`: filtra `STATUS = ACTIVE` no jOOQ, colapsa
"não existe" e "não-ativa" em `null`. Mantém a neutralidade no nível da query. Sem novo port ou repositório.

### 4. `PersonController` novo, separado do `AuthenticationController`
Segue o KDoc já escrito no `AuthenticationController`. `@Controller("/persons")`, `@Get("/me")`, com
`@Authenticated` **no método** `me()` (não na classe) — futuros `PATCH`/`DELETE` podem ter marcações
próprias, e deixar a granularidade no método é o mais honesto. Injeta `MessagePort` + `MeUseCase`; recebe
`AuthenticatedActor` como parâmetro do handler (o binder o satisfaz). Ramifica sobre `MeResult`:
`Success -> HttpResponse.ok(person.toResponse())`, `Failure -> error.toResponse(messages)`.

### 5. Documentação e segurança OpenAPI na interface `PersonControllerDoc`
Segue o split `<Controller>Doc`: `@Tag`/`@Operation`/`@ApiResponse` (200→`PersonResponse`, 401/500→
`ErrorResponse`) vivem na interface implementada. O **security scheme Bearer** é global e cross-cutting, então
é declarado uma vez no `OpenApiDefinition` do core (`@SecurityScheme(name="bearerAuth", type=HTTP,
scheme="bearer")`) e a operação protegida o referencia com `@SecurityRequirement(name="bearerAuth")` na
`PersonControllerDoc`. Sem `400` documentado (a rota não tem corpo nem parâmetros validáveis).

## Risks / Trade-offs

- [O `AuthenticatedActor` é uma `data class` de `String`; um handler que peça o ator numa rota **sem**
  `@Authenticated` teria binding insatisfeito] → é erro de programação sem caminho de request legítimo (o
  binder só lê o atributo que o filtro escreve); a rota `me()` é `@Authenticated`, então o atributo sempre
  existe. Coberto por um teste ponta-a-ponta que bate sem token e espera `401`.
- [Modelar sessão órfã como caminho de domínio adiciona um `MeError` para um caso hoje quase impossível] →
  aceitável: é barato, mantém o `sealed` result exaustivo (padrão do projeto) e já deixa o slot pronto para
  quando a deleção de conta existir; o custo é uma classe de erro e uma linha no mapper.
- [Adicionar `@SecurityScheme` global muda o documento OpenAPI emitido] → é aditivo e não afeta runtime
  (anotações OpenAPI são inertes em execução); rotas abertas não referenciam o esquema, então nada nelas muda.
- [Reuso da chave i18n `error.authentication.message` acopla o `401` do use case ao texto do guard] → é
  desejado: o invariante de não-vazamento **exige** que as duas respostas sejam idênticas; um texto separado
  poderia divergir e virar oráculo.
