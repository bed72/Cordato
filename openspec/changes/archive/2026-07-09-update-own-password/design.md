## Context

`identity` já tem duas fatias de escrita sobre a própria pessoa: o nome (`UpdateNameCommand` →
`UpdateNameUseCase` → `UpdateNameResult`, exposto por `PATCH /persons/me/name`) e o e-mail
(`UpdateEmailCommand` → `UpdateEmailUseCase`, exposto por `PATCH /persons/me/email`, com confirmação de senha
via `PasswordHasherPort.verify`). Ambas partem do `AuthenticatedActor.personId` que a borda resolveu,
devolvem `PersonResponse`, e colapsam a sessão órfã no `401` neutro compartilhado. Esta mudança adiciona a
troca da **senha**, reusando essa fatia, mas a senha carrega quatro coisas que nome e e-mail não tinham:

1. **É o segredo de autenticação, não um dado de perfil.** Trocá-la é a operação mais sensível depois da
   exclusão de conta: exige a **confirmação da senha atual** (step-up), como a troca de e-mail já exige.
2. **Não é única nem consultável.** Diferente do e-mail (unicidade global, desfecho de três estados), a senha
   não colide com a de ninguém: a persistência tem só **dois** desfechos (atualizada vs. pessoa não-ativa),
   então um `Boolean` basta — como o `updateName`, não como o `updateEmail`.
