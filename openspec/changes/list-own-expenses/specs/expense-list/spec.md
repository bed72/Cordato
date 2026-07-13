# expense-list

## Purpose

A leitura da lista dos próprios gastos do ator autenticado no contexto `expense`. Cobre o recorte de
propriedade (só os gastos do dono, nunca os de outra pessoa), a ordenação determinística (data
decrescente com desempate estável), o caso da pessoa sem nenhum gasto (lista vazia, não erro) e a visão
pública de cada item — sem qualquer vínculo a orçamento. É o lado de leitura que fecha o loop do registro
(`expense-create`) e a base de consulta que outros contextos derivam depois.

## ADDED Requirements

### Requirement: Listar retorna os gastos do ator autenticado

O sistema SHALL permitir listar os gastos de uma pessoa, retornando **todos e somente** os gastos cujo
dono é o **ator autenticado** que fez a requisição. A identidade do dono consultado SHALL vir sempre do
ator autenticado — nunca de um parâmetro, filtro ou corpo da requisição —, de modo que uma pessoa SHALL
NOT conseguir listar os gastos de outra. Cada gasto retornado SHALL expor apenas o fato bruto (dono,
valor exato em centavos, data, descrição opcional) e SHALL NOT conter nenhuma referência a um orçamento.

#### Scenario: Lista contém apenas os gastos do dono

- **WHEN** um ator autenticado com gastos registrados lista seus gastos
- **THEN** o sistema retorna exatamente os gastos cujo dono é aquele ator
- **AND** nenhum gasto pertencente a outra pessoa aparece na lista

#### Scenario: O dono consultado vem do ator, nunca da requisição

- **WHEN** a listagem é processada para um ator autenticado
- **THEN** o conjunto retornado é o dos gastos do identificador do ator autenticado
- **AND** nenhum identificador de pessoa presente em parâmetro/filtro/corpo influencia quais gastos são listados

#### Scenario: Cada item não carrega vínculo a orçamento

- **WHEN** a lista de gastos é retornada
- **THEN** cada item contém apenas dono, valor, data e descrição opcional
- **AND** nenhum item contém referência a um orçamento

### Requirement: A lista é ordenada de forma determinística

O sistema SHALL retornar os gastos em uma ordem **determinística e estável**: por data do gasto
(`spent_on`) em ordem **decrescente** — o gasto que aconteceu mais recentemente primeiro — e, para gastos
de mesma data, com um desempate estável por identificador, de forma que a mesma consulta sobre os mesmos
dados SHALL sempre produzir a mesma ordem.

#### Scenario: Gasto mais recente primeiro

- **WHEN** um ator possui gastos em datas diferentes
- **THEN** a lista vem ordenada pela data do gasto em ordem decrescente (mais recente primeiro)

#### Scenario: Ordem estável para gastos de mesma data

- **WHEN** um ator possui mais de um gasto na mesma data
- **THEN** esses gastos vêm em uma ordem determinística e estável (desempate por identificador)
- **AND** a mesma consulta sobre os mesmos dados produz sempre a mesma ordem

### Requirement: Pessoa sem gastos recebe uma lista vazia

O sistema SHALL tratar a ausência de gastos como um resultado normal: uma pessoa que não possui nenhum
gasto registrado SHALL receber uma **lista vazia**, e isso SHALL NOT ser um erro nem uma condição de
"não encontrado". Listar os próprios gastos não tem ramo de falha de domínio — sempre sucede, com zero ou
mais itens.

#### Scenario: Nenhum gasto retorna lista vazia

- **WHEN** um ator autenticado sem nenhum gasto registrado lista seus gastos
- **THEN** o sistema retorna uma lista vazia
- **AND** não sinaliza erro nem "não encontrado"
