# `identity/` — a pessoa

A pessoa é a **âncora do ledger**: tudo (budgets, expenses, pares, notificações) pendura do `id` dela.
Este módulo cuida de quem essa pessoa é e de como ela entra no sistema.

## Responsabilidade

- **Cadastrar** uma pessoa (hoje o único caso de uso: `create-person`).
- Garantir os invariantes de identidade: **e-mail único e válido**, **nome válido**, **senha forte** —
  e que a senha seja persistida **só como hash**, nunca em plaintext.
- Expor o conceito de **status** de conta (`active` / `deleted`).

### O que ele deliberadamente NÃO faz

- **Não é dono de dinheiro.** Nenhum budget, expense ou agregado mora aqui — só hangam do `id`.
- **Não guarda senha em claro.** A entidade carrega **o hash** (uma `str` simples — sem value object,
  porque um hash não tem invariante a defender). O plaintext é consumido no hash e descartado.
- **Não conhece o algoritmo de hash.** Argon2 vive atrás de uma porta; trocar de algoritmo não toca o
  domínio nem o use case.
- **Não decide HTTP.** Erros de domínio são mensagens curtas em pt-BR que **não vazam dado sensível**
  (revelar se um e-mail existe é enumeração de conta).

## Vocabulário

| Termo | É | Significa |
|---|---|---|
| `PersonEntity` | entidade | Âncora do ledger. Igualdade por `id`. Nasce só via `create(...)`, sempre `ACTIVE`. |
| `EmailValueObject` | value object | Valida **e** normaliza o e-mail (ganha sua existência). |
| `NameValueObject` | value object | Valida o nome. |
| `PasswordValueObject` | value object | Valida a política e esconde o plaintext (transitório, nunca persistido). |
| `password: str` | primitivo | O **hash** guardado na entidade — propositalmente *não* é value object. |
| `PersonStatus` | enum/VO | `ACTIVE` / `DELETED`. `DELETED` só por exclusão de conta. |
| `PasswordHasherInterface` | porta | `async hash(PasswordValueObject) -> str`. Mora em identity (concern de auth), não no core. |

## Mapa do módulo

| Camada | Arquivo | Papel |
|---|---|---|
| domain / entities | `person_entity.py` | A pessoa; factory `create(...)` nasce `ACTIVE`. |
| domain / value_objects | `email_value_object.py` · `name_value_object.py` · `password_value_object.py` · `person_status.py` | Invariantes de identidade. |
| domain / errors | `email_already_in_use_error.py` · `invalid_email_error.py` · `invalid_name_error.py` · `weak_password_error.py` | Recusas em pt-BR, sem vazar valor. |
| application / data | `create_person_data.py` (comando) · `person_data.py` (read-model) | Entrada/saída do use case. |
| application / interfaces | `person_repository_interface.py` · `password_hasher_interface.py` | Portas ABC. |
| application / use_cases | `create_person_use_case.py` | Orquestra: valida, checa e-mail único, hasheia, persiste. |
| application / mappers | `person_data_mapper.py` | `Entity → Data`. |
| infrastructure / repositories | `person_repository.py` | Adapter in-memory (por enquanto). |
| infrastructure / gateways | `password_hasher.py` | Argon2; chamada síncrona embrulhada com `asyncio.to_thread` na borda. |

## Detalhe de orquestração

O use case mantém o **guard antes do gather**: checa a unicidade do e-mail *antes* de pagar pelo hashing
de senha (caro). Awaits independentes (`id`, `created_at`) vão juntos via `asyncio.gather`.

## Estado atual vs. deferido

Vertical slice in-memory: `person_repository.py` é em memória; o `password_hasher.py` (Argon2) já é real.
**Deferido:** `PersonModel`/`PersonModelMapper` (entram com o ORM), e os lifecycles de **exclusão de
conta** (hard-delete) descritos no `CLAUDE.md` ainda não implementados.

## Onde aprofundar

- **Convenções** → [`../../../../CLAUDE.md`](../../../../CLAUDE.md) (entidade *Person*, *Domain error messages*)
- **Comportamento** → `openspec/specs/register-person/spec.md`
