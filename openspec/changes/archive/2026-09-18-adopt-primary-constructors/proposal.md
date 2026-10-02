## Why

O Cordato já exige Dart 3.13 e começou a usar primary constructors, mas ainda não possui uma convenção que defina onde a sintaxe melhora o código, quais casos devem permanecer tradicionais e como preservar contratos durante conversões. Formalizar essa decisão agora evita adoção inconsistente, migrações mecânicas arriscadas e diffs amplos sem ganho funcional.

## What Changes

- Estabelecer primary constructors como forma preferencial para novos tipos simples com um único construtor generativo principal, especialmente widgets, enums com dados, failures, value objects e implementações com dependências apenas armazenadas.
- Definir critérios objetivos para manter construtores tradicionais em inicializações complexas, múltiplos caminhos generativos ou situações em que a forma tradicional seja mais legível.
- Preservar nomes, parâmetros, nulabilidade, valores padrão, visibilidade, constância, tear-offs `Type.new`, factories, redirects e comportamento observável durante qualquer conversão.
- Migrar nesta change todas as declarações existentes elegíveis em `lib/`, incluindo widgets, enums com dados, failures, entidades, estados imutáveis e implementações que apenas armazenam dependências.
- Manter sem conversão apenas declarações sem benefício ou cuja forma tradicional seja necessária, como interfaces, mixins comuns, classes `State`, mocks, construtores vazios sem estado e construções complexas em que a sintaxe nova prejudique clareza ou semântica.
- Após a migração inicial completa, aplicar a convenção incrementalmente a código novo e a novas declarações elegíveis.
- Documentar Dart 3.13 como requisito mínimo da convenção e alinhar a documentação de contribuição do projeto.
- Manter factories e redirecting constructors no corpo da classe quando necessários e revisar manualmente commands, initializer lists, asserts e construtores com corpo.
- Validar a adoção por formatação, análise estática, testes existentes e busca por alterações acidentais de assinatura.

## Capabilities

### New Capabilities

- `dart-primary-constructor-conventions`: Regras de elegibilidade, preservação de contratos, exceções, compatibilidade de tooling e validação para adoção incremental de primary constructors no Cordato.

### Modified Capabilities

Nenhuma.

## Impact

- Afeta convenções de código Dart, documentação de contribuição e arquitetura, e todas as declarações existentes elegíveis em `lib/`; mocks e declarações sem construtor útil em `test/` permanecem inalterados.
- Exige Dart 3.13 ou superior; o requisito atual `sdk: ^3.13.2` já satisfaz essa condição.
- Não requer nova dependência, geração de código, mudança de analyzer, alteração de módulos, rotas, DI, Supabase ou bounded contexts.
- Não altera APIs de chamada, comportamento em runtime, performance, persistência, regras financeiras ou experiência do usuário.
- Factories, redirecting constructors e inicializações complexas continuam suportados, mas permanecem sujeitos a revisão manual em vez de transformação mecânica.
