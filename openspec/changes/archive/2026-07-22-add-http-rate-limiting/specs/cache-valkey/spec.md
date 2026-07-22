## ADDED Requirements

### Requirement: Incremento atômico com TTL na primeira chamada da janela

O `CachePort` SHALL expor, além do incremento atômico sem expiração já existente, uma operação que
incrementa atomicamente um contador nomeado **e** garante que ele expire sozinho após um TTL — o TTL SHALL
ser aplicado apenas na chamada que cria o contador (a primeira da janela), e chamadas subsequentes SHALL NOT
estender ou renovar esse TTL. A operação SHALL retornar o novo valor do contador, da mesma forma que o
incremento sem TTL.

#### Scenario: Primeira chamada da janela cria o contador com TTL

- **WHEN** um contador nomeado é incrementado com TTL pela primeira vez (ou após a expiração anterior)
- **THEN** o port retorna `1`
- **AND** o contador expira sozinho após o TTL informado

#### Scenario: Chamadas subsequentes não renovam o TTL

- **WHEN** o mesmo contador é incrementado com TTL novamente antes de expirar
- **THEN** o port retorna o valor acumulado (incrementado)
- **AND** o tempo restante até a expiração não é estendido pela nova chamada

#### Scenario: Contador expirado reinicia do zero

- **WHEN** um contador incrementado com TTL expira e é incrementado novamente
- **THEN** o port trata como uma nova primeira chamada, retornando `1` e aplicando um novo TTL
