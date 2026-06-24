# Trocado / Cordato

Ferramenta de finanças pessoais para **casais** que se recusa a dissolver o indivíduo na relação.
Cada pessoa é dona do próprio dinheiro, orçamentos e gastos. Quando duas pessoas se pareiam,
surge uma **view compartilhada** por cima dos dados individuais — uma lente, não uma fusão.
Se o par se desfaz, a lente some e cada um leva tudo o que tinha, intacto.

> Se você lembrar de só uma coisa: **o casal é um ponto de vista, não um dono.**

As três tensões mantidas de propósito:
- **Individual por padrão.** Todo dado pertence a exatamente uma pessoa.
- **Compartilhado por consentimento.** Parear adiciona uma perspectiva de *leitura* sobre dois indivíduos.
- **Reversível sem perda.** Desparear nunca destrói nem move dado de ninguém.

---

## Princípio central de modelagem: derive, não armazene

O grafo de referências é **deliberadamente plano**. Adicione um link só quando a relação é um
**fato intrínseco de posse** (pessoa possui budget), nunca por conveniência de uma query.

> Prefira **associação derivada por atributo** (ex.: containment de data) a **referência armazenada**,
> sempre que a associação pode ser recomputada barato e exigiria manutenção a cada mudança.
> **Armazene eventos; compute agrupamentos.**

Esse princípio já aparece **três vezes** no domínio (expense→budget, budget-default, couple budget).
Essa repetição é o sinal de que o modelo é coerente consigo mesmo — mantenha-a.

### A associação que NÃO existe de propósito: `Expense ──╳── Budget`

Um expense **não** aponta para um budget. Ele pertence a um budget **dinamicamente**, por cair
dentro do range de datas do budget. A associação é **computada em read-time, nunca armazenada**.

Por quê (preserve esse raciocínio):
1. **Sem rewiring.** Editar datas de um budget, apagá-lo ou criar outro nunca toca um expense.
2. **Expense é um fato, não um arquivamento.** O gasto aconteceu numa data, por um valor, por alguém —
   verdade independente de como os budgets são fatiados depois.
3. **Sem órfãos, sem links pendurados, sem dupla contagem.** Link derivado nunca fica stale.
4. **A mesma leveza escala pra view compartilhada.**

---

## Entidades armazenadas

Todas têm `id` (identidade opaca — âncora do ledger) e `created_at`.

### Person
`id`, `created_at`, `email` (único), `name`, `password` (**armazena o HASH — Argon2/bcrypt —, nunca texto puro**),
`status` (`active` / `deleted`).
- Possui N Budget, N Expense, N InviteCode, N Notification; está em ≤1 Pair ativo.
- **Hard-delete** (a única deleção física do domínio) — ver Lifecycles.

### Budget
`id`, `created_at`, `person_id`, `amount` (decimal exato, centavos, **BRL**), `start_date`, `end_date`
(datas inclusivas nas duas pontas, **sem hora**), `note` (opcional), `deleted_at` (**soft-delete**).
- Individual, sempre aponta pra uma Person. **Não tem lista de expenses** — gasto é computado.
- **Invariante de não-overlap:** dois budgets *vivos* da mesma pessoa não compartilham nenhuma data,
  nem o dia de fronteira (A termina dia 15, B começa dia 16 ✅; B começa dia 15 ❌).
  É essa regra que torna "o budget ativo" e o pertencimento por data **não-ambíguos**.

### Expense
`id`, `created_at`, `person_id` (quem gastou — só isso), `amount` (decimal exato), `date` (sem hora),
`description` (opcional), `deleted_at` (**soft-delete**).
- **Zero link para Budget.** Pertencimento é puramente date-range.

### Pair
`id`, `created_at`, `person_a_id`, `person_b_id`, `deleted_at` (**soft-delete** = dissolvido).
- **Não possui dinheiro, budget nem expense.** Link fino entre dois indivíduos, só pra habilitar a view.
- **Invariante:** uma pessoa em ≤1 par com `deleted_at = null`. N dissolvidos no histórico, ok.

### InviteCode
`id`, `created_at`, `creator_id`, `code` (token curto, **gerado por CSPRNG — fonte criptográfica, nunca previsível**),
`expires_at` (~1 dia), `consumed_at` (null = não usado).
- Aceitar code válido (não expirado, não consumido) → cria o Pair e marca `consumed_at`. Single-use.

