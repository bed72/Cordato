## ADDED Requirements

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
