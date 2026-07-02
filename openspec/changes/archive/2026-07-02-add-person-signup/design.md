## Context

Cordato está em fase de design: só existem `Main.kt` (stub) e o teste de arquitetura Konsist. Este é o
**primeiro comportamento** a ser implementado, então ele carrega peso estrutural além do próprio
cadastro — assenta a forma do módulo `identity` (3 camadas hexagonais) e um `core/` mínimo.

Restrições herdadas (CLAUDE.md e READMEs, fonte da verdade do domínio):
- Dependências apontam para dentro: `infrastructure → application → domain`. `domain/` nunca conhece
  lib/framework.
- Value Objects onde há regra de validade; erros de domínio como `sealed` retornados (não exceções);
  DI (Koin) só na composition root.
- Determinismo (relógio, id) mora em `core/`.
- `identity` nunca vaza se um e-mail está cadastrado.

## Goals / Non-Goals

**Goals:**
- Implementar `SignUpUseCase` end-to-end sobre ports, com resultado `sealed`.
- Fixar o formato de camadas de `identity` que os próximos contextos vão copiar.
- Assentar `core/` mínimo com os ports de determinismo `Clock` e `IdGenerator`.
- Garantir por construção: unicidade-antes-do-hash e não-vazamento de existência de conta.

**Non-Goals:**
- Autenticação/sessão, logout, exclusão de conta, updates (name/email/password) — changes futuros.
- Qualquer superfície de transporte (HTTP/rota). O cadastro é exposto pela assinatura pública do use case.
- Persistência real (banco). Um `PersonRepository` in-memory basta para esta fatia; a troca por um
  adapter real é transparente por ser um port.
- `core/` de dinheiro — irrelevante aqui.

## Decisions

### 1. `Password` é dois tipos, não um
- **`RawPassword` (VO, `domain/`)**: encapsula a senha digitada e valida a **política pública** (ex.:
  tamanho mínimo). Existe só o tempo de validar e ser passada ao hasher.
- **`PasswordHash` (VO/opaco, `domain/`)**: o que a `Person` guarda. Sem operação de "reverter".
- **`PasswordHasher` (port, `application/ports/`)**: `hash(RawPassword): PasswordHash`. A implementação
  (bcrypt/argon2) vive em `infrastructure/adapters/`.
- **Rationale**: hashing depende de lib e é custoso; manter isso fora do `domain/` preserva a pureza e
  permite ordenar unicidade-antes-do-hash. **Alternativa rejeitada**: um único `Password` que se
  auto-hasheia — vazaria dependência de lib para o `domain/` e misturaria política com hashing.

### 2. Ordem no use case: validar → checar unicidade → hashear → persistir
Sequência do `SignUpUseCase`:
1. Construir `Email`, `Name`, `RawPassword` (validações independentes; qualquer falha retorna o erro
   correspondente sem seguir adiante).
2. `PersonRepository.existsByEmail(email)` — se existe, retorna conflito **sem** hashear.
3. `PasswordHasher.hash(rawPassword)`.
4. Montar `Person` com `IdGenerator.newId()` e status ativo (carimbo de `Clock` se a entidade registrar
   criação).
5. `PersonRepository.save(person)` e retornar sucesso.
- **Rationale**: o passo 2 antes do 3 é requisito de domínio (não pagar hash por cadastro recusado) e é
  observável em teste (o hasher fake não é invocado no caminho de conflito).

### 3. Resultado `sealed`, sem exceções
`SignUpResult` = `sealed interface` com `Success(person)` e um erro `sealed` (`SignUpError`) cobrindo
`EmailAlreadyInUse`, `InvalidEmail`, `InvalidName`, `WeakPassword`. O use case retorna esse tipo; nenhum
erro de domínio é lançado.
- **Rationale**: exaustividade em `when` no compilador e testes sem `assertThrows`, conforme CLAUDE.md.
- **Ordem de reporte quando múltiplas entradas são inválidas**: reportar o **primeiro** erro de validação
  encontrado (fail-fast), começando pelo e-mail — mantém o resultado simples (um erro por vez) e alinha
  com a ordem "e-mail antes de senha". Ver Open Questions se agregação vier a ser desejada.

### 4. Não-vazamento por construção
- `EmailAlreadyInUse` **não carrega** o e-mail tentado nem dados da pessoa existente — é um marcador
  vazio (ou com contexto público mínimo).
- `WeakPassword` **pode** carregar qual regra pública foi violada (não revela nada sobre uma pessoa).
- **Rationale**: transforma a garantia da spec em uma propriedade do tipo, não em disciplina do chamador.

### 5. `core/` mínimo
`core/application/ports/` (ou `core/domain/ports/` conforme onde contratos de determinismo assentam
melhor — ver Open Questions): `Clock.now(): Instant` e `IdGenerator.newId(): <IdType>`. Implementações
(system clock, UUID) em `core/infrastructure/adapters/`. Sem lógica de negócio.
- **Rationale**: determinismo testável (fakes fixos em teste) e reuso pelos próximos contextos.

### 6. Formato de camadas de `identity` (referência para os demais contextos)
```
core/
  domain/ | application/ (ports: Clock, IdGenerator) | infrastructure/adapters/
features/identity/
  domain/
    entities/Person
    value_objects/{Email, Name, RawPassword, PasswordHash}
    errors/SignUpError (sealed)
    enums/PersonStatus            # ou sealed
  application/
    ports/{PersonRepository, PasswordHasher}
    data/{SignUpCommand, SignUpResult}
    use_cases/SignUpUseCase
    mappers/
  infrastructure/
    repositories/InMemoryPersonRepository (+ models/, mappers/)
    adapters/{PasswordHasher impl, determinismo se aplicável}
    di/ (módulo Koin — composition root)
```
- `SignUpCommand` é o read-model de entrada (strings cruas); a construção dos VOs ocorre dentro do use
  case, para que a validação seja parte do comportamento e não do chamador.

## Risks / Trade-offs

- **[Escolha do algoritmo de hash]** → Isolada atrás do `PasswordHasher`; começar com bcrypt/argon2 via
  lib e trocar sem tocar `domain`/`application`.
- **[`IdType` ainda indefinido — UUID vs. tipado]** → Definir em `core/` agora (provável `UUID` ou um VO
  `PersonId`); por ser port, a troca é local. Ver Open Questions.
- **[Persistência in-memory não valida unicidade concorrente]** → Aceitável nesta fatia; o adapter real
  futuro imporá a unicidade também no nível de storage (índice único), reforçando a checagem do use case.
- **[Política de senha mínima ainda não numericamente fixada]** → Escolher um mínimo público simples
  (ex.: comprimento) agora; endurecer depois é aditivo e não quebra a spec.

## Migration Plan

Não aplicável — nenhum comportamento ou dado existente. Entrega puramente aditiva (novo `core/` e novo
módulo `identity`). "Rollback" é remover os pacotes novos.

## Open Questions

- **`Clock`/`IdGenerator` em `core/domain/ports/` ou `core/application/ports/`?** Contratos de
  determinismo são fronteira com o mundo externo (relógio/aleatório), o que sugere `application/ports/`;
  decidir na implementação e manter consistente para os próximos contextos.
- **Tipo de id**: `UUID` cru vs. VO `PersonId` (tipado). Recomendação: VO tipado no `identity/domain` com
  o `IdGenerator` do `core/` produzindo o valor bruto — confirmar no apply.
- **Agregação de erros de validação**: fail-fast (decidido) vs. retornar todos os erros de uma vez. Se o
  produto pedir múltiplos erros no futuro, o resultado `sealed` comporta um caso `ValidationFailed(list)`
  aditivamente.
