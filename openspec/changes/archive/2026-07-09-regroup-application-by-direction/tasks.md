## 1. Migrar `core/application/` (só lado *driven*)

- [x] 1.1 Criar o segmento `core/application/driven/` e mover `ports/` (`ClockPort`, `IdGeneratorPort`, `MessagePort`, `TokenizerPort`) e `repositories/` (`SessionRepository`) para `core/application/driven/ports/` e `core/application/driven/repositories/`
- [x] 1.2 Atualizar a declaração de `package` dos 5 arquivos movidos para `...core.application.driven.ports` / `...core.application.driven.repositories`
- [x] 1.3 Atualizar todos os imports dos ~33 sites que referenciam `core.application.ports.*` / `core.application.repositories.*` (adapters em `core/infrastructure`, `CoreFactory`, o guard de auth em `core/infrastructure/http/authentication`, e testes/fakes em `core/factories` e `support/`)
- [x] 1.4 Confirmar que `core/application/` não tem `driving/` nem `mappers/` (o kernel não tem use cases) e que nenhuma pasta de categoria ficou solta na raiz

## 2. Migrar `features/identity/application/` — lado *driving*

- [x] 2.1 Criar `identity/application/driving/` e mover `use_cases/` (`Me`, `SignIn`, `SignUp`, `UpdateName`, `UpdateEmail`), `commands/` (os 5 `*Command`) e `results/` (os 5 `*Result`) para baixo dele
- [x] 2.2 Atualizar a declaração de `package` de todos os arquivos movidos para `...identity.application.driving.<categoria>`

## 3. Migrar `features/identity/application/` — lado *driven*

- [x] 3.1 Criar `identity/application/driven/` e mover `ports/` (`PasswordHasherPort`), `repositories/` (`PersonRepository`) e `outcomes/` (`UpdateEmailOutcome`) para baixo dele
- [x] 3.2 Atualizar a declaração de `package` dos arquivos movidos para `...identity.application.driven.<categoria>`

## 4. Atualizar os imports cruzados de `identity`

- [x] 4.1 Atualizar os ~46 sites que importam `features.identity.application.{commands,results,outcomes,ports,repositories,use_cases}.*`: `main/IdentityFactory.kt`, os controllers e docs em `identity/controllers`, os mappers de HTTP em `identity/infrastructure/http/mappers`, o `PersistencePersonRepository`, e os testes (`application/*UseCaseTest`, `factories/FakePersonRepository`, `SignUpUseCaseMockFactory`, testes de HTTP)
- [x] 4.2 Verificar que `identity` não tem `application/mappers/` hoje (nada a mover); a regra "mappers neutro na raiz" fica documentada para quando surgir

## 5. Verificação

- [x] 5.1 `./gradlew build` verde — o compilador Kotlin resolve todos os `package`/imports e o Konsist (`ArchitectureTest`, globs `..application..`) continua passando sem alteração de regra
- [x] 5.2 Rodar `./gradlew test` e confirmar a suíte inteira verde, provando que nenhum comportamento mudou (só movimentação de arquivos)
- [x] 5.3 Conferir que `domain/` e `infrastructure/` não tiveram nenhum arquivo movido de pacote por causa deste change

## 6. Documentação

- [x] 6.1 Atualizar o CLAUDE.md: a tabela de camadas passa a mostrar `application/` agrupado por `driving/` (`use_cases`, `commands`, `results`) e `driven/` (`ports`, `repositories`, `outcomes`), com `mappers/` neutro na raiz
- [x] 6.2 Documentar no CLAUDE.md a regra fixa "sem balde genérico (`data/`/`dto/`/`models/`); se agrupar, é por direção do hexágono", preservando explicitamente a regra "pasta-folha = sufixo de categoria" (segmentos `driving`/`driven` não impõem sufixo)
- [x] 6.3 Remover o `proposal.md` da raiz do repositório (seu conteúdo foi consolidado no `design.md` deste change)

## 7. Reconciliação

- [x] 7.1 Reconciliar specs (`/opsx:sync`) — cria `openspec/specs/application-layer-structure/spec.md` a partir do delta
- [x] 7.2 Arquivar a change (`/opsx:archive`)
