## Context

A borda HTTP hoje tem uma rota (`POST /sign-up`) e todo o texto legível das respostas de erro está como
literal PtBr inline em cinco arquivos (o mapper de erro de identity, o request DTO, e três handlers do
`core`). Não há origem única para o texto nem variação por idioma, e a API não publica contrato navegável.

A stack é **Micronaut 4.10** com processamento em compile-time via KSP (DI, Serde, validação) — nenhuma
reflection em runtime. Qualquer mecanismo novo precisa respeitar isso e a tabela de camadas do CLAUDE.md:
`domain`/`application` nunca importam framework; a wiring vive em `main/`; o contrato de erro cross-cutting
vive em `core/infrastructure/http/`. Este design cobre duas frentes independentes agrupadas numa mudança:
i18n das mensagens e documentação OpenAPI.

## Goals / Non-Goals

**Goals:**
- Uma origem única e localizável para cada mensagem de resposta, resolvida por chave de um `MessageSource`.
- Locale derivado do `Accept-Language`, com fallback silencioso para o bundle default pt-BR.
- Domínio 100% intocado: nenhum VO/erro passa a conhecer texto ou `MessageSource`.
- Documento OpenAPI gerado em compile-time (KSP) + Swagger UI servida.
- Padrão da interface de documentação (`<Controller>Doc`) que mantém o controller magro.

**Non-Goals:**
- Traduzir para qualquer idioma além de pt-BR agora (só a infra fica pronta).
- Localizar a Swagger UI ou o conteúdo do documento OpenAPI.
- Tornar as mensagens de Bean Validation cientes do locale por-requisição (ver Riscos) — com pt-BR como
  default isso é irrelevante hoje.
- Qualquer mudança em `domain`/`application` ou em regra de negócio.

## Decisions

### D1 — `ResourceBundleMessageSource` como bean no `core`, resolução localizada por requisição

Um `@Factory` no `core` (`CoreModule` já existe como o `@Factory` do núcleo, ou um factory dedicado)
expõe `@Singleton MessageSource` = `ResourceBundleMessageSource("i18n.messages")`. O bundle default
`src/main/resources/i18n/messages.properties` fica em pt-BR; futuros idiomas entram como
`messages_<locale>.properties` sem tocar código.

Para o locale por-requisição, o Micronaut HTTP já fornece `HttpLocalizedMessageSource`
(`@RequestScope`), que combina o `MessageSource` acima com o `RequestLocaleResolver` (que lê
`Accept-Language`). Os call sites injetam `LocalizedMessageSource` e chamam `getMessage(key, args…)`; sem
`Accept-Language` correspondente, cai no default.

*Alternativa considerada:* resolver o locale à mão em cada handler. Rejeitada — o
`HttpLocalizedMessageSource`/`RequestLocaleResolver` já é o mecanismo idiomático e testável.

### D2 — Resolução acontece nos call sites de política; os builders do `core` continuam "burros"

Os builders `badRequest`/`unprocessable`/`internalError` continuam recebendo `code` + `message` **já
resolvidos** (eles só moldam o corpo num status). A resolução da chave → texto acontece um nível acima:

- **Handlers do `core`** (`@Singleton`) injetam `LocalizedMessageSource` (proxy request-scoped — o
  Micronaut permite injetar bean request-scoped em singleton) e resolvem a chave antes de chamar o
  builder.
- **Mapper de erro de identity** (`SignUpError.toResponse`) hoje é uma extension function pura. Passa a
  receber o `MessageSource`/`LocalizedMessageSource` como **parâmetro** (`error.toResponse(messages)`),
  mantendo a convenção de mapper-como-extension (não vira `@Singleton`/objeto). O `PersonController`
  injeta `LocalizedMessageSource` e o repassa ao mapper.

Isso mantém "o builder é dono do shape, o mapper é dono da política" e adiciona "a resolução mora no site
de política". A invariante de não-vazamento fica preservada: a chave de `EmailAlreadyInUse` aponta para um
texto genérico e continua escalar (nunca `FieldError(field="email")`).

*Alternativa considerada:* fazer os builders resolverem a chave (recebendo `MessageSource`). Rejeitada —
acoplaria o `core` de shape ao mecanismo de i18n e obrigaria todo call site a ter um `MessageSource`
mesmo para texto fixo.

### D3 — Bean Validation via chaves `{...}` no mesmo bundle