### Notification
`id`, `created_at`, `person_id`, `type` (ex.: `budget_near_limit`, `budget_exceeded`, `budget_ending`),
`payload`, `read_at`, `cleared_at`.
- Produzida **só internamente** (reação a evento + passagem de tempo). **Sem "create" externo.**
  Pessoa só lê e limpa o próprio feed. (Lógica de disparo: ver Parking lot.)

---

## Objetos virtuais — computados em read-time, NUNCA armazenados

- **Active budget (enriquecido):** o budget vivo cujo range contém hoje + `total_spent`
  (soma dos expenses do dono no range) + `remaining`.
- **Default budget ("Sem orçamento"):** bucket fabricado na hora pra agrupar os expenses do dono que
  não caem em nenhum budget real. Resolve a nulabilidade na aplicação, sem linha no banco.
- **Couple budget (combined view):** período `[min(inícios), max(fins)]` dos budgets ativos dos dois,
  valor = soma, gasto = soma. **Lente de panorama, deliberadamente aproximada** — a verdade exata vive
  nas views individuais. NÃO é entidade; o par não possui nada.
- **Expenses do casal:** união dos expenses dos dois, cada um marcado `mine` / `theirs` pro leitor atual.

---

## Lifecycles e a garantia de "sem perda de dado"

### Dissolver um par
Remove só a *view compartilhada* (soft-delete do Pair). Ambos mantêm todo budget e expense intactos.
O produto volta a se comportar como dois indivíduos não-pareados que têm histórico.

### Deletar a conta (hard-delete — a opção nuclear)
Ação única, atômica, guardada (exige re-confirmar identidade: sessão viva **e** senha). **Sem restore.**
O grafo plano é o que torna isso **seguro**: ninguém referencia os dados de uma pessoa além dela mesma
(o par não possui nada; o parceiro só tinha uma *view*). Então, numa operação indivisível:
- invalida a sessão, verifica a senha contra o hash;
- **apaga fisicamente (cascade) budgets e expenses da pessoa**;
- **neutraliza o email** da conta antiga (ex.: `deleted+<id>@…`), liberando o email pra reuso;
- marca `status = deleted` (não autentica mais);
- **dissolve** qualquer par ativo como consequência.
- Reusar o email cria uma Person **nova** (id novo, ledger vazio) — não ressuscita a antiga.

### Soft-delete no dia a dia
`delete` em Budget/Expense/Pair = **soft-remove** (`deleted_at`, some das views normais; visível em
auditoria). Recuperação de engano + trilha de auditoria. **Exceção:** deleção de *conta* é física (acima).

---

## Expectativas transversais

- **Autorização por pessoa.** Cada um vê/muta só os próprios dados, exceto pelas views compartilhadas
  explícitas do par — que são **só leitura** (parear não dá write nos dados do parceiro).
- **Dinheiro e datas são first-class.** Valores em **decimal exato** (nunca float). Pertencimento de
  budget é pura lógica de date-range. Mantenha os dois precisos.
- **Números derivados são cacheáveis mas nunca autoritativos.** `total_spent`, `remaining` e os agregados
  do casal vêm dos eventos. **Decisão atual: SEM cache** (casal = pouco dado, soma é instantânea).
- **Reações a estado pertencem ao sistema, não ao caller.** Notificações são emitidas pelo sistema
  observando os próprios dados e a passagem do tempo.

---

## Parking lot (decidir depois)

- **Disparo de notificações:** depende de **passagem de tempo** ("budget acabando", "excedido por tempo"),
  não só de eventos de request → exige algo varrendo o estado periodicamente (scheduler/job). A discutir.
- **Meta conjunta do casal:** se um dia o casal quiser definir um orçamento conjunto *genuíno* (intenção
  nova, não derivável dos individuais), aí sim seria uma entidade armazenada própria, com ciclo de vida
  próprio. **Fora de escopo por ora.**
- **Fuso/hora em datas:** hoje usamos `date` pura (sem hora). Se precisar de timezone, tratar depois.

---

## Arquitetura & convenções

Clean Architecture + DDD tático + Ports & Adapters, num **monólito modular**. O domínio é
independente de framework e se testa sem subir nada. Regra de dependência sempre **para
dentro**: `infrastructure → application → domain`. O `domain/` não importa nada de fora.

### Organização de pacotes (`src/trocado/`)
- `core/` — shared kernel: tudo que os demais módulos precisam. **Segue a mesma estrutura
  de um feature** (`domain/` · `application/` · `infrastructure/`).
