## Context

O cadastro (`person-signup`) já existe como fatia vertical completa (domínio → aplicação → infra → HTTP),
e é o modelo de referência em código para as camadas hexagonais do projeto. O `signIn` espelha essa
estrutura, mas introduz três novidades que o cadastro não tinha: (1) é o **primeiro produtor de sessão** do
sistema, então precisa assentar o conceito de sessão em `core/` — o primeiro **agregado persistido** do
kernel; (2) a superfície é a **mais sensível a vazamento** (o login não pode virar oráculo de descoberta de
conta por corpo, status ou tempo); (3) coordena com a change em voo do guard
(`replace-auth-binder-with-filter-guard`), que **consome** a sessão que esta produz.

Decisões já ratificadas com o usuário (registradas na memória de design): sessão mora em `core`; rota
`POST /sign-in`; corpo `{ token, expiresAt }`; sem `micronaut-security`.

## Goals / Non-Goals

**Goals:**
- Autenticar por e-mail + senha e abrir uma sessão, espelhando o shape de `SignUp`
  (`Command → UseCase → sealed Result`).
- Não-vazamento total: um único `InvalidCredentials`, `401 UNAUTHENTICATED` neutro, e verificação
  **timing-constant** (sempre paga o custo do hash).
- Assentar o conceito de sessão em `core`: `SessionEntity`, `SessionRepository` (`open` + `findActiveByToken`),
  `TokenizerPort`, tabela `sessions`, token opaco devolvido uma vez e armazenado só como hash.
- Produzir o `SessionRepository.findActiveByToken` e o `401 UNAUTHENTICATED` que o guard consome.

**Non-Goals:**
- Testes e documentação (`SignInControllerDoc`/OpenAPI + README) — chores de follow-up, fora desta change.
- Logout, revogação de sessão, exclusão de conta, refresh/rotação de token, papéis/escopos.
- O guard em si (`@Authenticated`/filtro) — vive na change em voo; aqui só produzimos o que ele consome.

## Decisions

### Sessão em `core`, não em `identity`
Mantém a linha do `CLAUDE.md` ("o conceito de token/sessão pertence a `core`"): sessão é um primitivo
ambiente do sistema, como `Clock`/`IdGenerator`. `identity/SignInUseCase` referencia os tipos de `core`
(`identity → core` é permitido, aponta para dentro). Alternativa considerada e recusada: mover o agregado
para `identity` e core expor um `SessionResolverPort` que identity implementa (inversão P&A). Recusada por
contradizer o `CLAUDE.md` e exigir emenda de doc numa change que deve ficar enxuta. Trade-off aceito: core
ganha seu **primeiro agregado persistido** (antes só tinha ports de determinismo), o que é uma ampliação
consciente do papel do kernel.

### Verificação timing-constant (inverso do cadastro)
O cadastro checa existência **antes** de hashear (otimização: cadastro fadado não paga o custo). O login faz
o **oposto**: `findByEmail` primeiro, mas `PasswordHasher.verify` é **sempre** chamado — contra o hash real
quando a pessoa existe e está ativa, contra um **hash dummy** (um bcrypt fixo pré-computado, de custo
equivalente) quando não existe ou não está ativa. Sem isso, o tempo de resposta distinguiria "e-mail
existe" de "não existe" — o mesmo oráculo que o corpo e o status escondem. `verify` retornar `true` no
caminho dummy é impossível (a senha nunca bate o dummy), mas o custo é pago.

### Token opaco: JDK, sem dependência nova
Geração: `SecureRandom` → bytes → base64url (sem padding). Armazenamento: `MessageDigest` SHA-256 do token
→ `hashToken`. Ambos JDK puro; bcrypt (at.favre) já está no classpath para senha. `TokenizerPort` em `core`
expõe `generate(): String` (token em claro) e `hash(token): String` (hash a persistir). A verificação por
token é comparar hashes, não desfazer o hash. Alternativa recusada: `micronaut-security` — seus defaults
vazam (razões de falha tipadas, `WWW-Authenticate: Bearer`, `Authentication` stringly-typed), e seu valor
real (JWT/OAuth2/roles) está fora de escopo. Condição de flip registrada na memória: se roles/OAuth2/JWT
entrarem no roadmap, adotar o módulo inteiro.

### `SignInResult.Success` carrega o token em claro
Diferença sutil frente ao `SignUpResult.Success(person)`: a `SessionEntity` só guarda o `hashToken`, mas o
cliente precisa do token em claro. Logo `Success(session, token)` carrega ambos — o token em claro nunca é
persistido nem recuperável depois, só trafega do use case até o response mapper.

### Validação de borda: só presença
`SignInRequest` usa apenas `@NotBlank` em `email`/`password`. **Nunca** `@Size`/`@Pattern`: validar política
de senha na borda travaria um usuário legítimo diante de uma mudança de política (uma senha antiga válida
seria recusada com `400` antes de sequer tentar autenticar) e divergiria o sinal do `401`. É o oposto do
`SignUpRequest`, que espelha as constantes dos value objects — aqui a borda só garante que há o que enviar
ao use case.

### `401 UNAUTHENTICATED` produzido aqui, consumido pelo guard
Esta change adiciona o builder `unauthorized(code, message)` em `ErrorResponses.kt` (já antecipado no
comentário do arquivo) e o `SignInErrorResponseMapper` que mapeia `InvalidCredentials → 401 UNAUTHENTICATED`
via i18n. O mesmo code/shape é o que o filtro do guard emitirá para rota protegida sem sessão — por isso a
resposta de login-recusado e a de rota-protegida-sem-sessão são idênticas por construção.

## Risks / Trade-offs

- **[Dois emissores do `401 UNAUTHENTICATED` — esta change e o guard]** → esta change é dona da **forma**
  (builder `unauthorized` + code + i18n); o guard é dono do **handler de rota**. Ao integrar as duas, o
  guard reusa o builder e o code em vez de redefini-los. Nenhuma das duas deve introduzir um shape próprio.
- **[Hash dummy mal calibrado enfraquece a defesa de timing]** → o dummy precisa ter o mesmo custo (mesmo
  work factor bcrypt) do hash real; se for barato demais, o oráculo de timing volta. Usar a mesma
  configuração do `PasswordHasherAdapter`.
- **[Core ganha persistência/agregado — ampliação de papel]** → aceito e alinhado com o usuário; o
  `CLAUDE.md` já previa "o conceito de token/sessão pertence a core". Mantém-se a estrutura de 3 camadas do
  core (a tabela `sessions` via Flyway espelha o padrão de `identity-persistence`).
- **[Política de expiração de sessão]** → o TTL (~1 dia) é definido na abertura via `Clock.now() + TTL`;
  fica como constante em `core` até que revogação/refresh (fora de escopo) exijam mais. `findActiveByToken`
  recebe o instante atual e compara com `expiresAt`.

## Migration Plan

Change puramente aditiva — nenhuma rota, tabela ou contrato existente muda de forma. Uma nova migração
Flyway cria a tabela `sessions`; o `Main` já força as migrações no boot (fail-fast). Sem rollback de dados
necessário (tabela nova, nenhum backfill). O follow-up de testes e OpenAPI/README vem em change/PR separado.

## Open Questions

- Nenhuma bloqueante. As três decisões antes em aberto (ownership da sessão, rota, corpo da resposta) foram
  ratificadas pelo usuário e estão registradas na memória `signin-design-debate`.
