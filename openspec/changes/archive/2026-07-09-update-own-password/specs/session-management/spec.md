## ADDED Requirements

### Requirement: Revogar todas as sessões de uma pessoa exceto uma

O sistema SHALL prover, no repositório de sessões, uma operação que **revogue** (remova de forma que deixem de
ser resolvíveis) todas as sessões vivas de uma pessoa **exceto** uma sessão indicada (a atual, por seu
identificador). A revogação SHALL ser **autoritativa no servidor**: uma sessão revogada SHALL deixar de ser
resolvida por `findActiveByToken` imediatamente, colapsando no mesmo resultado ausente que um token
desconhecido produz. A operação SHALL preservar intacta a sessão indicada e SHALL NOT lançar exceção quando a
pessoa não tiver outras sessões (nada a revogar é um resultado válido, não um erro).

#### Scenario: As demais sessões da pessoa são revogadas, a indicada é preservada

- **WHEN** a operação recebe o identificador de uma pessoa com várias sessões vivas e o identificador de uma delas para preservar
- **THEN** o sistema remove todas as outras sessões vivas dessa pessoa
- **AND** a sessão indicada permanece resolvível por seu token

#### Scenario: Uma sessão revogada deixa de ser resolvida

- **WHEN** uma sessão foi revogada por essa operação
- **THEN** `findActiveByToken` para o token daquela sessão retorna ausência de sessão, sem lançar exceção

#### Scenario: Pessoa sem outras sessões não é um erro

- **WHEN** a operação recebe uma pessoa cuja única sessão viva é a indicada para preservar
- **THEN** o sistema não revoga nada e não lança exceção
- **AND** a sessão indicada permanece resolvível
