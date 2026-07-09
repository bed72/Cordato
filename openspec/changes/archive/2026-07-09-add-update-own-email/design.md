## Context

`identity` já tem a fatia de escrita do próprio nome: `UpdateNameCommand` → `UpdateNameUseCase` →
`UpdateNameResult` (sealed: `Success` com a visão pública ou `InvalidName`/`PersonNotFound`), exposta por
`PATCH /persons/me` (`@Authenticated`), com o `PersonController` delegando a partir do
`AuthenticatedActor.personId` e devolvendo `PersonResponse`. A sessão órfã já colapsa no `401` neutro
compartilhado; o `NameValueObject` é a autoridade única do nome. Esta mudança adiciona a troca do **e-mail**,
reusando essa fatia, mas o e-mail carrega três coisas que o nome não tinha:

1. **É sensível** — é o identificador de login e o canal de recuperação. Por decisão de produto, trocá-lo é
   uma operação de *step-up*: exige a **confirmação da senha atual**, como a exclusão de conta já exige
   (README de `identity`), diferente do nome ("o único campo mutável e não-sensível").
2. **É único globalmente** — o `EmailValueObject` novo pode colidir com o e-mail de outra pessoa; a mesma
   invariante de unicidade e o mesmo não-vazamento de existência de conta do cadastro se aplicam.
3. **Tem um no-op legítimo** — trocar para o próprio e-mail atual não é conflito.

O `SignUpUseCase` já mostra o padrão de unicidade (pré-checagem `existsByEmail` + `signUp` autoritativo), o
`SignInUseCase` mostra a confirmação de senha (`hasher.verify`), e o `SignInError.InvalidCredentials` mostra
o `401` neutro para credenciais — esta mudança compõe os três.

## Goals / Non-Goals

**Goals:**
- Um endpoint protegido `PATCH /persons/me/email` que troca **apenas** o e-mail da própria pessoa, mediante
  confirmação da senha atual.
- Reusar `PersonResponse`/`PersonResponseMapper`, o `401` neutro e o contrato de erro compartilhado — zero
  divergência de forma com as demais rotas de pessoa.
- Manter as invariantes transversais do contexto: nenhuma senha vaza; o conflito de e-mail e a sessão órfã
  não viram oráculo de descoberta de conta; senha-incorreta e sessão-órfã são indistinguíveis de um token
  inválido.
- Tornar as duas edições **simétricas**: sub-recursos de campo único `/persons/me/name` e
  `/persons/me/email`.

**Non-Goals:**
- Trocar senha, nome ou status por esta rota (cada um tem regra própria; a troca de senha pede sua própria
  mudança).
- Um `PATCH /persons/me` de patch parcial multi-campo — deliberadamente evitado, como já era no nome.
- Um fluxo de **verificação/confirmação do novo e-mail** (enviar link para o novo endereço antes de efetivar).
  É a evolução natural para um e-mail sensível, mas fica fora de escopo aqui — a troca é efetivada
  diretamente após a confirmação de senha; ver Open Questions.
- Editar o e-mail de **outra** pessoa. A rota opera só sobre o ator autenticado.

## Decisions

**Novo use case dedicado, espelhando a fatia do `UpdateName` e compondo a confirmação de senha.** Novos
tipos em `identity`, com os sufixos de categoria: `UpdateEmailCommand(personId, email, password)`
(`application/commands/`), `UpdateEmailResult` (`application/results/`, sealed `Success(person)` /
`Failure(error)`), `UpdateEmailError` (`domain/errors/`, sealed com `InvalidEmail`, `EmailAlreadyInUse`,
`InvalidCredentials`, `PersonNotFound`), `UpdateEmailUseCase` (`application/use_cases/`, recebendo
`PasswordHasherPort` + `PersonRepository`). A ordem do `invoke`:
1. `EmailValueObject.of(command.email)` → `null` ⇒ `InvalidEmail`.
2. `repository.findById(personId)` → `null` ⇒ `PersonNotFound`.
3. `hasher.verify(command.password, person.hash)` → `false` ⇒ `InvalidCredentials`.
4. Se o novo e-mail (normalizado) == `person.email` ⇒ `Success(person)` (no-op idempotente; sem escrita).
5. `repository.updateEmail(person.id, email)` → ramifica o desfecho (abaixo).
- *Alternativa considerada*: estender `UpdateNameUseCase` para multi-campo. Rejeitada — mistura um campo
  não-sensível com um sensível (regras de confirmação diferentes) e some com a exaustividade limpa de cada
  `sealed result`.

