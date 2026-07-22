## ADDED Requirements

### Requirement: Um terceiro primitivo atômico expira uma chave sem alterar seu valor

O `CachePort` SHALL expor um terceiro primitivo, além de obter/gravar-com-TTL e incrementar: armar um TTL em
uma chave existente **sem** alterar o seu valor, e apenas se a chave ainda não tiver um TTL armado (semântica
equivalente a `EXPIRE ... NX`) — nunca sobrescrevendo um TTL já em curso. Essa operação SHALL ser idempotente:
chamá-la múltiplas vezes sobre a mesma chave, antes ou depois de outras chamadas concorrentes à mesma
operação, produz o mesmo resultado (a chave termina com exatamente um TTL armado, o do primeiro chamador a
chegar). Este é o primitivo que permite compor "incrementa agora, expira uma vez" sem que o `set`
existente (que sobrescreveria o valor do contador) seja usado para esse fim.

#### Scenario: Armar TTL em uma chave sem TTL

- **WHEN** o TTL é armado sobre uma chave que ainda não tem TTL algum
- **THEN** a chave passa a expirar após o TTL informado
- **AND** o valor previamente gravado na chave permanece inalterado

#### Scenario: Chamada repetida não sobrescreve um TTL já armado

- **WHEN** o TTL é armado sobre uma chave que já tem um TTL em curso
- **THEN** o TTL original da chave permanece inalterado (a nova chamada é um no-op)

#### Scenario: Armar TTL sobre chave incrementada preserva o contador

- **WHEN** uma chave é incrementada atomicamente e, em seguida, tem seu TTL armado por esta operação
- **THEN** o valor do contador obtido após o incremento permanece o mesmo após o TTL ser armado
