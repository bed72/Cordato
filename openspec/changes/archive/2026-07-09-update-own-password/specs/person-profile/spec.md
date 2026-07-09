## ADDED Requirements

### Requirement: A pessoa autenticada troca a própria senha confirmando a senha atual

O sistema SHALL prover uma operação de aplicação que, dada a identidade da sessão viva (o `personId` e o
`sessionId` do ator autenticado), a **senha atual** para confirmação e a **nova senha**, resolve a pessoa
**ativa** correspondente, **confere a senha atual** contra o hash guardado, valida a nova senha pela política
(o `PasswordValueObject`, autoridade única) e persiste **apenas** o hash da nova senha. A operação SHALL
receber a identidade já resolvida pela borda (não relê a sessão nem o token) e SHALL NOT reimplementar
autenticação. A operação SHALL NOT alterar nome, e-mail, status ou identificador da pessoa. Em caso de
sucesso, SHALL retornar a **visão pública** da pessoa (identificador, nome, e-mail), nunca material de senha.

#### Scenario: Nova senha válida com senha atual correta atualiza o hash

- **WHEN** a operação recebe o `personId` de uma pessoa ativa persistida, a senha atual correta e uma nova senha que satisfaz a política e difere da atual
- **THEN** o sistema persiste o novo hash de senha dessa pessoa e retorna um resultado de sucesso com a visão pública
- **AND** a visão contém identificador, nome e e-mail, e nenhum material de senha

#### Scenario: Apenas o hash da senha é alterado

- **WHEN** a troca de senha de uma pessoa ativa é bem-sucedida
- **THEN** o nome, o e-mail, o status e o identificador da pessoa permanecem exatamente como antes
- **AND** somente o hash de senha reflete a nova senha

### Requirement: Confirmação da senha atual é obrigatória e sua falha colapsa numa falha neutra

O sistema SHALL exigir a **senha atual** como confirmação da troca e SHALL conferi-la contra o hash guardado
da pessoa **antes** de qualquer escrita. Uma senha atual incorreta SHALL ser tratada como uma **falha** da
operação (`InvalidCredentials`), não como um sucesso, e o hash persistido SHALL permanecer inalterado. A
falha SHALL ser genérica, sem detalhe, de modo que a borda possa mapeá-la à **mesma** recusa neutra de
autenticação que uma sessão ausente produz.

#### Scenario: Senha atual incorreta falha sem escrever

- **WHEN** a operação recebe um `personId` de pessoa ativa, uma nova senha válida e uma senha atual que **não** confere com o hash guardado
- **THEN** o sistema retorna a falha `InvalidCredentials`
- **AND** o hash de senha persistido permanece inalterado
- **AND** nenhuma sessão é revogada

### Requirement: Nova senha fraca colapsa numa falha de domínio pública

O sistema SHALL tratar uma nova senha que **não satisfaz a política mínima** do `PasswordValueObject` como
uma **falha** da operação (`WeakPassword`), não como um sucesso. A política SHALL ser decidida pelo próprio
value object — a autoridade única —, nunca reimplementada na operação. Por ser uma **regra pública**
(o tamanho mínimo não revela nada sobre nenhuma pessoa), essa falha PODE ser específica. Quando a operação
falha por senha fraca, o hash persistido SHALL permanecer inalterado.

#### Scenario: Nova senha que viola a política falha

- **WHEN** a operação recebe um `personId` de pessoa ativa, a senha atual correta e uma nova senha que o `PasswordValueObject` rejeita
- **THEN** o sistema retorna a falha `WeakPassword`
- **AND** o hash de senha persistido permanece inalterado

### Requirement: Nova senha igual à atual é recusada

O sistema SHALL recusar uma nova senha que, embora satisfaça a política, **coincide com a senha atual** da
pessoa, tratando-a como uma **falha** da operação (`SamePassword`), não como um sucesso nem como um no-op. A
coincidência SHALL ser decidida conferindo a nova senha contra o hash guardado, **após** a confirmação da
senha atual. Quando a operação falha por senha igual, o hash persistido SHALL permanecer inalterado e nenhuma
sessão SHALL ser revogada.

#### Scenario: Nova senha igual à atual falha sem escrever

- **WHEN** a operação recebe um `personId` de pessoa ativa, a senha atual correta e uma nova senha que confere com o hash guardado (ou seja, é a própria senha atual)
- **THEN** o sistema retorna a falha `SamePassword`
- **AND** o hash de senha persistido permanece inalterado

### Requirement: A troca de senha revoga as demais sessões vivas, mantendo a atual

O sistema SHALL, após persistir com sucesso a nova senha, revogar **todas as demais sessões vivas** da pessoa,
mantendo válida **a sessão que fez a troca** (identificada pelo `sessionId` do ator). A revogação SHALL ser o
efeito colateral **final** da operação, ocorrendo somente quando a troca foi de fato persistida — se a
persistência falhar, nenhuma sessão SHALL ser tocada.

#### Scenario: Troca bem-sucedida encerra as outras sessões e poupa a atual

- **WHEN** a troca de senha de uma pessoa ativa com múltiplas sessões vivas é bem-sucedida, a partir de uma delas
- **THEN** o sistema revoga todas as sessões vivas dessa pessoa **exceto** a sessão a partir da qual a troca foi feita
- **AND** a sessão atual permanece válida

#### Scenario: Falha na persistência não revoga sessão alguma

- **WHEN** a operação falha ao persistir a nova senha (a pessoa deixou de estar ativa numa corrida com a exclusão de conta)
- **THEN** o sistema retorna a falha `PersonNotFound`
- **AND** nenhuma sessão da pessoa é revogada

### Requirement: Sessão órfã na troca de senha colapsa numa falha neutra

O sistema SHALL, quando a sessão estiver viva mas a pessoa já não estiver mais **ativa** (uma corrida com a
exclusão de conta), tratar a troca de senha como a **falha** `PersonNotFound`, sem alterar nada. Essa falha
SHALL NOT carregar detalhe, de modo que a borda a colapse na **mesma** recusa neutra de autenticação que uma
senha atual incorreta e uma sessão ausente produzem — indistinguíveis entre si.

#### Scenario: Pessoa não mais ativa falha de forma neutra

- **WHEN** a operação recebe o `personId` de uma sessão viva cuja pessoa não está mais ativa
- **THEN** o sistema retorna a falha `PersonNotFound`
- **AND** nenhum hash é escrito e nenhuma sessão é revogada

### Requirement: Resultado da troca de senha é exaustivo e sem exceções

O sistema SHALL expressar o desfecho da troca de senha como um resultado exaustivo (`sealed`), com um caso de
sucesso (a visão pública) e casos de falha de domínio (`WeakPassword`, `SamePassword`, `InvalidCredentials`,
`PersonNotFound`). A operação SHALL NOT lançar exceção para sinalizar falha de domínio, de modo que todo
consumidor trate cada caso exaustivamente.

#### Scenario: Cada desfecho é um caso do resultado selado

- **WHEN** a operação de troca de senha termina (por sucesso ou por qualquer falha de domínio)
- **THEN** o desfecho é um caso do resultado selado, nunca uma exceção lançada
