## 1. core/ mínimo (determinismo)

- [x] 1.1 Criar a estrutura de pacotes de `core/` (domain/application/infrastructure) seguindo o formato de 3 camadas
- [x] 1.2 Definir o port `Clock` (`now(): Instant`) na camada de contratos de `core/`
- [x] 1.3 Definir o port `IdGenerator` (`newId(): <IdType>`) na camada de contratos de `core/`
- [x] 1.4 Implementar adapters concretos em `core/infrastructure/adapters/` (system clock, gerador de UUID)
- [x] 1.5 Testes de determinismo com fakes fixos (clock congelado, id previsível)

## 2. identity — domínio

- [x] 2.1 Criar a estrutura de pacotes de `features/identity/` (domain/application/infrastructure)
- [x] 2.2 VO `Email` com validação de formato (inválido → falha de construção)
- [x] 2.3 VO `Name` com regras de validade
- [x] 2.4 VO `RawPassword` que valida a política mínima pública (ex.: comprimento)
- [x] 2.5 VO/opaco `PasswordHash` (sem operação de reversão)
- [x] 2.6 `PersonStatus` (enum/sealed) com valores ativa/apagada; cadastro nasce ativa
- [x] 2.7 Definir `PersonId` (VO tipado) conforme decisão do design
- [x] 2.8 Entidade `Person` (`id`, `Email`, `Name`, `PasswordHash`, `status`)
- [x] 2.9 Erros `sealed` `SignUpError`: `EmailAlreadyInUse` (sem e-mail/dados), `InvalidEmail`, `InvalidName`, `WeakPassword` (pode citar a regra pública)
- [x] 2.10 Testes de domínio dos VOs, política de senha e não-vazamento do `EmailAlreadyInUse`

## 3. identity — aplicação

- [x] 3.1 Port `PersonRepository` (`existsByEmail(email): Boolean`, `save(person)`)
- [x] 3.2 Port `PasswordHasher` (`hash(RawPassword): PasswordHash`)
- [x] 3.3 Read-models em `data/`: `SignUpCommand` (entrada crua) e `SignUpResult` (`sealed`: `Success(person)` | `SignUpError`)
- [x] 3.4 `SignUpUseCase`: validar → `existsByEmail` (antes do hash) → `hash` → montar `Person` (id/clock) → `save` → sucesso
- [x] 3.5 Mappers necessários entre command/entidade se aplicável — nenhum necessário: o use case monta a `Person` diretamente
- [x] 3.6 Teste: cadastro bem-sucedido cria pessoa ativa, id único e senha só como hash
- [x] 3.7 Teste: e-mail já em uso retorna conflito e o `PasswordHasher` fake NÃO é invocado (unicidade antes do hash)
- [x] 3.8 Teste: e-mail inválido / nome inválido / senha fraca retornam o erro específico e não persistem
- [x] 3.9 Teste: resultado `sealed` é exaustivo em `when` e nenhum erro de domínio é lançado

## 4. identity — infraestrutura

- [x] 4.1 `InMemoryPersonRepository` implementando o port (com `models/`/`mappers/` se necessário)
- [x] 4.2 Adapter `PasswordHasher` com lib de hashing (bcrypt/argon2) em `infrastructure/adapters/`
- [x] 4.3 Adicionar a dependência de hashing ao `build.gradle.kts` (usada só em infrastructure)
- [x] 4.4 Módulo Koin (composition root) fiando `SignUpUseCase`, ports e adapters — sem Koin em domain/application

## 5. Fechamento

- [x] 5.1 `./gradlew build` e `./gradlew test` verdes
- [x] 5.2 Teste de arquitetura Konsist passa (dependências apontam para dentro; domain sem lib/DI)
- [x] 5.3 `/opsx:sync` para reconciliar specs e `/opsx:archive` após revisão
