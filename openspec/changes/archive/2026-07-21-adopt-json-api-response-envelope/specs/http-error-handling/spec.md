## MODIFIED Requirements

### Requirement: Corpo de erro único e compartilhado

O sistema SHALL expor um único tipo de corpo de erro, compartilhado por toda borda HTTP, na forma do
envelope `errors` definido pela capability `http-response-envelope`: um array de um ou mais itens, cada um
com um `code` estável legível por máquina e uma `message` legível por humano. Um item SHALL carregar
`source.field` apenas quando a falha é atribuível a um campo específico do request; falhas escalares (recusa
de domínio, corpo malformado, erro interno, autenticação) SHALL produzir um array com exatamente **um**
item, sem `source`. Esse contrato SHALL residir no núcleo compartilhado (`core`), não em um contexto
específico, e todo caminho de falha HTTP — validação de borda, corpo malformado, recusa de domínio e falha
inesperada — SHALL responder nesse mesmo shape.

#### Scenario: Falha escalar produz um único item sem source

- **WHEN** uma falha não é atribuível a campos específicos (recusa de domínio, corpo malformado, erro interno)
- **THEN** o corpo de erro é `{ "errors": [...] }` com exatamente um item
- **AND** esse item carrega `code` e `message`, sem a propriedade `source`

#### Scenario: O contrato é compartilhado, não específico de um contexto

- **WHEN** qualquer borda HTTP do sistema precisa renderizar uma falha
- **THEN** ela usa o mesmo envelope `errors` definido no núcleo compartilhado
- **AND** nenhum contexto redefine um shape de erro próprio

### Requirement: Violação de validação de borda responde 400 por campo

O sistema SHALL tratar uma falha de Bean Validation na borda como `400 Bad Request` no envelope `errors`
compartilhado, substituindo o corpo default do framework. Quando mais de um campo viola suas restrições, o
array `errors` SHALL listar **cada** campo violado como um item, com `source.field` identificando o campo
(o nó final do caminho, sem expor a forma interna do método ou do argumento) e `message` como o texto
curado da restrição, em vez de concatenar as mensagens em uma única string ou em um único item.

#### Scenario: Violação de um único campo

- **WHEN** exatamente um campo do corpo viola uma restrição de borda
- **THEN** o sistema responde `400 Bad Request` no envelope `errors`
- **AND** `errors` contém um item, com `source.field` igual ao nome do campo violado e `message` curada

#### Scenario: Violações de múltiplos campos são reportadas cada uma

- **WHEN** dois ou mais campos do corpo violam suas restrições na mesma requisição
- **THEN** o sistema responde `400 Bad Request`
- **AND** `errors` contém um item por campo violado, cada um com seu `source.field` e sua `message`
- **AND** as mensagens não são coladas em um único item nem em uma única string

#### Scenario: O nome do campo não expõe a forma interna

- **WHEN** uma violação é serializada para um item de `errors`
- **THEN** `source.field` é o nome do campo do request (ex.: `email`), não o caminho interno do método/argumento

### Requirement: Corpo malformado ou ausente responde 400

O sistema SHALL tratar uma requisição com corpo ausente ou JSON inválido/não-parseável como `400 Bad
Request` no envelope `errors` compartilhado, antes de qualquer lógica de domínio, com um único item escalar
(mensagem genérica, sem `source`). A resposta SHALL NOT cair no corpo default do framework.

#### Scenario: JSON inválido

- **WHEN** o endpoint recebe um corpo que não é JSON válido
- **THEN** o sistema responde `400 Bad Request` no envelope `errors` com um único item e mensagem genérica
- **AND** nenhuma lógica de domínio é executada

#### Scenario: Corpo ausente

- **WHEN** o endpoint que exige corpo recebe uma requisição sem corpo
- **THEN** o sistema responde `400 Bad Request` no envelope `errors` compartilhado

### Requirement: Falha inesperada responde 500 neutro sem vazar detalhe

O sistema SHALL tratar qualquer exceção não capturada por um handler mais específico como `500 Internal
Server Error` no envelope `errors` compartilhado, com um único item escalar (`code` estável, `message`
genérica fixa, sem `source`). A resposta SHALL NOT conter a mensagem da exceção, o stacktrace, nem qualquer
detalhe interno (SQL, caminho, tipo). O detalhe SHALL ser registrado apenas no log do servidor, respeitando
a invariante de não-vazamento.

#### Scenario: Exceção inesperada não vaza detalhe

- **WHEN** uma exceção não tratada é lançada durante o atendimento de uma requisição
- **THEN** o sistema responde `500 Internal Server Error` no envelope `errors` com um único item e mensagem genérica
- **AND** o item não contém a mensagem da exceção nem o stacktrace
- **AND** o detalhe da exceção é registrado no log do servidor

#### Scenario: O fallback não engole falhas já tratadas

- **WHEN** uma falha tem um handler mais específico (validação, corpo malformado, recusa de domínio)
- **THEN** o handler específico responde
- **AND** o fallback `500` não é acionado para essa falha

### Requirement: Rejeição de autenticação responde 401 neutro compartilhado

O sistema SHALL prover, no envelope `errors` compartilhado do `core`, uma forma de rejeição de autenticação
`401`, via um builder `unauthorized(code, message)` (irmão de `unprocessable`/`badRequest`) que produz um
array com **um** item. Esse item SHALL ser escalar (um `code` estável `UNAUTHENTICATED`, uma `message`
genérica, sem `source`) e a resposta SHALL NOT incluir o header `WWW-Authenticate`. Toda falha de
autenticação — credenciais de login inválidas ou rota protegida acessada sem sessão viva — SHALL resolver
nessa **mesma** resposta, de modo que nem o corpo, nem o code, nem o status distingam a causa.

#### Scenario: Falha de autenticação usa o 401 neutro

- **WHEN** uma borda precisa recusar por autenticação (login inválido ou rota protegida sem sessão)
- **THEN** o sistema responde `401` no envelope `errors` com um único item, code `UNAUTHENTICATED` e mensagem genérica
- **AND** esse item não carrega `source`

#### Scenario: O 401 não carrega WWW-Authenticate nem detalhe da causa

- **WHEN** o sistema serializa uma rejeição de autenticação
- **THEN** a resposta não inclui o header `WWW-Authenticate`
- **AND** a mensagem não revela se o e-mail existe, se a senha falhou, ou se a sessão expirou/foi revogada

#### Scenario: Login inválido e rota protegida sem sessão são indistinguíveis

- **WHEN** o login recusa por `InvalidCredentials` e, separadamente, uma rota protegida é acessada sem sessão viva
- **THEN** ambas respondem `401` com o mesmo code `UNAUTHENTICATED` e o mesmo item escalar no envelope `errors`