3. **A nova senha passa por uma política pública.** O `PasswordValueObject.of` (mínimo de `MIN_LENGTH`) é a
   autoridade única; uma senha fraca é uma falha de domínio (`WeakPassword`). Ao contrário da unicidade de
   e-mail, essa regra é **pública** (o README de `identity` diz que "uma regra pública como o tamanho mínimo
   de senha pode ser dita abertamente") — pode ter mensagem específica sem virar oráculo.
4. **Trocar a senha encerra as demais sessões.** É o gatilho clássico de comprometimento. O token opaco foi
   escolhido no `identity` justamente para permitir revogação imediata no servidor; a exclusão de conta já
   invalida a sessão atomicamente. Aqui, a decisão (deixada em aberto pelo design da troca de e-mail) é:
   **revogar todas as outras sessões vivas da pessoa, mantendo a atual válida.**

O `SignInUseCase` já mostra a confirmação de senha (`hasher.verify` contra o hash real, `DUMMY_HASH` quando
ausente) e a criação de sessão (`SessionRepository.open`); o `SignUpUseCase` mostra `hasher.create` a partir
de um `PasswordValueObject` validado — esta mudança compõe os dois com uma revogação em massa nova.

## Goals / Non-Goals

**Goals:**
- Um endpoint protegido `PATCH /persons/me/password` que troca **apenas** a senha da própria pessoa, mediante
  confirmação da senha atual.
- Reusar `PersonResponse`/`PersonResponseMapper`, o `401` neutro e o contrato de erro compartilhado — zero
  divergência de forma com as demais rotas de pessoa.
- Encerrar as demais sessões vivas da pessoa ao trocar a senha, mantendo **a sessão que fez a troca** válida.
- Manter as invariantes transversais do contexto: nenhuma senha vaza (nem a atual, nem a nova); senha atual
  incorreta e sessão órfã são indistinguíveis entre si e de um token inválido.
- Completar a simetria de sub-recursos de campo único: `/persons/me/name`, `/persons/me/email`,
  `/persons/me/password`.

**Non-Goals:**
- Um fluxo de **recuperação de senha** por e-mail ("esqueci minha senha", reset via link para quem **não**
  tem sessão nem lembra a senha atual). É uma capacidade distinta (não é step-up autenticado) e depende de um
  canal de envio de e-mail que o sistema ainda não tem. Fica como mudança futura.
- Trocar nome, e-mail ou status por esta rota; cada um tem a sua.
- Política de senha mais rica (histórico de senhas anteriores, complexidade além do tamanho mínimo,
  expiração). A política segue sendo o `MIN_LENGTH` do `PasswordValueObject`, autoridade única.
- Revogar **também** a sessão atual (forçar re-login em todo lugar). Foi considerado e rejeitado (abaixo).

## Decisions

**Novo use case dedicado, espelhando a fatia do `UpdateEmail` e compondo `create` + `verify` + revogação.**
Novos tipos em `identity`, com os sufixos de categoria: `UpdatePasswordCommand(personId, sessionId,
currentPassword, newPassword)` (`application/driving/commands/`), `UpdatePasswordResult`
(`application/driving/results/`, sealed `Success(person)` / `Failure(error)`), `UpdatePasswordError`
(`domain/errors/`, sealed com `WeakPassword`, `SamePassword`, `InvalidCredentials`, `PersonNotFound`),
`UpdatePasswordUseCase` (`application/driving/use_cases/`, recebendo `PasswordHasherPort`, `PersonRepository`
e o `SessionRepository` do core). A ordem do `invoke`:
1. `PasswordValueObject.of(command.newPassword)` → `null` ⇒ `WeakPassword` (valida a **nova** senha pela
   política antes de tocar em qualquer coisa; a autoridade é o value object).
2. `repository.findById(personId)` → `null` ⇒ `PersonNotFound`.
3. `hasher.verify(command.currentPassword, person.hash)` → `false` ⇒ `InvalidCredentials`.
4. `hasher.verify(command.newPassword, person.hash)` → `true` ⇒ `SamePassword` (a nova senha coincide com a
   atual; recusa a rotação nula, sem escrever).
5. `val hash = hasher.create(newPassword)`; `repository.updatePassword(person.id, hash)` → `false` ⇒
   `PersonNotFound` (corrida com a exclusão de conta entre o `findById` e o `UPDATE`).
6. `sessions.revokeAllForPersonExcept(personId, command.sessionId)` — encerra as demais sessões, poupando a
   atual; a troca já foi persistida, então a revogação é o efeito colateral final.
7. `Success(person)` — a visão pública (id, nome, e-mail) não muda numa troca de senha, mas é devolvida para
   uniformidade com nome/e-mail.
- *Alternativa considerada*: estender `UpdateEmailUseCase` para multi-campo. Rejeitada pelo mesmo motivo do
  e-mail — mistura regras distintas e some com a exaustividade limpa de cada `sealed result`.

**`PersonRepository.updatePassword` retorna `Boolean`, não um `Outcome`.** A senha não é única: a persistência
tem só dois desfechos (hash atualizado da pessoa ativa vs. nenhuma pessoa ativa). Um `Boolean` basta — como
`updateName`, não como `updateEmail` (que precisou de três estados por causa da colisão de unicidade). O
adapter jOOQ faz `UPDATE person SET password_hash=? WHERE id=? AND status=ACTIVE`; zero linhas ⇒ `false` ⇒
`PersonNotFound`; uma linha ⇒ `true`. Deliberadamente estreito (só o hash), como as demais escritas do port.

**Confirmação da senha atual reusa `PasswordHasherPort.verify`; sua falha é `InvalidCredentials` → `401`
neutro.** A senha atual é conferida contra o hash guardado **antes** de qualquer escrita (passo 3). A falha é
uma recusa de credencial, mapeada ao **mesmo** `401` neutro (`UNAUTHENTICATED`, `error.authentication.message`)
que o guard, o `SignInError.InvalidCredentials`, o `MeError.PersonNotFound` e a troca de e-mail já emitem.

**Nova senha igual à atual é `SamePassword` → `422`, detectada por `verify`.** Depois de conferida a senha
atual, a nova senha (já válida pela política) é conferida contra o hash guardado: se casar, é a senha atual —
`SamePassword`, sem escrever. Como é a própria senha do dono autenticado, uma mensagem específica ("a nova
senha deve ser diferente da atual") **não** é oráculo de descoberta de conta e é boa UX. `422`.
- *Alternativa considerada*: aceitar como no-op de sucesso (espelhando "trocar para o próprio e-mail atual").
  Rejeitada — para o e-mail o no-op é inócuo, mas re-hashear a mesma senha e ainda assim revogar as outras
  sessões seria um efeito colateral surpreendente para uma "troca" que não troca nada; recusar é mais honesto.

**Senha fraca é `WeakPassword` → `422` com mensagem específica.** A política mínima é uma **regra pública** —
o README autoriza dizê-la abertamente, pois não revela nada sobre nenhuma pessoa. Diferente do conflito de
e-mail (que precisa de mensagem genérica para não virar oráculo), `WeakPassword` pode ter código/mensagem
próprios. Compartilha o `422` com `SamePassword`: as duas recusas de domínio "públicas" desta rota dividem o
status, então o status nunca delata **qual** ocorreu — coerente com a regra do `CLAUDE.md` de que o split
`400`/`422` é por *kind*, não por regra de negócio. O par não-vazante (`InvalidCredentials`/`PersonNotFound`)
fica no `401` neutro, como nas demais rotas.

**Revogar as outras sessões, manter a atual — e como a atual é identificada.** Trocar a senha encerra todas
as demais sessões vivas da pessoa (postura de segurança); a sessão que fez a troca **continua válida** (melhor
UX — não desloga o dispositivo que acabou de rotacionar a senha). Isso exige que o use case saiba **qual**
sessão poupar. O `AuthenticatedFilter` já resolve a `SessionEntity` inteira (tem `session.id`), mas hoje só
guarda `session.personId` num atributo de request. **Decisão: o `AuthenticatedActor` passa a carregar também
o `sessionId`.** O filtro guarda `session.id` sob uma segunda chave de atributo; o binder lê as duas; o actor
vira `AuthenticatedActor(personId, sessionId)`. O `UpdatePasswordCommand` carrega `personId` + `sessionId`, e
o novo `SessionRepository.revokeAllForPersonExcept(personId, sessionId)` faz
`DELETE FROM session WHERE person_id = ? AND id <> ?`. A revogação é autoritativa no servidor (o token opaco
some do datastore ⇒ `findActiveByToken` devolve ausência ⇒ o guard recusa `401`), fechando as outras sessões
imediatamente.
- *Por que estender o actor e não criar um segundo tipo/binder*: a alternativa (um `AuthenticatedSession`
  separado com o próprio binder) duplicaria o `personId` e adicionaria mais máquina que a extensão aditiva de
  um campo. "Quem está chamando" legitimamente inclui "em qual sessão" para uma escrita de escopo de sessão —
  o actor é o lugar honesto. A mudança é **aditiva**: os handlers que só leem `personId` seguem intactos, e o
  `CLAUDE.md` (que hoje diz "carries only the personId") é atualizado para "personId + sessionId da sessão
  atual".
- *Por que não revogar também a atual*: forçar re-login em todo lugar é mais conservador, mas a opção
  escolhida mantém o dispositivo de origem logado, que é o comportamento esperado por quem acabou de trocar a
  senha ali. Como a troca já provou posse da senha atual naquele dispositivo, poupá-lo não enfraquece a
  postura.
- *Por que não rotacionar (revogar tudo + emitir novo token)*: manteria o dono logado com um token **novo**,
  mas o requisito é que a **sessão atual continue válida** (o token apresentado segue funcionando), então não
  se emite token novo nesta rota.

**Ordem: revogar depois de persistir.** A revogação das outras sessões é o **último** passo, após o `UPDATE`
da senha ter sucesso. Se o `updatePassword` falhar (corrida com deleção ⇒ `false` ⇒ `PersonNotFound`), nenhuma
sessão é tocada — não se encerra sessão de uma troca que não aconteceu.

**Validação em duas camadas, uma definição.** `UpdatePasswordRequest` (`@Serdeable`) carrega
`@NotBlank(message="{…}")` na `currentPassword` (só presença — a borda **não** aplica política à senha de
confirmação, que apenas confere o hash) e `@NotBlank` + `@Size(min = PasswordValueObject.MIN_LENGTH,
message="{…}")` na `newPassword` — `400` antecipado por campo, referenciando a constante do value object,
nunca um literal. O `PasswordValueObject` segue autoridade única da política; mensagens por chave i18n; `code`
inline.

**Rota simétrica.** O método `PATCH("/me/password")` entra no `PersonController` (mesmo controller do `me()`,
nome e e-mail), `@Authenticated`, injetando o `AuthenticatedActor` (agora com `sessionId`) e o
`@Valid @Body UpdatePasswordRequest`, retornando `HttpResponse<*>` com `PersonResponse` no sucesso. A
documentação (`@Operation`/`@ApiResponse` com `200 → PersonResponse`, `4xx → ErrorResponse`,
`@Status(HttpStatus.OK)`) vai no `PersonControllerDoc`.

## Risks / Trade-offs

- **Corrida entre a troca e a deleção de conta** (a pessoa é apagada entre `findById`/`verify` e o `UPDATE`)
  → Mitigação: o `UPDATE` é condicionado à pessoa **ativa** no `WHERE`; zero linhas ⇒ `false` ⇒
  `PersonNotFound` ⇒ `401` neutro, sem meia-troca; a revogação nem chega a rodar.
- **A sessão atual deixar de existir entre o guard e a revogação** (a própria sessão poupada expira/é apagada
  concorrentemente) → Trade-off aceito: o `DELETE ... id <> sessionId` simplesmente não encontra a atual para
  poupar (ela já não está lá); nenhuma inconsistência — o pior caso é a pessoa precisar logar de novo, o
  comportamento seguro.
- **Trocar a senha sem re-provar posse por MFA** → Fora de escopo (não há MFA no sistema); a confirmação da
  senha atual é a prova de step-up disponível, coerente com a troca de e-mail e a exclusão de conta.
- **Mudança no `AuthenticatedActor` toca o core** → Aditiva e contida: os três handlers existentes só leem
  `personId` e não mudam; o filtro e o binder ganham uma segunda chave de atributo; os testes de filtro/binder
  e o `FakeSessionRepository` são atualizados junto. O `CLAUDE.md` é ajustado (o actor "carries only the
  personId" vira "personId + sessionId").
- **Drift entre borda e domínio no tamanho mínimo da senha** → Mitigação embutida: o `@Size(min = …)`
  referencia `PasswordValueObject.MIN_LENGTH`; a convenção e o teste de arquitetura barram o literal
  duplicado.

## Open Questions

- **Recuperação de senha ("esqueci minha senha") sem sessão** — a evolução natural para quem não lembra a
  senha atual, mas é uma capacidade distinta (não é step-up) e depende de um canal de envio de e-mail
  inexistente. Fica como mudança futura.
- **Notificar a pessoa por e-mail após a troca de senha** ("sua senha foi alterada") — boa prática de
  segurança, mas depende do mesmo canal de e-mail ausente. Revisitar junto com a recuperação de senha.
