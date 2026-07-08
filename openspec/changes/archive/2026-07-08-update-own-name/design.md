## Context

`identity` já tem a fatia de leitura da própria pessoa: `MeCommand` → `MeUseCase` → `MeResult` (sealed:
sucesso com `MeResult` público ou `PersonNotFound`), exposta por `GET /persons/me` (`@Authenticated`), com
`PersonController` delegando ao use case a partir do `AuthenticatedActor.personId` e devolvendo
`PersonResponse` via `PersonResponseMapper`. A sessão órfã já colapsa no `401` neutro compartilhado. Esta
mudança adiciona o **write** correspondente — atualizar o próprio nome — reusando ao máximo essa fatia. O
`NameValueObject` já existe e é a autoridade única da invariante do nome (com constante de tamanho e
normalização), então a operação não reimplementa nada: constrói o value object e propaga a rejeição.

## Goals / Non-Goals

**Goals:**
- Um único endpoint protegido `PATCH /persons/me` que altera **apenas** o nome da própria pessoa.
- Reusar a representação pública de pessoa (`PersonResponse` + `PersonResponseMapper`) e o contrato de
  erro/`401` neutro já existentes — zero divergência de forma com `GET /persons/me`.
- Manter as duas garantias transversais do contexto: nenhuma senha vaza; a sessão órfã é indistinguível de
  token inválido.

**Non-Goals:**
- Editar e-mail, senha ou status (fora de escopo; e-mail/senha têm regras próprias — unicidade, política —
  que pedem suas próprias mudanças).
- Editar o nome de **outra** pessoa (admin ou via id no path). A rota opera só sobre o ator autenticado.
- Introduzir `PUT`/substituição total do recurso ou um endpoint genérico de patch multi-campo.

## Decisions

**Novo use case dedicado, espelhando a fatia do `Me`.** Novos tipos em `identity`, com os sufixos de
categoria da convenção: `UpdateNameCommand(personId, name)` (`application/commands/`), `UpdateNameResult`
(`application/results/`, a visão pública atualizada), `UpdateNameError` (`domain/errors/`, sealed com
`InvalidName` e `PersonNotFound`), `UpdateNameUseCase` (`application/use_cases/`). O use case constrói o
`NameValueObject` (rejeição → `InvalidName`), resolve a pessoa ativa via `PersonRepository` (ausente/inativa
→ `PersonNotFound`), aplica o novo nome na `PersonEntity` (`copy(name = ...)`) e persiste.
- *Alternativa considerada*: estender `MeUseCase` para também escrever. Rejeitada — mistura leitura e
  escrita num só use case e some com a exaustividade limpa de cada `sealed result`.

**`PersonRepository` ganha uma operação de atualização de nome, não um "save" genérico.** Uma assinatura
estreita (atualizar o nome de uma pessoa por id, ou persistir a `PersonEntity` já com o novo nome)
mantém o "apenas o nome muda" verificável na fronteira de persistência, em vez de um `update(person)` que
poderia reescrever e-mail/hash/status. O adapter jOOQ (`PersistencePersonRepository`) faz um `UPDATE` só da
coluna do nome (via `PersonRecordMapper`/property setters, conforme a convenção de mappers).
- *Alternativa*: um `save(entity)` amplo. Rejeitada — dá à borda de persistência poder de mais e enfraquece
  a invariante de imutabilidade dos outros campos.

**Nome inválido → `422`; sessão órfã → `401` neutro.** Um `UpdateNameErrorResponseMapper`
(`infrastructure/http/mappers/errors/`) ramifica exaustivamente sobre `UpdateNameError`: `InvalidName` →
`unprocessable` (code `INVALID_NAME`, mensagem i18n por chave); `PersonNotFound` → o **mesmo** `401` neutro
(`UNAUTHENTICATED`, `error.authentication.message`) que o guard e o `MeErrorResponseMapper` já emitem. O
mapper é policy; a *forma* vem dos builders compartilhados de `core`.
- *Consistência de não-vazamento*: `PersonNotFound` nunca vira `404` nem corpo específico — seria um oráculo
  de "essa sessão perdeu a pessoa". Mesma decisão já tomada em `GET /persons/me`.

**Validação em duas camadas, uma definição.** `UpdateNameRequest` (`@Serdeable`) carrega
`@NotBlank(message = "{...}")` + `@Size(max = NameValueObject.MAX_LENGTH, message = "{...}")` referenciando a
constante do value object — `400` antecipado por campo. O `NameValueObject` segue autoridade única do
invariante (trim/normalização + rejeição → `422`). Mensagens por chave i18n em `messages.properties`; o
`code` fica constante inline (contrato de máquina).

**A rota reusa a representação pública e o `<Controller>Doc`.** O método `PATCH` entra em
`PersonController` (mesmo controller do `me()`), `@Authenticated`, injetando o `AuthenticatedActor` e o
corpo `@Valid @Body UpdateNameRequest`, retornando `HttpResponse<*>` com `PersonResponse` no sucesso. A
documentação (`@Operation`/`@ApiResponse` com `200 → PersonResponse`, `4xx → ErrorResponse`) vai em
`PersonControllerDoc`, não no controller.

## Risks / Trade-offs

- **Corrida entre a atualização e a deleção de conta** (a pessoa é apagada entre o guard e o `UPDATE`) →
  Mitigação: o `UPDATE` é condicionado à pessoa **ativa** (o `WHERE` filtra status), então zero linhas
  afetadas colapsa em `PersonNotFound` → `401` neutro, sem meia-atualização.
- **`PATCH` com semântica de campo único vs. patch parcial genérico** → escolha deliberada: hoje só `name`
  é mutável, então um patch de campo único é o contrato mais simples e honesto; se surgirem mais campos
  mutáveis, evolui-se o request então (nova mudança), sem prometer parcialidade agora.
- **Drift entre borda e domínio no tamanho do nome** → Mitigação já embutida: o `@Size` referencia
  `NameValueObject.MAX_LENGTH`; a convenção e o teste de arquitetura barram o literal duplicado.
