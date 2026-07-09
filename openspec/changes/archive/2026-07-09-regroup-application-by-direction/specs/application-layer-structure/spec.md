## ADDED Requirements

### Requirement: A camada application é agrupada pela direção da porta

A camada `application/` de cada módulo SHALL ser organizada agrupando suas subpastas de categoria **pela
direção da porta** do hexágono, em dois segmentos de agrupamento: `driving/` (portas primárias/inbound — o
mundo chamando o app) e `driven/` (portas secundárias/outbound — o app chamando o mundo). As subpastas de
categoria SHALL residir sob o lado correspondente: `use_cases/`, `commands/` e `results/` sob `driving/`;
`ports/`, `repositories/` e `outcomes/` sob `driven/`. A camada SHALL NOT manter essas categorias soltas na
raiz de `application/` quando o módulo adota o agrupamento.

#### Scenario: Categorias driving residem sob driving/

- **WHEN** o código-fonte de um módulo com use cases é inspecionado
- **THEN** `use_cases/`, `commands/` e `results/` residem sob `application/driving/`
- **AND** os tipos correspondentes declaram `package` terminando em `.application.driving.<categoria>`

#### Scenario: Categorias driven residem sob driven/

- **WHEN** o código-fonte de um módulo é inspecionado
- **THEN** `ports/`, `repositories/` e `outcomes/` residem sob `application/driven/`
- **AND** os tipos correspondentes declaram `package` terminando em `.application.driven.<categoria>`

### Requirement: A regra pasta-folha-é-sufixo-de-categoria é preservada

O agrupamento por direção SHALL preservar a convenção `<Meaning><Category>` em que a **pasta-folha** nomeia o
sufixo do tipo. Os segmentos `driving/` e `driven/` SHALL ser segmentos de agrupamento com significado (como
`infrastructure/http/`), que NÃO impõem sufixo próprio aos tipos abaixo deles — nenhum tipo ganha um sufixo
`Driving`/`Driven`. Cada tipo SHALL continuar carregando o sufixo da sua pasta-folha (`SignUpCommand` em
`commands/`, `UpdateEmailOutcome` em `outcomes/`).

#### Scenario: Os tipos mantêm o sufixo da pasta-folha, não da direção

- **WHEN** os tipos sob `driving/` e `driven/` são inspecionados
- **THEN** cada tipo carrega o sufixo da sua pasta-folha de categoria (`Command`, `Result`, `UseCase`,
  `Outcome`, `Repository`, `Port`)
- **AND** nenhum tipo carrega um sufixo `Driving` ou `Driven`

### Requirement: Nenhum balde genérico agrupa a camada application

A camada `application/` SHALL NOT introduzir um segmento de agrupamento genérico — `data/`, `dto/`,
`models/` ou similar — para agrupar categorias. Quando as subpastas de `application/` são agrupadas, o
agrupamento SHALL ser exclusivamente por direção do hexágono (`driving/`/`driven/`), que nomeia um conceito
arquitetural real, e nunca por um rótulo genérico que junte direções opostas do hexágono.

#### Scenario: Ausência de segmento de agrupamento genérico

- **WHEN** a árvore de pacotes de `application/` de qualquer módulo é inspecionada
- **THEN** não existe nenhuma pasta `data/`, `dto/` ou `models/` agrupando categorias
- **AND** o único agrupamento de categorias presente é por direção (`driving/`/`driven/`)

### Requirement: Mappers de aplicação ficam neutros na raiz de application

Quando um módulo possui mappers de aplicação, a pasta `mappers/` SHALL residir na **raiz** de `application/`,
fora de `driving/` e de `driven/`, por atravessar os dois lados (por exemplo, traduzir um `Outcome` do lado
driven em um `Result`/`Error` do lado driving). A pasta `mappers/` SHALL NOT ser aninhada sob nenhum dos dois
lados.

#### Scenario: mappers/ é neutro na raiz

- **WHEN** um módulo com mappers de aplicação é inspecionado
- **THEN** `mappers/` reside diretamente sob `application/`, no mesmo nível de `driving/` e `driven/`
- **AND** `mappers/` não reside sob `driving/` nem sob `driven/`

### Requirement: Um módulo aplica apenas os lados que possui

Cada módulo SHALL criar apenas os segmentos de direção correspondentes aos lados que efetivamente possui,
sem pastas de agrupamento vazias. Um módulo sem use cases (o kernel `core/`, que é determinismo + persistência
+ sessão) SHALL conter apenas `driven/`, sem `driving/`. Um módulo com os dois lados (uma feature como
`identity/`) SHALL conter `driving/` e `driven/`.

#### Scenario: O kernel expõe apenas o lado driven

- **WHEN** a camada `application/` de `core/` é inspecionada
- **THEN** existe `driven/` (com `ports/` e `repositories/`) e não existe `driving/`

#### Scenario: Uma feature com os dois lados expõe ambos

- **WHEN** a camada `application/` de `identity/` é inspecionada
- **THEN** existem `driving/` (com `use_cases/`, `commands/`, `results/`) e `driven/` (com `ports/`,
  `repositories/`, `outcomes/`)

### Requirement: O agrupamento não altera domain, infrastructure nem comportamento

A convenção de agrupamento SHALL afetar exclusivamente a camada `application/`. As camadas `domain/` e
`infrastructure/` (incluindo `infrastructure/http/mappers/`) SHALL permanecer com sua estrutura inalterada.
A reorganização SHALL NOT alterar nenhuma assinatura pública, rota HTTP, contrato de erro, migração ou regra
de domínio — é movimentação de arquivos e ajuste de `package`/imports, cuja equivalência é provada pela suíte
de testes e pelo Konsist verdes.

#### Scenario: domain e infrastructure permanecem inalterados

- **WHEN** o diff da reorganização é inspecionado
- **THEN** nenhum arquivo sob `domain/` ou `infrastructure/` muda de pacote por causa do agrupamento

#### Scenario: A suíte prova a equivalência de comportamento

- **WHEN** `./gradlew build` (Konsist incluído) é executado após a reorganização
- **THEN** a build passa sem alteração de testes de comportamento, provando que nenhum comportamento mudou
