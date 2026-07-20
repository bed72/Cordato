# expense-list Specification

## Purpose

A leitura **paginada por cursor** da lista dos próprios gastos do ator autenticado no contexto `expense`.
Cobre o recorte de propriedade (só os gastos do dono, nunca os de outra pessoa), a ordenação determinística
`(spent_on desc, id desc)` que serve de base ao cursor, a paginação keyset (uma página de tamanho limitado
mais um cursor para a próxima), o caso da pessoa sem nenhum gasto (página vazia, não erro) e a visão pública
de cada item — sem qualquer vínculo a orçamento. É o lado de leitura que fecha o loop do registro
(`expense-create`) e a base de consulta que outros contextos derivam depois.

## Requirements

### Requirement: Listar retorna os gastos do ator autenticado

O sistema SHALL permitir listar os gastos de uma pessoa, retornando **apenas** os gastos cujo dono é o
**ator autenticado** que fez a requisição. A identidade do dono consultado SHALL vir sempre do ator
autenticado — nunca de um parâmetro, filtro ou corpo da requisição —, de modo que uma pessoa SHALL NOT
conseguir listar os gastos de outra. Cada gasto retornado SHALL expor apenas o fato bruto (dono, valor
exato em centavos, data, descrição opcional) e SHALL NOT conter nenhuma referência a um orçamento.

#### Scenario: Página contém apenas os gastos do dono

- **WHEN** um ator autenticado com gastos registrados lista seus gastos
- **THEN** o sistema retorna apenas gastos cujo dono é aquele ator
- **AND** nenhum gasto pertencente a outra pessoa aparece

#### Scenario: O dono consultado vem do ator, nunca da requisição

- **WHEN** a listagem é processada para um ator autenticado
- **THEN** o conjunto retornado é o dos gastos do identificador do ator autenticado
- **AND** nenhum identificador de pessoa presente em parâmetro/filtro/corpo influencia quais gastos são listados

#### Scenario: Cada item não carrega vínculo a orçamento

- **WHEN** a página de gastos é retornada
- **THEN** cada item contém apenas dono, valor, data e descrição opcional
- **AND** nenhum item contém referência a um orçamento

### Requirement: A listagem é paginada por cursor (keyset)

O sistema SHALL paginar a listagem por **cursor keyset**, nunca por offset. A leitura SHALL aceitar um
**tamanho de página** (`limit`) e um **cursor** opcional que marca a posição após a qual continuar. O
resultado SHALL ser uma **página**: os itens daquela fatia mais um **próximo cursor** que aponta para a
continuação, ou a ausência de próximo cursor quando não há mais itens. O `limit` SHALL ter um **default**
quando ausente e um **teto máximo** que o sistema não ultrapassa. O próximo cursor SHALL derivar da posição
`(spent_on, id)` do último item da página. Passar o próximo cursor de volta SHALL retornar a fatia seguinte
sem repetir nem pular itens sob dados estáveis.

#### Scenario: A primeira página respeita o tamanho pedido e oferece continuação

- **WHEN** um ator possui mais gastos do que o `limit` pedido e lista sem cursor
- **THEN** o sistema retorna os primeiros `limit` gastos na ordem determinística
- **AND** retorna um próximo cursor apontando para a continuação

#### Scenario: Seguir o cursor retorna a próxima fatia sem sobreposição

- **WHEN** o ator lista de novo passando o próximo cursor recebido
- **THEN** o sistema retorna os gastos seguintes àquela posição, sem repetir os já retornados

#### Scenario: A última página não oferece próximo cursor

- **WHEN** a página retornada esgota os gastos do ator
- **THEN** o sistema não retorna próximo cursor (indica o fim)

#### Scenario: O tamanho de página é limitado por um teto

- **WHEN** a listagem é pedida com um `limit` acima do teto máximo permitido
- **THEN** o sistema recusa o pedido no edge (não retorna uma página acima do teto)

### Requirement: A ordem é determinística e é a base do cursor

O sistema SHALL retornar os gastos em uma ordem **determinística e estável**: por data do gasto
(`spent_on`) **decrescente** — o gasto que aconteceu mais recentemente primeiro — e, para gastos de mesma
data, com desempate estável por identificador (`id`) decrescente. Essa mesma dupla `(spent_on, id)` SHALL
ser a base do cursor keyset, de forma que a mesma consulta sobre os mesmos dados SHALL sempre produzir a
mesma ordem e os mesmos limites de página.

#### Scenario: Gasto mais recente primeiro

- **WHEN** um ator possui gastos em datas diferentes
- **THEN** a página vem ordenada pela data do gasto em ordem decrescente (mais recente primeiro)

#### Scenario: Ordem estável para gastos de mesma data

- **WHEN** um ator possui mais de um gasto na mesma data
- **THEN** esses gastos vêm em uma ordem determinística e estável (desempate por identificador)
- **AND** a mesma consulta sobre os mesmos dados produz sempre a mesma ordem e a mesma divisão em páginas

### Requirement: Pessoa sem gastos recebe uma página vazia

O sistema SHALL tratar a ausência de gastos como um resultado normal: uma pessoa que não possui nenhum
gasto registrado (ou cujo cursor já esgotou os gastos) SHALL receber uma **página vazia** — sem itens e sem
próximo cursor —, e isso SHALL NOT ser um erro nem uma condição de "não encontrado". Listar os próprios
gastos não tem ramo de falha de domínio — sempre sucede, com zero ou mais itens.

#### Scenario: Nenhum gasto retorna página vazia

- **WHEN** um ator autenticado sem nenhum gasto registrado lista seus gastos
- **THEN** o sistema retorna uma página vazia (sem itens, sem próximo cursor)
- **AND** não sinaliza erro nem "não encontrado"

### Requirement: A listagem reflete as escritas do dono

O sistema SHALL garantir que a listagem de uma pessoa reflita as mudanças no seu conjunto de gastos: após
o dono registrar (ou, quando existir, editar ou apagar) um gasto, uma nova listagem daquele dono SHALL
refletir a mudança — o mecanismo de cache que serve a leitura SHALL NOT servir uma página obsoleta que
ignore a escrita recém-confirmada do próprio dono.

#### Scenario: Um gasto recém-registrado aparece na listagem do dono

- **WHEN** o dono registra um novo gasto e em seguida lista seus gastos
- **THEN** a listagem reflete o gasto recém-registrado (não uma versão obsoleta anterior à escrita)
