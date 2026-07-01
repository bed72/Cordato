## Why

Os arquivos `main/` de `budgeting` e `pairing` ainda importam repositórios de features irmãs (`ExpenseRepository`, `BudgetRepository`, `PersonRepository`) para montar os callables que alimentam os gateways. A regra atual em `feature-composition` tolerava esse cruzamento nos `main/` — esta mudança fecha o último ponto de acoplamento: nenhum arquivo do projeto importa de outro feature, incluindo os `main/`.

## What Changes

- `budgeting/main/budgeting_route.py` deixa de importar `ExpenseRepository` de `expenses`; passa a usar um leitor de amounts próprio de `budgeting`
- `pairing/main/pairing_route.py` deixa de importar `ExpenseRepository` de `expenses`, `BudgetRepository` e `BudgetRepositoryInterface` de `budgeting`, `PersonRepository` e `PersonRepositoryInterface` de `identity`; passa a usar leitores próprios de `pairing`
- Cada módulo consumidor ganha um gateway de leitura local (com sua própria interface em `application/interfaces/`, como todo gateway do projeto) que retorna tipos já definidos no próprio módulo — duplicação intencional que garante evolução independente
- Quando o dado já existe como tipo próprio do módulo (`PartnerExpenseData`, `PartnerActiveBudgetData`, `PartnerProfileData`), a infraestrutura local popula esse tipo diretamente sem passar por entidades de outros features
- A regra em `feature-composition` é atualizada: **nenhum** arquivo de qualquer feature importa de outro feature, sem exceção para `main/`

## Capabilities

### New Capabilities

- `local-read-infrastructure`: cada módulo consumidor possui seu próprio gateway de leitura (`application/interfaces/*_reader_interface.py` + `infrastructure/gateways/*_reader.py`, seguindo o padrão de todo gateway do projeto — porta ABC + adaptador) com métodos que retornam tipos do próprio módulo, duplicando a lógica de query sem compartilhar código com o módulo produtor

### Modified Capabilities

- `feature-composition`: remoção da exceção que permitia imports cross-feature em `main/`; a regra passa a valer para todos os arquivos sem distinção de camada

## Impact

- `src/trocado/features/budgeting/main/budgeting_route.py` — remove import de `expenses`
- `src/trocado/features/pairing/main/pairing_route.py` — remove imports de `expenses`, `budgeting` e `identity`
- Novos arquivos em `budgeting/application/interfaces/`, `budgeting/infrastructure/gateways/`, `pairing/application/interfaces/`, `pairing/application/data/` e `pairing/infrastructure/gateways/`
- Testes dos novos readers
- `openspec/specs/feature-composition/spec.md` — atualização da regra
