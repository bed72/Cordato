## ADDED Requirements

### Requirement: Remoção é recuperável e restrita ao orçamento vivo do ator autenticado

O sistema SHALL permitir remover um orçamento **vivo** identificado por `id`, pertencente ao ator
autenticado, transicionando seu estado para **removido**. A remoção SHALL ser recuperável no sentido de
que nenhum dado é apagado fisicamente — apenas o estado do orçamento muda. Uma pessoa SHALL NOT remover um
orçamento de outra pessoa.

#### Scenario: Remoção bem-sucedida de um orçamento vivo

- **WHEN** a remoção recebe o `id` de um orçamento vivo do ator autenticado
- **THEN** o sistema transiciona o `Budget` para o estado removido
- **AND** persiste a transição
- **AND** retorna um resultado de sucesso contendo o orçamento já no estado removido

#### Scenario: Remoção não apaga nenhum dado

- **WHEN** um orçamento é removido com sucesso
- **THEN** o registro do orçamento continua existindo, apenas com o estado alterado para removido
- **AND** nenhum campo além do estado (valor, intervalo, anotação, dono) é alterado

### Requirement: Orçamento removido não compete mais na invariante de não-sobreposição nem aparece nas visões derivadas

Um orçamento no estado removido SHALL deixar imediatamente de contar para a invariante de
não-sobreposição de futuras criações/edições, e SHALL deixar de aparecer nas visões de orçamento ativo e
de orçamento padrão ("sem orçamento") do ator autenticado a partir da remoção.

#### Scenario: Após remover, o intervalo fica livre para um novo orçamento

- **WHEN** a pessoa remove um orçamento vivo e, em seguida, cria um novo orçamento com o mesmo intervalo
  de datas
- **THEN** a criação do novo orçamento não é recusada por sobreposição com o orçamento removido

#### Scenario: Após remover, gastos daquele período passam a aparecer no orçamento padrão

- **WHEN** a pessoa remove o único orçamento vivo que cobria a data de um gasto já registrado
- **THEN** consultas subsequentes à visão de orçamento padrão passam a incluir esse gasto
- **AND** a visão de orçamento ativo, se consultada para uma data coberta apenas pelo orçamento removido,
  não retorna mais nenhum orçamento ativo

### Requirement: Orçamento inexistente, já removido ou de outra pessoa é um erro único de "não encontrado"

O sistema SHALL tratar como o **mesmo** erro de domínio as três situações em que a remoção não pode
prosseguir: o `id` não corresponde a nenhum orçamento existente, o orçamento já está **removido**, ou o
orçamento existe e está vivo mas pertence a **outra** pessoa. Nenhuma dessas três situações SHALL ser
distinguível a partir do erro retornado. Uma remoção recusada SHALL NOT alterar nenhum orçamento.

#### Scenario: Orçamento inexistente é recusado

- **WHEN** a remoção recebe um `id` que não corresponde a nenhum orçamento
- **THEN** o sistema retorna o erro de domínio de "orçamento não encontrado"
- **AND** nenhum orçamento é alterado

#### Scenario: Remover um orçamento já removido é recusado

- **WHEN** a remoção recebe o `id` de um orçamento que já está no estado removido
- **THEN** o sistema retorna o erro de domínio de "orçamento não encontrado"
- **AND** nenhum orçamento é alterado

#### Scenario: Orçamento de outra pessoa é recusado com o mesmo erro

- **WHEN** a remoção recebe o `id` de um orçamento vivo que pertence a outra pessoa, não ao ator
  autenticado
- **THEN** o sistema retorna o **mesmo** erro de domínio de "orçamento não encontrado" que um `id`
  inexistente produziria
- **AND** nenhum orçamento é alterado
