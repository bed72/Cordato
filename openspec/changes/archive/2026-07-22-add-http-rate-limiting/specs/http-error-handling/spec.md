## ADDED Requirements

### Requirement: Limite de taxa excedido responde 429 neutro com Retry-After

O sistema SHALL prover, no envelope `errors` compartilhado do `core`, uma forma de recusa por limite de
taxa `429 Too Many Requests`, via um builder `tooManyRequests(code, message, retryAfter)` (irmão de
`unauthorized`/`unprocessable`/`badRequest`) que produz um array com **um** item. Esse item SHALL ser
escalar (um `code` estável `RATE_LIMITED`, uma `message` genérica, sem `source`), e a resposta SHALL incluir
o header `Retry-After` com os segundos restantes até a janela de limite atual expirar. Toda recusa por
limite de taxa — independentemente de qual regra de limite foi excedida — SHALL resolver nessa mesma
resposta, de modo que nem o corpo nem o `code` distingam a causa; apenas `Retry-After` pode variar.

#### Scenario: Limite de taxa excedido usa o 429 neutro

- **WHEN** uma requisição excede um limite de taxa configurado
- **THEN** o sistema responde `429` no envelope `errors` com um único item, code `RATE_LIMITED` e mensagem
  genérica
- **AND** esse item não carrega `source`
- **AND** a resposta inclui o header `Retry-After`

#### Scenario: Recusas por regras de limite diferentes são indistinguíveis no corpo

- **WHEN** duas requisições são recusadas por regras de limite de taxa diferentes (por exemplo, um limite
  geral e um limite mais apertado de uma rota específica)
- **THEN** ambas respondem `429` com o mesmo code `RATE_LIMITED` e o mesmo item escalar no envelope `errors`
- **AND** apenas o valor do header `Retry-After` pode diferir entre as duas respostas
