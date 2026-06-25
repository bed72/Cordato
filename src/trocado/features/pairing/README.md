# `pairing/` — o ponto de vista

O par é o coração do Trocado: **um casal é um ponto de vista, não um dono.** Este módulo não guarda dinheiro,
orçamento nem gasto — ele apenas **liga dois indivíduos** para que uma visão compartilhada possa emergir por
cima dos dados de cada um. Tudo começa por um **convite**: alguém o emite, o parceiro o aceita, e só então o
par nasce.

## Responsabilidade

- **Emitir** um convite (`create-invite-code`): mintar um código de uso único que um parceiro poderá resgatar.
- *(próxima fatia)* **Aceitar** um convite (`accept-invite`): validar o código e formar o `Pair`.

### O que ele deliberadamente NÃO faz

- **Não possui nada.** O par é um elo fino entre dois indivíduos — sem dinheiro, sem budget, sem expense.
  Dissolver o par remove só a *lente*; cada um mantém tudo o que tinha, intacto.
- **Não escreve nos dados do parceiro.** Parear concede uma visão de **leitura**, nunca escrita.

## Vocabulário

| Termo | É | Significa |
|---|---|---|
| `InviteCodeEntity` | entidade | O convite de uso único. Igualdade por `id`. Aponta só para o criador. |
| `code` | `str` | Token opaco de um **CSPRNG** — curto e imprevisível. Não é value object (sem invariante). |
| `expires_at` | `datetime` | ~1 dia após `created_at`; regra de domínio fixada na factory, **não** vinda do caller. |
| `consumed_at` | `datetime \| null` | `null` = não usado. O resgate (accept-invite) é quem o carimba. |
| `Pair` | entidade *(próxima fatia)* | O elo entre dois indivíduos. Invariante: ≤1 par vivo por pessoa. |

## Mapa do módulo

| Camada | Arquivo | Papel |
|---|---|---|
| domain / entities | `invite_code_entity.py` | O convite; factory `create(...)` fixa o TTL de 1 dia e nasce `consumed_at = null`. |
| application / data | `create_invite_code_data.py` (comando) · `invite_code_data.py` (read-model) | Entrada/saída. |
| application / interfaces | `invite_code_repository_interface.py` · `token_generator_interface.py` | Portas: persistir o código · mintar o token CSPRNG. |
| application / use_cases | `create_invite_code_use_case.py` | Orquestra: `gather` de id/now/token, nasce a entidade, persiste. |
| application / mappers | `invite_code_data_mapper.py` | `Entity → Data`. |
| infrastructure / repositories | `invite_code_repository.py` | Adapter in-memory (por enquanto). |
| infrastructure / gateways | `token_generator.py` | `TokenGenerator`: `secrets.token_urlsafe`, off-loop com `asyncio.to_thread`. |

## A fronteira (sem acoplamento)

- **Depende só de `identity`** de forma indireta: um convite carrega um `creator_id` opaco — o módulo **não**
  inspeciona nem valida a pessoa (a autorização chega com a auth, como nas demais fatias).
- **Reusa as portas de determinismo do `core/`** (`ClockInterface`, `IdentifierProviderInterface`) — `id` e
  `created_at` entram pela factory; a entidade nunca chama `uuid`/`datetime`.
- **A geração do token vive atrás de uma porta** (`TokenGeneratorInterface`): a fonte criptográfica é um
  adapter injetável, então o use case permanece puro e determinístico no teste.

## Estado atual vs. deferido

Vertical slice in-memory de `create-invite-code`. **Deferido:**
- **`accept-invite`** — onde nascem o `PairEntity`, a invariante ≤1 par vivo, e as checagens de resgate
  (não-expirado · não-consumido · não-auto-convite · nenhum dos dois já pareado) + o carimbo de `consumed_at`.
  É lá que entram `find_by_token` no repositório e os erros de domínio (pt-BR, sem vazar dados).
- **`InviteCodeModel`/`InviteCodeModelMapper`** e o constraint de unicidade do token — entram com o ORM.
- As **couple views** (couple budget, couple expenses) — projetadas por cima do par, depois que ele existir.

## Onde aprofundar

- **Convenções** → [`../../../../CLAUDE.md`](../../../../CLAUDE.md) (entidades *Pair* e *InviteCode*; *um casal é um ponto de vista*)
- **Comportamento** → `openspec/specs/create-invite-code/spec.md`
