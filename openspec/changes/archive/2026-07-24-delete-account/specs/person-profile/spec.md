## ADDED Requirements

### Requirement: A pessoa autenticada apaga a própria conta confirmando a senha

O sistema SHALL prover uma operação de aplicação que, dada a identidade da sessão viva (o `personId` do
ator autenticado) e a **senha atual** para confirmação, resolve a pessoa **ativa** correspondente, **confere
a senha** contra o hash guardado e, somente então, executa como uma única sequência ordenada: neutraliza e
libera o e-mail da pessoa, transiciona seu status para **apagada**, encerra **todas** as sessões vivas dela
(incluindo a sessão que fez a chamada) e aciona a remoção definitiva de todos os orçamentos e gastos que ela
possui. A operação SHALL receber a identidade já resolvida pela borda (não relê a sessão nem o token) e
SHALL NOT reimplementar autenticação. Uma pessoa SHALL apagar apenas a própria conta, nunca a de outra.

#### Scenario: Confirmação correta apaga a conta por completo

- **WHEN** a operação recebe o `personId` de uma pessoa ativa persistida e a senha atual correta
- **THEN** o sistema neutraliza e libera o e-mail dessa pessoa
- **AND** transiciona o status da pessoa para apagada
- **AND** encerra todas as sessões vivas dessa pessoa, incluindo a sessão que fez a chamada
- **AND** aciona a remoção definitiva de todos os orçamentos e gastos que ela possui
- **AND** retorna um resultado de sucesso

### Requirement: Nenhum efeito visível sobrevive a uma falha antes da confirmação de senha

O sistema SHALL garantir que, quando a operação de exclusão de conta falha (senha incorreta ou sessão
órfã), **nenhum** dos efeitos da exclusão ocorre: o e-mail permanece inalterado, o status da pessoa
permanece ativo, nenhuma sessão é revogada e nenhum orçamento ou gasto é removido.

#### Scenario: Falha na confirmação não produz nenhum efeito parcial

- **WHEN** a operação de exclusão de conta falha, seja por senha incorreta seja por sessão órfã
- **THEN** o e-mail, o status, as sessões vivas e os orçamentos/gastos da pessoa permanecem exatamente como
  antes da chamada

### Requirement: Confirmação de senha é obrigatória e sua falha colapsa numa falha neutra

O sistema SHALL exigir a **senha atual** como confirmação da exclusão de conta e SHALL conferi-la contra o
hash guardado da pessoa **antes** de qualquer efeito da exclusão. Uma senha de confirmação incorreta SHALL
ser tratada como uma **falha** da operação (`InvalidCredentials`), não como um sucesso. A falha SHALL ser
genérica, sem detalhe, de modo que a borda possa mapeá-la à **mesma** recusa neutra de autenticação que uma
sessão ausente produz.

#### Scenario: Senha de confirmação incorreta falha sem nenhum efeito

- **WHEN** a operação recebe o `personId` de uma pessoa ativa persistida e uma senha de confirmação que
  **não** confere com o hash guardado
- **THEN** o sistema retorna a falha `InvalidCredentials`
- **AND** nenhum efeito da exclusão ocorre

### Requirement: Sessão órfã na exclusão de conta colapsa numa falha neutra

O sistema SHALL tratar o caso em que a sessão é viva mas a pessoa referenciada **não está mais ativa** (uma
corrida em que a conta já foi apagada por outra chamada concorrente) como uma **falha** da operação de
exclusão, não como um sucesso. A operação SHALL retornar o **mesmo** erro de domínio único e genérico
(`PersonNotFound`) usado pelas demais operações de `person-profile`, sem detalhe, de modo que a borda possa
mapeá-lo à mesma recusa neutra de autenticação.

#### Scenario: Pessoa não mais ativa produz falha neutra na exclusão

- **WHEN** a operação de exclusão recebe um `personId` cuja pessoa não existe mais ou não está ativa
- **THEN** o sistema retorna a falha `PersonNotFound`
- **AND** nenhum efeito da exclusão ocorre

### Requirement: Reaproveitar o e-mail liberado cria uma pessoa nova e independente

O sistema SHALL garantir que, uma vez que o e-mail de uma pessoa apagada foi liberado, um novo cadastro
usando aquele mesmo endereço cria uma pessoa **nova e independente**, sem nenhuma relação com a conta
apagada além de terem usado o mesmo endereço em momentos diferentes. O cadastro novo SHALL NOT reativar,
restaurar ou de qualquer forma "ressuscitar" a pessoa apagada.

#### Scenario: Cadastro após exclusão gera uma pessoa nova

- **WHEN** uma pessoa apaga a própria conta e, em seguida, alguém se cadastra usando o e-mail original dela
- **THEN** o cadastro é aceito (o e-mail está livre)
- **AND** a pessoa criada tem um identificador novo, sem relação com o identificador da pessoa apagada

### Requirement: Resultado da exclusão de conta é exaustivo e sem exceções

O sistema SHALL expressar o desfecho da exclusão de conta como um resultado exaustivo (`sealed`), com um
caso de sucesso e os casos de falha de domínio (`InvalidCredentials`, `PersonNotFound`). A operação SHALL
NOT lançar exceção para sinalizar falha de domínio, de modo que todo consumidor trate cada caso
exaustivamente.

#### Scenario: Cada desfecho é um caso do resultado selado

- **WHEN** a operação de exclusão de conta termina (por sucesso ou por qualquer falha de domínio)
- **THEN** o desfecho é um caso do resultado selado, nunca uma exceção lançada
