## Context

O contrato de erro HTTP nasceu em `identity/infrastructure/http/errors/` porque `identity` foi a primeira
borda HTTP. Nada nele é específico de `identity`: `ErrorResponse` é um DTO neutro e o
`ConstraintViolationExceptionHandler` só sabe de `jakarta.validation`. Pela regra do projeto (cross-cutting
mora em `core/`, nunca em `shared/` nem num feature), esse contrato pertence a `core/`. `core/infrastructure/`
já existe (adapters de determinismo, persistência); falta o subpacote `http/`.

Hoje o "shape único" prometido pela `ErrorResponse` tem duas frestas: (a) um corpo malformado/ausente e
qualquer exceção não-tratada escapam para o corpo default do Micronaut (`_embedded.errors`), quebrando a
promessa; (b) o handler de validação faz `joinToString(" ")` sobre as violações, colando N campos numa
`message` só e perdendo qual campo falhou. E o projeto tem uma invariante forte de não-vazamento (o
conflito de e-mail é redigido para não virar oráculo de contas) — qualquer fallback genérico precisa
respeitá-la.

## Goals / Non-Goals

**Goals:**
- `core/infrastructure/http/` passa a ser dono do `ErrorResponse`, do `FieldError` e de todos os handlers
  genéricos (validação → `400`, corpo malformado → `400`, `Throwable` → `500`).
- Todo caminho de falha HTTP — borda, parse, domínio, inesperado — sai no **mesmo** shape `ErrorResponse`.
- O `400` de validação reporta **cada** campo violado (`errors: List<FieldError>`), sem concatenar.
- O `500` é neutro e o detalhe fica só no log — nunca ecoa `exception.message`.

**Non-Goals:**
- Não mexer no domínio/aplicação de `identity`: `SignUpUseCase` e `SignUpError` ficam intocados.
- Não trocar o `422` de domínio de fail-fast para acumulação — segue um único `SignUpError`.
- Não introduzir i18n/catálogo de mensagens; as mensagens curadas seguem inline como hoje.
- Não versionar a API nem manter o corpo antigo — a `errors[]` é aditiva e opcional.

## Decisions

### 1. `ErrorResponse` ganha `errors: List<FieldError>` opcional, com default vazio

```kotlin
@Serdeable data class ErrorResponse(
    val code: String,
    val message: String,
    val errors: List<FieldError> = emptyList(),
)
@Serdeable data class FieldError(val field: String, val message: String)
```

`errors` é aditivo: os casos escalares (`422` de domínio, `500`, `400` de corpo malformado) o deixam vazio
e continuam carregando tudo em `message`. Só o `400` de Bean Validation o preenche. **Alternativa
descartada**: um shape polimórfico (um tipo por caso) — mais tipos, quebra a promessa de "um shape só" e
não agrega, já que a lista vazia degrada bem.

### 2. Handlers continuam annotation-bearing e descobertos, não `@Factory`

Os `ExceptionHandler` do Micronaut são beans (`@Singleton`/`@Produces`, `@Replaces` quando substituem um
default). O framework os descobre por tipo de exceção — não há como declará-los por `@Factory`. São, portanto,
a **mesma** exceção já documentada para os `@Controller`: annotation-bearing na infraestrutura, descobertos
direto. `CoreModule` (`@Factory`) não os wira e permanece intocado. `ErrorResponse`/`FieldError` são DTOs
`@Serdeable`, sem wiring.

### 3. Três handlers genéricos em `core/infrastructure/http/`

- `ConstraintViolationExceptionHandler` (movido, agora por campo): mapeia cada violação para um
  `FieldError(field, message)` — `field` derivado do `propertyPath` (último nó, sem o prefixo do método/arg),
  `message` a mensagem curada da constraint. `code = "INVALID_REQUEST"`, `message` um resumo genérico.
- Handler de corpo malformado/ausente: trata o erro de bind/parse do Micronaut (JSON inválido ou corpo
  vazio) → `400` genérico, `errors` vazio. **Decisão de alvo**: capturar a exceção de conversão de corpo do
  Micronaut em vez de um `Throwable` amplo, para não colidir com o fallback `500`. A exceção exata a
  interceptar é um ponto de implementação a confirmar no `apply` (candidatos: `ConversionErrorException` /
  a exceção de request-body não-lida) — validado por teste de endpoint com JSON quebrado.
- Fallback `ExceptionHandler<Throwable>` → `500`, `code = "INTERNAL_ERROR"`, `message` genérica fixa. O
  `exception` é **logado** (stacktrace) mas nunca serializado. Como o Micronaut resolve o handler mais
  específico, este só pega o que os demais (e os controllers) não trataram.

### 4. `identity` só perde os tipos movidos; ganha nada de novo

`SignUpErrorResponseMapper` continua em `identity/infrastructure/http/mappers/`, agora importando
`ErrorResponse` de `core`. O `422` e a redação neutra do `EmailAlreadyInUse` não mudam. **Importante para o
não-vazamento**: `EmailAlreadyInUse` continua um erro escalar de `message` genérica — nunca vira um
`FieldError(field = "email", ...)`, o que reintroduziria o oráculo de contas.

## Risks / Trade-offs

- **[Acoplar ao nome interno da exceção de parse do Micronaut]** → interceptar o tipo errado deixaria o
  corpo malformado caindo no `500` em vez do `400`. Mitigação: um teste de endpoint com JSON quebrado e
  outro com corpo vazio fixam o comportamento observável, independente do tipo escolhido.
- **[Fallback `Throwable` mascarar bugs como `500` genérico]** → perda de sinal. Mitigação: log obrigatório
  com stacktrace no handler; o `500` é para o cliente, o detalhe é para o operador.
- **[`field` do `propertyPath` vazar forma interna]** (ex.: `signUp.request.email`) → mitigação: extrair só
  o último nó (`email`), coberto por teste.
- **[Konsist]** → `core` não pode importar `features/*`; o teste de arquitetura já cobre e roda no `apply`.

## Migration Plan

1. Criar `core/infrastructure/http/` com `ErrorResponse` + `FieldError` e os três handlers.
2. Apagar `ErrorResponse` e `ConstraintViolationExceptionHandler` de `identity/infrastructure/http/errors/`;
   repontar o import no `SignUpErrorResponseMapper`.
3. Ajustar testes (`PersonControllerTest` para `400` multi-campo; novos testes de handler em `core`).
4. `./gradlew build` (inclui Konsist). Sem migração de dados, sem flag de rollback — mudança só de código;
   reverter é reverter o commit.

## Open Questions

- Qual exceção exata do Micronaut representa "corpo ausente/JSON inválido" nesta versão (a confirmar por
  teste no `apply`) — não bloqueia o design, só a escolha do tipo interceptado.
