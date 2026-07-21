## Context

Hoje não existe nenhuma abstração de log em `core`. O único ponto do código que loga —
`UnexpectedFailureExceptionHandler` — chama `org.slf4j.LoggerFactory.getLogger(...)` diretamente, com
`logger.error("...", exception)`. O build declara só `slf4j-api` (trazido transitivamente pelo Micronaut);
não há `logback-classic`, `log4j-slf4j-impl` ou qualquer outro binding no classpath de runtime — então essa
chamada cai no logger NOP da SLF4J hoje: o log não aparece em lugar nenhum. `main/Main.kt` usa `println` pra
anunciar o boot. Nenhum dos dois passa por um port.

`core` já estabelece o padrão pra esse tipo de dependência transversal: `ClockPort`/`ClockAdapter` e
`IdGeneratorPort`/`IdGeneratorAdapter` são ports de determinismo, injetados via `CoreFactory`
(`@Factory`/`@Singleton`), nunca instanciados direto por quem consome. `application/` nunca importa a lib
concreta (ADR 0006; Konsist `ArchitectureTest` já barra import de lib de persistência e de DI framework em
`domain/`+`application/` — SLF4J não está nessa lista ainda). Este change segue exatamente essa forma para
logging, mais uma camada extra que os outros ports não precisam: dado que log é o único lugar do sistema
que existe **para** carregar detalhe operacional (stacktrace, path, id), ele é também o lugar com maior risco
de vazar dado sensível — e diferente da resposta HTTP (onde `core`'s contrato de erro já impede vazamento),
não há uma borda natural que filtre o que entra no log.

O horizonte declarado (README/CLAUDE.md) é integrar métricas/traces via OpenTelemetry no futuro. Este
change não implementa OTEL — implementa o port de forma que trocar `Slf4jLoggerAdapter` por um adapter que
emite via OTEL Logs Bridge (ou anexa atributos ao `LogRecord` do OTEL SDK) não exija tocar nenhum
call site em `application/`/`infrastructure/`.

## Goals / Non-Goals

**Goals:**
- Um `LoggerPort` único em `core`, consumido por `application/` (use cases) e por `infrastructure/`
  (adapters, filtros HTTP, exception handlers) — nunca SLF4J direto fora do próprio adapter.
- Atributos estruturados (`component` + `attributes: Map<String, LoggableValueObject>`), não mensagens com
  placeholder posicional — o formato que um backend de log/OTEL espera como atributos de um `LogRecord`.
- Duas camadas de proteção contra vazamento de dado sensível: `LoggableValueObject` restringe o que é
  *possível* passar por atributo; a denylist do adapter mascara/hasheia o que passa mesmo assim.
- Migrar as duas chamadas soltas existentes (`UnexpectedFailureExceptionHandler`, `Main.kt`) pro port.
- Um binding SLF4J real (`logback-classic`) — sem isso, nada do resto emite nada.
- Um filtro HTTP cross-cutting de log de request/response com correlation id via MDC, na mesma forma
  do `AuthenticatedFilter` já existente.
- Estender o Konsist `ArchitectureTest` pra barrar `org.slf4j` em `domain/`+`application/`.

**Non-Goals:**
- `MetricsPort`, instrumentação de métricas, ou qualquer dependência real do OpenTelemetry SDK
  (traces, exporters, Collector). Ver Open Questions / trabalho futuro.
- Correlacionar logs entre requisições (ex.: um id de "sessão de negócio" cross-request) — o
  correlation id deste change é por requisição HTTP, ponto.
- Configuração de nível de log por ambiente (dev/staging/prod) além do `logback.xml` default — fica
  pra quando houver múltiplos ambientes reais de deploy.
- Log assíncrono/buffer/batching de alta performance — volume esperado ainda é baixo; Logback
  síncrono default é suficiente.

## Decisions

**`LoggerPort` é uma interface multi-método, não um `fun interface` de operação única.**
Diferente de `ClockPort`/`IdGeneratorPort` (uma única operação determinística), log tem quatro níveis
com semântica distinta (`debug`/`info`/`warn`/`error`) e `error` carrega uma `cause: Throwable?` opcional
que os outros níveis não têm. Colapsar isso num único método (`invoke(event: LogEvent)`) economizaria uma
interface, mas empurraria pro chamador construir um `LogEvent(level = ...)` toda vez — mais verboso no
call site pro benefício de menos declaração no port. Rejeitado: o custo de quatro métodos numa interface é
baixo, e a forma "verbo por nível" é o que todo chamador já espera de um logger.

```kotlin
interface LoggerPort {
    fun debug(component: String, message: String, attributes: Map<String, LoggableValueObject> = emptyMap())
    fun info(component: String, message: String, attributes: Map<String, LoggableValueObject> = emptyMap())
    fun warn(component: String, message: String, attributes: Map<String, LoggableValueObject> = emptyMap())
    fun error(
        component: String,
        message: String,
        attributes: Map<String, LoggableValueObject> = emptyMap(),
        cause: Throwable? = null,
    )
}
```

**`component` é passado por chamada, não fixado no bean.** `LoggerPort` é injetado como singleton único
via `CoreFactory` (`@Singleton fun logger(): LoggerPort = Slf4jLoggerAdapter(LoggerFactory.getLogger("com.bed.cordato"))`,
o `Logger` SLF4J recebido pelo adapter via construtor — mesmo padrão de `MessageAdapter(messages)`,
`CoreFactory` é o único lugar que nomeia o tipo concreto) — não um bean por classe
consumidora, então não há como o adapter descobrir sozinho "quem" está logando (diferente do padrão
`LoggerFactory.getLogger(MinhaClasse::class.java)` que `UnexpectedFailureExceptionHandler` usa hoje). Cada
chamador passa seu próprio nome de componente explicitamente (ex.: `"SignUpUseCase"`,
`"UnexpectedFailureExceptionHandler"`). *Alternativa considerada*: logger fixo internamente
(`getLogger("com.bed.cordato")`), perdendo granularidade por classe/pacote na configuração do
`logback.xml`. Rejeitada — quem opera o sistema perde a capacidade de silenciar/elevar nível por origem.
*Alternativa considerada*: um bean por classe (`LoggerPort` parametrizado por `KClass` na injeção).
Rejeitada — foge do padrão de singleton único que todo outro port do `core` segue, sem ganho real (o nome
por chamada já resolve o problema).

**`LoggableValueObject` é um tipo restrito, não `Any?`.** Um `Map<String, Any?>` permite passar qualquer
entidade/value object inteiro por acidente (ex.: `attributes = mapOf("person" to person)` vazaria toda a
`PersonEntity`, incluindo hash de senha). `LoggableValueObject` restringe o valor a um pequeno conjunto seguro:

```kotlin
sealed interface LoggableValueObject {
    @JvmInline value class Text(val value: String) : LoggableValueObject
    @JvmInline value class Number(val value: kotlin.Number) : LoggableValueObject
    @JvmInline value class Flag(val value: Boolean) : LoggableValueObject
    @JvmInline value class Moment(val value: java.time.Instant) : LoggableValueObject
}
```

Isso força o chamador a extrair explicitamente o campo que quer logar (`"person_id" to LoggableValueObject.Text(person.id.toString())`),
nunca o objeto inteiro. *Alternativa considerada*: `Map<String, Any?>` com convenção de code review
("nunca passe uma entidade inteira"). Rejeitada — é exatamente o tipo de regra que uma revisão apressada
deixa passar, e o objetivo declarado é reduzir esse risco por construção, não só por processo.

**Denylist de chaves sensíveis no adapter, como segunda camada — não a única.** Mesmo com
`LoggableValueObject` travando o *tipo*, nada impede um chamador de fazer
`"password" to LoggableValueObject.Text(command.password.raw)` — o tipo permite, o nome da chave é que denuncia a
intenção. `Slf4jLoggerAdapter` mantém uma lista fixa de nomes de chave (`password`, `token`, `email`,
`authorization`, `secret`) e, antes de emitir, mascara (`***`) ou hasheia o valor associado a qualquer chave
que bata (case-insensitive) com essa lista — independente do que `LoggableValueObject` já filtrou. As duas camadas
cobrem falhas diferentes: `LoggableValueObject` pega "passei o objeto errado"; a denylist pega "passei o campo
certo, com o nome errado, mas o valor sensível".

**`Slf4jLoggerAdapter` usa a fluent API da SLF4J 2.x (`atInfo().addKeyValue(...)`), não interpolação de
string.** Isso preserva `component`/`attributes` como pares chave-valor estruturados no `LoggingEvent`, em
vez de embuti-los na mensagem formatada — a mesma forma que um `LogRecord` do OTEL usa para atributos.
`logback.xml` configura o encoder com o conversor `%kvp` (disponível desde Logback 1.3/1.4) pra esses pares
aparecerem na saída hoje, sem esperar o OTEL chegar.

**`logback-classic` é o binding escolhido.** É o binding de fato-padrão do ecossistema Micronaut/Kotlin, e
é o que o `OpenTelemetry Logback Appender` (quando o change de OTEL acontecer) se acopla nativamente — não
precisa trocar de binding pra ganhar a integração depois.

**Filtro de log HTTP espelha `AuthenticatedFilter`: `@ServerFilter(ServerFilter.MATCH_ALL_PATTERN)`,
descoberto por anotação, não por `@Factory`.** Loga `component = "HttpRequestLoggingFilter"`,
`attributes = {method, path, status, duration_ms}` via `LoggerPort.info` (ou `.warn`/`.error` conforme a
faixa de status). Antes de delegar, gera um correlation id (UUID) e o coloca no SLF4J `MDC` sob a chave
`correlation_id` — a mesma chave que vai receber o `trace_id` do OTEL quando a instrumentação de tracing
for adicionada, então nenhum call site muda nesse dia. O id também é ecoado num header de resposta
(`X-Correlation-Id`) pra permitir correlacionar client-side.

**`UnexpectedFailureExceptionHandler` e `Main.kt` migram para `LoggerPort`.** O handler troca
`LoggerFactory.getLogger(...)` + `logger.error(...)` por `logger.error("UnexpectedFailureExceptionHandler", "Unhandled failure", attributes, exception)`,
recebendo `LoggerPort` por construtor como já recebe `MessagePort`. `Main.kt` troca o `println` final por
`logger.info("Main", "Cordato started", attributes = {"uri" to ..., "port" to ...})` — exige resolver o
bean `LoggerPort` do `ApplicationContext` já criado, mesmo padrão do `EmbeddedServer`.

## Risks / Trade-offs

- **[Risco] Denylist de chaves é uma lista fixa — nomes de chave não previstos (`cpf`, `pix_key`, dado de
  negócio sensível futuro) escapam.** → Mitigação: a lista fica num único lugar (`Slf4jLoggerAdapter`),
  fácil de estender; `LoggableValueObject` continua sendo a primeira barreira independente do conteúdo da
  denylist.
- **[Risco] `logback.xml` mal configurado (nível `DEBUG` global em produção) pode reintroduzir vazamento
  mesmo com as duas camadas — a denylist mascara valor, mas não impede que alguém logue `debug` demais.**
  → Mitigação: fora de escopo deste change (é config de deploy, não de código), mas fica registrado como
  ponto de atenção operacional.
- **[Trade-off] `component: String` livre (não um enum/sealed) permite nomes inconsistentes entre
  chamadores (`"SignUpUseCase"` vs `"sign-up-use-case"`).** → Aceito: um enum central acoplaria toda
  feature a um tipo em `core`, o oposto do que o desenho de bounded context quer. Convenção (nome da
  classe) é suficiente e revisável.
- **[Risco] Adicionar `logback-classic` agora, sem binding antes, muda o comportamento de runtime
  (logs que eram NOP passam a aparecer) — pode expor volume/formato inesperado em produção no primeiro
  deploy.** → Mitigação: `logback.xml` default conservador (INFO+, console appender) neste change;
  ajuste fino de nível fica pra depois que houver operação real observada.

## Migration Plan

Sem dado persistido, sem contrato HTTP alterado — não há migração de estado. Ordem de implementação:
1. Binding (`logback-classic` + `logback.xml` mínimo) — sem isso nada mais é observável.
2. `LoggableValueObject` + `LoggerPort` (core/application) — nenhum consumidor ainda.
3. `Slf4jLoggerAdapter` + wiring em `CoreFactory`.
4. Migrar `UnexpectedFailureExceptionHandler` e `Main.kt` (os dois loose logs existentes).
5. Filtro HTTP de log + correlation id.
6. Estender `ArchitectureTest` (Konsist) pra barrar `org.slf4j` em `domain/`+`application/`.
Rollback: reverter o commit/PR — nenhuma migração de schema ou dado envolvida.

## Open Questions

- Quando o change de métricas/OTEL acontecer, o `correlation_id` do MDC vira literalmente o `trace_id`
  do OTEL, ou os dois convivem (correlation id nosso + trace id do OTEL, propósitos distintos)? Decisão
  adiada pro change de OTEL.
- Vale um nível de log dedicado pra "erro de domínio esperado" (ex.: `SignUpError.EmailAlreadyInUse`) além
  do `warn` genérico, ou esses nem deveriam ser logados (já são 422/401 no contrato de erro, não são
  "inesperados")? Fica pra quando um use case realmente precisar logar um branch de erro de domínio —
  este change só cobre a infraestrutura do port, não decide política de "o que cada use case loga".
