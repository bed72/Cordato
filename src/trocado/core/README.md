# `core/` — shared kernel

O que **todo** módulo precisa e nenhum deve duplicar. Segue a mesma estrutura de uma feature
(`domain/` · `application/` · `infrastructure/`), mas não é um bounded context: não tem caso de uso
próprio, não é dono de nenhum dado de negócio. É um fornecedor de **vocabulário** e de **portas**.

## Responsabilidade

- **Dinheiro exato.** `MoneyValueObject` — a única forma de representar valor em BRL no projeto.
- **Determinismo.** As portas que tiram o não-determinismo (`now()`, `generate()`) de dentro do domínio
  puro, para que entidades sejam testáveis e reprodutíveis.

### O que ele deliberadamente NÃO faz

- **Não conhece nenhuma feature.** A dependência aponta para o core, nunca dele para fora.
- **Não é depósito de utilitários.** Algo só entra no kernel quando é necessidade **transversal** real.
  Hashing de senha, por exemplo, mora em `identity` (é concern de autenticação), **não** aqui.
- **Não tem caso de uso.** O core oferece tipos e contratos; quem orquestra são as features.

## Vocabulário

| Termo | É | Significa |
|---|---|---|
| `MoneyValueObject` | value object | Decimal exato, BRL, normalizado a 2 casas. Nunca `float`. Sinal livre (zero/negativo válidos — para representar `remaining` negativo). Mais de 2 casas → erro, nunca arredonda em silêncio. |
| `ClockInterface` | porta | `async now() -> datetime` timezone-aware (UTC). O domínio nunca chama `datetime.now()`. |
| `IdentifierProviderInterface` | porta | `async generate() -> str` opaco. O domínio nunca chama `uuid`; a ordenação temporal (UUIDv7) é detalhe do adapter. |

## Mapa do módulo

| Camada | Arquivo | Papel |
|---|---|---|
| domain / value_objects | `money_value_object.py` | Valor monetário exato em centavos. |
| domain / errors | `invalid_money_error.py` | Recusa de valor não-finito ou com casas demais. |
| application / interfaces | `clock_interface.py` | Porta do relógio. |
| application / interfaces | `identifier_provider_interface.py` | Porta de geração de id. |
| infrastructure / gateways | `clock.py` | Adapter do relógio (wall clock real, UTC). |
| infrastructure / gateways | `identifier_provider.py` | Adapter de id (UUIDv7, `uuid.uuid7()`). |

## O padrão das portas de determinismo

O domínio puro deve ser **sem I/O e determinístico sob teste**, mas `id` e `created_at` são
não-determinísticos. A solução: o use case pede esses valores às portas e os **passa para a factory** da
entidade (`Entity.create(id=..., created_at=...)`). Em teste, fakes devolvem valores fixos; em produção,
os adapters de `gateways/` devolvem os reais. Entidades nunca chamam `uuid`/`datetime` diretamente.

## Estado atual vs. deferido

Os `gateways/` aqui são **reais** desde já (não são in-memory) — relógio e id não dependem de ORM nem de
web. Nada deferido neste módulo.

## Onde aprofundar

- **Convenções** → [`../../../CLAUDE.md`](../../../CLAUDE.md) (seção *Determinism, time, and identity*)
- **Comportamento** → `openspec/specs/core-determinism/spec.md`
