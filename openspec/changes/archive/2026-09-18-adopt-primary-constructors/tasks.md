## 1. Compatibilidade E Convenção

- [x] 1.1 Confirmar que `pubspec.yaml` mantém Dart 3.13 ou superior como limite mínimo e que nenhum experiment flag ou nova dependência é necessário.
- [x] 1.2 Documentar nas orientações de contribuição exemplos, matriz de elegibilidade, preservação integral de contratos e adoção posterior incremental.
- [x] 1.3 Corrigir proposal, spec e design para selecionar explicitamente todas as declarações elegíveis em `lib/`, em vez de somente os cinco pilotos.

## 2. Inventário Completo

- [x] 2.1 Inventariar construtores em `lib/` e classificá-los como conversão direta, revisão manual ou retenção justificada.
- [x] 2.2 Confirmar que `test/` contém somente mocks sem construtores explícitos e não exige conversões.
- [x] 2.3 Registrar no diff final que interfaces, mixins comuns, classes `State`, mocks e construtores vazios sem estado permanecem sem primary constructor por não removerem boilerplate.

## 3. Conversões Diretas

- [x] 3.1 Converter declarações elegíveis em `lib/features/core/` e nos arquivos Dart da raiz, preservando assinaturas, defaults, constância e factories existentes.
- [x] 3.2 Converter declarações elegíveis em `authentication`, `dashboard`, `settings` e `welcome`, preservando tear-offs `Type.new` e contratos de navegação.
- [x] 3.3 Converter declarações elegíveis em `budget` e `expense`, preservando centavos inteiros, normalização, validações e invariantes financeiras.

## 4. Revisão Manual

- [x] 4.1 Revisar commands com initializer lists e converter somente quando repository parameters continuarem transitórios e a criação e descarte dos commands permanecerem equivalentes.
- [x] 4.2 Revisar construtores privados de entidades, asserts, factories, redirects, subscriptions e lifecycle; converter apenas quando nome, escopo, ordem e comportamento forem preservados.
- [x] 4.3 Inspecionar todos os call sites e o diff completo para eliminar exposições de parâmetros, reordenações, mudanças de corpo ou alterações fora da sintaxe necessária.

## 5. Verificação

- [x] 5.1 Executar `dart format` somente nos arquivos Dart alterados por esta change.
- [x] 5.2 Executar `flutter analyze` e corrigir todos os diagnósticos causados pela migração.
- [x] 5.3 Executar `flutter test` e registrar qualquer falha anterior ou não relacionada, sem adicionar widget tests para a refatoração sintática.
- [x] 5.4 Validar a change OpenSpec em modo estrito e confirmar que a migração completa satisfaz `dart-primary-constructor-conventions`.

## 6. Padrão Futuro

- [x] 6.1 Atualizar as orientações de contribuição para tornar primary constructors o padrão daqui para frente em toda declaração elegível e documentar as exceções concretas.
- [x] 6.2 Registrar na documentação de arquitetura a decisão estrutural, sua neutralidade entre camadas e a exigência de preservar contratos.
- [x] 6.3 Revisar o diff documental e validar novamente a change OpenSpec em modo estrito.