As mensagens do `SignUpRequest` trocam `message = "texto"` por `message = "{signup.name.notBlank}"`. O
interpolador de validação do Micronaut resolve `{...}` contra o `MessageSource` bean (o mesmo de D1),
mantendo os placeholders existentes (`{max}`, `{min}`). Uma chave por restrição espelhada. As referências
a `NameValueObject.MAX_LENGTH` / `EmailValueObject.PATTERN` no `regexp`/`max` permanecem — só o texto vira
chave.

### D4 — OpenAPI em compile-time via KSP + Swagger UI

Adiciona `ksp("io.micronaut.openapi:micronaut-openapi:<v>")` (o processador) e
`compileOnly("io.micronaut.openapi:micronaut-openapi-annotations:<v>")` (as anotações
`io.swagger.v3.oas.annotations`). O documento é gerado no build (sem reflection). A Swagger UI é habilitada
pela propriedade do processador `micronaut.openapi.views.spec=swagger-ui.enabled=true` (via
`openapi.properties`/arg do KSP) e exposta por um `static-resources` mapeando `/swagger-ui/**` na config da
aplicação. Metadados globais (`@OpenAPIDefinition` com título/versão) ficam num ponto único (ex.: no
`Application`/`Main` ou num arquivo de definição da API).

*Alternativa considerada:* gerar spec em runtime (springdoc-style). Rejeitada — quebraria a postura
no-reflection/compile-time do projeto.

### D5 — Interface de documentação `<Controller>Doc`

As anotações `@Operation`/`@ApiResponse` migram para uma interface
`features/identity/infrastructure/http/controllers/PersonControllerDoc.kt`, que o `PersonController`
implementa. O Micronaut herda `AnnotationMetadata` de interfaces nativamente, então as anotações na
interface entram no documento gerado. Divisão de anotações:

- **Interface (`PersonControllerDoc`)**: documentação — `@Operation`, `@ApiResponse` (e `@Tag`).
- **Controller (`PersonController`)**: roteamento/validação — `@Controller`, `@Validated`, `@Post`,
  `@Body`, `@Valid` — e a delegação ao use case.

A mecânica exata (se o `@Post` precisa co-residir com as anotações de doc no mesmo elemento) SHALL ser
confirmada no primeiro passo de implementação e ajustada se o processador exigir. A interface é artefato de
documentação de infra — **não** um port de aplicação (não duplica a assinatura do use case).

## Risks / Trade-offs

- **[Interpolação de validação pode não ser locale-aware por requisição]** → O interpolador de Bean
  Validation resolve `{...}` no momento em que a violação é construída, tipicamente com o locale default
  do processo, não necessariamente o `Accept-Language` da requisição. Com pt-BR como único idioma isso é
  inócuo. Mitigação: documentar como limitação conhecida; quando um segundo idioma entrar, avaliar
  configurar o locale default do validador ou resolver a mensagem no `ConstraintViolationExceptionHandler`
  (que já é request-scoped-aware) em vez de confiar no texto já interpolado.
- **[Versão do processador OpenAPI não herda o BOM na config `ksp`]** → Assim como os outros processadores
  KSP do projeto, o `ksp(...)` não herda o `micronaut-platform` BOM. Mitigação: pinar a versão do
  `micronaut-openapi` explicitamente, seguindo o padrão já usado para serde/validation/inject.
- **[Injeção de bean request-scoped em handler singleton]** → Depende do proxy request-scoped do
  Micronaut. Mitigação: é comportamento suportado; validar com o teste de HTTP existente que já sobe Netty.
- **[Swagger UI exposta sem auth]** → A rota `/swagger-ui/**` fica pública. Aceitável no estágio atual
  (API ainda em bring-up); revisar quando houver autenticação/sessão.

## Migration Plan

Mudança puramente aditiva de borda, sem migração de dados nem breaking change de contrato (o shape do
`ErrorResponse` não muda; só a origem do texto). Sem estratégia de rollback além de reverter o commit. A
ordem natural: (1) infra de i18n + migração dos cinco pontos de texto; (2) OpenAPI/Swagger + interface de
doc. Os dois blocos são independentes e podem ser verificados em separado pelos testes de HTTP.

## Open Questions

- O `MessageSource` deve ser exposto pelo `CoreModule` existente ou por um `@Factory` dedicado de i18n no
  `core`? (Inclinação: um factory dedicado em `core/infrastructure/http/` ou `core/main/`, para não
  inchar o `CoreModule` de persistência.) — resolver na implementação.
- Onde declarar os metadados globais do OpenAPI (`@OpenAPIDefinition`): junto ao `Main`/`Application` ou
  num arquivo dedicado? — resolver na implementação.
