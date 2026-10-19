# AGENTS.md

## Objetivo E Fonte De Verdade

Estas regras orientam alterações no aplicativo Flutter Cordato e em seus testes.
A arquitetura canônica está em [ARCHITECTURE.md](ARCHITECTURE.md); o início rápido
e o estado do produto estão em [README.md](README.md).

Authentication/Sign-in é a implementação de referência para novas features e
migrações. O padrão obrigatório é:

```text
Screen/Widget -> Bloc -> contrato de repository em application
                           ^
                repository em infrastructure -> clients do core -> SDKs
```

O Bloc chama o contrato; o módulo injeta a implementação. Contratos retornam
dados por `Future<T>` e falhas esperadas por exceções de aplicação. Não use
`Either`, `Left`/`Right`, `response<T>`, CommandIt ou data sources como padrão
para código novo ou para um fluxo migrado.

Há código legado incompatível com esse desenho. Sua existência não constitui
uma exceção arquitetural aprovada. Não descreva a migração como concluída e não
amplie uma tarefa localizada para migrar o restante do aplicativo sem solicitação.
Specs OpenSpec, skills e referências a Supabase/RPC podem estar desatualizadas;
não restaure o fluxo antigo para satisfazer uma descrição histórica.

## Antes De Alterar

- Leia a feature afetada, os componentes compartilhados usados e seus testes.
- Confira `git status` e preserve alterações existentes, inclusive fora do escopo.
- Faça a menor alteração que satisfaça a tarefa; não reformate áreas não relacionadas.
- Não faça commit, push, reset ou exclusões destrutivas sem solicitação explícita.
- Atualize contratos, consumidores, bindings e testes na mesma mudança.
- Registre bloqueios reais de análise, compilação e testes, sem ocultá-los.
- Não adicione comentários de linha, bloco ou documentação ao código. Explicações
  ficam em Markdown; preserve comentários existentes fora do escopo.

## Produto E Limites

Cordato é um aplicativo de finanças pessoais e familiares. Cada pessoa é dona
dos próprios dados; família é uma lente autorizada de leitura, não dona do dinheiro.

| Feature/contexto | Responsabilidade |
| --- | --- |
| `authentication` | Entrada, cadastro, confirmação de e-mail, reenvio e logout. |
| `session` | Leitura e observação da presença do token. |
| `user` | Dados pessoais, nome, avatar e exclusão da conta. |
| `expense` | Fatos atômicos de gastos individuais. |
| `metrics` | Agregações financeiras somente leitura. |
| `insight` | Análises derivadas somente leitura, sem persistência própria. |
| `budget` | Planejado: tetos por intervalo de datas. |
| `family` | Planejado: organização de membros e leitura combinada. |
| `dashboard` | Apresentação e composição, não um bounded context financeiro. |
| `root` | Composição visual global e entrada do app. |

Não crie `identity` para reproduzir o backend legado. `chat` está fora do escopo.
O Kotlin legado é referência de domínio, não de estrutura Flutter.

Preserve as invariantes:

- Dinheiro em centavos inteiros de BRL; nunca use `double` para valores monetários.
- Gasto não referencia orçamento; pertencimento é derivado da data civil.
- Orçamentos vivos da mesma pessoa não podem se sobrepor.
- Família não concede escrita nos dados de outro membro.
- Sair ou encerrar família não altera os dados individuais.
- Visões combinadas e insights são derivados dos dados proprietários.
- Não apresente autorização do backend como garantia implementada pelo Flutter.

## Camadas E Arquivos

```text
lib/features/<feature>/
  <feature>_module.dart
  domain/
    entities/
    enums/
    value_objects/
  application/
    exceptions/
    repositories/interface_<feature>_repository.dart
  infrastructure/
    repositories/<feature>_repository.dart
    responses/
  presentation/
    screens/<screen>/
      <screen>_screen.dart
      bloc/
      mixins/
      widgets/
    validators/
    widgets/
    previews/
```

