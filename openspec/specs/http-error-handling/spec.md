# http-error-handling

## Purpose

O contrato de erro HTTP compartilhado por toda borda do sistema: um único shape de corpo (`ErrorResponse`,
com uma lista opcional de erros por campo) e os handlers genéricos que o produzem — violação de Bean
Validation → `400` por campo, corpo malformado/ausente → `400` escalar, e qualquer falha inesperada → `500`
neutro e logado. Sendo cross-cutting (nenhum contexto o conhece), reside no núcleo compartilhado (`core`),
e garante que todo caminho de falha HTTP responda no mesmo formato, sem vazar detalhe interno.
## Requirements
### Requirement: Corpo de erro único e compartilhado

O sistema SHALL expor um único tipo de corpo de erro, compartilhado por toda borda HTTP, com um `code`
estável legível por máquina e uma `message` legível por humano. O corpo SHALL suportar uma lista opcional
de erros por campo (`errors`, cada item com `field` e `message`), vazia ou omitida quando a falha não é
por campo. Esse contrato SHALL residir no núcleo compartilhado (`core`), não em um contexto específico, e
todo caminho de falha HTTP — validação de borda, corpo malformado, recusa de domínio e falha inesperada —
SHALL responder nesse mesmo shape.

#### Scenario: Falha escalar omite a lista de campos

- **WHEN** uma falha não é atribuível a campos específicos (recusa de domínio, corpo malformado, erro interno)
- **THEN** o corpo de erro carrega `code` e `message`
- **AND** a lista `errors` está vazia ou ausente

#### Scenario: O contrato é compartilhado, não específico de um contexto

- **WHEN** qualquer borda HTTP do sistema precisa renderizar uma falha
- **THEN** ela usa o mesmo tipo de corpo de erro definido no núcleo compartilhado
- **AND** nenhum contexto redefine um shape de erro próprio

### Requirement: Violação de validação de borda responde 400 por campo

O sistema SHALL tratar uma falha de Bean Validation na borda como `400 Bad Request` no corpo de erro
compartilhado, substituindo o corpo default do framework. Quando mais de um campo viola suas restrições, o
corpo SHALL listar **cada** campo violado como um item de `errors` (`field` + `message`), em vez de
concatenar as mensagens em uma única string. Cada `field` SHALL identificar o campo do request (o nó final
do caminho), sem expor a forma interna do método ou do argumento. Cada `message` SHALL ser o texto curado
da restrição, sem vazar padrão bruto ou detalhe interno.

#### Scenario: Violação de um único campo

- **WHEN** exatamente um campo do corpo viola uma restrição de borda
- **THEN** o sistema responde `400 Bad Request` no corpo compartilhado
- **AND** `errors` contém um item, com o nome do campo violado e a mensagem curada

#### Scenario: Violações de múltiplos campos são reportadas cada uma

- **WHEN** dois ou mais campos do corpo violam suas restrições na mesma requisição
- **THEN** o sistema responde `400 Bad Request`
- **AND** `errors` contém um item por campo violado, cada um com seu `field` e sua `message`
- **AND** as mensagens não são coladas em um único campo `message`

#### Scenario: O nome do campo não expõe a forma interna

- **WHEN** uma violação é serializada para um item de `errors`
- **THEN** `field` é o nome do campo do request (ex.: `email`), não o caminho interno do método/argumento

### Requirement: Corpo malformado ou ausente responde 400

O sistema SHALL tratar uma requisição com corpo ausente ou JSON inválido/não-parseável como `400 Bad
Request` no corpo de erro compartilhado, antes de qualquer lógica de domínio, com uma mensagem genérica e
`errors` vazia. A resposta SHALL NOT cair no corpo default do framework.

#### Scenario: JSON inválido

- **WHEN** o endpoint recebe um corpo que não é JSON válido
- **THEN** o sistema responde `400 Bad Request` no corpo compartilhado, com mensagem genérica
- **AND** nenhuma lógica de domínio é executada

#### Scenario: Corpo ausente

- **WHEN** o endpoint que exige corpo recebe uma requisição sem corpo
- **THEN** o sistema responde `400 Bad Request` no corpo compartilhado

### Requirement: Falha inesperada responde 500 neutro sem vazar detalhe

O sistema SHALL tratar qualquer exceção não capturada por um handler mais específico como `500 Internal
Server Error` no corpo de erro compartilhado, com um `code` estável e uma `message` genérica fixa. A
resposta SHALL NOT conter a mensagem da exceção, o stacktrace, nem qualquer detalhe interno (SQL, caminho,
tipo). O detalhe SHALL ser registrado apenas no log do servidor, respeitando a invariante de não-vazamento.

#### Scenario: Exceção inesperada não vaza detalhe

- **WHEN** uma exceção não tratada é lançada durante o atendimento de uma requisição
- **THEN** o sistema responde `500 Internal Server Error` no corpo compartilhado com mensagem genérica
- **AND** o corpo não contém a mensagem da exceção nem o stacktrace
- **AND** o detalhe da exceção é registrado no log do servidor

#### Scenario: O fallback não engole falhas já tratadas

- **WHEN** uma falha tem um handler mais específico (validação, corpo malformado, recusa de domínio)
- **THEN** o handler específico responde
- **AND** o fallback `500` não é acionado para essa falha

### Requirement: Rejeição de autenticação responde 401 neutro compartilhado

O sistema SHALL prover, no contrato de erro compartilhado do `core`, uma forma de rejeição de autenticação
`401` no mesmo `ErrorResponse` compartilhado, via um builder `unauthorized(code, message)` (irmão de
`unprocessable`/`badRequest`). Essa resposta SHALL ser **escalar** (um `code` estável `UNAUTHENTICATED` e
uma `message` genérica, sem lista de erros por campo) e SHALL NOT incluir o header `WWW-Authenticate`. Toda
falha de autenticação — credenciais de login inválidas ou rota protegida acessada sem sessão viva — SHALL
resolver nessa **mesma** resposta, de modo que nem o corpo, nem o code, nem o status distingam a causa.

#### Scenario: Falha de autenticação usa o 401 neutro

- **WHEN** uma borda precisa recusar por autenticação (login inválido ou rota protegida sem sessão)
- **THEN** o sistema responde `401` no corpo compartilhado com code `UNAUTHENTICATED` e mensagem genérica
- **AND** a resposta é escalar (sem lista de erros por campo)

#### Scenario: O 401 não carrega WWW-Authenticate nem detalhe da causa

- **WHEN** o sistema serializa uma rejeição de autenticação
- **THEN** a resposta não inclui o header `WWW-Authenticate`
- **AND** a mensagem não revela se o e-mail existe, se a senha falhou, ou se a sessão expirou/foi revogada

#### Scenario: Login inválido e rota protegida sem sessão são indistinguíveis

- **WHEN** o login recusa por `InvalidCredentials` e, separadamente, uma rota protegida é acessada sem sessão viva
- **THEN** ambas respondem `401` com o mesmo code `UNAUTHENTICATED` e o mesmo shape neutro

