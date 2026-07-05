## Why

O contrato de erro HTTP (`ErrorResponse` + o handler de `ConstraintViolationException`) nasceu dentro de
`identity/infrastructure/http/`, mas não conhece nada de `identity` — é cross-cutting e, pela regra do
projeto, pertence ao `core/`. Além disso o "shape único" hoje tem duas frestas: um corpo malformado/ausente
e qualquer exceção inesperada escapam para o corpo default do Micronaut (`_embedded.errors`), e o handler de
validação **concatena** múltiplas violações numa string só, perdendo qual campo falhou.

## What Changes

- Mover `ErrorResponse` e `ConstraintViolationExceptionHandler` de `identity/infrastructure/http/` para
  `core/infrastructure/http/`. Os `ExceptionHandler` seguem annotation-bearing (`@Singleton`/`@Produces`/
  `@Replaces`), descobertos direto pelo Micronaut — a mesma exceção documentada dos controllers, **sem**
  `@Factory`; `CoreModule` não é tocado. `identity` mantém só o `SignUpErrorResponseMapper`, que conhece
  `SignUpError`.
- **BREAKING (forma do corpo)**: evoluir `ErrorResponse` com uma lista opcional de erros por campo
  (`errors: List<FieldError>`, cada um com `field` + `message`), vazia/omitida nos casos escalares. O path
  `400` (Bean Validation) passa a reportar todos os campos violados de uma vez, em vez de concatenar as
  mensagens.
- Adicionar um handler para corpo malformado/ausente (erro de parse/conversão do Micronaut) → `400` no
  shape compartilhado.
- Adicionar um fallback `ExceptionHandler<Throwable>` → `500` genérico, com o detalhe registrado **apenas no
  log** — nunca ecoando `exception.message` — respeitando a invariante de não-vazamento.
- O `422` de domínio permanece **fail-fast**: um único `SignUpError`, sem acumular. `EmailAlreadyInUse`
  nunca vira um item de `errors` com `field=email` (continuaria confirmando a existência da conta).

## Capabilities

### New Capabilities
- `http-error-handling`: o contrato de erro HTTP compartilhado — o shape `ErrorResponse` (com a lista
  opcional de erros por campo) e os handlers genéricos que o produzem: violação de Bean Validation → `400`
  (por campo), corpo malformado/ausente → `400`, e qualquer exceção inesperada → `500` neutro e logado.

### Modified Capabilities
- `identity-http-api`: a falha de validação de borda passa a reportar **cada** campo violado (via o contrato
  compartilhado), não uma mensagem concatenada; e uma falha inesperada do endpoint passa a responder um
  `500` neutro do `http-error-handling` em vez do corpo default do framework.

## Impact

- **Novo**: `core/infrastructure/http/` (`ErrorResponse`, `FieldError`, `ConstraintViolationExceptionHandler`,
  handler de corpo malformado, fallback `Throwable`) — beans annotation-bearing descobertos direto;
  `CoreModule` intocado.
- **Movido/removido de** `identity/infrastructure/http/errors/`: `ErrorResponse` e
  `ConstraintViolationExceptionHandler` saem; `SignUpErrorResponseMapper` fica e passa a importar o
  `ErrorResponse` do `core`.
- **Testes**: novos testes de unidade dos handlers em `core`; `PersonControllerTest` ajustado para o corpo
  `400` multi-campo; teste do `500` neutro (sem vazar detalhe).
- **Konsist**: `core` não importa `features/*`; `domain`/`application` seguem sem importar Micronaut/HTTP.
- Sem mudança em `domain`/`application` de `identity` — `SignUpUseCase` e `SignUpError` intocados.
