## ADDED Requirements

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
