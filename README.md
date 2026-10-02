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

- `expense`: formulário e camadas de criação presentes, ainda sem persistência.
- `budget`: planejado. Tetos por intervalo de datas, com gasto e saldo derivados.
- `family`: planejado. Organização familiar com acesso combinado somente de leitura.
- `insight`: planejado. Análises derivadas, somente leitura e sem persistência própria.

O contexto `identity` do backend não será reproduzido no app neste momento. A
autenticação por e-mail e senha usa a API JSON:API; há sign-in, sign-up,
confirmação de e-mail por link e reenvio da verificação. O token opaco do
sign-in é salvo em storage seguro, mas ainda não há restauração de rota,
logout ou guard de sessão.
O contexto `chat` está fora do escopo atual.

## Estado atual

O app já possui:

- tela de boas-vindas;
- tela de sign-in com validação, feedback de erro e persistência segura do token
  no sucesso, ainda sem navegação pós-login;
- tela de sign-up com validação e tela de reenvio da verificação que mostra o e-mail
  cadastrado em um campo desabilitado após o sucesso, com reenvio do link de
  verificação após uma espera de 60 segundos e feedback da API;
- dashboard inicial com usuário de exemplo fornecido por um client local;
- formulário de gasto, cuja operação de criação ainda retorna falha;
- tela de configurações, com botão de saída ainda sem logout integrado;
- navegação de Welcome para Sign In, de Sign In para Sign Up por substituição
  de rota e de Dashboard para Settings e Expense;
- tema claro/escuro e componentes de apresentação reutilizáveis;
- confirmação automática de e-mail ao abrir o link HTTPS, com feedback por toast
  e retorno ao sign-in após sucesso, expiração ou erro de conexão, sem criar sessão.

`budget`, `family` e `insight` seguem planejados. Ao implementá-los, o grupo
familiar não deve se tornar dono dos dados financeiros de seus membros.

## Arquitetura

O código é organizado por feature e por camadas:

```text
presentation -> domain -> data -> infrastructure -> API HTTP
```

`presentation` não conhece SDKs externos. `domain` contém contratos e regras
independentes de framework, `data` implementa os repositórios e
`infrastructure` contém data sources que acessam HTTP, storage e plugins. Na
autenticação, o data source remoto usa o `IHttpClient` compartilhado do core
diretamente; a criação de gastos ainda não persiste dados.

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

No simulador iOS, selecione **Cordato (iOS simulator - Lerd)** no VS Code ou
execute `flutter run --dart-define=BASE_URL=https://trocado.test/api/`. O
simulador usa o domínio HTTPS local do Lerd no Mac; o endereço IP da configuração
**Cordato (debug)** é específico do compartilhamento LAN para Android e pode
ficar desatualizado. Reinicie o app após mudar o `--dart-define`.

## Android Release

O processo de configuração segura da chave, build e verificação de artefatos
Android está documentado em [`android/README.md`](android/README.md).

## API E Persistência

`coreModule` registra o Dio compartilhado, o cliente HTTP e o storage seguro.
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
`OpaqueTokenInterceptor` só envia `Authorization: Bearer <token>` quando a
rota protegida coincide com a origem e o caminho da API. `Bearer` é o esquema
HTTP, não o formato do token. A validade e a renovação continuam sob controle
do backend. A confirmação por link não envia token e omite a URL assinada dos
logs do Dio. Não há tratamento global de sessão expirada.

## Revisão De Mudanças

Mudanças em módulos, rotas, contratos, integração HTTP, comandos de validação
ou configuração de release devem atualizar, na mesma alteração, a
documentação canônica correspondente. Consulte a seção de revisão em
[`ARCHITECTURE.md`](ARCHITECTURE.md#revisão-de-documentação).