Crie somente diretórios necessários. Features exclusivamente visuais não precisam
de domínio ou repository. Não adicione use cases, inputs, outputs, services,
data sources, BaseBloc ou stores globais sem necessidade concreta aprovada.

- `domain`: tipos e regras puros, sem Flutter, Bloc, HTTP, storage ou application.
- `application`: contratos de operações e exceções esperadas, sem adapters ou UI.
  Contratos de repository ficam aqui, não em `domain/repositories/`.
- `infrastructure`: implementa os contratos e coordena HTTP, DTOs e persistência
  usando interfaces de clients do core. Não importe Dio no repository da feature.
- `presentation`: Bloc, estados, eventos, telas, validação e feedback. Conhece
  contratos e exceções de aplicação, nunca repositories concretos ou clients.
- Módulos fazem a composição e podem importar implementações concretas.
- `core` contém capacidades realmente compartilhadas; não mova regras de uma
  feature para ele apenas para contornar um limite de dependência.

Authentication e Session não importam uma à outra; comunicam-se pela chave de
token do storage. Expense e Budget não dependem de outros contextos financeiros.
Family e Insight devem consultar contextos proprietários por contratos próprios
com adapters em infrastructure, sem dependência reversa. Dashboard pode compor
contratos de aplicação dos contextos que consulta.

## Repositories, HTTP E Falhas

- Use parâmetros nomeados e tipos simples quando suficientes. Repository e Bloc
  não normalizam entradas que pertencem ao formulário.
- Retorne `Future<void>` quando o consumidor precisa somente da conclusão;
  não exponha token, DTO ou envelope JSON:API à apresentação.
- Parsing e montagem de payload pertencem a infrastructure. DTOs usam Dart puro
  e casts; não esconda `TypeError` ou `FormatException` como falhas de negócio.
- Repository chama `IHttpClient` e `IStorageClient` diretamente quando necessário,
  sem camadas de data source intermediárias para delegação simples.
- Trate `HttpResponseException` antes de `HttpClientException`: preserve os erros
  remotos convertidos para `ErrorsEntity`; use fallback nas demais falhas do client.
- Lance exceção específica de aplicação, como `AuthenticationException`.
  Não introduza `catch` genérico no repository para mascarar erros inesperados.
- Preserve ordem e metadados dos erros, incluindo `pointer` e `parameter`.
  Não converta exceções inesperadas ou falhas de storage em sucesso.
- Aguarde toda persistência exigida antes de concluir. Sign-in aguarda token e ID
  por `Future.wait`; isso não garante transação ou rollback entre as gravações.
- Requests usa somente `path`, `body`, `query` e `headers`; endpoints relativos
  preservam `/api/`. Headers e Bearer pertencem aos interceptors.
- Não coloque credenciais, tokens ou segredos no código, fixtures reais ou logs novos.

## Bloc E Estado De Tela

- Use Bloc para operações assíncronas e estado de execução da apresentação.
  Não introduza commands nos fluxos novos ou migrados.
- Organize eventos e estados em `screens/<screen>/bloc/`, junto ao Bloc.
- Prefira eventos concretos e estados sealed, imutáveis, mutuamente exclusivos,
  como `SignInInitial`, `SignInSubmitting`, `SignInSuccess` e `SignInFailure`.
- Derive disponibilidade de ações do estado (`canSubmit`, `isSubmitting`);
  não mantenha flags locais espelhando loading, resultado ou erro do Bloc.
- Não armazene senha, token ou credenciais no estado. O evento de submissão pode
  transportar a entrada somente pelo tempo necessário à operação.
- Defina concorrência explicitamente. Submissões como sign-in usam `droppable`:
  eventos durante envio são descartados, não enfileirados; sucesso bloqueia
  novos envios e falha permite retry manual, sem retry automático.
- Falha esperada preserva a mesma `ErrorsEntity` no estado. Falha inesperada
  usa fallback seguro e `addError(error, stackTrace)`; não injete CrashClient
  ou callback de telemetry no Bloc.
