## ADDED Requirements

### Requirement: Documento declara autenticação Bearer e marca rotas protegidas

O documento OpenAPI gerado SHALL declarar um **security scheme HTTP Bearer** (esquema `http`, formato
`bearer`) como metadado global, junto do restante do metadado do documento (`core`), e cada operação
protegida por `@Authenticated` SHALL referenciar esse esquema em sua documentação, de modo que o Swagger UI
exiba o requisito de autenticação (o "cadeado") e permita enviar o token. As rotas abertas (sign-up,
sign-in) SHALL NOT referenciar o esquema. Como o restante da documentação de rota, a marcação de segurança
SHALL viver na interface `<Controller>Doc`, não no controller.

#### Scenario: Rota protegida documenta o requisito de autenticação

- **WHEN** o documento é gerado para uma rota `@Authenticated` (ex.: `GET /persons/me`)
- **THEN** a operação referencia o security scheme Bearer declarado no documento
- **AND** o Swagger UI exibe o requisito de autenticação para essa rota

#### Scenario: Rotas abertas não exigem autenticação no documento

- **WHEN** o documento é gerado para uma rota aberta (sign-up, sign-in)
- **THEN** a operação não referencia o security scheme Bearer
