## 1. Infra de i18n (MessageSource + bundle)

- [x] 1.1 Criar o bundle default `src/main/resources/i18n/messages.properties` em pt-BR com uma chave por mensagem (erros de domínio de identity, validação de borda, corpo malformado, validação inválida, falha interna), reutilizando os placeholders existentes (`{min}`, `{max}`, mínimo de senha).
- [x] 1.2 Expor `@Singleton MessageSource` = `ResourceBundleMessageSource("i18n.messages")` via um `@Factory` no `core` (dedicado de i18n em `core/`, ou `CoreModule` — decidir conforme a Open Question do design), sem tocar `domain`/`application`.
- [x] 1.3 Confirmar que `LocalizedMessageSource` (request-scoped, via `RequestLocaleResolver`/`Accept-Language`) é injetável nos handlers `@Singleton` e no controller; validar o fallback para o default quando o header está ausente/desconhecido.

## 2. Migração dos textos para chaves

- [x] 2.1 `SignUpErrorResponseMapper.toResponse`: receber `LocalizedMessageSource` como parâmetro e resolver cada `SignUpError` por chave (interpolando `minLength` de `WeakPassword`); manter `EmailAlreadyInUse` genérico e escalar.
- [x] 2.2 `PersonController`: injetar `LocalizedMessageSource` e repassá-lo ao mapper (`error.toResponse(messages)`), mantendo o controller magro.
- [x] 2.3 Handlers do `core` (`ConstraintViolationExceptionHandler`, `MalformedRequestBodyHandlers`, `UnexpectedFailureExceptionHandler`): injetar `LocalizedMessageSource` e resolver a `message` por chave antes de chamar os builders (o `code` permanece contrato inline, não localizado); builders permanecem inalterados (só shape). Resolução centralizada em `core/infrastructure/http/i18n/resolve`.
- [x] 2.4 `SignUpRequest`: trocar cada `message = "texto"` por `message = "{chave}"` no mesmo bundle, preservando `{max}`/`{min}` e as referências a `NameValueObject.MAX_LENGTH`/`EmailValueObject.PATTERN`.
- [x] 2.5 Verificar que nenhum literal de texto de resposta permanece nos cinco pontos migrados e que `domain`/`application` seguem sem importar framework (Konsist verde).

## 3. Testes de i18n

- [x] 3.1 Ajustar/adicionar testes de HTTP: default pt-BR quando `Accept-Language` ausente; fallback quando pedir locale sem bundle; conflito de e-mail continua neutro e escalar; `500` só resolve mensagem genérica.
- [x] 3.2 Cobrir a resolução por chave nos handlers de validação/malformado (uma `FieldErrorResponse` por campo, texto vindo do bundle).

## 4. OpenAPI / Swagger — dependências e geração

- [x] 4.1 Adicionar ao `build.gradle.kts`: `ksp("io.micronaut.openapi:micronaut-openapi:<v>")` e `compileOnly("io.micronaut.openapi:micronaut-openapi-annotations:<v>")`, pinando a versão (não herda o BOM na config `ksp`, seguindo o padrão dos outros processadores).
- [x] 4.2 Declarar os metadados globais do documento (`@OpenAPIDefinition`: título/versão) num ponto único (junto ao `Main`/`Application` ou arquivo dedicado — decidir conforme Open Question).
- [x] 4.3 Habilitar a Swagger UI: propriedade do processador `micronaut.openapi.views.spec=swagger-ui.enabled=true` e mapear `static-resources` `/swagger-ui/**` na config da aplicação.
- [x] 4.4 Confirmar que o build gera o documento OpenAPI e que a UI carrega servindo-o.

## 5. Padrão da interface de documentação

- [x] 5.1 Criar `features/identity/infrastructure/http/controllers/PersonControllerDoc.kt` com as anotações `io.swagger.v3.oas.annotations` (`@Operation`, `@ApiResponse`, `@Tag`) da rota de sign-up.
- [x] 5.2 Fazer `PersonController` implementar `PersonControllerDoc`, mantendo nele apenas roteamento/validação (`@Controller`, `@Validated`, `@Post`, `@Body`, `@Valid`) e a delegação ao use case; confirmar a mecânica do Micronaut (se `@Post` precisa co-residir com as anotações de doc) e ajustar.
- [x] 5.3 Verificar no documento gerado que a operação e as respostas declaradas na interface aparecem para `POST /sign-up`.

## 6. Fechamento

- [x] 6.1 Rodar `./gradlew build` e a suíte de testes (incl. HTTP que sobe Netty) verdes; Konsist sem violação de camada.
- [x] 6.2 Atualizar `CLAUDE.md` documentando os dois novos padrões (i18n por chave na borda; interface `<Controller>Doc`) como convenção para os próximos contextos.
