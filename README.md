# Cordato

Aplicativo Flutter de finanças pessoais e familiares. O objetivo é ajudar cada
pessoa a cuidar do próprio dinheiro com clareza e, quando fizer parte de uma
família, oferecer uma visão compartilhada das finanças de seus membros.

## Produto

O modelo de negócio tem como referência o backend legado em Kotlin. O app usa
uma API HTTP JSON:API para autenticação e possui data sources remotos de User e Expense;
o cadastro de despesas está conectado à API. A regra central é:

> A pessoa é dona dos próprios dados. A família é apenas uma lente de leitura.

Os bounded contexts do produto são:

- `user`: modelo de domínio, contrato de repository e data source HTTP para
  consulta, atualização do nome e exclusão, com repository concreto e UI de
  edição de nome integrada à API pelo ID persistido no sign-in.
- `expense`: entidade de domínio, value object para valores positivos em centavos,
  categorias com rótulos pt-BR, input e contrato
  de repository para criação, implementação de repository, command, DTO e data
  source HTTP, com formulário e validators integrados ao cadastro e consulta
  paginada consumida pela Dashboard e pela listagem completa.
- `budget`: planejado. Tetos por intervalo de datas, com gasto e saldo derivados.
- `family`: planejado. Organização familiar com acesso combinado somente de leitura.
- `insight`: planejado. Análises derivadas, somente leitura e sem persistência própria.

O contexto `identity` do backend não será reproduzido no app neste momento. A
autenticação por e-mail e senha usa a API JSON:API; há sign-in, sign-up,
confirmação de e-mail por link e reenvio da verificação. O token opaco do
sign-in e o ID do usuário são salvos em storage seguro. A feature `session` lê
o token na abertura e observa mudanças para decidir entre dashboard e welcome, inclusive após o
logout confirmado em Settings. Não há validação da sessão no backend ao iniciar.
O contexto `chat` está fora do escopo atual.

## Estado atual

O app já possui:

- tela de boas-vindas;
- tela de entrada `AppScreen` em `/`, com logo e decisão inicial pela presença do token;
- tela de sign-in com validação, feedback de erro e persistência segura do token
  e do ID do usuário no sucesso, seguida de navegação para o dashboard;
- tela de sign-up com validação e tela de reenvio da verificação que mostra o e-mail
  cadastrado em um campo desabilitado após o sucesso, com reenvio do link de
  verificação após uma espera de 60 segundos e feedback da API;
- dashboard com nome e inicial do avatar consultados na API por `UserCommand`,
  e seção de despesas recentes com as seis primeiras despesas da API, skeleton,
  estado vazio, erro com título e descrição e atualização por gesto ou
  ao retornar do formulário de gasto;
- listagem completa em `/expenses`, aberta por “Ver tudo” da Dashboard, com
  rolagem infinita em páginas de 20 itens, atualização por gesto, loading, vazio
  e nova tentativa após erro, preservando os itens já carregados;
- formulário de gasto integrado à API, com descrição obrigatória, calculadora
  de valor em centavos, seleção de data, validação, loading, erros por campo e
  toast de sucesso; toque simples cadastra e retorna ao dashboard, enquanto
  completar o hold cadastra e limpa o formulário para adicionar outro gasto;
- tela de configurações com confirmação de saída, loading e erros em toast;
  o logout revoga o token na API e limpa o storage seguro, com retorno à welcome
  pelo observador global de sessão;
- tela de dados pessoais em `/user`, aberta por Settings, com nome clicável,
  nome e e-mail consultados na API por `UserCommand`, skeleton e opção de tentar
  novamente em caso de erro, e-mail desativado e exclusão de conta com confirmação,
  loading e feedback de erro por `DeleteUserCommand`; após exclusão confirmada,
  a limpeza da sessão redireciona para as boas-vindas;
- tela de edição de nome em `/user/edit`, aberta pelo item Nome, seguindo a UI
  centralizada da autenticação, com atualização pela API, loading, erros no campo
  ou toast e retorno dos dados atualizados para a tela de dados pessoais;
- navegação de Welcome para Sign In, de Sign In para Sign Up por substituição
  de rota e de Dashboard para Settings e Expense;
- tema claro/escuro e componentes de apresentação reutilizáveis;
- confirmação automática de e-mail ao abrir o link HTTPS, com feedback por toast
  e retorno ao sign-in após sucesso, expiração ou erro de conexão, sem criar sessão;
- remoção do token após 401 em requisição protegida e retorno à welcome quando
  o usuário estiver em uma rota protegida;