**`PersonRepository.updateEmail` retorna um desfecho de três estados, não um `Boolean`.** Diferente de
`updateName` (atualizado vs. não-ativa — dois estados, `Boolean` basta), a troca de e-mail tem **três**
desfechos autoritativos na fronteira de persistência: atualizado, **e-mail já em uso** (colisão de unicidade)
e **pessoa não-ativa** (zero linhas). Um `Boolean` colapsaria "em uso" e "não-ativa", que mapeiam para erros
diferentes (`422` vs `401`). Modela-se como um `enum`/`sealed` pequeno e puro no `application` (ex.
`UpdateEmailOutcome { UPDATED, EMAIL_TAKEN, PERSON_INACTIVE }`), retornado pelo port. O adapter jOOQ faz
`UPDATE person SET email=? WHERE id=? AND status=ACTIVE`, capturando a violação da restrição de unicidade →
`EMAIL_TAKEN`; zero linhas afetadas → `PERSON_INACTIVE`; uma linha → `UPDATED`. A unicidade é decidida no
datastore (autoritativa), fechando a corrida concorrente como o `signUp` já faz — não uma mera pré-checagem.
- *Alternativa*: pré-checar `existsByEmail` e usar `updateEmail: Boolean`. Rejeitada — a pré-checagem não
  fecha a corrida (dois writes concorrentes passariam), e o `Boolean` perde o terceiro estado.

**Confirmação de senha reusa o `PasswordHasherPort.verify`, e sua falha é `InvalidCredentials` → `401`
neutro.** A senha atual é conferida contra o hash guardado **antes** de qualquer escrita (passo 3). A falha
não é de política (não reusa `WeakPassword`) — é uma recusa de credencial, mapeada ao **mesmo** `401` neutro
(`UNAUTHENTICATED`, `error.authentication.message`) que o guard, o `SignInError.InvalidCredentials` e o
`PersonNotFound` já emitem.

**Senha incorreta e sessão órfã colapsam no mesmo `401` neutro.** O `UpdateEmailErrorResponseMapper` ramifica
exaustivamente: `InvalidEmail` → `unprocessable("INVALID_EMAIL", …)`; `EmailAlreadyInUse` →
`unprocessable("EMAIL_UPDATE_REJECTED", …)` genérico e escalar (postura de cadastro); `InvalidCredentials` e
`PersonNotFound` → **ambos** `unauthorized("UNAUTHENTICATED", messages("error.authentication.message"))`.
Colapsar os dois `401` no corpo idêntico é deliberado: um chamador com token válido roubado (sequestro de
sessão) que sondasse a rota não conseguiria distinguir "conta ainda existe, senha errada" de "conta
apagada" — a plena neutralidade fecha esse oráculo, além de ser a forma mais simples.
- *Alternativa considerada*: dar a `InvalidCredentials` uma mensagem específica ("senha incorreta") para
  melhor UX. Rejeitada em favor da neutralidade plena — a mensagem específica reabriria a distinção acima; o
  ganho de UX não compensa (só o próprio dono chega a esse ramo, mas a uniformidade com o guard vale mais).

