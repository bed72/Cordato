## 1. Binding SLF4J real

- [x] 1.1 Adicionar `logback-classic` (runtime) ao `build.gradle.kts` — hoje só `slf4j-api` está no
      classpath, transitivo, sem binding.
- [x] 1.2 Criar `src/main/resources/logback.xml` mínimo: console appender, encoder com `%kvp` (pares
      chave-valor da fluent API SLF4J 2.x), nível default `INFO`.

## 2. Port e tipo de valor logável (core/application)

- [x] 2.1 Criar `LoggableValueObject` (sealed interface + `Text`/`Number`/`Flag`/`Moment` como
      `@JvmInline value class`) em `core/domain/value_objects/` (é um tipo puro, sem dependência de
      framework — não pertence a `application/`).
- [x] 2.2 Criar `LoggerPort` em `core/application/driven/ports/LoggerPort.kt`: `debug`/`info`/`warn`
      recebendo `component: String`, `message: String`, `attributes: Map<String, LoggableValueObject> = emptyMap()`;
      `error` adicionalmente com `cause: Throwable? = null`.

## 3. Adapter SLF4J + redação de dados sensíveis (core/infrastructure)

- [x] 3.1 Criar `Slf4jLoggerAdapter` em `core/infrastructure/adapters/LoggerAdapter.kt`, implementando
      `LoggerPort` sobre a fluent API da SLF4J (`atInfo().addKeyValue(...).log()` etc.), recebendo o
      `Logger` SLF4J único (ex. `LoggerFactory.getLogger("com.bed.cordato")`) via construtor.
- [x] 3.2 Implementar a denylist de nomes de atributo sensíveis (`password`, `token`, `email`,
      `authorization`, `secret`, comparação case-insensitive) mascarando/hasheando o valor correspondente
      antes de emitir — independente do `LoggableValueObject` já usado pelo chamador.
- [x] 3.3 Testes do adapter (`LoggerAdapterTest`): nível correto por método; `component`/`message`/
      atributos aparecem no evento emitido; atributo com nome sensível sai mascarado; atributo comum sai
      intacto; `cause` em `error` é propagada ao evento.

## 4. Wiring

- [x] 4.1 Adicionar `@Singleton fun logger(): LoggerPort = Slf4jLoggerAdapter(LoggerFactory.getLogger("com.bed.cordato"))`
      em `CoreFactory`.
- [x] 4.2 Criar fake/factory de teste (`core/factories/FakeLoggerPort.kt` +
      `core/factories/FakeLoggerPortFactory.kt`, `@Factory @Replaces`) para os `@MicronautTest` que hoje
      não têm razão para exercitar logging real, seguindo o padrão de `FakeSessionRepository`/
      `FakeSessionRepositoryFactory`.

## 5. Migrar os dois logs soltos existentes

- [x] 5.1 `UnexpectedFailureExceptionHandler`: receber `LoggerPort` por construtor (ao lado de
      `MessagePort`), trocar `LoggerFactory.getLogger(...)` + `logger.error(...)` pela chamada ao port
      com `component = "UnexpectedFailureExceptionHandler"` e os atributos relevantes (method, path).
- [x] 5.2 Atualizar `UnexpectedFailureExceptionHandlerTest` para injetar um `LoggerPort` mockado/fake e
      assertar que a chamada de log ocorre (sem alterar as asserções existentes sobre a resposta HTTP).
- [x] 5.3 `main/Main.kt`: resolver `LoggerPort` do `ApplicationContext` já criado e substituir o
      `println(...)` final por uma chamada `logger.info("Main", "Cordato started", ...)` com a URI do
      servidor como atributo.

## 6. Filtro de log de request/response HTTP + correlation id

- [x] 6.1 Criar `HttpRequestLoggingFilter` (`@ServerFilter(ServerFilter.MATCH_ALL_PATTERN)`) em
      `core/infrastructure/http/logging/`, espelhando a forma de `AuthenticatedFilter`: gera um
      correlation id (UUID) por requisição, coloca no MDC sob `correlation_id`, mede a duração e loga
      method/path/status/duração via `LoggerPort` após a resposta.
- [x] 6.2 Ecoar o correlation id gerado num header de resposta (`X-Correlation-Id`).
- [x] 6.3 Teste (`HttpRequestLoggingFilterTest`, no padrão dos testes de filtro HTTP já existentes):
      requisições distintas recebem correlation ids distintos; o header de resposta carrega o id; o log
      é emitido com status e duração corretos tanto em sucesso quanto em erro.

## 7. Enforcement de arquitetura

- [x] 7.1 Estender `ArchitectureTest` (Konsist) com um teste que barra import de `org.slf4j` em arquivos
      sob `domain/` ou `application/`, na mesma forma dos testes já existentes para persistência e DI.

## 8. Verificação final

- [x] 8.1 `./gradlew build` — compila, Konsist novo passa, testes novos e existentes (incluindo
      `UnexpectedFailureExceptionHandlerTest` atualizado) passam.
- [x] 8.2 Rodar a aplicação localmente (`make db-up` + `./gradlew run`) e confirmar visualmente: log de
      boot aparece via `LoggerPort` (não mais `println`), uma requisição de exemplo produz uma linha de
      log com method/path/status/duração e um `X-Correlation-Id` na resposta.
