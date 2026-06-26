# Trocado / Cordato

> Finanças pessoais para **casais** que se recusam a dissolver o indivíduo na relação.

Cada pessoa é dona do próprio dinheiro, dos próprios orçamentos e dos próprios gastos. Quando duas
pessoas se pareiam, **não há fusão de contas**: surge apenas uma **view compartilhada** por cima dos
dados de cada um — uma lente, não um caldeirão. Se o casal se desfaz, a lente some e **cada um leva
tudo o que tinha, intacto**.

> A ideia central, em uma frase: **o casal é um ponto de vista, não um dono.**

---

## As três tensões que o produto mantém de propósito

| Tensão | O que significa |
|---|---|
| **Individual por padrão** | Todo dado pertence a exatamente uma pessoa. |
| **Compartilhado por consentimento** | Parear adiciona uma perspectiva de *leitura* sobre dois indivíduos — nunca um direito de escrita sobre o outro. |
| **Reversível sem perda** | Desparear nunca destrói nem move o dado de ninguém. |

Quase todo produto de "finanças do casal" escolhe um lado: ou trata o casal como uma conta única, ou
mantém duas contas que se ignoram. O Trocado fica deliberadamente **no meio** — duas vidas financeiras
independentes, com uma lente compartilhada que aparece e some sem deixar cicatriz.

---

## Como funciona, sem jargão

- **Cada pessoa** tem seus **orçamentos** (budgets) e seus **gastos** (expenses).
- Um **orçamento** é um valor para um intervalo de datas (ex.: R$ 1.500 de 1 a 30 de junho).
- Um **gasto** é um fato: aconteceu numa data, por um valor, por alguém.
- Um gasto **não fica "preso" a um orçamento**. Ele simplesmente **cai dentro** do intervalo de um
  orçamento — a relação é calculada na hora de ler, não guardada. Mudar as datas de um orçamento, apagá-lo
  ou criar outro **nunca mexe em nenhum gasto**.
- Para parear, uma pessoa gera um **convite** (código de uso único, com validade curta) e a outra aceita.
  Isso cria o **par** e habilita a view compartilhada.
- A **view do casal** soma orçamentos e gastos dos dois lado a lado — um panorama, marcando cada gasto
  como *meu* ou *do outro*. É uma aproximação proposital: a verdade exata continua morando nas views
  individuais.
- **Notificações** (orçamento perto do limite, estourado, terminando) são geradas **pelo próprio sistema**,
  observando os dados e a passagem do tempo. A pessoa só lê e limpa o próprio feed.

---

## A garantia de "sem perda de dado"

- **Desfazer o par** remove apenas a view compartilhada. Os dois mantêm tudo e o produto volta a se
  comportar como duas pessoas não-pareadas que têm histórico.
- **Apagar a conta** é a única ação destrutiva de verdade — atômica, protegida (exige sessão viva **e**
  senha) e sem volta. Como ninguém referencia os dados de uma pessoa além dela mesma, dá pra apagar com
  segurança: some os orçamentos e gastos da pessoa, o e-mail é liberado para reuso e qualquer par ativo
  se dissolve como consequência.
- No dia a dia, apagar um orçamento, gasto ou par é **soft-delete**: some das telas, mas fica na trilha
  de auditoria — recuperável em caso de engano.

---

## Princípio de modelagem: **derive, não armazene**

O coração técnico do projeto. Em vez de guardar ligações entre as coisas, o sistema **recalcula** essas
ligações quando precisa — barato e sempre correto.

O exemplo mais importante é o gasto que **não aponta** para um orçamento (descrito acima). Isso evita
toda uma classe de problemas: nada de ligações quebradas, gastos órfãos, contagem dupla ou manutenção a
cada edição. **Armazene eventos; compute agrupamentos.**

---

## Arquitetura

Clean Architecture + DDD tático + Ports & Adapters, num **monólito modular** em **Python**.

- O **domínio** é Python puro, independente de framework, e se testa sem subir nada.
- A dependência aponta sempre **para dentro**: `infrastructure → application → domain`.
- Um pacote por contexto: `expenses`, `budgeting`, `identity`, `pairing` — todos com
  a mesma forma de três camadas (`domain` / `application` / `infrastructure`).

Duas decisões são **inegociáveis** e valem para todo o código:

- **Spec primeiro, sempre.** Nenhuma funcionalidade nasce sem uma **change do [OpenSpec](https://openspec.dev)**
  amarrada a ela. A spec é o contrato; o código é a consequência.
- **Async em toda fronteira de I/O.** Repositórios, casos de uso e handlers web são `async` ponta a ponta.
  Só o domínio puro (que não faz I/O) permanece síncrono.

> Os detalhes completos de modelo, convenções e regras vivem em [`CLAUDE.md`](./CLAUDE.md).

---

## Ferramentas do projeto (`.claude/`)

O repositório traz comandos e skills que **garantem** as regras acima na prática:

| Ferramenta | O que faz |
|---|---|
| `/trocado:feature` | Conduz uma funcionalidade no fluxo spec-first: change → scaffold → implementação → auditoria → arquivamento. |
| `/trocado:guard` | Audita o diff atual contra todas as regras inegociáveis e responde **PASS** / **CHANGES REQUIRED**. |
| `feature-scaffold` (skill) | Gera o esqueleto de uma feature nas convenções — e **se recusa** a gerar código sem uma change do OpenSpec. |
| `architecture-guard` (skill) | Lê o código e reporta violações (spec-first, async, camadas, nomenclatura, derive-não-armazene, dinheiro decimal, soft-delete, autorização). |

Mais o fluxo do OpenSpec: `openspec-explore`, `openspec-propose`, `openspec-apply-change`,
`openspec-archive-change`.

---

## Status

🚧 **Em concepção.** O domínio e as convenções estão definidos; a stack de borda (web e persistência) e os
comandos de build/test/run serão preenchidos quando escolhidos. Toda implementação começa por uma spec.
