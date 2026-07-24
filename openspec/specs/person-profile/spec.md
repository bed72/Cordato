# person-profile

## Purpose

Read-only recuperação da própria pessoa a partir da identidade de uma sessão viva. Dada a
`personId` já resolvida pelo guard de borda, a operação de aplicação resolve a pessoa **ativa**
correspondente e devolve sua **visão pública** (identificador, nome, e-mail), nunca material de
senha. A operação não relê a sessão nem o token e não reimplementa autenticação — a decisão de
"quem está chamando" já foi tomada na borda. Uma sessão viva cuja pessoa não está mais ativa
colapsa numa falha de domínio única e neutra (`PersonNotFound`), exposta por um resultado `sealed`
exaustivo e sem exceções, para que a borda a mapeie à mesma recusa neutra de autenticação.
## Requirements
### Requirement: A pessoa autenticada recupera a própria visão pública

O sistema SHALL prover uma operação de aplicação que, dada a identidade da sessão viva (o `personId` do ator
autenticado), resolve a pessoa **ativa** correspondente e retorna sua **visão pública** — ao menos
identificador, nome e e-mail. A operação SHALL receber o `personId` já resolvido pela borda (não relê a
sessão nem o token), SHALL NOT expor material de senha (senha ou hash), e SHALL NOT reimplementar
autenticação — a decisão de "quem está chamando" já foi tomada pelo guard de borda.

#### Scenario: Sessão de pessoa ativa retorna a visão pública

- **WHEN** a operação recebe o `personId` de uma pessoa ativa persistida
- **THEN** o sistema retorna um resultado de sucesso contendo a visão pública dessa pessoa
- **AND** a visão contém identificador, nome e e-mail, e nenhum material de senha

### Requirement: Sessão órfã colapsa numa falha neutra

O sistema SHALL tratar o caso em que a sessão é viva mas a pessoa referenciada **não está mais ativa**
(deletada ou inativa numa corrida com a deleção de conta) como uma **falha** da operação, não como um
sucesso com dados ausentes. A operação SHALL retornar um erro de domínio único e genérico
(`PersonNotFound`), sem detalhe, de modo que a borda possa mapeá-lo à **mesma** recusa neutra de
autenticação que uma rota protegida sem sessão emite — sem distinguir "sessão órfã" de "token inválido".

#### Scenario: Pessoa não-ativa produz falha

- **WHEN** a operação recebe um `personId` cuja pessoa não existe mais ou não está ativa
- **THEN** o sistema retorna a falha `PersonNotFound`
- **AND** nenhuma visão de pessoa é retornada

### Requirement: Resultado da operação é exaustivo e sem exceções

O sistema SHALL expor o resultado da operação como um tipo **`sealed`** que representa exaustivamente ou o
sucesso (com a visão pública da pessoa) ou o erro de domínio `PersonNotFound`. O caminho de erro SHALL NOT
ser sinalizado por exceção lançada, permitindo verificação exaustiva por `when` em tempo de compilação.

#### Scenario: Consumidor trata todos os casos

- **WHEN** um consumidor invoca a operação e ramifica sobre o resultado
- **THEN** o compilador exige o tratamento exaustivo do sucesso e do erro de domínio
- **AND** nenhum caminho de erro de domínio é comunicado via exceção lançada

### Requirement: A pessoa autenticada atualiza o próprio nome

O sistema SHALL prover uma operação de aplicação que, dada a identidade da sessão viva (o `personId` do
ator autenticado) e um novo nome, resolve a pessoa **ativa** correspondente, aplica o novo nome como um
`NameValueObject` válido e persiste **apenas** o nome. A operação SHALL receber o `personId` já resolvido
pela borda (não relê a sessão nem o token) e SHALL NOT reimplementar autenticação. A operação SHALL NOT
alterar e-mail, senha (ou seu hash), status ou identificador da pessoa. Em caso de sucesso, SHALL retornar
a **visão pública** atualizada da pessoa (identificador, nome, e-mail), nunca material de senha.

#### Scenario: Nome válido atualiza e retorna a visão pública

- **WHEN** a operação recebe o `personId` de uma pessoa ativa persistida e um nome que satisfaz a invariante do value object
- **THEN** o sistema persiste o novo nome dessa pessoa e retorna um resultado de sucesso com a visão pública atualizada
- **AND** a visão contém identificador, nome (o novo) e e-mail, e nenhum material de senha

#### Scenario: Apenas o nome é alterado

- **WHEN** a atualização de nome de uma pessoa ativa é bem-sucedida
- **THEN** o e-mail, a senha (hash), o status e o identificador da pessoa permanecem exatamente como antes
- **AND** somente o nome reflete o novo valor

### Requirement: Nome inválido colapsa numa falha de domínio

