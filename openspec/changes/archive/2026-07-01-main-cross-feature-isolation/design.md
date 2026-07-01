## Context

A mudança anterior (`pairing-self-contained`, já arquivada) tirou os imports cross-feature de dentro de `gateways/` movendo `SpendReaderInterface`/`SpendReader` para `core/` e fazendo os gateways de `pairing` receberem Callables. Mas ela manteve uma exceção deliberada: `main/` (o composition root de cada feature) continuava importando repositórios de outras features para *construir* esses Callables:

- `budgeting/main/budgeting_route.py` importa `ExpenseRepository` de `expenses` para alimentar o `SpendReader`.
- `pairing/main/pairing_route.py` importa `ExpenseRepository` de `expenses`, `BudgetRepository`/`BudgetRepositoryInterface` de `budgeting` e `PersonRepository`/`PersonRepositoryInterface` de `identity` para alimentar `PartnerExpenseReader`, `PartnerBudgetReader` e `PersonDirectory`.

Um scan completo do projeto (`grep` de `from trocado.features.` fora do próprio módulo) confirma que esses são os únicos dois arquivos com esse tipo de cruzamento — leitura de dados entre módulos. Existe um terceiro ponto de cruzamento (`CurrentPersonProvider`, importado direto por controllers de `expenses`/`budgeting`/`pairing`), mas é de natureza diferente (autenticação, não leitura de dados) e fica fora de escopo desta mudança por decisão explícita — vira parking lot para uma mudança futura.

Hoje, pré-ORM, cada `main/` já instancia sua **própria** instância de `ExpenseRepository`/`BudgetRepository`/`PersonRepository` — uma cópia separada do dicionário em memória usado pela feature dona do dado. Ou seja, o valor real (`total_spent`, despesas do parceiro, perfil do parceiro) já não reflete dados reais entre módulos hoje — é um limite aceito e documentado no design da mudança anterior, que só se resolve quando o ORM chegar e todas as instâncias apontarem para o mesmo banco.

## Goals / Non-Goals

**Goals:**
- Zero imports cross-feature em **qualquer** arquivo do projeto, incluindo `main/` — sem exceção.
- `budgeting` e `pairing` ganham seus próprios gateways de leitura (`application/interfaces/*_reader_interface.py` + `infrastructure/gateways/*_reader.py`) com a lógica de query hoje presente nos repositórios de outras features, duplicada meramente (não compartilhada) — seguindo o padrão de **todo** gateway já existente no projeto (porta ABC + adaptador concreto).
- Os readers retornam/alimentam apenas tipos já existentes no módulo consumidor (`Decimal`, `PartnerExpenseData`, `ActiveBudgetReadingData`, `PartnerProfileData`) — nunca entidades de outro feature.
- `feature-composition` passa a proibir cruzamento em qualquer camada, sem distinção de `main/`.
- Duas únicas buckets em `infrastructure/` (`repositories/`, `gateways/`) e um-conceito-por-arquivo continuam valendo sem exceção — os readers vivem em `gateways/`, nunca em uma pasta nova.

**Non-Goals:**
- Resolver o CurrentPersonProvider cross-feature nos controllers — fica para mudança futura.
- Compartilhar dados reais entre os readers duplicados e os repositórios originais — pré-ORM isso é impossível sem reintroduzir o import; o comportamento (armazenamento isolado, portanto vazio entre features) já é o de hoje, não há regressão.
- Criar ABCs novas em `core/` — os readers não são um conceito de shared kernel, são gateways locais de um único módulo consumidor, com interface no próprio `application/interfaces/` desse módulo.
- Mudar qualquer contrato HTTP, comportamento de domínio ou teste de integração HTTP existente.

## Decisions

### Cada reader é um gateway igual a todos os outros: ABC em `application/interfaces/` + adaptador em `infrastructure/gateways/`

Uma primeira versão deste design cogitou uma pasta nova (`infrastructure/readers/`) com classes concretas sem interface, por não serem injetadas via DI do Litestar. Isso violava duas regras não-negociáveis: **duas buckets só** em `infrastructure/` (`repositories/`, `gateways/` — nenhuma pasta nova) e o padrão 100% consistente de que todo gateway do projeto (`SpendReader`, `PartnerExpenseReader`, `PartnerBudgetReader`, `PersonDirectory`, `TokenGenerator`, `PasswordHasher`, `Clock`) implementa uma interface própria. A versão final corrige isso: cada reader é um gateway como qualquer outro — interface `abc.ABC` em `application/interfaces/`, adaptador concreto em `infrastructure/gateways/` — só que instanciado e consumido apenas dentro do próprio `main/` (nunca registrado como dependência do Litestar), exatamente como `BudgetRepository`/`PersonRepository` já são hoje.

### Um-conceito-por-arquivo vale também para as linhas de armazenamento local — agrupadas em `gateways/rows/`

Cada reader precisa de uma forma mínima de armazenamento local (pré-ORM) para poder duplicar de fato a lógica de filtro do repositório original — sem isso não haveria nada para testar. Essas linhas (`ExpenseAmountRow`, `ExpenseRow`, `BudgetRow`, `PersonRow`) são dataclasses simples, sem invariante nem comportamento (puro carregador de campos), cada uma no seu próprio arquivo. Por decisão explícita do usuário, elas ficam em um subdiretório `infrastructure/gateways/rows/` — não soltas ao lado dos readers. Isso é uma exceção pontual à leitura mais estrita de "`gateways/` é flat, um arquivo por adaptador" (essa frase mira os *adaptadores* em si, ex. não criar `hashers/`/`providers/`/`senders/`; as rows não são adaptadores, são o carregador de dados que os acompanha) — mantida porque agrupa por natureza do conceito (linha de armazenamento vs. adaptador) e melhora a navegação sem reintroduzir a pasta banida `infrastructure/readers/` nem misturar classes no mesmo arquivo.