- estrutura de `user` com entidade, contrato de repository, DTO e data source
  HTTP para buscar por ID, atualizar somente o nome e excluir o usuário; essa
  estrutura está registrada em DI e é consumida pela tela de edição.

A tela de dados pessoais consulta o perfil ao abrir e novamente após salvar
o nome, usando o ID persistido no sign-in.

`budget`, `family` e `insight` seguem planejados. Ao implementá-los, o grupo
familiar não deve se tornar dono dos dados financeiros de seus membros.

## Arquitetura

O código é organizado por feature e por camadas:

```text
Screen/Widget -> Command -> contrato de repository (domain)
  -> repository (data) -> data source (infrastructure) -> HTTP/storage
```

`presentation` não conhece SDKs externos. `domain` contém contratos e regras
independentes de framework, `data` implementa os repositórios e
`infrastructure` contém data sources que acessam HTTP, storage e plugins. Na
autenticação, o data source remoto usa o `IHttpClient` compartilhado do core
diretamente; `session` encapsula a leitura e a observação do token para a
entrada do app. Esse é o fluxo implementado para autenticação e leitura de
sessão; features exclusivamente visuais não precisam de camadas vazias.

Decisões técnicas atuais:

- Dart `^3.13.2` e primary constructors para declarações elegíveis;
- `flutter_modular` 7 com módulos de dependências separados dos módulos de rotas;
- `command_it` para operações observáveis e estado efêmero local nos widgets;
- Material 3 via `material_ui`, tema compartilhado, Inter e localização `pt_BR`;
- `Requests` com parâmetros nomeados e somente `path`, `body`, `query` e `headers`;
  caminhos do enum são usados diretamente, com IDs interpolados no data source;
- `response<T>` compartilhado no core para conversão de sucesso e tratamento
  dos erros JSON:API nos data sources;
- testes unitários para lógica e adapters; validação visual e de fluxos com
  Maestro, sem suíte Flutter de widgets ou `integration_test`.

`AppWidget` cuida de tema, router, toast e redirecionamentos globais;
`AppScreen` compõe a entrada do app. Ambos ficam em
`lib/features/root/presentation/`; `root` reúne a apresentação de composição
global, e `app_module.dart` registra a rota `/`.
`session` observa o token sem importar `authentication`; o logout é um command
de `authentication` consumido por Settings. Não há guard de rota do Modular
nem validação ou renovação automática do token no app.

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
dart run tool/widget_preview.dart
```

Abra no navegador a URL impressa pelo comando. O launcher usa
`flutter widget-preview start --web-server` e dispara uma atualização após o
servidor iniciar para contornar a descoberta vazia na abertura do Flutter 3.47.6.
A atualização cria um arquivo Dart temporário em `tool/`, removido ao encerrar o
comando, sem reescrever os arquivos da aplicação.

Para executar o app, use `flutter run`. A autenticação usa por padrão
`https://api.cordato.cloud/api/`. Para apontá-la a outra API:

```bash
flutter run --dart-define=BASE_URL=https://api.exemplo.com/api/
```

O valor de `BASE_URL` deve incluir o prefixo `/api/`.
O domínio de entrada de produção confirmado para `APP_URL` é
`https://app.cordato.cloud`. Esse servidor precisa oferecer a página
`/authentication/confirm-email` e os arquivos de associação Android e iOS
em `/.well-known/`.

Para usar o backend local do Lerd em um Android na mesma rede, execute
`make android-lan` antes de iniciar **Cordato (debug)** no VS Code. O comando
compartilha o site pelo IP da rede e atualiza a URL de debug em
`.vscode/launch.json`; reinicie o app para aplicar o novo `--dart-define`.
O backend é procurado em `../../../BackEnd/PHP/Trocado` a partir deste projeto;
use `make android-lan LERD_SITE_PATH=/caminho/do/backend` se estiver em outro
local. O HTTP da rede local é permitido apenas no build Android de debug.

No simulador iOS, execute
`flutter run --dart-define=BASE_URL=https://trocado.test/api/`. O simulador usa
o domínio HTTPS local do Lerd no Mac. A configuração **Cordato (debug)** também
aponta para esse endereço no arquivo versionado, mas `make android-lan` a
substitui pelo IP da rede para Android. Reinicie o app após mudar o
`--dart-define`.

As configurações **Cordato (profile)** e **Cordato (release)** do VS Code
atualmente sobrescrevem a base com `https://app.cordato.cloud/api`, diferente
do padrão de `coreDependenciesModule`. Consulte `.vscode/launch.json` ao
executar por esses perfis; `BASE_URL` é definido em tempo de compilação.

