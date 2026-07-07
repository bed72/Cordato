## ADDED Requirements

### Requirement: Token opaco é gerado e devolvido uma única vez

O sistema SHALL gerar, ao abrir uma sessão, um token **opaco** (sem significado embutido) a partir de uma
fonte criptograficamente segura (`SecureRandom`), com entropia suficiente para ser impraticável de
adivinhar, codificado em base64url. Esse token em claro SHALL ser devolvido ao cliente **uma única vez**,
no momento da abertura, e SHALL NOT ser recuperável a partir da sessão depois disso.

#### Scenario: Cada sessão recebe um token único e imprevisível

- **WHEN** duas sessões são abertas
- **THEN** cada uma recebe um token opaco distinto derivado de `SecureRandom`
- **AND** o token não carrega dado legível sobre a pessoa ou a sessão

#### Scenario: Token em claro não é recuperável depois

- **WHEN** uma sessão já foi aberta e o token em claro entregue
- **THEN** a sessão persistida não permite recuperar o token em claro

### Requirement: Token é armazenado apenas como hash

O sistema SHALL armazenar apenas o **hash SHA-256** do token (`hashToken`), nunca o token em claro. A
resolução de uma sessão por token SHALL comparar o hash do token apresentado com o hash armazenado, de
modo que um vazamento do armazenamento não exponha tokens utilizáveis.

#### Scenario: O armazenamento guarda o hash, não o token

- **WHEN** uma sessão é aberta
- **THEN** o valor persistido do token é o seu hash SHA-256
- **AND** o token em claro não está presente no armazenamento

### Requirement: Sessão tem expiração

O sistema SHALL associar a cada sessão um instante de expiração definido no momento da abertura. Uma
sessão SHALL ser considerada **viva** apenas enquanto não expirada.

#### Scenario: Sessão aberta registra sua expiração

- **WHEN** uma sessão é aberta
- **THEN** ela carrega um instante de expiração futuro definido na abertura

### Requirement: Abrir e resolver uma sessão viva por token

O sistema SHALL prover um repositório de sessões capaz de **abrir** (criar e persistir) uma sessão para
uma pessoa, e de **resolver** uma sessão viva a partir de um token e do instante atual
(`findActiveByToken`). A resolução SHALL retornar a sessão somente quando o hash do token apresentado
corresponder ao armazenado **e** a sessão não estiver expirada; caso contrário SHALL retornar ausência de
sessão (sem lançar exceção), para que o consumidor de borda trate token ausente, inválido ou expirado de
forma indistinguível.

#### Scenario: Token válido e não expirado resolve a sessão

- **WHEN** `findActiveByToken` recebe um token cujo hash existe e cuja sessão não expirou, no instante atual
- **THEN** o sistema retorna a sessão viva correspondente

#### Scenario: Token expirado não resolve

- **WHEN** `findActiveByToken` recebe um token cuja sessão já expirou no instante atual
- **THEN** o sistema retorna ausência de sessão

#### Scenario: Token desconhecido não resolve

- **WHEN** `findActiveByToken` recebe um token cujo hash não existe no armazenamento
- **THEN** o sistema retorna ausência de sessão, sem lançar exceção
