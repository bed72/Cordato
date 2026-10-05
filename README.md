# Cordato

Aplicativo Flutter de finanças pessoais e familiares. O objetivo é ajudar cada
pessoa a cuidar do próprio dinheiro com clareza e, quando fizer parte de uma
família, oferecer uma visão compartilhada das finanças de seus membros.

## Produto

O modelo de negócio tem como referência o backend legado em Kotlin. O app usa
uma API HTTP JSON:API para autenticação; a persistência das features financeiras
ainda não está conectada. A regra central é:

> A pessoa é dona dos próprios dados. A família é apenas uma lente de leitura.

Os bounded contexts do produto são:

- `expense`: estrutura visual de formulário e validators, sem criação ou persistência.
- `budget`: planejado. Tetos por intervalo de datas, com gasto e saldo derivados.
- `family`: planejado. Organização familiar com acesso combinado somente de leitura.
- `insight`: planejado. Análises derivadas, somente leitura e sem persistência própria.

O contexto `identity` do backend não será reproduzido no app neste momento. A
autenticação por e-mail e senha usa a API JSON:API; há sign-in, sign-up,
confirmação de e-mail por link e reenvio da verificação. O token opaco do
sign-in é salvo em storage seguro. A feature `session` lê o token na abertura
e observa mudanças para decidir entre dashboard e welcome, inclusive após o
logout confirmado em Settings. Não há validação da sessão no backend ao iniciar.
O contexto `chat` está fora do escopo atual.

## Estado atual

O app já possui:

- tela de boas-vindas;
- tela de entrada `AppScreen` em `/`, com logo e decisão inicial pela presença do token;
- tela de sign-in com validação, feedback de erro e persistência segura do token
  no sucesso, seguida de navegação para o dashboard;
- tela de sign-up com validação e tela de reenvio da verificação que mostra o e-mail
  cadastrado em um campo desabilitado após o sucesso, com reenvio do link de
  verificação após uma espera de 60 segundos e feedback da API;
- dashboard inicial com nome de exemplo fixo no widget e conteúdo placeholder;
- estrutura visual de formulário de gasto com descrição, valor e data;
  os handlers ainda não estão conectados e o cadastro está desabilitado;
- tela de configurações com confirmação de saída, loading e erros em toast;
  o logout revoga o token na API e o remove localmente, com retorno à welcome
  pelo observador global de sessão;
- navegação de Welcome para Sign In, de Sign In para Sign Up por substituição
  de rota e de Dashboard para Settings e Expense;
- tema claro/escuro e componentes de apresentação reutilizáveis;
- confirmação automática de e-mail ao abrir o link HTTPS, com feedback por toast
  e retorno ao sign-in após sucesso, expiração ou erro de conexão, sem criar sessão;
- remoção do token após 401 em requisição protegida e retorno à welcome quando
  o usuário estiver em uma rota protegida.

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
flutter widget-preview start
```

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
local grava o token. A API é externa a este repositório; não há schema ou
migrations do backend financeiro versionados aqui. Ao conectar as features
financeiras, preserve propriedade individual, autorização e invariantes no
serviço responsável, com testes próprios.

O token opaco do sign-in é armazenado por `AuthenticationLocalDataSource`
via `FlutterSecureStorage`. `HttpPathEnum` marca endpoints protegidos; o
`SessionInterceptor` só envia `Authorization: Bearer <token>` quando a
rota protegida coincide com a origem e o caminho da API. `Bearer` é o esquema
HTTP, não o formato do token. A validade é controlada pelo backend; o app não
implementa refresh nem bloqueia chamadas por `expiresAt`. A confirmação por
link não envia token e omite a URL assinada dos logs do Dio. Um 401 de
requisição protegida remove o token somente se ele ainda for o token enviado;
`SessionCommand` observa a mudança e o app volta à welcome se estiver em uma
rota protegida.

A integração HTTP atual é de autenticação. `expenses` consta no catálogo de
endpoints protegidos, mas não há command, repository, data source ou client de
gastos no código atual. Dashboard não consulta um perfil remoto. O logger Dio
de debug registra headers e payloads usuais, inclusive credenciais e resposta
de sign-in; apenas requisições com logging desabilitado, como a confirmação
assinada, são omitidas. Em release esse logger não é instalado.

## Revisão De Mudanças

Mudanças em módulos, rotas, contratos, integração HTTP, comandos de validação
ou configuração de release devem atualizar, na mesma alteração, a
documentação canônica correspondente. Consulte a seção de revisão em
[`ARCHITECTURE.md`](ARCHITECTURE.md#revisão-de-documentação).
