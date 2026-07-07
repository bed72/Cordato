## Why

Depois do cadastro, uma pessoa precisa **entrar no sistema**. O `signIn` (autenticar/login) é a segunda
fatia vertical de `identity` e o **primeiro produtor de sessão** de todo o sistema — sem ele nenhuma rota
protegida tem como existir (a change em voo do guard só sabe *consumir* uma sessão que ainda não é
produzida por ninguém). É também a superfície mais sensível ao vazamento: a resposta não pode permitir a
um atacante distinguir "e-mail não existe" de "e-mail existe, senha errada", nem pelo corpo, nem pelo
status, nem pelo tempo de resposta.

## What Changes

- Introduz o **login de pessoa** (`SignInUseCase`): dado e-mail e senha, autentica uma pessoa **ativa** e,
  em sucesso, **abre uma sessão** — devolvendo um token opaco ao cliente —, ou retorna um erro de domínio.
- Erro de domínio único **`SignInError.InvalidCredentials`** (`data object`, sem detalhe): senha errada,
  e-mail inexistente e pessoa não-ativa **colapsam todos no mesmo erro** (não-vazamento de existência de
  conta). Resultado `sealed` exaustivo, sem exceções, espelhando `SignUpResult`.
- **Timing-constant**: o login SHALL **sempre** pagar o custo do `verify` de senha — contra um hash real
  quando o e-mail existe, contra um hash dummy quando não existe —, o **inverso** da otimização
  "checar existência antes de hashear" do cadastro. Caso contrário o tempo de resposta vira um oráculo de
  descoberta de conta.
- Assenta o conceito de **sessão no `core/`** (primeiro agregado persistido do kernel compartilhado):
  `SessionEntity` (id, pessoa, `hashToken`, expiração), um `SessionRepository` (`open`/`save` +
  `findActiveByToken` que o guard consome) e um `Tokenizer` que gera o token opaco (`SecureRandom` +
  base64url, devolvido **uma única vez** ao cliente) e o armazena apenas como **hash SHA-256** — nunca o
  token em claro. **Sem `micronaut-security`.**
- Ports crescem: `PasswordHasherPort.verify(password, hash): Boolean` (mesma lib at.favre bcrypt, sem
  dependência nova) e `PersonRepository.findByEmail(email): PersonEntity?` (retorna apenas pessoas
  **ativas**).
- Expõe a fatia HTTP do login: rota **`POST /sign-in`**, `SignInRequest` com validação de borda de
  **presença apenas** (`@NotBlank`, nunca `@Size`/`@Pattern` — política de senha na borda travaria usuário
  legítimo em drift de política e divergiria o sinal do 401), resposta **`{ token, expiresAt }`**, e um
  mapper de erro que traduz `InvalidCredentials` no **`401` neutro compartilhado** (code `UNAUTHENTICATED`)
  — indistinguível de uma rota protegida acessada sem sessão.
- Adiciona ao contrato de erro compartilhado do `core` o builder **`unauthorized(code, message)`** (irmão
  de `unprocessable`, já antecipado no comentário de `ErrorResponses.kt`), preservando a invariante de
  não-vazamento: mesma resposta para toda falha de autenticação, sem header `WWW-Authenticate`.

Fora de escopo (chores não-comportamentais, follow-up separado): **testes** e **documentação**
(`SignInControllerDoc`/OpenAPI + README). O controller, a rota e os DTOs de request/response **ficam** —
só a interface de doc OpenAPI é adiada. Também fora de escopo: logout, revogação e exclusão de conta.

## Capabilities

### New Capabilities
- `person-sign-in`: autenticação de uma pessoa por e-mail e senha no contexto `identity` — verificação
  timing-constant que sempre paga o custo do hash, erro de domínio único que não vaza a existência de
  conta, resultado `sealed` exaustivo, e abertura de sessão em caso de sucesso.
- `session-management`: o conceito de sessão de `core` — geração de token opaco devolvido uma única vez e
  armazenado apenas como hash, agregado `Session` com expiração, e o repositório que abre uma sessão e
  resolve uma sessão viva por token (consumido pelo guard).

### Modified Capabilities
- `identity-http-api`: adiciona o endpoint `POST /sign-in` (validação de borda de presença apenas,
  resposta `{ token, expiresAt }`, `InvalidCredentials` → `401` neutro).
- `identity-persistence`: adiciona a consulta `findByEmail` de `PersonRepository`, restrita a pessoas
  ativas.
- `http-error-handling`: adiciona o `401` neutro compartilhado (code `UNAUTHENTICATED`, sem
  `WWW-Authenticate`) como forma de rejeição de autenticação, via o novo builder `unauthorized`.

## Impact

- **Código novo (`core/`):** `domain/entities/SessionEntity`, `application/…/SessionRepository`,
  `application/ports/TokenizerPort`, `infrastructure/repositories/PersistenceSessionRepository` (+ record
  mapper), `infrastructure/adapters/TokenizerAdapter`, migração Flyway da tabela `sessions`, e o builder
  `unauthorized` em `infrastructure/http/responses/ErrorResponses.kt`.
- **Código novo (`features/identity/`):** `application/commands/SignInCommand`,
  `application/results/SignInResult`, `application/use_cases/SignInUseCase`,
  `domain/errors/SignInError`; fatia HTTP `infrastructure/http/{requests/SignInRequest,
  responses/SignInResponse, mappers/…}` e o método de rota no controller.
- **Código alterado:** `PasswordHasherPort` (+`verify`) e `PasswordHasherAdapter`; `PersonRepository`
  (+`findByEmail`) e `PersistencePersonRepository`; `IdentityFactory` e `CoreFactory` (fiação dos novos
  singletons); novas chaves em `i18n/messages.properties`.
- **Dependências:** nenhuma adicionada (bcrypt at.favre já presente; token via JDK `SecureRandom`/
  `MessageDigest`).
- **Coordenação:** produz o agregado `Session` + `SessionRepository.findActiveByToken` + o `401`
  `UNAUTHENTICATED` que a change em voo `replace-auth-binder-with-filter-guard` **consome** — sign-in é o
  produtor, o guard é o consumidor.
- **Fora de escopo:** testes e `SignInControllerDoc`/OpenAPI + README (follow-up).