O sistema SHALL tratar um novo nome que **não satisfaz a invariante** do `NameValueObject` como uma
**falha** da operação (`InvalidName`), não como um sucesso. A invariante do nome SHALL ser decidida pelo
próprio value object — a autoridade única —, nunca reimplementada na operação. Quando a operação falha por
nome inválido, o nome persistido da pessoa SHALL permanecer inalterado.

#### Scenario: Nome que viola a invariante falha

- **WHEN** a operação recebe um `personId` de pessoa ativa e um nome que o `NameValueObject` rejeita
- **THEN** o sistema retorna a falha `InvalidName`
- **AND** o nome persistido da pessoa permanece inalterado

### Requirement: Sessão órfã na atualização colapsa numa falha neutra

O sistema SHALL tratar o caso em que a sessão é viva mas a pessoa referenciada **não está mais ativa**
(deletada ou inativa numa corrida com a deleção de conta) como uma **falha** da operação de atualização,
não como um sucesso. A operação SHALL retornar o **mesmo** erro de domínio único e genérico
(`PersonNotFound`) usado pela recuperação da própria pessoa, sem detalhe, de modo que a borda possa
mapeá-lo à mesma recusa neutra de autenticação.

#### Scenario: Pessoa não-ativa produz falha na atualização

- **WHEN** a operação de atualização recebe um `personId` cuja pessoa não existe mais ou não está ativa
- **THEN** o sistema retorna a falha `PersonNotFound`
- **AND** nenhum nome é alterado e nenhuma visão de pessoa é retornada

### Requirement: Resultado da atualização é exaustivo e sem exceções

O sistema SHALL expor o resultado da operação de atualização de nome como um tipo **`sealed`** que
representa exaustivamente o sucesso (com a visão pública atualizada) ou os erros de domínio (`InvalidName`
e `PersonNotFound`). O caminho de erro SHALL NOT ser sinalizado por exceção lançada, permitindo verificação
exaustiva por `when` em tempo de compilação.

#### Scenario: Consumidor trata todos os casos da atualização

- **WHEN** um consumidor invoca a operação de atualização e ramifica sobre o resultado
- **THEN** o compilador exige o tratamento exaustivo do sucesso e de cada erro de domínio
- **AND** nenhum caminho de erro de domínio é comunicado via exceção lançada

### Requirement: A pessoa autenticada troca o próprio e-mail confirmando a senha

O sistema SHALL prover uma operação de aplicação que, dada a identidade da sessão viva (o `personId` do ator
autenticado), um novo e-mail e a **senha atual** para confirmação, resolve a pessoa **ativa** correspondente,
**confere a senha** contra o hash guardado, aplica o novo e-mail como um `EmailValueObject` válido garantindo
sua **unicidade global** e persiste **apenas** o e-mail. A operação SHALL receber o `personId` já resolvido
pela borda (não relê a sessão nem o token) e SHALL NOT reimplementar autenticação. A operação SHALL NOT
alterar nome, senha (ou seu hash), status ou identificador da pessoa. Em caso de sucesso, SHALL retornar a
**visão pública** atualizada da pessoa (identificador, nome, e-mail), nunca material de senha.

#### Scenario: E-mail válido com senha correta atualiza e retorna a visão pública

- **WHEN** a operação recebe o `personId` de uma pessoa ativa persistida, a senha atual correta e um novo e-mail que satisfaz a invariante do value object e ainda não está em uso
- **THEN** o sistema persiste o novo e-mail dessa pessoa e retorna um resultado de sucesso com a visão pública atualizada
- **AND** a visão contém identificador, nome e e-mail (o novo), e nenhum material de senha

#### Scenario: Apenas o e-mail é alterado

- **WHEN** a troca de e-mail de uma pessoa ativa é bem-sucedida
- **THEN** o nome, a senha (hash), o status e o identificador da pessoa permanecem exatamente como antes
- **AND** somente o e-mail reflete o novo valor

### Requirement: Confirmação de senha é obrigatória e sua falha colapsa numa falha neutra

O sistema SHALL exigir a **senha atual** como confirmação da troca de e-mail e SHALL conferi-la contra o
hash guardado da pessoa **antes** de qualquer escrita. Uma senha de confirmação incorreta SHALL ser tratada
como uma **falha** da operação (`InvalidCredentials`), não como um sucesso, e o e-mail persistido SHALL
permanecer inalterado. A falha SHALL ser genérica, sem detalhe, de modo que a borda possa mapeá-la à **mesma**
recusa neutra de autenticação que uma sessão ausente produz.

#### Scenario: Senha de confirmação incorreta falha sem escrever

- **WHEN** a operação recebe um `personId` de pessoa ativa, um novo e-mail válido e uma senha de confirmação que **não** confere com o hash guardado
- **THEN** o sistema retorna a falha `InvalidCredentials`
- **AND** o e-mail persistido da pessoa permanece inalterado

### Requirement: E-mail inválido na troca colapsa numa falha de domínio

