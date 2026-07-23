## ADDED Requirements

### Requirement: Edição atualiza valor, intervalo e anotação de um orçamento vivo do ator autenticado

O sistema SHALL permitir editar um orçamento **vivo** identificado por `id`, reaplicando as mesmas
validações da criação sobre o valor, o intervalo de datas e a anotação. A edição SHALL substituir os três
campos mutáveis juntos (mesmo formato da criação, mais o identificador) — não existe edição de um único
campo isolado. A edição SHALL pertencer sempre ao ator autenticado: uma pessoa SHALL NOT editar um
orçamento de outra pessoa.

#### Scenario: Edição bem-sucedida com todos os campos

- **WHEN** a edição recebe o `id` de um orçamento vivo do ator autenticado, um valor válido (> 0), um
  intervalo de datas válido (fim ≥ início) sem sobreposição com outro orçamento vivo da mesma pessoa
  (excluindo o próprio orçamento editado), e uma anotação não-vazia
- **THEN** o sistema atualiza o `Budget` com o novo valor, intervalo e anotação
- **AND** persiste a atualização
- **AND** retorna um resultado de sucesso contendo o orçamento atualizado

#### Scenario: Edição não muda o dono do orçamento

- **WHEN** a edição é processada para um ator autenticado
- **THEN** o `Budget` atualizado continua pertencendo ao mesmo dono de antes da edição
- **AND** nenhum identificador de pessoa presente no corpo da requisição influencia o dono do orçamento

### Requirement: Orçamento inexistente, removido ou de outra pessoa é um erro único de "não encontrado"

O sistema SHALL tratar como o **mesmo** erro de domínio as três situações em que a edição não pode
prosseguir: o `id` não corresponde a nenhum orçamento existente, o orçamento existe mas já está
**removido**, ou o orçamento existe e está vivo mas pertence a **outra** pessoa. Nenhuma dessas três
situações SHALL ser distinguível a partir do erro retornado.

#### Scenario: Orçamento inexistente é recusado

- **WHEN** a edição recebe um `id` que não corresponde a nenhum orçamento
- **THEN** o sistema retorna o erro de domínio de "orçamento não encontrado"
- **AND** nenhuma atualização é persistida

#### Scenario: Orçamento já removido é recusado

- **WHEN** a edição recebe o `id` de um orçamento que já está no estado removido
- **THEN** o sistema retorna o erro de domínio de "orçamento não encontrado"
- **AND** nenhuma atualização é persistida

#### Scenario: Orçamento de outra pessoa é recusado com o mesmo erro

- **WHEN** a edição recebe o `id` de um orçamento vivo que pertence a outra pessoa, não ao ator
  autenticado
- **THEN** o sistema retorna o **mesmo** erro de domínio de "orçamento não encontrado" que um `id`
  inexistente produziria
- **AND** nenhuma atualização é persistida

### Requirement: Edição reaplica valor, intervalo e anotação da criação

O valor, o intervalo de datas e a anotação da edição SHALL seguir exatamente as mesmas regras de domínio
da criação: valor exato em centavos, sempre maior que zero; intervalo com início e fim incluídos, fim
nunca anterior ao início; anotação opcional, aparada, tratada como ausente quando vazia após o trim, e
limitada ao comprimento máximo. Uma violação de qualquer uma dessas regras SHALL ser recusada como erro de
domínio, e nenhuma atualização SHALL ser persistida nesse caso.

#### Scenario: Valor zero ou negativo é recusado

- **WHEN** a edição recebe um valor igual ou menor que zero
- **THEN** o sistema retorna um erro de domínio de valor inválido
- **AND** nenhuma atualização é persistida

#### Scenario: Intervalo com fim antes do início é recusado

- **WHEN** a edição recebe uma data de fim anterior à data de início
- **THEN** o sistema retorna um erro de domínio de intervalo inválido
- **AND** nenhuma atualização é persistida

#### Scenario: Anotação longa demais é recusada

- **WHEN** a edição recebe uma anotação que excede o comprimento máximo
- **THEN** o sistema retorna um erro de domínio de anotação inválida
- **AND** nenhuma atualização é persistida

### Requirement: Não-sobreposição na edição exclui o próprio orçamento

A checagem de não-sobreposição da edição SHALL comparar o novo intervalo contra os **demais** orçamentos
vivos da mesma pessoa, **excluindo** o próprio orçamento sendo editado — o orçamento nunca é considerado
sobreposto a si mesmo. Um novo intervalo que compartilhe qualquer dia (incluindo fronteira) com **outro**
orçamento vivo da mesma pessoa SHALL ser recusado como erro de domínio, e nenhuma atualização SHALL ser
persistida nesse caso.

#### Scenario: Editar sem mudar o intervalo não conflita consigo mesmo

- **WHEN** a edição de um orçamento reenvia o mesmo intervalo de datas que ele já tinha, sem nenhum outro
  orçamento vivo sobreposto
- **THEN** a edição é aceita normalmente, sem erro de sobreposição

#### Scenario: Sobreposição com outro orçamento vivo é recusada

- **WHEN** a pessoa tem um outro orçamento vivo cujo intervalo compartilha um dia (incluindo fronteira)
  com o novo intervalo da edição
- **THEN** o sistema retorna um erro de domínio de sobreposição
- **AND** nenhuma atualização é persistida
