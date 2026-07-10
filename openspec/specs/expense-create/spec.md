# expense-create Specification

## Purpose
TBD - created by archiving change add-expense-create. Update Purpose after archive.
## Requirements
### Requirement: Registro cria um gasto do ator autenticado

O sistema SHALL permitir registrar um novo gasto a partir de um valor, uma data opcional e uma descrição
opcional. O gasto criado SHALL pertencer a **exatamente uma pessoa** — o ator autenticado que fez a
requisição — e uma pessoa SHALL NOT registrar gasto em nome de outra: a identidade do dono vem sempre do
ator autenticado, nunca do corpo da requisição. Quando as entradas forem válidas, o sistema SHALL criar
um `Expense` com um identificador único e SHALL persisti-lo, retornando um resultado de sucesso contendo
o gasto criado.

#### Scenario: Registro bem-sucedido com todos os campos

- **WHEN** o registro recebe um valor válido (> 0), uma data não-futura e uma descrição não-vazia, de um
  ator autenticado
- **THEN** o sistema cria um `Expense` com um identificador único, pertencente ao ator autenticado
- **AND** persiste o gasto
- **AND** retorna um resultado de sucesso contendo o gasto criado

#### Scenario: O dono vem do ator, nunca do corpo

- **WHEN** o registro é processado para um ator autenticado
- **THEN** o `Expense` criado pertence ao identificador do ator autenticado
- **AND** nenhum identificador de pessoa presente no corpo da requisição influencia o dono do gasto

### Requirement: Valor do gasto é exato e maior que zero

O sistema SHALL representar o valor do gasto como um número exato de centavos (inteiro), nunca como ponto
flutuante. O valor SHALL ser sempre **maior que zero**: um valor zero ou negativo SHALL ser recusado como
erro de domínio, e nenhum gasto SHALL ser persistido nesse caso.

#### Scenario: Valor zero é recusado

- **WHEN** o registro recebe um valor igual a zero
- **THEN** o sistema retorna um erro de domínio de valor inválido
- **AND** não persiste nenhum gasto

#### Scenario: Valor negativo é recusado

- **WHEN** o registro recebe um valor menor que zero
- **THEN** o sistema retorna um erro de domínio de valor inválido
- **AND** não persiste nenhum gasto

#### Scenario: Valor positivo é aceito

- **WHEN** o registro recebe um valor maior que zero (em centavos)
- **THEN** o valor é aceito como o valor exato do gasto

### Requirement: Data do gasto é opcional, default hoje, nunca futura

A data do gasto SHALL representar a data em que o gasto **efetivamente aconteceu** no mundo real. A data
SHALL ser opcional na entrada: quando ausente, o sistema SHALL usar a data de criação (a data de **hoje**
segundo o relógio do sistema, via `ClockPort`). Quando informada, a data MAY ser hoje ou qualquer data no
passado, mas SHALL NOT ser posterior a hoje: uma data futura SHALL ser recusada como erro de domínio, e
nenhum gasto SHALL ser persistido nesse caso.

#### Scenario: Data ausente assume hoje

- **WHEN** o registro é recebido sem uma data
- **THEN** o gasto é criado com a data de hoje segundo o relógio do sistema

#### Scenario: Data no passado é aceita

- **WHEN** o registro recebe uma data anterior a hoje
- **THEN** o gasto é criado com exatamente aquela data, independentemente da data de registro

#### Scenario: Data futura é recusada

- **WHEN** o registro recebe uma data posterior a hoje
- **THEN** o sistema retorna um erro de domínio de data inválida
- **AND** não persiste nenhum gasto

### Requirement: Descrição é opcional, aparada e limitada

A descrição do gasto SHALL ser opcional. Quando informada, o sistema SHALL apará-la (trim); se após o
trim ela ficar vazia, o sistema SHALL tratá-la como **ausente** (sem descrição). Uma descrição presente
SHALL NOT exceder o comprimento máximo definido; uma descrição que o exceda SHALL ser recusada como erro
de domínio, e nenhum gasto SHALL ser persistido nesse caso.

#### Scenario: Sem descrição é válido

- **WHEN** o registro é recebido sem descrição (ou com uma descrição vazia/só espaços)
- **THEN** o gasto é criado sem descrição

#### Scenario: Descrição é aparada

- **WHEN** o registro recebe uma descrição com espaços nas bordas
- **THEN** o gasto é criado com a descrição aparada

#### Scenario: Descrição longa demais é recusada

- **WHEN** o registro recebe uma descrição que excede o comprimento máximo
- **THEN** o sistema retorna um erro de domínio de descrição inválida
- **AND** não persiste nenhum gasto

### Requirement: Gasto nunca referencia orçamento

O sistema SHALL registrar apenas o fato bruto do gasto — quem, quanto, quando e (opcionalmente) a
descrição. O `Expense` SHALL NOT conter nenhuma referência a um orçamento, em nenhum sentido. Registrar um
gasto SHALL NOT consultar, exigir ou alterar qualquer orçamento, e um gasto que não caia em nenhum
orçamento vivo de sua pessoa SHALL NOT ser um erro.

#### Scenario: Gasto criado não carrega vínculo a orçamento

- **WHEN** um gasto é registrado com sucesso
- **THEN** o gasto contém apenas dono, valor, data e descrição opcional
- **AND** não contém nenhuma referência a um orçamento

#### Scenario: Registro não depende de existir orçamento

- **WHEN** um gasto é registrado para uma pessoa que não possui nenhum orçamento vivo cobrindo aquela data
- **THEN** o registro é bem-sucedido normalmente, sem erro