- Antes de publicar após `await`, respeite `isClosed` e `emit.isDone`.
  Fechar Bloc ou invalidar handler não cancela HTTP nem persistência.
- Use o lifecycle nativo do Bloc, sem flags paralelas ou override de `close()`
  para reproduzir o fechamento da biblioteca.

## Screens, Formulários E Lifecycle

- A screen recebe uma factory estável `Bloc Function()` por construtor, cria
  sua instância e é a única proprietária do fechamento.
- Crie em `initState`, feche em `dispose` e feche/substitua em `didUpdateWidget`
  somente quando a factory mudar. Rebuild comum não cria outro Bloc.
- Use `BlocBuilder` para renderização e `BlocListener`/`BlocConsumer` para efeitos
  únicos. Não mostre toast, navegue ou envie operações durante o build.
- Se usar `BlocProvider.value`, a propriedade do fechamento continua com a screen.
- Formulário mantém entrada, validação e erros por campo localmente. No sign-in,
  o validator remove espaços do e-mail, mas preserva a senha; Bloc e repository
  delegam os valores recebidos sem outra normalização.
- Desabilite campos e envio conforme o estado. Mapeie erros 422 conhecidos por
  pointer e mostre somente os restantes em toast, com fallback seguro.
- Preserve entrada após falha; editar limpa somente o erro do campo correspondente.
- No sign-in, sucesso não navega diretamente: a observação global da sessão
  continua responsável pelo redirecionamento.
- Ações de navegação novas usam as extensões de `BuildContext` do Modular no
  widget responsável, não callbacks transportados pela rota nem `Modular.to`.
  Preserve callbacks legados até migrar seus consumidores explicitamente.

Extraia lifecycle, controllers, timers e handlers substanciais para mixin
específico com `on State<Widget>`. A screen mantém composição visual. O mixin
não acessa repository, HTTP ou storage e descarta todo recurso que cria.
Helpers usam o `context` do próprio State, sem repasse redundante.
Lógica visual pura de StatelessWidget pode usar mixin próprio com
`on StatelessWidget`, sem recursos mutáveis ou operações assíncronas.

## Dart, Imports E Componentes

- SDK Dart `^3.13.2`; use primary constructors em declarações novas elegíveis.
  Campos induzidos imutáveis têm tipo explícito e `final`; preserve `const`.
- Parâmetros usados só para inicialização não induzem campos. Construtores com
  lifecycle ou múltiplos caminhos generativos exigem avaliação semântica.
- Não introduza construtor primary vazio em interfaces, mixins, States ou mocks.
- Widgets novos são públicos, `final`, com sufixo `Widget`, arquivo próprio,
  parâmetros nomeados, `required` e `super.key`; use `const` quando possível.
- Não extraia componentes visuais privados dentro do arquivo de outra tela.
- Imports da aplicação usam `package:cordato/`, nunca caminhos relativos de `lib/`.
- UI Material usa `package:material_ui/material_ui.dart`, não
  `package:flutter/material.dart`. Imports Flutter especializados são permitidos
  para símbolos não exportados. Remova imports não utilizados; não crie barrels.
- Reutilize botões, fields, `BounceWidget`, animações e imagens do core antes
  de criar componentes. Botões compartilhados incorporam o bounce de pressão.
- Use `context.colors`, `context.typography` e `context.radius`; não duplique
  extensões ou tokens. Scaffold herda o tema; não fixe fundo sem necessidade.
- Assets ficam em `AssetEnum` e `pubspec.yaml`; use `ImageWidget` para imagens.
- Reutilize `ErrorScreen` para erro de tela; preserve acessibilidade, rolagem,
  textos ampliados e exclusão semântica de imagens decorativas e skeletons.

## Módulos E Rotas

Use a API funcional `createModule` do `flutter_modular` 7. Registre contratos
apontando para implementações e Bloc por factory, nunca singleton compartilhado
entre telas. Injete a factory estável como `bloc: inject<SignInBloc>`, sem criar
closures novas a cada rebuild ou instâncias durante o build.