**Conflito de e-mail é `422`, nunca `409` nem `FieldError`.** `EmailAlreadyInUse` compartilha o `422` das
demais recusas de domínio da troca — dar-lhe um `409 Conflict` "de livro" faria o status delatar que o e-mail
está cadastrado (o mesmo oráculo que a mensagem genérica esconde), exatamente o anti-padrão que o CLAUDE.md
proíbe. Mensagem genérica, escalar, sem `field="email"`.

**Validação em duas camadas, uma definição.** `UpdateEmailRequest` (`@Serdeable`) carrega
`@NotBlank(message="{…}")` + `@Pattern(regexp = EmailValueObject.PATTERN, message="{…}")` no `email` e
`@NotBlank(message="{…}")` no `password` — `400` antecipado por campo. A borda **não** aplica política de
senha (só presença): travar por política recusaria uma senha legítima definida antes de um endurecimento de
política, e a confirmação apenas confere o hash. O `EmailValueObject` segue autoridade única do formato;
mensagens por chave i18n; `code` inline.

**Rota simétrica, e o nome move para `/me/name`.** O método `PATCH("/me/email")` entra no `PersonController`
(mesmo controller do `me()` e da troca de nome), `@Authenticated`, injetando o `AuthenticatedActor` e o
`@Valid @Body UpdateEmailRequest`, retornando `HttpResponse<*>` com `PersonResponse` no sucesso. Para manter a
simetria de sub-recursos de campo único, a troca de nome **move** de `PATCH("/me")` para `PATCH("/me/name")`
(mesmo comportamento, novo path) — evita um `PATCH /me` ambíguo e alinha os dois campos mutáveis como
`/me/<campo>`. A documentação (`@Operation`/`@ApiResponse` com `200 → PersonResponse`, `4xx → ErrorResponse`)
vai no `PersonControllerDoc`, e o path do nome é atualizado lá e no teste e2e.

## Risks / Trade-offs

- **Corrida entre a troca e a deleção de conta** (a pessoa é apagada entre o `findById`/`verify` e o
  `UPDATE`) → Mitigação: o `UPDATE` é condicionado à pessoa **ativa** no `WHERE`; zero linhas ⇒
  `PERSON_INACTIVE` ⇒ `PersonNotFound` ⇒ `401` neutro, sem meia-troca.
- **Corrida de unicidade** (dois pedidos tentam o mesmo e-mail livre ao mesmo tempo) → Mitigação: a restrição
  de unicidade no datastore é autoritativa; o perdedor captura a violação ⇒ `EMAIL_TAKEN` ⇒ `EmailAlreadyInUse`,
  nunca dois e-mails iguais nem uma exceção vazada.
- **E-mail trocado sem verificar posse do novo endereço** → Trade-off aceito no escopo: a confirmação de
  senha protege contra sequestro de sessão, mas não prova que a pessoa controla o novo e-mail (risco de erro
  de digitação travar o login). A verificação do novo e-mail é a evolução natural (Open Questions), fora do
  escopo desta mudança.
- **BREAKING no path do nome** (`PATCH /persons/me` → `/me/name`) → Baixo risco: a rota foi adicionada há
  pouco e ainda não foi liberada; o ganho de simetria supera. `GET /persons/me` permanece.
- **Drift entre borda e domínio no formato do e-mail** → Mitigação embutida: o `@Pattern` referencia
  `EmailValueObject.PATTERN`; a convenção e o teste de arquitetura barram o literal duplicado.

## Open Questions

- **Verificação do novo e-mail antes de efetivar** (enviar um link/código para o novo endereço e só então
  trocar) — desejável para um campo de login/recuperação, mas depende de um canal de envio de e-mail que o
  sistema ainda não tem. Fica como mudança futura; esta efetiva a troca direto após a confirmação de senha.
- **Invalidar sessões após a troca de e-mail** — trocar o identificador de login poderia justificar encerrar
  outras sessões vivas. Não incluído aqui (a troca não mexe em sessão); revisitar junto com a troca de senha,
  que tem a mesma pergunta.
