## ADDED Requirements

### Requirement: Revogar todas as sessões vivas de uma pessoa, sem exceção

O sistema SHALL prover, no repositório de sessões, uma operação que **revogue** todas as sessões vivas de
uma pessoa identificada por `personId`, **sem poupar nenhuma** — nem mesmo a sessão a partir da qual a
chamada foi feita. Isso é distinto de `revokeAllForPersonExcept`, que preserva uma sessão indicada; aqui não
existe sessão a preservar, porque a conta à qual as sessões pertencem deixa de existir. A operação SHALL ser
**autoritativa no servidor** (uma sessão revogada deixa de ser resolvida por `findActiveByToken`
imediatamente) e SHALL NOT lançar exceção quando a pessoa não tiver nenhuma sessão viva (nada a revogar é
um resultado válido, não um erro).

#### Scenario: Todas as sessões da pessoa são revogadas, incluindo a atual

- **WHEN** a operação recebe o identificador de uma pessoa com várias sessões vivas, uma delas sendo a
  sessão que fez a chamada
- **THEN** o sistema remove todas as sessões vivas dessa pessoa, sem exceção
- **AND** `findActiveByToken` para o token de qualquer uma delas, incluindo a que fez a chamada, passa a
  retornar ausência de sessão

#### Scenario: Pessoa sem sessões vivas não é um erro

- **WHEN** a operação recebe o identificador de uma pessoa sem nenhuma sessão viva
- **THEN** o sistema não lança exceção
- **AND** nenhuma sessão é alterada
