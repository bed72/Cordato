# budget-create Specification

## Purpose
TBD - created by archiving change add-budget-create. Update Purpose after archive.
## Requirements
### Requirement: Criação cria um orçamento do ator autenticado

O sistema SHALL permitir criar um novo orçamento a partir de um valor, uma data de início, uma data de
fim e uma anotação opcional. O orçamento criado SHALL pertencer a **exatamente uma pessoa** — o ator
autenticado que fez a requisição — e uma pessoa SHALL NOT criar orçamento em nome de outra: a identidade
do dono vem sempre do ator autenticado, nunca do corpo da requisição. Quando as entradas forem válidas e
não houver sobreposição com outro orçamento vivo da mesma pessoa, o sistema SHALL criar um `Budget` com um
identificador único, no estado **vivo**, e SHALL persisti-lo, retornando um resultado de sucesso contendo
o orçamento criado.

#### Scenario: Criação bem-sucedida com todos os campos

- **WHEN** a criação recebe um valor válido (> 0), um intervalo de datas válido (fim ≥ início) sem
  sobreposição com outro orçamento vivo da pessoa, e uma anotação não-vazia, de um ator autenticado
- **THEN** o sistema cria um `Budget` com um identificador único, pertencente ao ator autenticado, no
  estado vivo
- **AND** persiste o orçamento
- **AND** retorna um resultado de sucesso contendo o orçamento criado

#### Scenario: O dono vem do ator, nunca do corpo

- **WHEN** a criação é processada para um ator autenticado
- **THEN** o `Budget` criado pertence ao identificador do ator autenticado
- **AND** nenhum identificador de pessoa presente no corpo da requisição influencia o dono do orçamento

### Requirement: Valor do orçamento é exato e maior que zero

O sistema SHALL representar o valor do orçamento como um número exato de centavos (inteiro), nunca como
ponto flutuante, reutilizando a mesma representação de dinheiro do restante do sistema. O valor SHALL ser
sempre **maior que zero**: um valor zero ou negativo SHALL ser recusado como erro de domínio, e nenhum
orçamento SHALL ser persistido nesse caso.

#### Scenario: Valor zero é recusado

- **WHEN** a criação recebe um valor igual a zero
- **THEN** o sistema retorna um erro de domínio de valor inválido
- **AND** não persiste nenhum orçamento

#### Scenario: Valor negativo é recusado

- **WHEN** a criação recebe um valor menor que zero
- **THEN** o sistema retorna um erro de domínio de valor inválido
- **AND** não persiste nenhum orçamento

#### Scenario: Valor positivo é aceito

- **WHEN** a criação recebe um valor maior que zero (em centavos)
- **THEN** o valor é aceito como o valor exato do orçamento

### Requirement: Intervalo de datas tem início e fim, ambos incluídos, fim nunca antes do início

O orçamento SHALL ter uma data de início e uma data de fim, ambas **incluídas** no intervalo, sem hora
envolvida. A data de fim SHALL NOT ser anterior à data de início: um intervalo em que o fim vem antes do
início SHALL ser recusado como erro de domínio, e nenhum orçamento SHALL ser persistido nesse caso. Um
intervalo de um único dia (início igual ao fim) SHALL ser válido.

#### Scenario: Intervalo com fim antes do início é recusado

- **WHEN** a criação recebe uma data de fim anterior à data de início
- **THEN** o sistema retorna um erro de domínio de intervalo inválido
- **AND** não persiste nenhum orçamento

#### Scenario: Intervalo de um único dia é aceito

- **WHEN** a criação recebe a mesma data para início e fim
- **THEN** o intervalo é aceito como válido

#### Scenario: Intervalo com fim após o início é aceito

- **WHEN** a criação recebe uma data de fim posterior à data de início
- **THEN** o intervalo é aceito como válido

### Requirement: Anotação é opcional, aparada e limitada

A anotação do orçamento SHALL ser opcional. Quando informada, o sistema SHALL apará-la (trim); se após o
trim ela ficar vazia, o sistema SHALL tratá-la como **ausente** (sem anotação). Uma anotação presente
SHALL NOT exceder o comprimento máximo definido; uma anotação que o exceda SHALL ser recusada como erro de
domínio, e nenhum orçamento SHALL ser persistido nesse caso.

#### Scenario: Sem anotação é válido

- **WHEN** a criação é recebida sem anotação (ou com uma anotação vazia/só espaços)
- **THEN** o orçamento é criado sem anotação

#### Scenario: Anotação é aparada

- **WHEN** a criação recebe uma anotação com espaços nas bordas
- **THEN** o orçamento é criado com a anotação aparada

#### Scenario: Anotação longa demais é recusada

- **WHEN** a criação recebe uma anotação que excede o comprimento máximo
- **THEN** o sistema retorna um erro de domínio de anotação inválida
- **AND** não persiste nenhum orçamento

### Requirement: Não-sobreposição entre orçamentos vivos da mesma pessoa

O sistema SHALL impor que a mesma pessoa nunca tenha dois orçamentos **vivos** cujos intervalos
compartilhem sequer um único dia, incluindo dias de fronteira: um orçamento que termina em uma data e
outro que também começa nessa mesma data SHALL ser considerado sobreposto; um orçamento que termina em uma
data e outro que começa no dia seguinte SHALL NOT ser considerado sobreposto. Orçamentos de pessoas
diferentes SHALL NOT ser comparados entre si — a invariante é sempre por pessoa. Um orçamento que não está
mais vivo (removido) SHALL NOT contar para esta checagem. Uma tentativa de criação cujo intervalo se
sobreponha a outro orçamento vivo da mesma pessoa SHALL ser recusada como erro de domínio, e nenhum
orçamento SHALL ser persistido nesse caso.

#### Scenario: Sobreposição de fronteira é recusada

- **WHEN** a pessoa já tem um orçamento vivo terminando em uma data **D**, e a criação recebe um novo
  intervalo que também começa em **D**
- **THEN** o sistema retorna um erro de domínio de sobreposição
- **AND** não persiste nenhum orçamento

#### Scenario: Intervalos adjacentes sem sobreposição são aceitos

- **WHEN** a pessoa já tem um orçamento vivo terminando em uma data **D**, e a criação recebe um novo
  intervalo que começa em **D+1**
- **THEN** o orçamento é criado normalmente, sem erro

#### Scenario: Sobreposição só é checada entre orçamentos vivos

- **WHEN** a pessoa tem um orçamento **removido** cujo intervalo se sobreporia ao novo, mas nenhum
  orçamento vivo sobreposto
- **THEN** o orçamento é criado normalmente, sem erro

#### Scenario: Orçamentos de pessoas diferentes nunca competem

- **WHEN** duas pessoas diferentes têm orçamentos com intervalos idênticos ou sobrepostos entre si
- **THEN** a criação de qualquer um dos dois orçamentos não é afetada pelo orçamento da outra pessoa

### Requirement: Orçamento nunca referencia gastos

O sistema SHALL criar o orçamento apenas com os dados intrínsecos ao teto planejado — dono, valor,
intervalo de datas e anotação opcional. O `Budget` SHALL NOT conter nenhuma referência a gastos, em nenhum
sentido, nem valores derivados (quanto foi gasto, quanto resta). Criar um orçamento SHALL NOT consultar,
exigir ou alterar qualquer gasto existente.

#### Scenario: Orçamento criado não carrega vínculo a gastos

- **WHEN** um orçamento é criado com sucesso
- **THEN** o orçamento contém apenas dono, valor, intervalo de datas, anotação opcional e estado (vivo)
- **AND** não contém nenhuma referência a gastos nem valores derivados de gasto
