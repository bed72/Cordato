## ADDED Requirements

### Requirement: Limite geral por IP em toda rota

O sistema SHALL limitar, por IP de origem, o número de requisições aceitas em toda rota dentro de uma
janela fixa configurável. Quando uma requisição excede esse limite geral, o sistema SHALL responder
`429 Too Many Requests` antes de invocar a lógica da rota, para qualquer rota — protegida ou aberta.

#### Scenario: Requisição dentro do limite geral prossegue

- **WHEN** um IP faz uma requisição a qualquer rota e ainda não excedeu o limite geral da janela atual
- **THEN** a requisição prossegue normalmente para a lógica da rota

#### Scenario: Requisição além do limite geral é recusada

- **WHEN** um IP já excedeu o limite geral de requisições na janela atual
- **THEN** o sistema responde `429 Too Many Requests` sem invocar a lógica da rota

### Requirement: Limite apertado adicional para rotas sem `@Authenticated`

O sistema SHALL aplicar, além do limite geral, um segundo limite — mais apertado — por IP, específico para
qualquer rota que não carregue a anotação `@Authenticated`. Essa classificação SHALL reaproveitar a mesma
resolução de rota que decide se `@Authenticated` está presente, sem depender de uma lista de paths mantida
separadamente. Uma rota `@Authenticated` SHALL NOT ser sujeita a esse segundo limite, apenas ao geral.

#### Scenario: Rota sem @Authenticated é sujeita ao limite apertado

- **WHEN** um IP faz requisições a uma rota que não carrega `@Authenticated` (ex.: `POST /sign-up`,
  `POST /sign-in`) além do limite apertado da janela atual
- **THEN** o sistema responde `429 Too Many Requests`, mesmo que o limite geral ainda não tenha sido
  atingido

#### Scenario: Rota autenticada não é sujeita ao limite apertado

- **WHEN** um IP faz requisições a uma rota `@Authenticated` acima do que seria o limite apertado, mas
  ainda dentro do limite geral
- **THEN** a requisição prossegue normalmente, já que apenas o limite geral se aplica a rotas autenticadas

#### Scenario: Uma rota aberta nova herda o limite apertado automaticamente

- **WHEN** uma rota nova é adicionada sem a anotação `@Authenticated`
- **THEN** ela é sujeita ao limite apertado sem exigir nenhuma configuração adicional de path

### Requirement: Contagem em janela fixa por IP e nível

O sistema SHALL contar requisições por IP em uma janela de tempo fixa e configurável (contagem máxima e
duração da janela, independentes para o nível geral e para o nível apertado), via um contador atômico que
expira sozinho ao final da janela. Os contadores dos dois níveis SHALL ser independentes entre si — nenhum
consome a contagem do outro.

#### Scenario: Contador expira ao final da janela

- **WHEN** a janela de contagem de um IP termina
- **THEN** a próxima requisição desse IP inicia um novo contador do zero

#### Scenario: Contadores dos dois níveis não interferem entre si

- **WHEN** um IP acumula requisições contra o limite apertado (rota sem `@Authenticated`)
- **THEN** essas requisições também contam para o limite geral do mesmo IP
- **AND** o inverso não ocorre: requisições a rotas autenticadas não contam para o limite apertado

### Requirement: Recusa por limite de taxa é neutra e não distingue o nível excedido

Quando qualquer um dos dois limites é excedido, o sistema SHALL responder `429 Too Many Requests` no
envelope `errors` compartilhado (capability `http-response-envelope`), com um único item escalar de `code`
e `message` estáveis, mais o header `Retry-After` indicando os segundos restantes até a janela atual
expirar. O corpo e o `code` da resposta SHALL NOT distinguir se foi o limite geral ou o limite apertado que
foi excedido — apenas o valor de `Retry-After` pode variar.

#### Scenario: Excesso do limite geral responde 429 com Retry-After

- **WHEN** o limite geral de um IP é excedido
- **THEN** o sistema responde `429 Too Many Requests` com um único item escalar no envelope `errors` e o
  header `Retry-After`

#### Scenario: Excesso do limite apertado responde com o mesmo corpo do limite geral

- **WHEN** o limite apertado de um IP (rota sem `@Authenticated`) é excedido
- **THEN** a resposta tem o mesmo status, `code` e `message` que a recusa por limite geral
- **AND** apenas o valor de `Retry-After` pode diferir entre os dois casos

### Requirement: Limites configuráveis externamente

O sistema SHALL ler a contagem máxima e a duração da janela de cada nível (geral e apertado) de
configuração externa, nunca de um literal no código.

#### Scenario: Limite é lido de configuração

- **WHEN** o contexto de aplicação sobe
- **THEN** a contagem máxima e a duração da janela de cada nível vêm de `application.properties`, não de
  um valor fixo no código-fonte
