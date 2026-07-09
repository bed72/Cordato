## Context

A camada `application/` de cada bounded context segue hoje a convenção "uma pasta por categoria de tipo"
(`commands/`, `results/`, `outcomes/`, `ports/`, `repositories/`, `use_cases/`), com a pasta-folha nomeando
o sufixo do tipo (`<Meaning><Category>`). Em `identity` isso já são seis subpastas de topo; à medida que os
contextos crescem (`budget`, `couple` terão ACL, convites, invariantes de não-sobreposição), a lista plana
deixa de ser escaneável e os dois lados do hexágono passam a se misturar visualmente.

O CLAUDE.md já descreve conceitualmente a distinção *driving* vs. *driven* ("These are all *driven*
(secondary) ports — the app calling out. The *driving* (primary) side ... is already served by the public
signatures of `use_cases/`"), mas ela não tem forma física no layout de pastas. Este change dá forma a esse
conceito já assumido, sem inventar nada novo.

Restrições herdadas do CLAUDE.md, todas preservadas: naming Hexagonal (não genérico); `domain/` e
`application/` framework-agnósticos (Konsist); a regra "pasta-folha = sufixo de categoria"; "same internal
shape" por contexto.

## Goals / Non-Goals

**Goals:**
- Agrupar `application/` pela **direção da porta** — `driving/` (inbound) e `driven/` (outbound) — o eixo
  primário de Ports & Adapters.
- Fixar como convenção documentada (CLAUDE.md) a regra "sem balde genérico; se agrupar, é por direção".
- Migrar fisicamente os dois módulos com código hoje (`core/`, `identity/`) sem alterar comportamento.

**Non-Goals:**
- Tocar em `domain/` ou `infrastructure/` (inclusive `infrastructure/http/mappers/` — os mappers de HTTP
  não são afetados; identity ainda não tem `application/mappers/`).
- Mudar qualquer assinatura pública, rota HTTP, contrato de erro, migração ou regra de domínio.
- Adotar em `budget`/`expense`/`couple` (ainda são só design nos READMEs — nada a mover).
- Adicionar a regra Konsist que executa a convenção (barra subpastas fora de `driving`/`driven`/`mappers`) —
  fica para um change futuro.

## Decisions

### 1. Agrupar por direção (`driving/` + `driven/`), não por "tipo de arquivo" nem por balde genérico

```
application/
  driving/     ← o mundo chamando o app (portas primárias/inbound)
    use_cases/   commands/   results/
  driven/      ← o app chamando o mundo (portas secundárias/outbound)
    ports/       repositories/   outcomes/
  mappers/     ← tradução entre os dois lados (neutro; fica na raiz)
```

| Subpasta        | Lado    | Papel                                                              |
|-----------------|---------|-------------------------------------------------------------------|
| `use_cases/`    | driving | A porta primária: a assinatura pública que o mundo invoca.        |
| `commands/`     | driving | Entrada do use case (o pedido do mundo, cru).                     |
| `results/`      | driving | Saída do use case para a borda (read-model / resultado selado).  |
| `ports/`        | driven  | Contrato que o app precisa do mundo externo (hashing, clock, ACL).|
| `repositories/` | driven  | Contrato de persistência (subtipo de porta driven, termo DDD).   |
| `outcomes/`     | driven  | Desfecho enumerado que uma porta driven devolve ao use case.     |
| `mappers/`      | neutro  | Tradução entre lados (`Outcome` → `Result`/`Error`); raiz.       |

**Rationale:** o projeto já usa prefixos de agrupamento, mas só quando nomeiam um conceito real
(`infrastructure/http/`, `.../http/authentication/`, `core/infrastructure/persistence/`). `driving`/`driven`
nomeiam o lado do hexágono — o conceito estruturante da camada — exatamente como `http/` nomeia um protocolo.
São segmentos de agrupamento com significado que **não** carregam sufixo próprio (assim como `http/` não
impõe um sufixo `Http`), então a regra `<Meaning><Category>` da pasta-folha continua valendo intacta:
`commands/` segue guardando `SignUpCommand`, `outcomes/` segue guardando `UpdateEmailOutcome`.

**Alternativas consideradas:**
1. *Manter plano (status quo).* Idiomático, cada pasta tem nome preciso — a escolha certa **até** o gatilho
   de ~8–10 subpastas. `identity` está no limiar; é o candidato natural para ser o primeiro exemplo
   trabalhado. Rejeitada como estado final, aceita como o "de onde partimos".
2. *Balde `data/` sobre `commands`/`results`/`outcomes`.* Rejeitada: nome genérico proibido pela filosofia
   do projeto, e junta direções opostas do hexágono — apaga a distinção que a arquitetura preserva.
3. *Agrupar por caso de uso* (uma pasta por feature com command/result/use_case juntos). Rejeitada: quebra a
   convenção "pasta = sufixo de categoria" transversal e espalha a mesma categoria por N pastas.

### 2. `mappers/` fica neutro na raiz de `application/`, fora de `driving`/`driven`

Um mapper de aplicação frequentemente atravessa os dois lados (traduz um `Outcome` do lado driven em um
`Result`/`Error` do lado driving, ou monta um `Result` a partir de uma entidade de domínio), então não
pertence limpo a nenhum. (Hoje identity não tem `application/mappers/` — a decisão vale para quando surgir.)

### 3. Um módulo aplica só os lados que possui — pastas vazias não são criadas

- `core/` é só determinismo + persistência + sessão, **sem use cases** → só `driven/`
  (`driven/ports/`, `driven/repositories/`). Sem `driving/`, sem `mappers/`.
- `identity/` tem os dois lados → `driving/{use_cases,commands,results}` +
  `driven/{ports,repositories,outcomes}`.

### 4. Escopo desta migração: só `core/` e `identity/`; consistência garantida por serem os únicos com código

O CLAUDE.md exige "same internal shape" por contexto. Como só `core/` e `identity/` têm código de
`application/` hoje, migrar ambos já mantém a forma consistente entre todos os contextos existentes;
`budget`/`expense`/`couple` nascerão já na forma nova quando forem implementados.

## Risks / Trade-offs

- **[Imports/`package` desatualizados quebram a compilação]** → o compilador Kotlin e o Konsist pegam
  qualquer referência órfã; `./gradlew build` verde é o critério de aceite. Movimentação puramente mecânica.
- **[Wiring de DI (`main/IdentityFactory.kt`, `CoreFactory.kt`) referencia os tipos movidos]** → só ajuste
  de imports; os `@Factory` constroem os mesmos tipos com os mesmos parâmetros. Coberto pelo build.
- **[Espelhos de teste (`factories/`, doubles) importam os tipos movidos]** → acompanham os novos pacotes;
  a suíte de testes verde prova a equivalência de comportamento.
- **[Ruído de diff grande mas raso]** → é o preço de um refactor de mover-arquivos; isolado num change
  próprio (fora do trabalho de feature), o diff fica legível como "só renomeações de `package`".
- **Reversível:** como nada de comportamento muda, reverter é `git revert` do commit de movimentação.

## Migration Plan

Por módulo (repetir para `core/` e `identity/`):
1. Criar `driving/` e/ou `driven/` sob `application/` conforme os lados que o módulo possui.
2. Mover cada subpasta de categoria para o lado correto (produção **e** espelho de teste).
3. Atualizar as declarações de `package` dos arquivos movidos e todos os imports que os referenciam
   (incluindo `main/` factories, controllers, mappers de HTTP, testes).
4. `./gradlew build` (Konsist incluso) verde.

Depois dos dois módulos: atualizar o CLAUDE.md (tabela de camadas + regra "sem balde genérico; agrupar por
direção"; `mappers/` neutro na raiz) e remover o `proposal.md` da raiz do repo (consolidado aqui).

**Rollback:** `git revert` do commit — nenhum estado externo (DB, contrato HTTP) é tocado.

## Open Questions

- **Nome do lado driven:** `driven/` é o termo canônico de Ports & Adapters e casa com o vocabulário do
  CLAUDE.md ("driven (secondary) ports"); mantido salvo objeção.
- **`mappers/` na raiz vs. por lado:** mantido neutro na raiz; revisitar só se surgir um mapper claramente
  de um lado só.
- **Regra Konsist executável:** desejável, mas fora do escopo deste change (evita acoplar a migração a uma
  nova regra de arquitetura).
