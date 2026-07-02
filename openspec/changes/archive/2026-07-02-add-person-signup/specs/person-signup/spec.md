## ADDED Requirements

### Requirement: Cadastro cria uma pessoa ativa

O sistema SHALL permitir cadastrar uma nova pessoa a partir de um e-mail, um nome e uma senha. Quando as
três entradas forem válidas e o e-mail ainda não estiver em uso, o sistema SHALL criar uma `Person` com
um identificador único, status **ativa**, e a senha armazenada apenas como um hash irreversível — nunca o
valor digitado — e SHALL persistir essa pessoa.

#### Scenario: Cadastro bem-sucedido

- **WHEN** o cadastro recebe um e-mail não usado, um nome válido e uma senha que cumpre a política
- **THEN** o sistema cria uma `Person` com status **ativa** e um identificador único
- **AND** armazena a senha apenas como hash irreversível, nunca o valor digitado
- **AND** persiste a pessoa e retorna um resultado de sucesso contendo a pessoa criada

#### Scenario: Senha nunca é persistida em texto puro

- **WHEN** uma pessoa é criada com sucesso
- **THEN** o valor armazenado da senha é um hash produzido pelo `PasswordHasher`
- **AND** o valor digitado da senha não é acessível a partir da `Person` persistida

### Requirement: E-mail é único no sistema

O sistema SHALL garantir que não existam duas pessoas com o mesmo e-mail simultaneamente. A checagem de
unicidade do e-mail SHALL ocorrer **antes** de qualquer processamento custoso da senha (hashing), de modo
que um cadastro fadado à recusa não pague esse custo.

#### Scenario: E-mail já em uso

- **WHEN** o cadastro recebe um e-mail que já pertence a uma pessoa existente
- **THEN** o sistema retorna um erro de domínio de conflito de cadastro
- **AND** não computa o hash da senha
- **AND** não persiste nenhuma pessoa

#### Scenario: Unicidade é verificada antes do hashing

- **WHEN** o e-mail informado já está em uso
- **THEN** o `PasswordHasher` não é invocado

### Requirement: Erros de cadastro não vazam a existência de conta

O sistema SHALL redigir os erros de cadastro de modo que ninguém de fora consiga descobrir se um e-mail
específico está cadastrado. O erro de e-mail já em uso SHALL NOT ecoar qual e-mail foi tentado nem
qualquer dado da pessoa existente. Regras públicas (como a política mínima de senha) MAY ser comunicadas
abertamente, pois não revelam nada sobre uma pessoa específica.

#### Scenario: Conflito de e-mail não ecoa o e-mail tentado

- **WHEN** o cadastro é recusado por e-mail já em uso
- **THEN** o erro retornado não contém o e-mail tentado
- **AND** não contém nenhum dado da pessoa existente

#### Scenario: Violação de política de senha pode ser explícita

- **WHEN** o cadastro é recusado porque a senha não cumpre a política
- **THEN** o erro pode indicar abertamente qual regra pública de senha foi violada

### Requirement: Validação de e-mail, nome e senha

O sistema SHALL validar de forma independente o formato do e-mail, a validade do nome e a política mínima
de robustez da senha. Uma entrada inválida SHALL resultar em um erro de domínio específico, sem criar
nem persistir qualquer pessoa. Nenhuma dessas validações SHALL depender do resultado de outra.

#### Scenario: E-mail com formato inválido

- **WHEN** o cadastro recebe um e-mail cujo formato é inválido
- **THEN** o sistema retorna um erro de domínio de e-mail inválido
- **AND** não cria nem persiste nenhuma pessoa

#### Scenario: Nome inválido

- **WHEN** o cadastro recebe um nome que não cumpre as regras de validade
- **THEN** o sistema retorna um erro de domínio de nome inválido
- **AND** não cria nem persiste nenhuma pessoa

#### Scenario: Senha não cumpre a política mínima

- **WHEN** o cadastro recebe uma senha que não cumpre a política mínima de robustez
- **THEN** o sistema retorna um erro de domínio de senha fraca
- **AND** não computa o hash nem persiste nenhuma pessoa

### Requirement: Resultado do cadastro é exaustivo e sem exceções

O sistema SHALL expor o resultado do cadastro como um tipo **`sealed`** que representa exaustivamente ou o
sucesso (com a pessoa criada) ou cada erro de domínio possível. O caminho de erro SHALL NOT ser sinalizado
por exceções lançadas, permitindo verificação exaustiva por `when` em tempo de compilação.

#### Scenario: Consumidor trata todos os casos

- **WHEN** um consumidor invoca o cadastro e ramifica sobre o resultado
- **THEN** o compilador exige o tratamento exaustivo de sucesso e de cada erro de domínio
- **AND** nenhum caminho de erro de domínio é comunicado via exceção lançada