Módulos pertencem à feature. Separe dependências compartilhadas de rotas quando
necessário, sem criar módulo vazio. A organização atual de `authenticationModule`
não obriga módulos artificiais adicionais. `app_module.dart` faz a composição global.

## Testes Obrigatórios

Os testes seguem a mesma arquitetura, não o padrão antigo de data sources ou
commands. Espelhe o caminho de produção em `test/features/<feature>/`.

| Alvo | Cobertura mínima |
| --- | --- |
| Domain | Invariantes, imutabilidade e semântica dos valores, sem SDKs. |
| Application | Contratos puros e preservação de erros nas exceções. |
| Repository em infrastructure | Payload, DTO, clients mockados, erros HTTP, parsing inválido, ordem/espera de persistência e propagação de falhas inesperadas. |
| Bloc | Estado inicial, sequência de estados, delegação, falha esperada/inesperada, concorrência, retry e fechamento pendente. |
| Screen/widget | Bloc real com repository mockado; validação, teclado, loading, feedback único, rebuild, troca de factory e descarte. |
| E2E Maestro | Success, Failure e Loading no app, com API de fixtures isolada. |
| Architecture | Imports, camadas, contextos e isolamento de contratos; DI/rotas exigem testes próprios. |

- Use `mocktail`, `bloc_test` e `flutter_test`. Em teste de Bloc, mocke o contrato
  de repository, não o client HTTP. Em teste do repository, mocke os clients.
- Nos testes de screen, use o tema real, `pt_BR` e provider de toast. A screen
  continua dona do Bloc; não mascare erros de lifecycle fechando-o por outro dono.
- Controle operações pendentes com `Completer` ou sinais observáveis; não dependa
  de sleeps arbitrários para provar concorrência.
- Mocks/fakes/adapters públicos ficam em arquivos próprios sob
  `test/support/<feature>/mocks/` ou `fakes/`, nunca dentro de `*_test.dart` ou `lib/`.
- Reutilize um double por contrato; instâncias, stubs e fixtures de cenário são
  locais a cada teste. Imports de suporte usam caminhos relativos explícitos.
- Cancele subscriptions, conclua Futures controlados e descarte recursos criados.
- Flows Maestro pertencem a `presentation/screens/<screen>/e2e/` na árvore de
  testes, com README de execução e fixtures em `test/support/`.
- Não execute fixtures com credenciais fictícias contra produção. Maestro não
  substitui testes de parsing, storage, concorrência ou lifecycle.
- Nunca declare E2E validado apenas porque YAML existe ou passou na sintaxe.

## Previews E Verificação

Previews usam `@CordatoPreview`, tema real, localização e toast compartilhados.
Ficam em `presentation/previews/`; fakes de catálogo não usam rede, storage ou
mocktail. Mantenha um único dono de cada recurso, inclusive Bloc. Use
`PreviewResourceWidget` quando o recurso não pertencer ao lifecycle da tela.
Execute `dart run tool/widget_preview.dart`; `.widget_preview/` não é versionado.

Quando aplicável, execute nesta ordem:

```bash
flutter pub get
flutter analyze
flutter test
```

Verificação focada: `flutter test test/architecture` e testes da feature afetada.
Registre os comandos executados, os resultados e os bloqueios anteriores à tarefa.
Mudança exclusivamente documental não exige executar o app ou a suíte Flutter.

## Revisão E Pendências

Mudanças estruturais atualizam `ARCHITECTURE.md`; convenções e testes atualizam
este arquivo; estado do produto/configuração atualizam `README.md`. Release
Android atualiza `android/README.md`.

Antes de concluir, confira: camadas corretas, contrato puro, Bloc sem SDKs,
efeitos fora do build, ownership único, testes nas camadas corretas, documentação
coerente e ausência de comentários novos no código.

O estado de transição está registrado em `ARCHITECTURE.md`. Não restaure
dependências removidas nem enfraqueça testes arquiteturais para tornar o legado
aparentemente compatível. Migre cada fluxo completo, com seus consumidores e
testes, quando isso fizer parte da tarefa solicitada.
