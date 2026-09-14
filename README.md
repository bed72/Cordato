# Cordato

Aplicativo Flutter de finanças pessoais. O objetivo é ajudar cada pessoa a
cuidar do próprio dinheiro com clareza e, quando houver pareamento, oferecer
uma visão compartilhada das finanças do casal.

## Produto

O modelo de negócio foi definido no backend legado em Kotlin. O backend ativo
do aplicativo é o Supabase versionado neste repositório. A regra central é:

> A pessoa é dona dos próprios dados. O casal é apenas uma lente de leitura.

Os bounded contexts do produto são:

- `expense`: implementado. Fatos atômicos de gastos de uma pessoa.
- `budget`: implementado. Tetos planejados por intervalo de datas; gasto e saldo são derivados.
- `couple`: planejado. Pareamento com acesso compartilhado somente de leitura.
- `insight`: placeholder de apresentação visível. Análises financeiras derivadas,
  somente leitura e sem persistência própria continuam planejadas.

O contexto `identity` do backend não será reproduzido no app neste momento. A
autenticação e a sessão são fornecidas pelo Supabase Auth através de magic link.
O contexto `chat` está fora do escopo atual.

## Estado atual

O app já possui:

- tela de boas-vindas;
- autenticação por e-mail com magic link;
- callback de autenticação e restauração de sessão;
- dashboard inicial com dados do usuário;
- criação de gastos e orçamentos individuais;
- tela de configurações;
- navegação autenticada persistente entre Dashboard, Transações, Insights e
  Configurações, com Transações e Insights ainda como placeholders;
- tema claro/escuro e componentes de apresentação reutilizáveis.

As próximas features devem priorizar pareamento e insights, sem transformar o
casal em dono de dados financeiros.

## Arquitetura

O código é organizado por feature e por camadas:

```text
presentation -> domain -> data -> infrastructure -> Supabase
```

`presentation` não conhece SDKs externos. `domain` contém contratos e regras
independentes de framework, `data` implementa os repositórios e
`infrastructure` encapsula Supabase, storage e plugins.

Consulte [`ARCHITECTURE.md`](ARCHITECTURE.md) para módulos, rotas, limites
técnicos e validação, e [`AGENTS.md`](AGENTS.md) para as convenções de
contribuição.

## Desenvolvimento

```bash
flutter pub get
flutter analyze
flutter test
```

Para abrir os previews de telas e componentes no Widget Previewer do Flutter:

```bash
flutter widget-preview start
```

Para executar o app, forneça as configurações do Supabase:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://example.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=...
```

`SUPABASE_REDIRECT_URL` é opcional e possui um valor padrão no módulo de
autenticação.

## Android Release

O processo de configuração segura da chave, build e verificação de artefatos
Android está documentado em [`android/README.md`](android/README.md).

## Backend Supabase

A configuração local, migrações ordenadas e documentação do backend vivem em
[`supabase/`](supabase/README.md). Para provisionar e validar um banco local
limpo, com Docker e a Supabase CLI instalados:

```bash
supabase start
supabase db reset
supabase migration list --local
supabase db lint --local
supabase test db
```

Não edite o schema pelo dashboard. Toda mudança de banco, RLS, grants,
triggers ou funções deve ser adicionada como uma nova migration em
`supabase/migrations/`. `supabase test db` executa testes locais de schema, RPC,
autorização, invariantes e concorrência; eles são distintos dos testes Flutter.

## Revisão De Mudanças

Mudanças em módulos, rotas, contratos, migrations, RPCs, RLS, comandos de
validação ou configuração de release devem atualizar, na mesma alteração, a
documentação canônica correspondente. Consulte a seção de revisão em
[`ARCHITECTURE.md`](ARCHITECTURE.md#revisão-de-documentação).
