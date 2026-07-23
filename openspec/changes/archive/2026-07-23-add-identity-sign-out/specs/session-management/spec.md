## ADDED Requirements

### Requirement: Revogar uma única sessão pelo seu identificador

O sistema SHALL prover, no repositório de sessões, uma operação que **revogue** uma única sessão
identificada pelo seu `sessionId`, tornando-a definitivamente não-resolvível por `findActiveByToken` a
partir desse momento. A revogação SHALL ser **autoritativa no servidor** e SHALL NOT lançar exceção quando
o `sessionId` não corresponder a nenhuma sessão viva (nada a revogar é um resultado válido, não um erro) —
mesma postura de `revokeAllForPersonExcept`, mas aplicada a uma única sessão indicada diretamente, sem
depender de um `personId`.

#### Scenario: Sessão indicada é revogada

- **WHEN** a operação recebe o identificador de uma sessão viva
- **THEN** o sistema revoga essa sessão
- **AND** `findActiveByToken` para o token daquela sessão passa a retornar ausência de sessão

#### Scenario: Revogar sessão inexistente ou já revogada não é um erro

- **WHEN** a operação recebe um `sessionId` que não corresponde a nenhuma sessão viva
- **THEN** o sistema não lança exceção
- **AND** o resultado indica que nada foi revogado
