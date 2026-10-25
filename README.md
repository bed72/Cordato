# Cordato

Aplicativo Flutter de finanças pessoais e familiares.

> Cada pessoa é dona dos próprios dados. A família é uma lente de leitura,
> nunca dona do dinheiro ou autorizada a escrever nos dados de outro membro.

## Arquitetura

Authentication/Sign-in é a referência obrigatória para desenvolvimento e testes:

```text
Screen/Form -> Bloc -> contrato de repository (application)
                         -> repository (infrastructure)
                         -> clients do core -> HTTP/storage
```

- Organização por feature, sem camadas ou abstrações vazias.
- Domain com entidades e regras puras; application com contratos e exceções.
- Repositories concretos em `infrastructure/repositories/`, usando `IHttpClient`
  e `IStorageClient` diretamente, sem data sources intermediários desnecessários.
- Retorno por `Future<T>`; falhas esperadas por exceção de aplicação, sem Either.
- Bloc com eventos concretos e estados sealed imutáveis. Tela é dona do lifecycle;
  formulário mantém entrada e validação, sem copiar loading ou resultado do Bloc.
- Testes de repository, Bloc, widget e E2E organizados junto à feature/tela.

CommandIt, data sources e repositories concretos em application ainda existentes
são legado pendente de migração, não alternativas aprovadas para código novo.

Leia [ARCHITECTURE.md](ARCHITECTURE.md) para decisões e fronteiras e
[AGENTS.md](AGENTS.md) para convenções de contribuição.

## Estado Do Projeto

**O checkout está em transição arquitetural e ainda possui bloqueios de
compilação/composição. A documentação não significa que a migração foi concluída.**

Authentication já possui contrato em application e repository em infrastructure.
Sign-in e cadastro usam Bloc, controle de submissões concorrentes, falhas tipadas
e testes de Bloc/tela. Cadastro mantém erros por campo, retry manual e navegação
para confirmação sem criar sessão. Reenvio, confirmação e logout ainda possuem
apresentação legada baseada em commands.

