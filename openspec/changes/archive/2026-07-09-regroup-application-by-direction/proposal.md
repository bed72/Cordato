## Why

A camada `application/` de um contexto vem crescendo em número de subpastas de topo — `identity` já tem
seis (`commands`, `results`, `outcomes`, `ports`, `repositories`, `use_cases`) e está no limiar em que a
lista plana deixa de ser escaneável. A tentação natural é um balde genérico (`data/`), mas o CLAUDE.md o
proíbe ("Naming is deliberately Hexagonal, **not generic**") e ele apagaria justamente a distinção que a
arquitetura preserva: `commands`/`results` são o vocabulário do lado *driving* (o mundo chamando o app),
enquanto `outcomes`/`ports`/`repositories` são o lado *driven* (o app chamando o mundo). Este change
materializa fisicamente uma distinção que o CLAUDE.md já descreve conceitualmente, agrupando `application/`
**pela direção da porta** (`driving/` + `driven/`) em vez de por "tipo de arquivo".

## What Changes

- **Convenção estrutural (documentação):** o CLAUDE.md passa a documentar `application/` agrupado por
  `driving/` (portas primárias/inbound: `use_cases/`, `commands/`, `results/`) e `driven/` (portas
  secundárias/outbound: `ports/`, `repositories/`, `outcomes/`), com `mappers/` neutro na raiz por
  atravessar os dois lados. Regra fixa: **nunca** um balde genérico (`data/`, `dto/`, `models/`); se
  agrupar, é por direção do hexágono. A regra "pasta-folha = sufixo de categoria" (`<Meaning><Category>`)
  permanece inalterada — `driving`/`driven` são segmentos de agrupamento com significado, como `http/`, que
  não impõem sufixo próprio.
- **Migração física (só `application/`):** mover as subpastas de `application/` para dentro de `driving/`
  e `driven/` nos dois módulos que hoje têm código, ajustando declarações de `package` e imports:
  - `core/`: só o lado *driven* (`driven/ports/`, `driven/repositories/`) — o kernel não tem use cases.
  - `identity/`: os dois lados (`driving/{use_cases,commands,results}`, `driven/{ports,repositories,outcomes}`).
- **Sem mudança de comportamento.** `domain/` e `infrastructure/` ficam intactos. Nenhuma assinatura
  pública, rota, contrato HTTP ou regra de domínio muda — é só movimentação de arquivos + `package`/imports.
  A suíte de testes e o Konsist provam a equivalência.

## Capabilities

### New Capabilities
- `application-layer-structure`: a convenção estrutural da camada `application/` de cada módulo — agrupamento
  por direção do hexágono (`driving/` + `driven/`), `mappers/` neutro na raiz, proibição de balde genérico e
  preservação da regra "pasta-folha = sufixo de categoria". Segue o precedente das capabilities estruturais
  já existentes (`api-versioning`, `dependency-injection`): requisitos verificáveis por inspeção do
  código-fonte, sem comportamento de runtime.

### Modified Capabilities
<!-- Nenhuma: nenhum requisito de comportamento de runtime muda; apenas se acrescenta a convenção estrutural acima. -->

## Impact

- **Código:** apenas arquivos sob `core/src/main/kotlin/.../core/application/` e
  `.../features/identity/application/` (produção) e seus espelhos de teste — mudam declarações de `package`
  e imports; nenhum corpo de método muda. Os testes que importam esses tipos acompanham os novos pacotes.
- **Docs:** CLAUDE.md (tabela de camadas + regra "sem balde genérico; agrupar por direção"). O `proposal.md`
  na raiz do repo é o design detalhado desta decisão e é consolidado no `design.md` deste change (e removido
  da raiz ao final).
- **Sem impacto:** APIs HTTP, migrações, dependências, DI (`main/` factories só ajustam imports),
  `domain/`, `infrastructure/`. Nenhum contrato externo muda.
- **Konsist:** os testes de arquitetura existentes devem continuar verdes; uma regra futura que barre
  subpastas de `application/` fora de `driving`/`driven`/`mappers` fica fora do escopo deste change.
