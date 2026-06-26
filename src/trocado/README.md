# `trocado/` — mapa dos módulos

Ponto de entrada do código. Este README costura os módulos e diz **onde cada coisa mora**;
ele não repete regras nem comportamento — esses vivem em outros lugares (ver [Onde aprofundar](#onde-aprofundar)).

> Se você lembrar de uma só coisa: **um casal é um ponto de vista, não um dono.** Cada pessoa é dona
> do próprio dinheiro; o par é uma *lente de leitura* sobre dois indivíduos, reversível sem perda.

## Os dois tipos de pacote

| Pacote | Natureza | Papel |
|---|---|---|
| `core/` | **shared kernel** | O que todo módulo precisa: dinheiro exato, portas de determinismo (relógio, id). Segue a mesma estrutura de uma feature. |
| `features/<contexto>/` | **bounded context** | Um pacote por contexto, todos com o mesmo formato. **Não existe `shared/`.** |

## Módulos hoje

| Módulo | Responsabilidade em uma linha | README |
|---|---|---|
| `core` | Kernel compartilhado: `MoneyValueObject` + portas `Clock`/`IdentifierProvider`. | [core/README.md](core/README.md) |
| `features/identity` | A pessoa — âncora do ledger: cadastro, e-mail, nome, senha (hash). | [features/identity/README.md](features/identity/README.md) |
| `features/expenses` | O gasto — fato atômico: quem gastou, quanto, em que dia. Zero link a budget. | [features/expenses/README.md](features/expenses/README.md) |
| `features/budgeting` | O orçamento — teto por intervalo de datas; gasto e saldo **derivados**. | [features/budgeting/README.md](features/budgeting/README.md) |
| `features/pairing` | O ponto de vista — liga dois indivíduos; começa pelo convite (`create-invite-code`). | [features/pairing/README.md](features/pairing/README.md) |

## A regra de modelagem que atravessa tudo: derive, don't store

O grafo de referências é **deliberadamente plano**. Um link só existe quando é um **fato intrínseco de
posse** (uma pessoa é dona de um budget) — nunca pela conveniência de uma query. A associação
`Expense ──╳── Budget` **não existe**: o pertencimento é calculado em tempo de leitura por contenção de
data. Isso reaparece em três pontos do domínio, e essa repetição é o sinal de que o modelo é consistente
consigo mesmo.

## A direção da dependência aponta sempre para dentro

```
infrastructure → application → domain
```

`domain/` não importa nada de fora. Cada módulo tem as três camadas:

| Camada | Conteúdo | Conhece a lib/ORM? |
|---|---|---|
| `domain/` | `entities/`, `value_objects/`, `virtual_objects/`, `errors/` — Python puro, síncrono | nunca |
| `application/` | `interfaces/` (portas ABC), `data/` (comandos e read-models), `use_cases/`, `mappers/` | não |
| `infrastructure/` | `repositories/` (+ `models/`, `mappers/`) e `gateways/` (todo o resto) | **só aqui** |

## Estágio atual (transitório)

Web e ORM ainda **deferidos**. Cada feature ship como **vertical slice in-memory, totalmente testada**:
`domain/` puro + portas em `application/` + adapter **in-memory** em `repositories/` + `gateways/` reais
(ex.: hasher Argon2). **Sem `Model`/`ModelMapper`** até o ORM ser escolhido — eles ligam uma tabela que
ainda não existe. Quando ORM/web entrarem, encaixam atrás das portas existentes sem tocar em
`domain/`/`application/`.

## Onde aprofundar

- **Convenções e regras inegociáveis** (layering, naming, async, money, soft-delete, autorização) →
  [`../../CLAUDE.md`](../../CLAUDE.md)
- **Comportamento (fonte de verdade)** → `openspec/specs/<capability>/spec.md`
- **Auditar um diff contra as regras** → `/trocado:guard`
