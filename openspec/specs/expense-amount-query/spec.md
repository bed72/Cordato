# expense-amount-query Specification

## Purpose
TBD - created by archiving change add-budget-active-view. Update Purpose after archive.
## Requirements
### Requirement: expense expõe uma soma agregada por pessoa e intervalo de datas, nunca gastos individuais

O sistema SHALL expor, na aplicação de `expense`, um único ponto de leitura agregada para consumo por
outros contextos: dado um `personId` e um intervalo de datas `[startDate, endDate]` (ambos incluídos), SHALL
retornar a soma, em centavos, de todos os gastos daquela pessoa cuja data cai dentro do intervalo. Essa
operação SHALL ser a **única** pergunta que `expense` responde sobre os próprios dados a quem está de fora
— nunca um gasto individual, nunca a lista deles. A soma SHALL ser resolvida inteiramente no banco de dados
(agregação SQL), nunca carregando gastos individuais para somar em memória na aplicação.

#### Scenario: Soma reflete os gastos da pessoa dentro do intervalo

- **WHEN** a soma é pedida para uma pessoa com gastos cuja data cai dentro do intervalo dado
- **THEN** o resultado é a soma exata, em centavos, desses gastos
- **AND** gastos daquela pessoa com data fora do intervalo não entram na soma
- **AND** gastos de qualquer outra pessoa nunca entram na soma

#### Scenario: Sem gastos no intervalo, a soma é zero

- **WHEN** a pessoa não tem nenhum gasto com data dentro do intervalo dado
- **THEN** o resultado é `0`
- **AND** nenhum erro é produzido — zero é uma resposta válida, não uma falha

### Requirement: expense nunca conhece budget nem qualquer outro consumidor desta consulta

O sistema SHALL manter esta consulta agregada como parte da aplicação de `expense`, exposta como o `invoke`
público de um caso de uso — nunca uma exceção que `expense` faça à regra de "não referenciar nenhum outro
contexto". `expense/domain` e `expense/application` SHALL NOT importar nenhum tipo de `budget` ou de
qualquer outro contexto consumidor. Todo consumidor desta consulta (hoje, `budget`) SHALL chamá-la
in-process através do próprio caso de uso público de `expense`, nunca acessando o `ExpenseRepository` ou
qualquer tipo interno de `expense` diretamente — a Anti-Corruption Layer (ADR 0013) é responsabilidade do
consumidor, definida no vocabulário dele.

#### Scenario: expense não importa nada de budget

- **WHEN** o código-fonte de `expense/domain` e `expense/application` é inspecionado
- **THEN** nenhum tipo de `budget` (ou de qualquer outro contexto) aparece em nenhuma importação

#### Scenario: O consumidor chama o caso de uso público, não o repositório

- **WHEN** `budget` precisa da soma de gastos de uma pessoa num intervalo
- **THEN** a chamada ocorre através do caso de uso público de `expense` (in-process), nunca por acesso
  direto ao `ExpenseRepository` de `expense` a partir de `budget`
