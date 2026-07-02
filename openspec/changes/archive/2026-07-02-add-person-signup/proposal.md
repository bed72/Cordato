## Why

`Person` (contexto `identity`) é a âncora de todo o sistema: orçamentos, gastos e pares penduram da
identidade de alguém. Nada pode existir antes de uma pessoa poder entrar no sistema. O cadastro
(`signUp`) é, portanto, a primeira fatia vertical de comportamento — e a que destrava todos os demais
contextos. Hoje só existe o stub `Main.kt` e o teste de arquitetura; não há domínio nem camadas.

## What Changes

- Introduz o **cadastro de pessoa** (`SignUpUseCase`): dado e-mail, nome e senha, cria uma `Person`
  **ativa** e a persiste, ou retorna um erro de domínio.
- Modela o domínio de `identity`: entidade `Person` (`id`, `Email`, `Name`, hash de senha, `status`),
  Value Objects `Email`, `Name` e senha crua com política, VO/opaco `PasswordHash`, e `status` como
  enum/sealed.
- Regra de ordem: a **unicidade do e-mail é checada antes** de qualquer hashing de senha (o processamento
  custoso não é pago por um cadastro que será recusado).
- Erros de domínio como hierarquia **`sealed`** retornada do use case (nunca exceções), com **redação que
  não vaza** a existência de conta ("e-mail já em uso" não ecoa o e-mail tentado; regra pública de senha
  pode ser dita abertamente).
- Define os **ports** que o cadastro precisa: `PersonRepository` (`existsByEmail` + persistência) e
  `PasswordHasher` (hashing), ambos em `identity/application/ports/`, implementados em
  `identity/infrastructure/`.
- Assenta um **`core/` mínimo**: ports de determinismo `Clock` e `IdGenerator` (contratos, sem
  comportamento) que o cadastro consome para gerar id/instante. `core/` segue a mesma estrutura de 3
  camadas.
- Fiação de DI (Koin) apenas na composition root (infrastructure).

Fora de escopo (changes futuros): autenticação/sessão, logout, exclusão de conta, e updates de
nome/e-mail/senha.

## Capabilities

### New Capabilities
- `person-signup`: cadastro de uma nova pessoa a partir de e-mail, nome e senha — validação de e-mail,
  nome e política de senha; unicidade de e-mail verificada antes do hashing; criação de `Person` ativa
  com senha armazenada apenas como hash; erros de domínio que não vazam a existência de conta.

### Modified Capabilities
<!-- Nenhuma: primeiro comportamento do sistema, não há specs existentes. -->

## Impact

- **Código novo** (nenhum existente é alterado além do scaffolding):
  - `core/` (mínimo): `domain`/`application` com ports `Clock` e `IdGenerator`.
  - `features/identity/domain/`: `entities/Person`, `value_objects/{Email,Name,RawPassword,PasswordHash}`,
    `errors/` (sealed), `enums/status`.
  - `features/identity/application/`: `ports/{PersonRepository,PasswordHasher}`, `data/` (comando de
    cadastro + resultado), `use_cases/SignUpUseCase`, `mappers/`.
  - `features/identity/infrastructure/`: `repositories/` (impl. `PersonRepository`, in-memory por ora),
    `adapters/` (impl. `PasswordHasher` e determinismo), composition root Koin.
- **Dependências**: adiciona lib de hashing de senha (ex.: bcrypt/argon2) usada só em `infrastructure/`;
  Koin para DI na borda. `domain/` e `application/` permanecem sem dependência de framework.
- **APIs**: nenhuma superfície HTTP ainda — o cadastro é exposto pela assinatura pública do
  `SignUpUseCase`; transporte fica para depois.
- **Testes**: testes de domínio (VOs, política de senha, erros) e de use case (ordem unicidade-antes-do-
  hash, não-vazamento) sobre implementações in-memory/fakes dos ports.