- `features/<contexto>/` — um pacote por contexto (`expenses`, `budgeting`, `identity`,
  `pairing`, `notifications`). Todos seguem o mesmo formato. **NÃO existe `shared/`.**

### Camadas dentro de cada módulo
- `domain/` → `entities/`, `value_objects/`, `errors/` (+ `policies/`, `services/` quando houver). Python puro.
- `application/` → `interfaces/` (ports, ABC), `data/` (comandos e read-models), `use_cases/`, `mappers/`, `services/`.
- `infrastructure/` → `models/`, `mappers/`, `repositories/` (adapters). **Único lugar que conhece lib/ORM.**

### Convenções de nome (valem para TODOS os módulos)
| Conceito | Pasta | Arquivo | Classe |
|---|---|---|---|
| Entidade | `domain/entities` | `expense_entity.py` | `ExpenseEntity` |
| Value Object | `domain/value_objects` | `money_value_object.py` | `MoneyValueObject` |
| Erro | `domain/errors` | `expense_not_found_error.py` | `ExpenseNotFoundError` |
| Interface (port) | `application/interfaces` | `expense_repository_interface.py` | `ExpenseRepositoryInterface` |
| Implementação | `infrastructure/repositories` | `expense_repository.py` | `ExpenseRepository` |
| Use case | `application/use_cases` | `record_expense_use_case.py` | `RecordExpenseUseCase` |
| Data (comando/saída) | `application/data` | `record_expense_data.py` / `expense_data.py` | `RecordExpenseData` / `ExpenseData` |
| Mapper entity↔model | `infrastructure/mappers` | `expense_model_mapper.py` | `ExpenseModelMapper` |
| Mapper entity→data | `application/mappers` | `expense_data_mapper.py` | `ExpenseDataMapper` |
| Model (tabela) | `infrastructure/models` | `expense_model.py` | `ExpenseModel` |

Regras inegociáveis:
- **Interfaces sempre via `abc.ABC` + `@abstractmethod`.** Nada de duck typing — contrato assinado e explícito.
- **Nunca o nome da lib no arquivo nem na classe.** `ExpenseRepository`, jamais `SqlAlchemyExpenseRepository`. A ferramenta fica escondida *dentro* do arquivo.
- **Nada de abreviar.** `value_objects` (não `vos`); `MoneyValueObject` (não `MoneyVO`).
- **Mapper dedicado em cada fronteira** — sempre uma classe própria, nunca conversão inline.

### As três camadas de dados (cada uma nomeada pela SUA natureza)
| Camada | Natureza | Nomes |
|---|---|---|
| Web (controller) | request/response (validação, HTTP) | `RecordExpenseRequest`, `ExpenseResponse` |
| Application (`data`) | comando / read-model | `RecordExpenseData`, `ExpenseData` |
| Domain | fato + regra | `ExpenseEntity`, `MoneyValueObject` |

- Entrada nomeada pelo **comando** (plural, específica do use case); saída pelo que **representa**.
- **Não se usa `in`/`out`** na `data`: implica simetria 1:1 que não existe. Direção request/response mora só no web.

### Fluxo de um dado (mappers dedicados em cada salto)
```
Request → [ExpenseRequestMapper] → Data → UseCase → Entity → [ExpenseModelMapper] → Model → DB
DB → Model → [ExpenseModelMapper] → Entity → [ExpenseDataMapper] → Data → [ExpenseResponseMapper] → Response
```

### Repositórios
- **Interface (port)** na `application`; **implementação (adapter)** na `infrastructure`.
- Recebem/devolvem **sempre entidades de domínio**; usam o `ModelMapper` por dentro.
- **Soft-delete é responsabilidade do repositório**: leituras normais excluem `deleted_at != null`;
  só um método de auditoria explícito (`list_including_removed`) enxerga tudo.
- `find_in_range(person, start, end)` no `ExpenseRepository` é o método que **deriva** o
  pertencimento expense→budget — sem nenhum FK.

## Stack e comandos

TODO — a definir. Domínio em **Python puro** (sem framework). Web (FastAPI vs BlackSheep) e
persistência (ORM) entram só na borda, via adapters em `composition/` + `infrastructure/`.
Auth (JWT vs sessão server-side) adiada. Preencher build / test / run / migrations quando a stack for escolhida.