### `budgeting` ganha `ExpenseAmountReader`

`budgeting/application/interfaces/expense_amount_reader_interface.py` → `ExpenseAmountReaderInterface(ABC)` com `async def find_amounts_in_range(self, person_id: str, start: date, end: date) -> list[Decimal]`. `budgeting/infrastructure/gateways/rows/expense_amount_row.py` → `ExpenseAmountRow` (linha local: `person_id`, `amount`, `occurred_on`, `deleted_at`). `budgeting/infrastructure/gateways/expense_amount_reader.py` → `ExpenseAmountReader(ExpenseAmountReaderInterface)`, duplicando o filtro hoje em `ExpenseRepository.find_in_range` sobre `self._rows: dict[str, ExpenseAmountRow]` — nunca a `ExpenseEntity` de `expenses`. `budgeting_route.py` instancia `ExpenseAmountReader()` e passa `reader.find_amounts_in_range` para `SpendReader`, no lugar do `expense_repository.find_in_range` de hoje.

### `pairing` ganha três readers, um por capability cross-feature

- `pairing/application/interfaces/expense_reader_interface.py` → `ExpenseReaderInterface(ABC)` com dois métodos: `find_amounts_in_range` (alimenta o `SpendReader` de `pairing`) e `list_live_for_person` (alimenta `PartnerExpenseReader`). `pairing/infrastructure/gateways/rows/expense_row.py` → `ExpenseRow` (linha local com os campos extras — `id`, `created_at`, `description` — que `PartnerExpenseData` exige). `pairing/infrastructure/gateways/expense_reader.py` → `ExpenseReader(ExpenseReaderInterface)`. `list_live_for_person` já retorna `PartnerExpenseData` diretamente — a montagem que hoje vive em `_list_partner_expenses` (dentro de `pairing_route.py`) migra para dentro do reader.
- `pairing/application/data/active_budget_reading_data.py` → `ActiveBudgetReadingData` (`start_date`, `end_date`, `amount`) — a forma que `BudgetReaderInterface.find_active_for_person` devolve, antes de `SpendReader` completar o `total_spent`. `pairing/application/interfaces/budget_reader_interface.py` → `BudgetReaderInterface(ABC)`. `pairing/infrastructure/gateways/rows/budget_row.py` → `BudgetRow` (linha local). `pairing/infrastructure/gateways/budget_reader.py` → `BudgetReader(BudgetReaderInterface)`, duplicando `BudgetRepository.find_active_for_person`. Não devolve `PartnerActiveBudgetData` completo — montar o `total_spent` continua em `pairing_route.py`, exatamente como hoje faz `_find_active_partner_budget`. Só o import de `BudgetRepository` desaparece.
- `pairing/application/interfaces/person_reader_interface.py` → `PersonReaderInterface(ABC)` com `find_active_profile(person_id) -> PartnerProfileData | None`. `pairing/infrastructure/gateways/rows/person_row.py` → `PersonRow` (`name`, `is_active` — sem importar o enum `PersonStatus` de `identity`). `pairing/infrastructure/gateways/person_reader.py` → `PersonReader(PersonReaderInterface)`, duplicando `PersonRepository.find_active_by_id` mais a extração de `name`.

### `pairing_route.py` e `budgeting_route.py` continuam sendo o único lugar que compõe Callables

A composição de `SpendReader`, `PartnerExpenseReader`, `PartnerBudgetReader` e `PersonDirectory` a partir dos métodos do reader continua em `main/`, só que agora os Callables fecham sobre instâncias de readers locais (tipadas pela própria interface, ex.: `expense_reader: ExpenseReaderInterface = ExpenseReader()`) em vez de repositórios de outro feature. Nenhum reader é registrado via `Provide()` do Litestar — permanecem detalhes de composição, não dependências dos use cases.

### `feature-composition` remove a exceção de `main/`

A regra existente (`Zero imports cross-feature fora de main/`) vira `Zero imports cross-feature em qualquer arquivo`. `main/` deixa de ser mencionado como exceção; passa a ser só mais um lugar sujeito à regra.

## Risks / Trade-offs

**Readers pré-ORM nunca veem dado real de outro módulo** → Aceito, é o comportamento de hoje (cada `main/` já instancia um repositório separado do da feature dona). Quando o ORM chegar, cada reader troca seu armazenamento local por uma query real contra a mesma tabela física (via `core/infrastructure/persistence`), sem nunca voltar a importar a classe de repositório de outro feature — a duplicação de query é o preço aceito para o isolamento arquitetural.

**Duplicação de lógica de filtro entre o repositório original e o reader** → Se o filtro do repositório original mudar (ex: nova regra de soft-delete), o reader duplicado não muda junto automaticamente. Aceito conscientemente — é o trade-off central desta mudança (`local-read-infrastructure`), coberto por teste dedicado em cada reader para travar o comportamento esperado.

**Mais arquivos por reader (interface + row + gateway) do que uma classe única faria** → Aceito porque é o único jeito de manter zero exceção às regras de bucket único e um-conceito-por-arquivo já em vigor — consistência com os 7 gateways existentes pesa mais que a economia de 2 arquivos por reader.
