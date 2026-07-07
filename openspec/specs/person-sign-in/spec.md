# person-sign-in Specification

## Purpose
TBD - created by archiving change add-identity-sign-in. Update Purpose after archive.
## Requirements
### Requirement: Login autentica uma pessoa ativa e abre uma sessão

O sistema SHALL permitir autenticar uma pessoa a partir de um e-mail e uma senha. Quando existir uma
pessoa **ativa** com aquele e-mail e a senha informada corresponder ao hash armazenado, o sistema SHALL
abrir uma sessão para ela e SHALL retornar um resultado de sucesso contendo a sessão criada **e o token em
claro** a ser devolvido ao cliente. O login SHALL NOT reimplementar a política de senha do cadastro — ele
apenas verifica a senha contra o hash existente.

#### Scenario: Login bem-sucedido abre sessão

- **WHEN** o login recebe o e-mail de uma pessoa ativa e a senha correta
- **THEN** o sistema abre uma sessão para essa pessoa
- **AND** retorna um resultado de sucesso contendo a sessão criada e o token em claro

#### Scenario: Resultado de sucesso carrega o token em claro

- **WHEN** o login é bem-sucedido
- **THEN** o resultado de sucesso expõe o token em claro (para entrega ao cliente) além da sessão
- **AND** a sessão persistida guarda apenas o hash do token, nunca o token em claro

### Requirement: Verificação de senha é timing-constant

O sistema SHALL **sempre** pagar o custo da verificação de senha em toda tentativa de login — verificando
contra o hash real quando o e-mail existe, e contra um hash dummy de custo equivalente quando o e-mail não
existe. Esse é o **inverso** da otimização de cadastro (que checa a existência antes de hashear): aqui,
pular a verificação quando o e-mail é desconhecido transformaria o tempo de resposta em um oráculo de
descoberta de conta, e portanto é proibido.

#### Scenario: E-mail inexistente ainda paga o custo do hash

- **WHEN** o login recebe um e-mail que não pertence a nenhuma pessoa
- **THEN** o sistema executa a verificação de senha contra um hash dummy antes de recusar
- **AND** não abre nenhuma sessão

#### Scenario: O caminho de recusa não pula a verificação

- **WHEN** o e-mail informado é desconhecido ou a pessoa não está ativa
- **THEN** o `PasswordHasher.verify` é invocado do mesmo modo que no caminho de senha incorreta
- **AND** o esforço computacional gasto não distingue os casos

### Requirement: Falha de login não vaza a existência de conta

O sistema SHALL recusar toda tentativa de login inválida com um **único** erro de domínio genérico
(`InvalidCredentials`), sem detalhe. Senha incorreta, e-mail inexistente e pessoa não-ativa (deletada ou
inativa) SHALL colapsar todos nesse mesmo erro. A recusa SHALL NOT ecoar o e-mail tentado, SHALL NOT
indicar qual fator falhou, e SHALL NOT permitir a quem está de fora distinguir "e-mail não existe" de
"e-mail existe, senha errada".

#### Scenario: Senha incorreta recusa com erro genérico

- **WHEN** o login recebe o e-mail de uma pessoa ativa mas a senha errada
- **THEN** o sistema retorna `InvalidCredentials`
- **AND** nenhuma sessão é aberta

#### Scenario: E-mail inexistente colapsa no mesmo erro

- **WHEN** o login recebe um e-mail que não pertence a nenhuma pessoa
- **THEN** o sistema retorna `InvalidCredentials`, indistinguível da recusa por senha incorreta

#### Scenario: Pessoa não-ativa colapsa no mesmo erro

- **WHEN** o login recebe as credenciais corretas de uma pessoa deletada ou não-ativa
- **THEN** o sistema retorna `InvalidCredentials`, indistinguível dos demais casos de recusa
- **AND** nenhuma sessão é aberta

### Requirement: Resultado do login é exaustivo e sem exceções

O sistema SHALL expor o resultado do login como um tipo **`sealed`** que representa exaustivamente ou o
sucesso (com a sessão criada e o token) ou o erro de domínio `InvalidCredentials`. O caminho de erro SHALL
NOT ser sinalizado por exceções lançadas, permitindo verificação exaustiva por `when` em tempo de
compilação.

#### Scenario: Consumidor trata todos os casos

- **WHEN** um consumidor invoca o login e ramifica sobre o resultado
- **THEN** o compilador exige o tratamento exaustivo de sucesso e do erro de domínio
- **AND** nenhum caminho de erro de domínio é comunicado via exceção lançada