Outras features ainda referenciam `Either`, `response<T>` e CommandIt removidos.
Há módulos desativados em `app_module.dart` e referência a módulo de rotas de
Authentication que não está definido no arquivo atual da feature. Esses pontos
impedem tratar o app, a suíte completa e os flows E2E como prontos para execução.
Os detalhes estão em [Estado atual e migração](ARCHITECTURE.md#estado-atual-e-migração).

O código existente inclui os seguintes fluxos, cuja disponibilidade depende da
conclusão da migração e da composição dos módulos:

- Boas-vindas e decisão inicial pela presença do token.
- Entrada/cadastro com e-mail e senha, confirmação por link e reenvio com cooldown.
- Perfil, edição do nome, avatar gerado com salvamento após dois segundos e
  exclusão da conta.
- Criação/edição de despesas, valor em centavos, data civil e cadastro contínuo
  por hold; listagem paginada com filtros de período/categoria e gestos de edição/exclusão.
- Dashboard mensal com métricas por categoria, insights e seis despesas recentes.
- Configurações e logout com revogação remota antes de limpar o storage.
- Tema claro/escuro, componentes compartilhados e previews.

`budget` e `family` são planejados, sem features Flutter implementadas.
`identity` não reproduz o backend legado; `chat` está fora do escopo.
O backend é externo; este repositório não contém seu schema ou migrations.

## Stack

- Flutter com Dart `^3.13.2` e primary constructors.
- `bloc`, `flutter_bloc` e `bloc_concurrency` para apresentação assíncrona.
- `flutter_modular` 7 para composição, DI e rotas.
- Material 3 via `material_ui`, fonte Inter e localização pt-BR.
- Dio para HTTP JSON:API e `flutter_secure_storage` para persistência segura.
- Firebase Core, Crashlytics, Messaging e notificações locais.
- `flutter_test`, `bloc_test`, `mocktail` e Maestro para testes.

## Desenvolvimento

Na raiz do projeto:

```bash
flutter pub get
flutter analyze
flutter test
```

Os comandos podem expor os bloqueios de migração descritos acima. Não restaure
dependências antigas ou silencie checks para aparentar compatibilidade.

Após resolver os bloqueios de compilação e composição, execute em Android/iOS:

```bash
flutter run
```

A API padrão é `https://app.cordato.cloud/api/`. Para outra base:

```bash
flutter run --dart-define=BASE_URL=https://api.exemplo.com/api/
```

Preserve o prefixo `/api/`. `BASE_URL` é definido no build; reinicie o app após
alterá-lo. Confira também os overrides de `.vscode/launch.json`.
Firebase está configurado somente para Android/iOS, com identificador
`com.bed.cordato`, no projeto `trocado-d362e`.

### Backend Local

Para Android físico via USB:

```bash
adb devices
python3 tool/android_usb_proxy.py --device <id-do-adb>
```

Mantenha o proxy aberto. Ele encaminha a API local `https://trocado.test` pelo
loopback do Mac, valida o CA do mkcert e configura `adb reverse`. O perfil debug
usa `http://127.0.0.1:8765/api/`; reexecute após reconectar o dispositivo.

Para Android na mesma rede, `make android-lan` expõe deliberadamente o backend
na rede local e atualiza a URL debug. O backend padrão fica em
`../../../BackEnd/PHP/Trocado`; sobrescreva com
`make android-lan LERD_SITE_PATH=/caminho/do/backend` quando necessário.
HTTP local é permitido somente no build Android debug.

No simulador iOS, a base local pode ser `https://trocado.test/api/`, desde que
o domínio e o certificado estejam acessíveis no ambiente.

### Previews

```bash
dart run tool/widget_preview.dart
```

Abra a URL impressa. O launcher contorna a descoberta inicial vazia do previewer
no Flutter 3.47.6/3.47.7; se necessário, atualize o painel após a análise inicial.
Previews usam o tema real, pt-BR e fakes locais, sem rede/storage. Não substituem
testes de contrato ou E2E. `.widget_preview/` não deve ser versionado.

## Testes

| Camada | Padrão |
| --- | --- |
| Domain/application | Regras puras e exceções, sem SDKs. |
| Infrastructure/repository | Mocks dos clients; payload, parsing, erros e persistência. |
| Bloc | Repository mockado; estados, concorrência, retry e fechamento. |
| Screen/widget | Bloc real com repository mockado; interação, feedback e lifecycle. |
| E2E | Maestro com fixture HTTP isolada, cobrindo Success, Failure e Loading. |
| Architecture | Imports, fronteiras de contextos e direção das dependências. |

Testes espelham os caminhos de `lib/`; doubles públicos ficam em arquivos
próprios de `test/support/`, sem classes auxiliares nos arquivos `*_test.dart`.

```bash
flutter test test/architecture
flutter test test/features/authentication/infrastructure/repositories
flutter test test/features/authentication/presentation/screens/sign_in/bloc
flutter test test/features/authentication/presentation/screens/sign_in/sign_in_screen_test.dart
flutter test test/features/authentication/presentation/screens/sign_up
```

Os flows Maestro estão em
[`test/features/authentication/presentation/screens/sign_in/e2e/`](test/features/authentication/presentation/screens/sign_in/e2e/README.md).
Seu README descreve fixture, encaminhamento de porta e execução sequencial.
Não execute contra produção: usam dados fictícios e limpam dados/keychain do app.
Dependem de build compilável e módulos de sessão/destinos ativos; sua existência
não significa validação em dispositivo. Não há suíte Flutter `integration_test`.

## API, Sessão E Segurança

O repository de Authentication envia JSON:API e persiste token opaco e ID do
usuário por `IStorageClient`, aguardando ambas as escritas antes de concluir.
Não há garantia transacional entre elas. Bloc e UI não recebem token nem DTO.
Falhas esperadas viram `AuthenticationException`; erros inesperados propagam,
e o Bloc fornece fallback seguro e `addError` sem conhecer Crashlytics.

Session observa o token para entrada e redirecionamento global. Não há validação
remota ao abrir, refresh automático ou guard Modular. Um 401 protegido remove
somente o token enviado se ainda for o armazenado, preservando o ID.
Logout aceito remotamente aguarda a limpeza de todo o storage seguro.
Confirmação de e-mail usa o link assinado sem Bearer e não cria sessão.

O logger HTTP debug atual registra dados sensíveis; não use credenciais reais
em capturas compartilhadas. O logger não é instalado em release. Não adicione
segredos ao código ou fixtures. Valores financeiros são centavos inteiros de BRL,
e datas financeiras preservam seus componentes civis, sem conversão de fuso.

## Firebase E Release

Configurações Firebase ficam em
`lib/features/core/infrastructure/clients/firebase/firebase_options.dart`,
`firebase.json`, `android/app/google-services.json` e
`ios/Runner/GoogleService-Info.plist`. Para regenerar com acesso ao projeto:

```bash
firebase login
dart pub global activate flutterfire_cli
flutterfire configure \
  --project=trocado-d362e \
  --out=lib/features/core/infrastructure/clients/firebase/firebase_options.dart \
  --platforms=android,ios \
  --android-package-name=com.bed.cordato \
  --ios-bundle-id=com.bed.cordato
```

Revise o diff e os comentários gerados antes de versionar. O iOS usa Swift
Package Manager; preserve `ios/upload_crashlytics_symbols.sh` no build Release
para dispositivo e mantenha FlutterFire CLI no PATH.

Messaging e notificações locais possuem clients no core, mas o app ainda não
envia tokens ao backend nem integra automaticamente mensagens em primeiro plano
ou navegação por toque. Push iOS exige chave APNs no console e provisioning
com Push Notifications; não versione a chave `.p8`. Entrega real de push e
recebimento no Crashlytics ainda exigem validação.

Build, assinatura e verificação Android:
[android/README.md](android/README.md).

## Contribuição

Siga [AGENTS.md](AGENTS.md). Migre cada fluxo com contratos, implementação,
Bloc, consumidores, bindings e testes na mesma mudança, sem ampliar o escopo
incidentalmente. Preserve alterações existentes e não faça commit/push sem pedido.
Não adicione comentários ao código; decisões ficam em Markdown.

Mudanças de arquitetura, testes ou estado do produto devem manter estes três
documentos coerentes e registrar limitações reais, sem declarar migrações ou
validações que ainda não ocorreram.
