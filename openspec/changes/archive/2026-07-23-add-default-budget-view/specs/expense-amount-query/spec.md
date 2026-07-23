## MODIFIED Requirements

### Requirement: expense expõe somas agregadas por pessoa, nunca gastos individuais

O sistema SHALL expor, na aplicação de `expense`, dois pontos de leitura agregada para consumo por outros
contextos:

1. Dado um `personId` e um intervalo de datas `[startDate, endDate]` (ambos incluídos), a soma, em
   centavos, de todos os gastos daquela pessoa cuja data cai dentro do intervalo.
2. Dado apenas um `personId`, a soma, em centavos, de **todos** os gastos daquela pessoa, sem nenhum
   limite de intervalo.

Essas operações SHALL ser as **únicas** perguntas que `expense` responde sobre os próprios dados a quem
está de fora — nunca um gasto individual, nunca a lista deles. Ambas as somas SHALL ser resolvidas
inteiramente no banco de dados (agregação SQL), nunca carregando gastos individuais para somar em memória
na aplicação.

#### Scenario: Soma por intervalo reflete os gastos da pessoa dentro do intervalo

- **WHEN** a soma por intervalo é pedida para uma pessoa com gastos cuja data cai dentro do intervalo dado
- **THEN** o resultado é a soma exata, em centavos, desses gastos
- **AND** gastos daquela pessoa com data fora do intervalo não entram na soma
- **AND** gastos de qualquer outra pessoa nunca entram na soma

#### Scenario: Sem gastos no intervalo, a soma por intervalo é zero

- **WHEN** a pessoa não tem nenhum gasto com data dentro do intervalo dado
- **THEN** o resultado é `0`
- **AND** nenhum erro é produzido — zero é uma resposta válida, não uma falha

#### Scenario: Soma total reflete todos os gastos da pessoa, sem limite de intervalo

- **WHEN** a soma total é pedida para uma pessoa com gastos registrados em qualquer data
- **THEN** o resultado é a soma exata, em centavos, de todos os gastos dessa pessoa
- **AND** gastos de qualquer outra pessoa nunca entram na soma

#### Scenario: Sem nenhum gasto registrado, a soma total é zero

- **WHEN** a pessoa não tem nenhum gasto registrado
- **THEN** o resultado é `0`
- **AND** nenhum erro é produzido — zero é uma resposta válida, não uma falha
