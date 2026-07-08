# openapi-documentation Specification

## Purpose
TBD - created by archiving change add-http-i18n-and-openapi. Update Purpose after archive.
## Requirements
### Requirement: Documento OpenAPI gerado em compile-time

O sistema SHALL gerar um documento OpenAPI descrevendo a API HTTP durante a **compilação**, sem introduzir
reflection em runtime, de forma coerente com o restante da stack (Serde, validação e DI, todos em
compile-time). O documento gerado SHALL refletir as rotas registradas e seus corpos de requisição/resposta.

#### Scenario: O spec é produzido no build

- **WHEN** o projeto é compilado
- **THEN** um documento OpenAPI descrevendo as rotas existentes é gerado como artefato de build

#### Scenario: Sem reflection em runtime

- **WHEN** a documentação OpenAPI é produzida
- **THEN** ela é derivada em compile-time, sem varredura por reflection em tempo de execução

### Requirement: Swagger UI exposta

O sistema SHALL expor uma UI navegável (Swagger UI) que serve o documento OpenAPI gerado, permitindo a um
consumidor descobrir e inspecionar os endpoints da API.

#### Scenario: A UI serve o documento gerado

- **WHEN** um consumidor acessa a rota da Swagger UI
- **THEN** a UI carrega e apresenta o documento OpenAPI gerado, listando os endpoints disponíveis

### Requirement: Anotações OpenAPI vivem numa interface de documentação

O sistema SHALL manter as anotações de documentação OpenAPI (descrição da operação e das respostas) numa
**interface de documentação** dedicada — nomeada `<Controller>Doc` e colocada junto ao controller na
camada de infraestrutura HTTP — que o controller **implementa**. O controller SHALL permanecer enxuto,
carregando apenas as anotações de roteamento/validação e a lógica de delegação ao use case, sem as
anotações de documentação. A documentação declarada na interface SHALL ser refletida no documento OpenAPI
gerado para a rota implementada.

Essa interface é um artefato de **documentação de infraestrutura**, não um port de aplicação: ela SHALL
NOT introduzir um contrato de camada de aplicação para o lado driving nem duplicar a assinatura pública do
use case como um port.

#### Scenario: A documentação fica na interface, não no controller

- **WHEN** um endpoint é documentado
- **THEN** as anotações OpenAPI (operação e respostas) ficam na interface `<Controller>Doc`
- **AND** o controller apenas a implementa, mantendo só roteamento/validação e a delegação ao use case

#### Scenario: A documentação da interface aparece no spec gerado

- **WHEN** o documento OpenAPI é gerado para uma rota cujo controller implementa a interface de documentação
- **THEN** a descrição da operação e das respostas declaradas na interface aparece no documento

#### Scenario: A interface não é um port de aplicação

- **WHEN** a interface de documentação é definida
- **THEN** ela reside na camada de infraestrutura HTTP, junto ao controller
- **AND** não introduz um port na camada de aplicação nem duplica a assinatura do use case


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