O sistema SHALL tratar um novo e-mail que **não satisfaz a invariante** do `EmailValueObject` como uma
**falha** da operação (`InvalidEmail`), não como um sucesso. A invariante do e-mail SHALL ser decidida pelo
próprio value object — a autoridade única —, nunca reimplementada na operação. Quando a operação falha por
e-mail inválido, o e-mail persistido da pessoa SHALL permanecer inalterado.

#### Scenario: E-mail que viola a invariante falha

- **WHEN** a operação recebe um `personId` de pessoa ativa, a senha correta e um e-mail que o `EmailValueObject` rejeita
- **THEN** o sistema retorna a falha `InvalidEmail`
- **AND** o e-mail persistido da pessoa permanece inalterado

### Requirement: E-mail já em uso colapsa numa falha de conflito neutra

O sistema SHALL garantir a unicidade global do e-mail na troca: se o novo e-mail já pertencer a **outra**
pessoa, a operação SHALL falhar com `EmailAlreadyInUse`, sem alterar nada. Essa falha SHALL NOT carregar o
e-mail tentado nem qualquer dado da pessoa existente, preservando a invariante de não-vazamento de existência
de conta do contexto. A garantia de unicidade SHALL ser autoritativa na fronteira de persistência (não
apenas uma pré-checagem), de modo que uma corrida concorrente não produza dois e-mails iguais.

#### Scenario: Novo e-mail pertencente a outra pessoa falha como conflito

- **WHEN** a operação recebe um novo e-mail que já pertence a outra pessoa ativa
- **THEN** o sistema retorna a falha `EmailAlreadyInUse`
- **AND** nenhum e-mail é alterado
- **AND** a falha não carrega o e-mail tentado nem qualquer dado da pessoa existente

### Requirement: Trocar para o próprio e-mail atual é um no-op bem-sucedido

O sistema SHALL tratar a troca para o e-mail que a própria pessoa **já possui** (após a normalização do value
object) como um **sucesso** idempotente, não como um conflito `EmailAlreadyInUse` — a unicidade global só é
violada por um e-mail pertencente a **outra** pessoa. O resultado SHALL ser a visão pública da pessoa, com o
mesmo e-mail.

#### Scenario: Novo e-mail igual ao atual da própria pessoa

- **WHEN** a operação recebe, com a senha correta, um novo e-mail que normaliza para o e-mail atual da própria pessoa
- **THEN** o sistema retorna um resultado de sucesso com a visão pública da pessoa
- **AND** a operação não falha por `EmailAlreadyInUse`

### Requirement: Sessão órfã na troca de e-mail colapsa numa falha neutra

O sistema SHALL tratar o caso em que a sessão é viva mas a pessoa referenciada **não está mais ativa**
(deletada ou inativa numa corrida com a deleção de conta) como uma **falha** da operação de troca de e-mail,
não como um sucesso. A operação SHALL retornar o **mesmo** erro de domínio único e genérico (`PersonNotFound`)
usado pela recuperação da própria pessoa, sem detalhe, de modo que a borda possa mapeá-lo à mesma recusa
neutra de autenticação. Esse mesmo desfecho SHALL cobrir a corrida em que a pessoa deixa de estar ativa
entre a leitura e a escrita.

#### Scenario: Pessoa não-ativa produz falha na troca

- **WHEN** a operação de troca recebe um `personId` cuja pessoa não existe mais ou não está ativa
- **THEN** o sistema retorna a falha `PersonNotFound`
- **AND** nenhum e-mail é alterado e nenhuma visão de pessoa é retornada

### Requirement: Resultado da troca de e-mail é exaustivo e sem exceções

O sistema SHALL expor o resultado da operação de troca de e-mail como um tipo **`sealed`** que representa
exaustivamente o sucesso (com a visão pública atualizada) ou cada erro de domínio (`InvalidEmail`,
`EmailAlreadyInUse`, `InvalidCredentials` e `PersonNotFound`). O caminho de erro SHALL NOT ser sinalizado por
exceção lançada, permitindo verificação exaustiva por `when` em tempo de compilação.

#### Scenario: Consumidor trata todos os casos da troca

- **WHEN** um consumidor invoca a operação de troca de e-mail e ramifica sobre o resultado
- **THEN** o compilador exige o tratamento exaustivo do sucesso e de cada erro de domínio
- **AND** nenhum caminho de erro de domínio é comunicado via exceção lançada

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

### Requirement: A pessoa autenticada apaga a própria conta confirmando a senha

O sistema SHALL prover uma operação de aplicação que, dada a identidade da sessão viva (o `personId` do ator
autenticado) e a **senha atual** para confirmação, resolve a pessoa **ativa** correspondente, **confere
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

### Requirement: Confirmação de senha é obrigatória e sua falha colapsa numa falha neutra (exclusão de conta)

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

