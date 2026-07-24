## ADDED Requirements

### Requirement: Repositório neutraliza o e-mail e marca a pessoa como apagada, numa única escrita

O `PersonRepository` SHALL expor uma operação que, dado o identificador de uma pessoa **ativa**, substitui
seu e-mail por um valor **neutralizado** (sintaticamente válido, globalmente único, e sem capacidade de
autenticar login) e transiciona seu status para **apagada**, como uma única escrita atômica. A operação
SHALL deixar nome, senha (hash) e identificador intocados. Assim como as demais operações estreitas de
`PersonRepository` (`updateName`, `updateEmail`, `updatePassword`), esta é deliberadamente restrita a esses
dois campos, não um `save(person)` genérico.

#### Scenario: E-mail é neutralizado e status transiciona para apagada

- **WHEN** a operação recebe o identificador de uma pessoa ativa
- **THEN** o e-mail persistido dessa pessoa passa a ser um valor neutralizado, sintaticamente válido e único
- **AND** o status persistido dessa pessoa passa a ser apagada
- **AND** o nome, a senha (hash) e o identificador permanecem exatamente como estavam

#### Scenario: Pessoa não-ativa não é afetada

- **WHEN** a operação recebe o identificador de uma pessoa que não existe, ou que já não está ativa
- **THEN** nenhuma linha é alterada
- **AND** a operação retorna que nenhuma pessoa ativa foi encontrada, o mesmo desfecho ausente que
  `findById` reporta

### Requirement: E-mail neutralizado libera o endereço original para um novo cadastro

O sistema SHALL garantir que, após a neutralização, o endereço de e-mail **original** da pessoa apagada não
está mais associado a nenhuma linha ativa — de modo que a checagem de unicidade de um novo cadastro para
esse mesmo endereço não encontre conflito. A garantia de unicidade global do e-mail (autoritativa na
fronteira de persistência, como já vale para `updateEmail`) SHALL continuar valendo entre pessoas ativas;
uma pessoa apagada nunca compete por essa unicidade.

#### Scenario: E-mail original fica disponível após a exclusão

- **WHEN** uma pessoa é marcada como apagada e seu e-mail neutralizado
- **THEN** um cadastro subsequente usando o e-mail original dessa pessoa não é recusado por
  `EmailAlreadyInUse`