## Android Release

O processo de configuração segura da chave, build e verificação de artefatos
Android está documentado em [`android/README.md`](android/README.md).

## API E Persistência

`coreDependenciesModule` registra o Dio compartilhado, o cliente HTTP e o storage seguro.
O fluxo de autenticação passa por command, contrato de repository, repository
e data sources remoto/local. O remoto monta as requisições e usa `IHttpClient`
do core diretamente, sem client próprio da feature. `HttpClient` preserva
status e corpo em `HttpResponse`; `SignInResponse` e `SignUpResponse` leem os
mapas JSON com Dart puro, o data source remoto converte erros JSON:API e o
local grava token e ID do usuário. A API é externa a este repositório; não há
schema ou migrations do backend financeiro versionados aqui. Ao conectar as features
financeiras, preserve propriedade individual, autorização e invariantes no
serviço responsável, com testes próprios.

`AuthenticationLocalDataSource` usa `IStorageClient`, implementado por
`StorageClient` com `FlutterSecureStorage`. `saveToken` grava
`StorageKeyEnum.opaqueToken` (`@trocado.opaque_token`) e `saveUserId` grava
`StorageKeyEnum.userId` (`@trocado.user_id`). O repository aguarda ambas as
gravações com `Future.wait` antes de retornar sucesso. Após revogação remota
aceita no logout, `clear()` limpa todo o storage seguro. Um 401 de endpoint
protegido remove somente o token enviado, sem limpar o ID do usuário.

`HttpPathEnum.authenticated` marca endpoints protegidos; o
`SessionInterceptor` só envia `Authorization: Bearer <token>` quando o
caminho relativo coincide com a origem e o endpoint da API. `Bearer` é o esquema
HTTP, não o formato do token. A validade é controlada pelo backend; o app não
implementa refresh nem bloqueia chamadas por `expiresAt`. A confirmação por
link usa uma URL absoluta. URLs absolutas não recebem token e o cliente HTTP
desabilita seus redirecionamentos e logs automaticamente. Um 401 de
requisição protegida remove o token somente se ele ainda for o token enviado;
`SessionCommand` observa a mudança e o app volta à welcome se estiver em uma
rota protegida.

A integração HTTP atual inclui os fluxos de autenticação e o data source e
repository de User, registrados em `userDependenciesModule` e compostos por
`appModule`, com atualização de nome consumida por `UpdateUserCommand` na edição.
As operações `getById()`, `update({String? name})` e `delete()` de `UserRepository`
leem o ID por `UserLocalDataSource.getUserId()` e chamam o data source remoto
com o ID explícito; ID ausente impede a requisição. `UserRepository` converte
respostas e erros remotos para os tipos de domínio nas operações de consulta,
atualização do nome e exclusão. Após exclusão de User confirmada com status 204,
o repository aguarda a limpeza de todo o storage seguro por `UserLocalDataSource`,
que delega a `IStorageClient.clear()`. `expenses` consta
no catálogo de endpoints protegidos e é usado por `ExpenseRemoteDataSource.create`.
O POST envia centavos inteiros, descrição e data civil como `yyyy-MM-dd`, e retorna
`ExpenseResponse`; sua conversão à entidade valida o valor pelo VO. O data source
é registrado em DI e consumido por `ExpenseRepository` e `CreateExpenseCommand`
no formulário. O logger Dio
de debug registra headers e payloads usuais, inclusive credenciais e resposta
de sign-in; requisições com URLs absolutas, como a confirmação assinada, são
omitidas. Em release esse logger não é instalado.

Os data sources de Authentication, User e Expense reutilizam a função top-level
`response<T>` em `core/infrastructure/clients/http/responses/responses.dart`.
Ela recebe `execute` para a requisição e `from` para converter o `HttpResponse`
de sucesso, com acesso ao corpo e ao status, e retorna `Either<ErrorsResponse, T>`.
Erros JSON:API são preservados; exceções inesperadas viram erro genérico.
O status da confirmação de e-mail continua sendo tratado por Authentication.

## Revisão De Mudanças

Mudanças em módulos, rotas, contratos, integração HTTP, comandos de validação
ou configuração de release devem atualizar, na mesma alteração, a
documentação canônica correspondente. Consulte a seção de revisão em
[`ARCHITECTURE.md`](ARCHITECTURE.md#revisão-de-documentação).

Não adicione comentários no código, incluindo comentários de documentação.
Use nomes e estrutura claros e registre explicações e decisões nos arquivos
Markdown, conforme a regra de [`AGENTS.md`](AGENTS.md#comentários-no-código).
