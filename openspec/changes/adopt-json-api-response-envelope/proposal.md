## Why

Hoje a API HTTP não tem um envelope de resposta padronizado: sucesso devolve o objeto/array puro
(`ExpenseResponse`, `PersonResponse`, `ExpensePageResponse` direto no corpo) e erro devolve um único
`ErrorResponse{code, message, errors}` — não uma lista. Cada consumidor precisa lidar com duas formas
distintas (objeto solto vs. objeto de erro) e a paginação por cursor mistura dado de navegação
(`nextCursor`) dentro do mesmo corpo dos itens. Adotar um envelope único — sucesso em `data`
(+`meta`/`links` quando aplicável), erro em `errors: [...]` — torna a resposta previsível em toda a borda,
sem abrir mão de nenhum invariante já garantido pela ADR 0008 (não-vazamento por status/campo).

## What Changes

- **BREAKING**: toda resposta de sucesso (200/201) passa a vir envelopada em `{ "data": ... }` — item único
  como objeto, coleção como array. Nenhum controller volta a devolver o corpo cru.
- **BREAKING**: o corpo de erro deixa de ser um objeto único (`ErrorResponse{code,message,errors}`) e passa
  a ser sempre um array `{ "errors": [...] }`, com um item por causa relevante:
  - falha escalar (422 de domínio, 500 interno, 401 de autenticação) → array com **um** item genérico
    `{status, code, message}` — nunca um item por regra de negócio, preservando o invariante de não-vazamento
    da ADR 0008 (ex.: `EmailAlreadyInUse` continua indistinguível de `InvalidEmail`);
  - violação de validação de borda (400) → **um item por campo violado**, cada um
    `{status, code, message, source: {field}}`.
- **BREAKING**: `GET /expenses` para de carregar `nextCursor` dentro do corpo de itens; a página vira
  `data` (os itens) + `meta.pagination.next_cursor` + `links.self`/`links.next` (`null` na última página).
- `meta` e `links` só aparecem quando há conteúdo — nunca chaves vazias/nulas por padrão.
- Documentação OpenAPI (`*ControllerDoc`) e Swagger passam a refletir os novos schemas de envelope
  (`data`, `meta`, `links`, `errors`) em vez de `ErrorResponse`/corpo cru.
- Deliberadamente **não** adotado (diverge do JSON:API "de livro"): `title`+`detail` separados (mantém
  `message` único, já i18n-curado), `source.pointer` (mantém `source.field`, já o nome final do campo),
  resource identifier objects (`type`/`id` como objeto de topo).

## Capabilities

### New Capabilities
- `http-response-envelope`: o envelope de resposta compartilhado por toda borda HTTP — `data` (+`meta`
  opcional, +`links` opcional) no sucesso, `errors: [...]` na falha. Cross-cutting, reside no núcleo
  (`core`), como a capability irmã `http-error-handling` hoje.

### Modified Capabilities
- `http-error-handling`: o corpo de erro deixa de ser um único `ErrorResponse` e passa a ser o array
  `errors: [...]` do `http-response-envelope`; os requisitos de shape (campo único/múltiplo, 400/422/500/401)
  são reescritos para o novo formato, sem alterar nenhuma política de status/oráculo já estabelecida.
- `expense-http-api`: toda resposta de sucesso passa a vir em `data`; `GET /expenses` perde `nextCursor` do
  corpo de itens em favor de `meta.pagination`/`links`.
- `identity-http-api`: toda resposta de sucesso (`sign-up`, `sign-in`, `persons/me` e seus sub-recursos)
  passa a vir em `data`.

## Impact

- **Código afetado**: `core/infrastructure/http/responses/` (novo envelope reutilizável para `data`, reforma
  de `ErrorResponse`/`FieldErrorResponse` em item de array, `ErrorResponses.kt` — `badRequest`,
  `unprocessable`, `internalError`, `unauthorized`); todos os controllers de `identity` e `expense`
  (`AuthenticationController`, `PersonController`, `ExpenseController`) e seus mappers de resposta
  (`*ResponseMapper.kt`); `ExpensePageResponse` (perde `nextCursor` do corpo, ganha `meta`/`links`); as
  interfaces `*ControllerDoc` (schemas OpenAPI).
- **Documentos**: ADR 0008 é superada por uma nova ADR (o formato de erro estrutural muda de objeto para
  array); README/specs de `http-error-handling`, `expense-http-api`, `identity-http-api` recebem delta.
- **Consumidores**: qualquer client existente que leia o corpo cru (sem `data`) ou o `ErrorResponse` como
  objeto único quebra — é uma mudança de contrato, não aditiva.
- **Testes**: cobertura nova para o envelope de sucesso (item único e coleção paginada) e de erro (escalar
  e por campo, múltiplos itens) nos dois bounded contexts existentes.
