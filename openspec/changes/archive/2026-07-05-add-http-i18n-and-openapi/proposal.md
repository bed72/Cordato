## Why

Hoje os textos legíveis das respostas de erro estão espalhados como literais PtBr fixos em cinco pontos
da camada HTTP (mappers de erro, request DTO, handlers do `core`), sem nenhum ponto único de origem nem
capacidade de variar por idioma. Ao mesmo tempo, a API não expõe documentação navegável: um consumidor
não tem contrato descoberto do `POST /sign-up`. Ambos são dívidas de borda que só crescem a cada novo
contexto (`budget`, `expense`, `couple`), então vale estabelecer os dois padrões agora, enquanto a
superfície HTTP ainda é uma rota só.

## What Changes

- Introduz a infraestrutura de i18n das mensagens HTTP: um `MessageSource` (ResourceBundle) com o bundle
  default em pt-BR, o locale resolvido do header `Accept-Language`, e as mensagens passando a ser
  resolvidas por **chave** em vez de literal inline. pt-BR é o único idioma traduzido agora; a infra fica
  pronta para receber `messages_<locale>.properties` depois sem mudança de código.
- Migra os cinco pontos de texto atuais para chaves de bundle: `SignUpErrorResponseMapper`, as mensagens
  de Bean Validation em `SignUpRequest`, e os handlers do `core` (`MalformedRequestBodyHandlers`,
  `ConstraintViolationExceptionHandler`, `UnexpectedFailureExceptionHandler`).
- **O domínio permanece intocado.** O texto continua sendo responsabilidade exclusiva da camada HTTP; os
  erros de domínio seguem carregando apenas dado semântico (ex.: `WeakPassword.minLength`), nunca string.
  Nenhum value object passa a conhecer `MessageSource`. Preserva a invariante de não-vazamento
  (`EmailAlreadyInUse` continua genérico, jamais vira erro por campo `email`).
- Introduz documentação OpenAPI gerada em **compile-time** (via KSP, sem reflection em runtime — coerente
  com Serde/validação/DI do projeto) e serve a Swagger UI.
- Estabelece o **padrão da interface de documentação**: as anotações OpenAPI (`@Operation`,
  `@ApiResponse`) vivem numa interface `<Controller>Doc` que o controller implementa, mantendo o
  controller magro. Aplicado ao `PersonController` como caso de referência e definido como padrão para os
  próximos contextos.

## Capabilities

### New Capabilities

- `http-i18n`: a resolução localizada das mensagens de resposta HTTP a partir de um bundle de mensagens,
  com o locale derivado do `Accept-Language` e pt-BR como default; as mensagens são referenciadas por
  chave estável, e o domínio nunca produz texto de apresentação.
- `openapi-documentation`: a geração do documento OpenAPI em compile-time e a exposição da Swagger UI,
  incluindo o padrão da interface de documentação (`<Controller>Doc`) que separa as anotações OpenAPI da
  implementação do controller.

### Modified Capabilities

<!-- Nenhuma requirement de comportamento existente muda. As mensagens de erro continuam neutras, curadas e
     não-vazantes (identity-http-api, http-error-handling); apenas sua ORIGEM passa de literal para chave de
     bundle — um detalhe de implementação coberto pela nova capability http-i18n. -->

## Impact

- **Dependências**: adiciona `micronaut-openapi` (+ processador KSP) e as anotações `io.swagger.core.v3`;
  a Swagger UI é habilitada por configuração do processador OpenAPI.
- **Recursos novos**: `src/main/resources/i18n/messages.properties` (bundle default pt-BR).
- **Código afetado (i18n)**: `features/identity/infrastructure/http/mappers/SignUpErrorResponseMapper.kt`,
  `features/identity/infrastructure/http/requests/SignUpRequest.kt`, e no `core`
  `infrastructure/http/errors/handlers/{MalformedRequestBodyHandlers,ConstraintViolationExceptionHandler,UnexpectedFailureExceptionHandler}.kt`.
  As mensagens escalares (mapper + handlers) passam a resolver via `MessageSource`; as mensagens de Bean
  Validation passam a usar chaves `{...}` do bundle.
- **Código afetado (OpenAPI)**: nova interface `features/identity/infrastructure/http/controllers/PersonControllerDoc.kt`
  e `PersonController` passa a implementá-la; possível configuração em `application` properties/annotation
  do processador.
- **Domínio/aplicação**: nenhum arquivo tocado — a mudança é inteiramente de borda/infra.
- **Konsist**: nenhuma regra de camada é relaxada; `domain`/`application` seguem sem importar framework.
