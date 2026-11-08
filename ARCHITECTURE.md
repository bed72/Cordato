# Arquitetura

## Decisão Canônica

Authentication/Sign-in define a arquitetura obrigatória do Cordato: organização
por feature, contratos de aplicação, repositories concretos em infrastructure,
clients compartilhados do core e apresentação com Bloc.

Este documento distingue **padrão obrigatório** de **estado atual**. A decisão
vale para novas implementações e migrações; não significa que todo o código já
foi convertido. Implementações antigas não são modelos alternativos aprovados.

```text
Fluxo de execução

Screen/Form -> evento -> Bloc -> IFeatureRepository
                                     |
                         FeatureRepository
                                     |
                        SDK PocketBase / clients nativos

Direção de dependências

presentation ----------------> application ----------------> domain
infrastructure --------------> application / domain
infrastructure da feature ---> SDK PocketBase / clients do core
módulo ----------------------> contratos + implementações + apresentação
```

O SDK PocketBase pode ser usado diretamente pelos repositories em infrastructure,
sem wrapper de CRUD. Seus tipos não chegam aos contratos, Blocs ou domínio.

Não há data source obrigatório entre repository e client, nem command ou use
case obrigatório entre tela e repository. Não adicione abstrações que apenas
deleguem a mesma chamada. O Bloc nunca depende da implementação do repository.

## Produto E Contextos

Cordato oferece finanças pessoais e familiares. A pessoa é dona dos dados;
família é somente uma lente autorizada de leitura. O backend Kotlin legado é
referência de domínio, não dependência de execução ou modelo de pastas Flutter.
O serviço PocketBase 0.41.1 agora está versionado separadamente em `backend/`,
incluindo schema, migrations e Compose. Seu contexto de build
fica restrito a essa pasta; runtime e volume são independentes do aplicativo.
Authentication, Session, User, Expense e Metrics no Flutter usam o SDK PocketBase.
Isso não comprova homologação remota nem equivalência com todos os recursos
financeiros do backend anterior.

| Contexto/feature | Escopo                                                                |
| ---------------- | --------------------------------------------------------------------- |
| Authentication   | E-mail/senha, cadastro, confirmação por link, reenvio e logout.       |
| Session          | Validação inicial via auth-refresh e observação da presença do token. |
| User             | Perfil, nome, avatar e exclusão da conta.                             |
| Expense          | Registro, consulta, edição e exclusão de gastos individuais.          |
| Metrics          | Agregações somente leitura, como totais e distribuição por categoria. |
| Budget           | Planejado: tetos por intervalo inclusivo de datas.                    |
| Family           | Planejado: membros e leitura combinada autorizada.                    |
| Dashboard        | Composição de apresentação, não contexto de negócio.                  |
| Root             | Entrada e composição visual global, sem domínio próprio.              |
| Information      | Termos, privacidade e ajuda públicos, exclusivamente de apresentação. |

`identity` não será recriado para espelhar o backend antigo; `chat` está fora
do escopo atual. Features visuais não precisam de camadas vazias.

Invariantes financeiras:

- Valores monetários em centavos inteiros de BRL, sem conversão por `double`.
  Percentuais não são valores monetários.
- Gastos são fatos individuais; não referenciam orçamento. Pertencimento ao
  orçamento deriva da data civil, preservada sem conversão de fuso.
- Orçamentos vivos da mesma pessoa não se sobrepõem.
- Participar de família não concede escrita nos dados de outra pessoa.
- Sair ou encerrar família não modifica os dados individuais.
- Visões combinadas derivam dos dados proprietários.

As garantias de autorização pertencem ao serviço responsável e exigem testes
no backend; o aplicativo não as prova por ocultar ações na interface.

## Atalho de cadastro pela tela inicial do celular

Root possui a observação de lançamentos do widget e a coordenação com Session.
`AppWidget` recebe somente factories de Blocs, além da chave de navegação: não
recebe client, consulta URI nativa nem assina streams de infraestrutura.
`HomeWidgetLaunchBloc` consome `IHomeWidgetLaunchRepository`; o adapter valida a
URI em infrastructure e entrega somente a decisão inicial e sinais de abertura.
A apresentação observa estados de solicitação e mantém o intent de navegação
pendente até ser possível executá-lo. O lifecycle nativo de `emit.onEach` cancela
a assinatura ao fechar o Bloc; uma leitura inicial tardia não duplica um sinal
já observado nem publica após o fechamento.

`IHomeWidgetClient` é um contrato puro em `core/application/clients/`; seu adapter
encapsula `home_widget` e não chama APIs em plataformas sem suporte. Esse contrato
é consumido por infrastructure/composição, nunca diretamente por widgets, mixins
de tela ou Blocs. Mover uma interface para application não permite pular o
repository. Testes arquiteturais proíbem imports de `application/clients/` pela
apresentação, assim como os demais adapters.

A URI permitida é somente `cordato://widget/add-expense?homeWidget=true`, sem
outros parâmetros. Não transporta credenciais nem dados de despesas. O fluxo
aguarda Session e o adiamento de redirecionamentos; ausência confirmada abre
sign-in, autenticação consome o intent e abre a criação sobre Dashboard. Falha
de sessão mantém a política de erro existente, sem assumir ausência confirmada.

`HomeWidgetExpenseNavigation` preserva a rota de criação existente por seus
argumentos, inclusive quando está abaixo de outra rota, e não confunde edição
por ID com criação. A leitura de `routeState` do Modular reflete a base, não o
topo; a busca usa `popUntil` sobre os estados reais da pilha, sem depender de
nomes de `Page` que o Modular não fornece. Navegação concreta continua no mixin
do AppWidget, por extensões de BuildContext.

RemoteViews e WidgetKit exibem mês por extenso iniciado em maiúscula, total mensal
em bold e **+ Nova despesa** em botão retangular com raio 14, cores primária/sobre
primária e texto centralizado, seguindo o DS e o tema do sistema. A altura do
botão é adaptada ao espaço nativo. O grupo fica centralizado verticalmente.
WidgetKit oferece famílias pequena e média; RemoteViews
adapta cada instância às dimensões fornecidas pelo launcher, com resumo e ação
lado a lado em formatos largos e composição vertical nos quadrados/altos.
Android solicita redimensionamento até 56dp de altura e possui composição
compacta baixa, com espaçamentos reduzidos e moeda mantida junto ao número.
Com menos de 96dp de altura, a composição é horizontal; se também houver menos
de 300dp de largura, a ação é ocultada e o resumo recebe toda a largura interna.
O toque no widget inteiro e sua descrição acessível continuam abrindo Nova despesa.
O padding horizontal fica em 16dp mesmo no formato de uma linha, com fonte
monetária preferencial/máxima de 15 na variante estreita sem botão e 16 na larga;
o padding vertical é ajustado separadamente. Composições verticais usam fonte
preferencial 19, limitada a 21; a horizontal regular mantém 22, limitada a 26.
WidgetKit seleciona a composição por `widgetFamily` e renova a identidade visual
ao trocar a família; a geometria serve somente à largura útil do texto. O valor
parte de 16 no pequeno e 18 no médio, limitado a 18/22 antes do ajuste de largura.
O intervalo entre resumo e ação no pequeno é de 10 pontos.
No WidgetKit, a ação preserva **+ Nova despesa**, com fonte de 13 pontos,
altura de 44, raio 14 e rótulo acessível “Nova despesa”. No médio, a largura
é de 136 pontos; o resumo considera essa reserva antes de ajustar o dinheiro.
`WidgetRenderedActionView` adapta o botão pelo `widgetRenderingMode`: full color
usa as cores do DS, accented/vibrant usam texto primário do sistema sobre fundo
a 16% de opacidade para impedir branco opaco sobre branco opaco em Liquid Glass.
`WidgetColorMode` mantém essa decisão pura e coberta por testes nativos.
Android desabilita o deeplink automático apenas para
a action do plugin, preservando verificação e recuperação. A extensão iOS é
incorporada pelo Runner em Debug, Release e Profile.

`HomeWidgetSyncBloc` tem proprietário único no AppWidget, assim como Session,
com factory estável em rootModule e fechamento/troca pelo mixin. Consome apenas
`IHomeWidgetSyncRepository`; o adapter de Root compõe `IMetricsRepository` e
`IHomeWidgetClient`. O próprio Bloc observa os pedidos de atualização através
do repository, em handler contínuo separado dos eventos de sincronização, para
que uma atualização restartable não cancele a observação. AppWidget não conhece
esses streams. `HomeWidgetLaunchBloc` também possui factory estável e um único
proprietário no AppWidget. Ausência confirmada de sessão limpa o resumo. Falha da
validação de sessão não é tratada como logout. Não há credenciais nos eventos,
estados ou dados compartilhados. Requests do widget são restartable: uma mutação
mais recente substitui a sincronização pendente, e logout impede publicação tardia.

Metrics publica no client somente respostas válidas do mês civil atual, incluindo
zero para uma lista vazia bem-sucedida. Consultas históricas não alteram o resumo;
nenhum cálculo monetário é refeito no Flutter. Expense solicita uma atualização
pela capacidade compartilhada do client somente após create/update/delete
bem-sucedidos, sem importar Metrics nem Root. Root recebe esse sinal e consulta
o mês atual, independentemente dos filtros da Dashboard.

O client usa revisões para descartar leituras anteriores a outra consulta, mutação
ou logout. Gravações nativas são serializadas: a limpeza segue uma publicação já
iniciada. Erros esperados do plugin são reportados sem transformar uma operação
financeira confirmada em falha; erros de HTTP/parsing das métricas não publicam zero.
Esses efeitos auxiliares não tornam HTTP, sessão e persistência nativa atômicos.

O snapshot é um JSON único `monthly_summary` com `month` em yyyy-MM e `cents`
inteiros. Android usa SharedPreferences do plugin; iOS usa o App Group
`group.com.bed.cordato` nos dois targets. Não são compartilhados JWT, proprietário
ou descrições. Os renderizadores nativos só exibem total quando a chave mensal
coincide com o mês corrente; ausência, JSON inválido ou mês diferente mostra
**Abra para atualizar**, nunca zero inventado ou o valor anterior rotulado como
atual. Dinheiro usa BigDecimal no Android e magnitude inteira no Swift, inclusive
para Int64.min, sem conversão monetária para double. `WidgetMoney` formata todo o
valor em BRL; `WidgetDimensions` seleciona a composição e calcula a largura útil;
`WidgetAmountLayout` decide separação da moeda e tamanho da fonte a partir de
medidas de texto feitas por Paint/UIFont. Nenhum dígito é abreviado ou substituído
por reticências. A fonte pode diminuir além dos limites anteriores para valores
extremos; a descrição de acessibilidade preserva o valor completo.

A virada do mês usa uma entrada futura da timeline no iOS e alarme não exato
com eventos de data/fuso no Android. O agendamento é local e sujeito ao SO;
nenhum deles faz consultas remotas. AddExpenseWidgetProvider separa leitura,
formatação, RemoteViews e agendamento. AddExpenseProvider fica em arquivo próprio
e separa leitura, formatação e timeline, sem misturar o layout SwiftUI.
As políticas nativas puras são executadas por JUnit e XCTest sem UI, através de
`tool/test_home_widget_native.dart`; os testes Swift compilam o arquivo de
produção em macOS, sem depender do Runner ou de um simulador. Isso não substitui
a compilação iOS nem a conferência visual do WidgetKit/launcher.

## Estrutura E Responsabilidades

O repositório contém duas unidades independentes: `lib/` e `test/` para o
aplicativo Flutter; `backend/` para o serviço PocketBase e seus testes. A árvore
abaixo descreve apenas o aplicativo. A organização Flutter não deve ser aplicada
ao runtime do backend.

```text
lib/
  main.dart
  app_module.dart
  features/
    core/
    root/presentation/
    <feature>/
      <feature>_module.dart
      domain/
        entities/
        enums/
        value_objects/
      application/
        exceptions/<feature>_exception.dart
        repositories/interface_<feature>_repository.dart
      infrastructure/
        repositories/<feature>_repository.dart
        responses/
      presentation/
        screens/<screen>/
          <screen>_screen.dart
          bloc/<screen>_bloc.dart
          bloc/<screen>_event.dart
          bloc/<screen>_state.dart
          mixins/
          widgets/
        validators/
        widgets/
        previews/
```

A árvore representa localizações, não diretórios obrigatórios. Não crie inputs,
outputs, wrappers, services ou clients próprios sem necessidade concreta.
Parâmetros nomeados e records são suficientes para operações simples.

### Domain

Contém entidades, enums, value objects e regras puras. Não conhece JSON:API,
HTTP, storage, Bloc, Flutter ou tipos de aplicação. Não faz parsing de DTOs,
formatação visual ou navegação. Os contratos de repository do novo padrão
pertencem a application, não a `domain/repositories/`.

### Application

Define os contratos consumidos pelo Bloc e as exceções esperadas do fluxo.
Não importa infrastructure, presentation, clients, SDKs ou frameworks de UI.
Pode usar tipos puros de domain e do core.

`IAuthenticationRepository`, em
`authentication/application/repositories/interface_authentication_repository.dart`,
define:

- `signIn({required String email, required String password}) -> Future<void>`;
- `signUp({required String email, required String password}) -> Future<void>`;
- `resendEmail({required String email}) -> Future<void>`;
- `signOut() -> Future<void>`;
- `confirmEmail(String token) -> Future<EmailVerificationStatusEnum>`.

Não há entidade de sessão ou output de login. Token e ID são detalhes internos
de persistência. `AuthenticationException`, em `application/exceptions/`,
transporta `ErrorsEntity` para falhas esperadas; não é regra de domínio.
Novos contratos retornam dados diretamente em `Future<T>`, sem `Either`.

### Infrastructure

Implementa contratos de application e coordena clients, payloads, DTOs e storage.
`AuthenticationRepository`, em `infrastructure/repositories/`, recebe o
PocketBase compartilhado diretamente. Não usa HTTP/storage próprios, data sources,
BuildContext, Modular ou Bloc.

DTOs ficam em `infrastructure/responses/`, usam Dart puro e não atravessam o
contrato de aplicação. Casts e parsing inválidos devem falhar explicitamente;
não fabrique dados de sucesso ou transforme todo defeito de contrato em erro
de conexão. Repository não aplica trim ou normalização oculta.

### Presentation

Contém Bloc, eventos, estados, telas, widgets, validators e mixins de UI.
Conhece contratos e exceções de application e tipos de domain. Não importa
repository concreto, DTO, data source ou clients HTTP/storage.

O Bloc coordena operações e estados; o formulário possui entrada e validação;
a screen compõe e entrega efeitos ao usuário. Módulos fazem a ligação concreta.
Não introduza BaseBloc, store global ou handlers genéricos para padronizar telas
com semânticas diferentes.

Mensagens de erro exibidas ao usuário são locais e em português. Screens e
formulários não exibem diretamente `ErrorEntity.title` ou `detail`, mesmo quando
o backend retorna uma mensagem em português. Infrastructure, exceções e Blocs
continuam preservando os erros remotos e seus metadados; a conversão é apenas
de apresentação, sem alterar `ErrorsEntity` ou modificar o protocolo HTTP.

`core/presentation/formatters/error_message_formatter.dart` fornece textos
compartilhados para status HTTP e fallback por operação, sem regras de negócio
de uma feature. Authentication, User e Expense possuem formatadores próprios
para erros de campos e contratos PocketBase/legados conhecidos. O sign-in trata
falha de autenticação sem afirmar que uma sessão anterior expirou. Códigos ou
campos desconhecidos não liberam texto remoto para a UI.

O roteamento de erros para os campos continua no formulário, pelos status e
pointers já reconhecidos, inclusive quando o detalhe remoto está ausente.
Mensagens repetidas em feedback geral podem ser consolidadas sem alterar a
coleção original. Testes unitários verificam o texto, os fallbacks, os metadados
preservados e o contexto; um teste arquitetural impede leitura direta de títulos
e detalhes remotos na apresentação. Dashboard e Metrics já usavam feedback local.

### Information: Conteúdo Público Local

`information` é uma feature exclusivamente de apresentação, sem domain,
application, infrastructure, Bloc ou operações de rede/storage. Seu módulo sem
`path` registra as URLs completas `/information/terms`, `/information/privacy`
e `/information/help`, públicas em `RouteEnum` e disponíveis sem sessão ou
dependências de módulos irmãos.

Welcome mantém o rodapé original e navega somente para termos e privacidade;
Ajuda permanece acessível pelas Configurações, sem link na Welcome. Settings
oferece os três destinos. A navegação usa as extensões de `BuildContext` nos
widgets responsáveis. Somente os antigos callbacks de
informações de Settings foram removidos; logout e demais contratos da tela
permanecem preservados. Root não inclui essas páginas no conjunto protegido.

O conteúdo editorial fica em
`information/presentation/content/information_content.dart`, com textos puros,
versão e data explícitas. Termos e privacidade compartilham composição de leitura
com resumo e seções numeradas; Ajuda usa perguntas expansíveis. Cabeçalho, cards,
cores, tipografia, ícones e botão de voltar reutilizam o core. A página possui
rolagem, seleção de texto e largura máxima de leitura; não cria estado global.
`InformationPageWidget` compartilha o cabeçalho recolhível do core nas três telas,
em uma única CustomScrollView. A seleção de texto permanece disponível e o
cabeçalho expandido acompanha a coluna de leitura de até 680 pixels em telas
largas; recolhido, o título se alinha ao voltar da barra superior.

O resumo usa diretamente `SummaryCardWidget` do core, também reutilizado por
Settings, com título acima do texto, largura integral, corpo legível e
superfície/borda discretas do tema, sem wrapper específico da feature.
Não reutiliza o card compacto de informação com ícone lateral, inadequado aos
parágrafos longos dos documentos. Previews isolados cobrem os dois resumos em
claro/escuro e privacidade em largura reduzida com texto ampliado.

O canal de suporte e privacidade é exibido como texto selecionável. Solicitações
de exclusão sem acesso ao app são orientadas por e-mail; não há formulário,
envio automático ou implementação de exclusão nesta feature. A exclusão
autenticada continua pertencendo a User. As páginas públicas Angular, seus links,
o recurso web exigido pelo Google Play e qualquer apoio via Pix são entregas
separadas. A UI local não comprova atendimento operacional, conformidade jurídica,
publicação web ou homologação das regras do PocketBase.

Testes verificam o catálogo público isolado e na composição global, a estrutura
editorial e os limites arquiteturais sem montar UI. Previews manuais incluem
temas claro/escuro, fonte ampliada e largura reduzida.

### Core E Dependências Entre Features

Core reúne tema, widgets básicos, animações, imagens, formatters, erros
compartilhados e clients de infraestrutura. Não recebe regras específicas de
uma feature para contornar imports proibidos.

- Authentication e Session não importam uma à outra. Compartilham o AuthStore do
  SDK; Session observa `authStore.onChange`, não o Secure Storage.
- Expense e Budget não dependem de outros contextos financeiros.
- Family pode ler Expense/Budget por contratos próprios e adapters de
  infrastructure. Contextos proprietários não dependem de Family.
- Dashboard pode compor contratos de aplicação de User, Expense e Metrics,
  sem conhecer suas implementações.
- Settings coordena sua interação de logout com `LogoutBloc` próprio, consumindo
  somente contrato e exceção de aplicação de Authentication. Não importa a
  apresentação ou a implementação do repository de Authentication.

## Backend PocketBase E Limite De Integração

O backend adotado está em `backend/`, com PocketBase 0.41.1 e APIs nativas.
Schema e regras ficam em `pb_migrations/`; empacotamento em `Dockerfile`,
`compose.yml` e `docker/`. Não há suíte de testes do backend, hooks, worker ou runtime
Node. Configuração operacional e evidências pertencem ao
[README do backend](backend/README.md); suas regras de manutenção estão em
[backend/AGENTS.md](backend/AGENTS.md).

O escopo implementado é conta individual, CRUD de despesas próprias e métricas
mensais por proprietário em View Collection. Login
exige e-mail verificado, exclusão da conta remove suas despesas e regras nativas
protegem propriedade. Isso não implementa família, orçamento, agregações arbitrárias,
insights ou endpoints customizados de sugestões. As sugestões do Flutter usam
a listagem nativa filtrada do histórico pessoal.

### Contrato Atual Do Cliente Versus Backend Adotado

| Aspecto            | Flutter atual                                                                                                                                                                                                                                                             | PocketBase atual                                                                                                                                                                            |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Transporte         | Authentication, Session, User, Expense e Metrics usam endpoints nativos PocketBase.                                                                                                                                                                                       | API REST nativa de coleções, sem envelope JSON:API.                                                                                                                                         |
| Autenticação       | AuthStore compartilhado; token e record persistidos no JSON `@cordato.pocketbase_auth`. Sign-out limpa a memória sem HTTP ou confirmação durável. | Autenticação nativa da coleção `users`; não há endpoint de logout ou revogação individual do JWT ao sair. |
| Confirmação        | SDK solicita e confirma verificação; callback recebe `token`. Cooldown de 60 segundos após sucesso; associação pública e homologação pendentes. | Migration inicial consolidada configura os templates de `users` para o app em banco novo; criar a conta não envia e-mail automaticamente. |
| Erros e paginação  | `ClientException` convertido por `PocketBaseMapper`; formatadores ainda aceitam códigos legados conhecidos. Expense usa páginas numéricas e Metrics lê o envelope por `send`. | Formatos nativos PocketBase. |
| Datas de despesas  | Data civil escrita como meia-noite UTC e lida pelos componentes do dia, sem conversão de fuso.                                                                                                                                                                            | `occurred_on` opcional como Date UTC, sem default.                                                                                                                                          |
| Categoria          | Novas despesas recebem `other`; edição preserva a categoria retornada. Sem classificação automática.                                                                                                                                                                      | Select opcional; vazio não significa `other`.                                                                                                                                               |
| Recursos derivados | Sugestões consultam o histórico por GET filtrado; Metrics lê totais e percentuais mensais já calculados.                                                                                                                                                                  | View `metrics` agrupa despesas por proprietário/mês; sem endpoint customizado.                                                                                                              |

Centavos inteiros continuam obrigatórios. Expense utiliza a representação UTC
como codificação da data civil: não chama `toUtc()` sobre a seleção local nem
`toLocal()` sobre a resposta. O fim do intervalo inclusivo é enviado como limite
exclusivo da meia-noite UTC do dia seguinte. Não há registros anteriores a migrar,
nem fallback que invente data ou categoria para campos vazios do PocketBase.

Trocar a URL não é migração. SDK/adapters, persistência de sessão, mapeamento de
erros, verificação de e-mail, paginação e destino dos recursos ausentes precisam
de decisão e implementação próprias. A infraestrutura agora configura o SDK
PocketBase 0.25.3, sem Dio ou client HTTP próprio. Authentication, Session, User,
Expense e Metrics já consomem o SDK compartilhado; não restam imports do HTTP/storage
removidos em `lib/`. A análise e a suíte Flutter globais estão limpas, incluindo
composição sem UI e os testes do core adaptados às APIs atuais. Não houve build
nativo ou homologação do serviço nesta etapa.

A arquitetura de camadas Flutter permanece válida. As seções de implementação
descrevem o SDK atual; registros identificados como históricos não autorizam
restaurar o client HTTP antigo. Alterações futuras devem atualizar implementação,
consumidores e testes juntos, sem apresentar fixtures como homologação do serviço.
Não há migração de dados, contas ou sessões do backend anterior neste trabalho.

## Referência Executável: Authentication/Sign-in

### Caminho De Uma Tentativa

1. `FormSignInWidget` mantém e-mail/senha, valida os campos e entrega um record.
2. O validator faz trim do e-mail; a senha é preservada. Nenhuma normalização
   adicional ocorre no evento, Bloc ou repository.
3. `SignInScreen` envia `SignInSubmittedEvent(email, password)`.
4. `SignInBloc` publica `SignInSubmitting` e aguarda o contrato `signIn`.
5. `AuthenticationRepository` chama `collection('users').authWithPassword` no SDK,
   preservando e-mail e senha recebidos. O SDK monta endpoint, JSON e headers.
6. O SDK faz parsing da resposta e atualiza seu AuthStore compartilhado. Campos
   como `verified` não são reinterpretados; a política de login é do backend.
7. O AsyncAuthStore enfileira persistência segura; o repository não aguarda a
   gravação durável. Não há DTO próprio de sign-in nem escritas separadas de ID/token.
8. O Bloc publica sucesso ou falha. A navegação de sucesso pertence à observação
   global da sessão, não ao listener de SignInScreen.

Credenciais podem existir no evento para a operação, mas nunca no estado do
Bloc. DTO, token e ID não são devolvidos à apresentação.

### Estados E Concorrência

`SignInState` é sealed, com quatro variantes imutáveis:

| Estado                  | Interface e ações                                   |
| ----------------------- | --------------------------------------------------- |
| `SignInInitial`         | Campos e envio disponíveis, sem request automática. |
| `SignInSubmitting`      | Campos/envio desabilitados e botão em loading.      |
| `SignInSuccess`         | Tentativa concluída; novos envios bloqueados.       |
| `SignInFailure(errors)` | Feedback e retry manual disponíveis.                |

`canSubmit` e `isSubmitting` são derivados do estado. Não há booleans locais
duplicando a execução nem credenciais armazenadas nas variantes.

O handler usa `droppable`: envios iguais ou diferentes durante uma tentativa
são descartados, não substituem a request nem entram em fila. O guard de
`canSubmit` também impede envio após sucesso. Falha não agenda retry automático.

Outros fluxos devem definir sua própria política explícita de concorrência;
`droppable` não deve ser aplicado cegamente a consultas substituíveis.
Dashboard usa `restartable` para sua coordenação de leituras sobre contratos de
aplicação. Seu estado agregado não constitui a referência geral para submissões.

### Falhas

No repository:

- `ClientException` vira `AuthenticationException` com os erros nativos
  convertidos, preservando mensagens, ordem e metadados.
- Falhas de transporte usam fallback de aplicação. Error e FormatException
  encapsulados pelo SDK propagam sem `catch` genérico.
- Falhas de leitura segura bloqueiam o bootstrap; gravação/exclusão seguem a
  persistência assíncrona nativa, sem confirmação durável pelo repository.

No Bloc:

- `AuthenticationException` publica `SignInFailure` com a mesma `ErrorsEntity`,
  inclusive lista vazia; não é reportada como erro inesperado.
- Erro inesperado chama `addError(error, stackTrace)` e publica falha segura.
- `isClosed` e `emit.isDone` impedem publicação de conclusões obsoletas.

`addError` usa o mecanismo do Bloc; não representa, por si só, integração
automática com telemetria. O Bloc não recebe client nem callback de telemetry.

Na UI, erros PocketBase 400 com `/identity` e `/password` vão para os campos de
e-mail e senha. Erros 422 legados com pointers conhecidos também são aceitos. Os
restantes vão para toast, sem duplicação; ausência de mensagens usa fallback
localizado. Editar limpa somente o erro daquele campo. Falha preserva a entrada.

### Propriedade E Lifecycle

Sign-in é o piloto de ownership pelo escopo de página do Modular V7.
`authenticationModule` registra `SignInBloc.new` no `provide` da rota por
`scope.addBloc<SignInBloc>`, sem bind adicional do Bloc no módulo. A extension
`BlocScopedExtension`, em `core/presentation/extensions/`, adapta `addStreamable`
para `BlocBase`, preservando constructor tear-offs com dependências injetadas.
O repository é lazy singleton pelo contrato no único módulo Authentication,
sem path, disponível no injector raiz inclusive para logout de Settings.

`SignInScreen` recebe a instância `SignInBloc bloc` e validators. O Modular cria
uma instância por página montada e chama `close()` no descarte do escopo; rebuild
não cria outra instância. A screen e seu mixin não criam nem fecham o Bloc.
`BlocConsumer` recebe a instância explicitamente. Testes e previews também precisam
de um proprietário externo explícito; nunca há dois donos do fechamento.
Os demais fluxos mantêm factories com ownership pelas respectivas telas;
Session continua global e pertence exclusivamente a `AppWidget`.

`BlocConsumer` separa composição de efeitos únicos. Loading e disponibilidade
dos campos vêm do estado; toast não é emitido no build. Mixins de UI concentram
lifecycle e handlers, nunca chamadas ao repository.

O fechamento é nativo do Bloc. Não há override de `close()`, flag paralela ou
cancelamento HTTP. A operação remota e gravações de storage podem continuar
após saída da tela; ausência de estado tardio não significa rollback da sessão.

## Operações Do SDK E Persistência

### Cadastro Com Bloc

`SignUpScreen` recebe uma factory estável de `SignUpBloc` e possui seu fechamento,
inclusive na troca de factory. O Bloc usa `SignUpSubmittedEvent`, `droppable` e
estados `Initial`, `Submitting`, `Success(email)` e `Failure(errors)`. Senha não
fica no estado; o e-mail de sucesso identifica o destino de confirmação.
Submissões pendentes e posteriores ao sucesso são bloqueadas; falha permite
retry manual. Falhas esperadas preservam `ErrorsEntity`; inesperadas usam
`addError` e fallback seguro, respeitando fechamento/handler invalidado.

O repository chama `collection('users').create` com `email`, `password` e
`passwordConfirm`. O SDK monta endpoint e headers; a configuração recebe a raiz
do serviço, sem `/api/`. Não envia `verified`, `emailVisibility` ou campos opcionais
de perfil. O SDK retorna um record nativo; o contrato precisa somente da conclusão,
portanto não há DTO de cadastro, parsing dos campos não consumidos ou sessão criada.
Após sucesso do cadastro, a tela de confirmação dispara automaticamente a
solicitação de verificação como operação separada. Falha de e-mail não se torna
falha da criação e o retry solicita somente o e-mail, sem recriar a conta.

O formulário preserva validação, trim de e-mail, senha sem normalização e entrada
após falha. Erros PocketBase 400 de `/email`, `/password` e `/passwordConfirm`
vão aos campos correspondentes; 422 de e-mail/senha e 409 legados de e-mail
continuam aceitos. Somente
erros restantes aparecem em toast. Campos e envio ficam desabilitados durante
submissão. O listener substitui a rota por confirmação com o e-mail, uma única
vez, sem criar sessão. O footer substitui a rota por sign-in via BuildContext.

Testes unitários cobrem o Bloc e o repository. Testes de formulário, navegação
visual e flows de UI foram removidos por decisão do projeto.

### Reenvio Com Bloc

O repository chama `collection('users').requestVerification(email)`, sem criar
sessão. Sucesso segue o contrato do SDK, sem revalidar status 204. `ClientException`
passa por `PocketBaseMapper` e vira `AuthenticationException`.

`ResendEmailScreen` recebe uma factory estável de `ResendEmailBloc`, cria a
instância em `initState`, substitui/fecha quando a factory muda e fecha no
descarte. A criação da instância envia `ResendEmailStartedEvent(email)`; rebuild
comum não repete o envio. Troca de factory ou endereço fecha o Bloc anterior e
inicia um novo fluxo. `ResendEmailSubmittedEvent(email)` representa retry manual.
Ambos delegam o endereço sem normalização. Os estados sealed são `Initial`,
`Submitting`, `Success`, `Cooldown(timeLeft)`, `Ready` e `Failure(errors)`.
O Bloc usa um único handler `droppable` para os dois eventos, preserva falhas
esperadas, reporta inesperadas via `addError` com fallback seguro e ignora
conclusões após fechamento. `Started` só é aceito em `Initial`; endereço vazio
não faz HTTP. `Initial`, envio pendente, sucesso e cooldown bloqueiam o botão.

Sucesso inicia cooldown de 60 segundos no Bloc, sem navegar nem criar sessão.
Somente `Ready` ou `Failure` permitem intenção manual; terminar o cooldown não
envia outro e-mail. O listener distingue primeiro envio e reenvio no toast.
Falha inicial informa que a conta já foi criada e permite retry manual imediato;
falha manual mostra os erros remotos com fallback para mensagens ausentes.
O e-mail permanece somente leitura.

O timer pertence a um stream consumido por `emit.forEach` no Bloc. O lifecycle
nativo cancela a subscription e o timer no fechamento, sem override de `close()`.
A contagem usa `Timer.tick` para contabilizar ticks atrasados. A UI deriva
disponibilidade e tempo restante somente do estado, sem timer ou flags paralelas.
Testes com `fake_async` verificam os 60 segundos, bloqueio de duplicatas,
ausência de retry automático e cancelamento. O fechamento do Bloc não cancela
a request HTTP em andamento.

O Bloc e o repository mantêm testes unitários; os flows de UI e sua fixture
isolada foram removidos.

### Callback Com Bloc

`CallbackScreen` recebe uma factory estável de `CallbackBloc` e possui a criação,
substituição e fechamento da instância. A entrada da tela envia
`CallbackRequestedEvent(token)` uma única vez; rebuild comum não
repete a confirmação. Alterar o token ou a factory inicia uma nova confirmação.
Os estados sealed são `Initial`, `Confirming`, `Success`, `Invalid` e `Failure`;
não armazenam token de verificação nem dados de sessão.

O Bloc trata token nulo/vazio como inválido sem acessar o repository. Nos demais
casos, delega o token original, sem trim ou decodificação adicional, e traduz o status do
contrato. Falhas inesperadas usam `addError` e o feedback seguro já existente.
`restartable` invalida o handler anterior quando outro link chega: somente o
resultado mais recente pode produzir efeitos. Ao contrário do command legado,
um token novo não precisa aguardar a request anterior terminar. Isso não cancela
HTTP nem desfaz uma confirmação remota já iniciada.

O listener mantém os três toasts existentes e usa as extensões de BuildContext
para resetar a navegação em Welcome e empilhar Sign-in. Não há callback de
navegação recebido pela rota, sessão criada ou redirecionamento autenticado.
A tela mantém o indicador animado e seu rótulo semântico durante a confirmação.
Fechamento, troca de factory e substituição do link impedem efeitos obsoletos.

Testes próprios do módulo verificam factories independentes e repository real
com SDK real e transporte mockado. Os testes de UI da rota e flows de callback foram removidos.
A entrega nativa de deep links não é provada pelos testes unitários.

O destino público é
`https://app.cordato.cloud/authentication/confirm-email?token={TOKEN}`. Android
declara o host/caminho e `autoVerify`; iOS declara Associated Domains nos
entitlements usados por Debug/Profile/Release. A única migration
`1793491200_initial.js`, consolidada e exclusiva para banco novo, configura o
template de verificação de `users` para esse destino e mantém destinos
administrativos nativos. Também cria diretamente a view `metrics`; as quatro
migrations incrementais foram incorporadas e removidas. Esta revisão não atualiza
bancos existentes.
`tool/app_links.dart` gera `assetlinks.json` e `apple-app-site-association` com
identificadores públicos fornecidos explicitamente, sem página alternativa ou
confirmação web. Não há deploy ou associação de domínio implícitos. Ordem
de publicação, proteção de query strings nos logs e homologação estão em
[app_links/README.md](app_links/README.md).

### Recuperação De Senha

Na etapa de confirmação do envio, o campo de e-mail usa o mesmo controller e
validator da solicitação inicial. Campo e botão Reenviar seguem `canSubmit`:
bloqueados durante envio e cooldown, editáveis quando o cooldown termina. O evento
de reenvio transporta o endereço atual validado; o Bloc não normaliza a entrada.
Falhas preservam a edição local e não iniciam cooldown. Erros 400 em `/email`
aparecem no campo também no reenvio; os demais mantêm o toast de falha.

`PasswordRecoveryBloc` e `ResetPasswordBloc` pertencem ao `provide` das rotas
`/authentication/password-recovery` e `/authentication/reset-password`. As screens
recebem instâncias explícitas, sem criar ou fechar Blocs. A resolução usa o
contrato de Authentication, sem depender de visitar uma rota irmã.

Solicitação e “Confira seu e-mail” são duas etapas visuais da mesma rota para
preservar cooldown e e-mail confirmado no estado, sem callbacks de navegação ou
flags locais de execução. `requestPasswordReset(email:)` delega ao método nativo
do SDK, que envia `email` para `collections/users/request-password-reset`. A confirmação visual é
neutra quanto à existência da conta. Submissões são `droppable`; o cooldown começa
apenas depois do sucesso, dura 60 segundos e não provoca reenvio automático.
`EmailCooldown` compartilha duração e ticks com `ResendEmailBloc`; o lifecycle
nativo do emitter cancela o timer quando a rota fecha. Falha no reenvio mantém
a etapa de confirmação e habilita retry imediato.

O callback extrai exatamente um token não vazio da query, decodificado uma única
vez. Não faz GET de URL recebida e não guarda token ou senhas no estado do Bloc.
Ao abrir, `ResetPasswordBloc` aguarda `signOut()` para limpar a sessão local antes
de habilitar a ação. Isso limpa o AuthStore em memória, sem aguardar exclusão
durável; falhas assíncronas de storage não são reportadas pelo Future de logout.
A observação global de Session preserva essa rota pública durante o logout.

`confirmPasswordReset(token:, password:, passwordConfirm:)` delega ao método
nativo do SDK para `collections/users/confirm-password-reset`, sem gravar
credenciais ou criar sessão. Erro PocketBase 400 em `/token` vira
`PasswordResetTokenException`, preservando os erros remotos. Outros erros remotos
viram `AuthenticationException`; falhas inesperadas não viram sucesso.
Validações e erros por campo ficam no formulário: senha segue o cadastro,
confirmação deve coincidir, erros 400 em `/password` e `/passwordConfirm` são
exibidos nos respectivos campos. Editar limpa somente o erro do campo editado.

Submissões pendentes e após sucesso são bloqueadas. Um novo link admitido usa
`restartable` e invalida o handler anterior, sem cancelar HTTP ou persistência já
iniciados. Sucesso e token inválido/expirado redirecionam ao sign-in com toast;
falhas de rede mantêm o formulário para retry. O backend invalida JWTs anteriores
e pode verificar o e-mail conforme a semântica nativa de reset do PocketBase.

Não há logging HTTP. Token e senhas não entram nos estados nem nos logs do
observer de Blocs. A inicial consolidada
`1793491200_initial.js` configura o link de recuperação de `users` para
`https://app.cordato.cloud/authentication/reset-password?token={TOKEN}` e mantém
destinos nativos em `_superusers`. Android declara o caminho exato e o gerador AASA inclui
a rota. Publicação das associações, deploy, entrega SMTP e abertura em dispositivo
são etapas operacionais separadas; não existe fallback web.

### Troca Autenticada De Senha E Política Compartilhada

`PasswordValidation` exige 6–16 code points Unicode, ao menos uma minúscula ASCII,
uma maiúscula ASCII e um número ASCII. Não remove espaços nem normaliza entradas.
Cadastro, sign-in, recuperação e troca compartilham o mesmo validator. A senha
atual da troca exige apenas preenchimento, pois sua validade pertence ao servidor.
`ChangePasswordValidation` rejeita nova senha exatamente igual à atual; confirmação
usa o validator já compartilhado com recuperação. Erros ficam nos respectivos
campos, sem mensagens remotas expostas.

Dados pessoais somente navega para `/authentication/change-password`, protegida
no catálogo de rotas. Authentication possui tela, mixin, formatter e
`ChangePasswordBloc`, registrado exclusivamente no `provide` via `addBloc`.
Tela e previews recebem instâncias com proprietário externo. User mantém seus
Blocs e seu lifecycle anteriores, sem importar apresentação de Authentication.

`IAuthenticationRepository.changePassword(oldPassword:, password:,
passwordConfirm:) -> Future<void>` lê o ID atual por `pocketBase.userId()` e usa
`update` nativo de `collections/users/records/{id}`, com os três campos em JSON
plano e sucesso definido pelo SDK. Não grava credenciais, não reautentica, não
captura snapshots e não limpa o AuthStore nesse método, inclusive em 401.
Ausência de ID propaga `MissingAuthenticatedUserException` da application do core;
ChangePasswordBloc preserva seu `ErrorsEntity` como falha esperada, sem reportar
erro inesperado ou executar logout, e permite retry manual. Erros remotos
preservam `ErrorsEntity`; falhas inesperadas propagam.

O Bloc descarta submissões concorrentes com `droppable` compartilhado entre
eventos e, após confirmar a alteração, emite SigningOut e aguarda `signOut()`.
Os controllers são limpos ao confirmar o PATCH. Falha de limpeza fica em estado
distinto e permite somente repetir `signOut`, nunca o PATCH. Fechamento suprime
publicações tardias, sem cancelar HTTP ou prometer rollback. Sucesso navega para
sign-in removendo o fluxo anterior e mostra “Senha alterada. Entre novamente”.

A composição root possui uma instância local de `SessionRedirectDeferral`,
exposta por `SessionRedirectScopeWidget` do core. A tela retém uma liberação
idempotente somente durante a operação; redirecionamentos ficam adiados apenas
na rota retida, inclusive se o token desaparecer antes de `clear()` concluir.
Falha de PATCH, sucesso da navegação e dispose liberam a retenção e reavaliam a
sessão atual. A liberação não reutiliza uma observação ainda autenticada para
redirecionar sign-in a Dashboard; novas observações continuam com a regra normal.
`SessionRoutePolicy` mantém a decisão de redirecionamento pura e
testada, preservando outros logouts. Não há store global, dependência entre
Authentication e Session ou outro proprietário de SessionBloc.

Não há logger HTTP nem interceptors próprios. O observer de debug registra
lifecycle e tipos seguros dos Blocs, sem imprimir eventos/estados completos,
payloads, senhas, tokens ou URLs de callback.

### Logout Em Settings

Authentication continua dona da limpeza local de sessão pelo contrato
`IAuthenticationRepository.signOut`. Não faz request HTTP nem revoga o JWT no
servidor. Como a interação pertence a Configurações,
`LogoutBloc` fica em `settings/presentation/screens/settings/bloc/`, junto dos
eventos e estados, sem tela ou módulo artificial de logout em Authentication.
`settingsRoutesModule` registra o Bloc por factory e injeta `bloc: inject<LogoutBloc>`;
o contrato de Authentication precisa estar disponível na composição externa.

`SettingsScreen` é dona do lifecycle da instância e usa `BlocConsumer` para
renderização e falhas. A confirmação mantém os textos e o cancelamento existentes;
confirmar somente envia `LogoutRequestedEvent` se a tela ainda estiver montada,
o Bloc for o mesmo dono do diálogo e estiver disponível. Troca de factory fecha
o Bloc anterior e invalida confirmações antigas.

Os estados sealed são `Initial`, `Submitting`, `Success` e `Failure(errors)`.
`droppable` descarta duplicatas pendentes; sucesso bloqueia novos envios e falha
permite retry manual com nova confirmação. Falhas esperadas preservam a mesma
`ErrorsEntity`; inesperadas usam `addError` e fallback seguro. Fechamento impede
estado/feedback tardio, não cancela limpeza já iniciada.

O repository limpa o AuthStore compartilhado sem HTTP. A persistência da exclusão
é assíncrona no SDK e não é aguardada nem confirmada pelo sucesso do Bloc.
Settings não navega nem mostra toast de sucesso:
a observação global de Session continua responsável pelo redirecionamento.
Os testes unitários de repository verificam ausência de HTTP e limpeza em memória;
os testes de Bloc preservam delegação, concorrência e tratamento de falhas do
contrato. A composição isolada testa resolução de dependências sem montar UI.
Testes de tela/rota e flows de logout foram removidos.

### Session E Composição Root

`ISessionRepository` fica em `session/application/repositories/` e retorna
`Future<bool> loadSession()` e `Stream<bool> sessionChanges`. A implementação em
`session/infrastructure/repositories/` recebe o SDK inicializado, sem data source
ou dependência de Authentication. `loadSession` lê o AuthStore; token vazio retorna
ausência sem request. Com token, usa `authRefresh` diretamente no PocketBase
compartilhado, com auto-save nativo no AuthStore. Chamadas simultâneas
compartilham o Future pendente; uma chamada posterior explícita pode validar de novo.

Por simplificação explicitamente aprovada, não há client temporário, comparação
de snapshots ou descarte de respostas antigas. Um sucesso tardio pode sobrescrever
logout ou novo login. HTTP 401 limpa o AuthStore atual, mesmo após troca de sessão; 403, demais
erros HTTP e transporte lançam `SessionException` sem limpar a sessão. Parsing
inválido rejeitado pelo SDK propaga; valores ausentes seguem seus defaults, sem
validação própria de token/ID. O retorno indica a presença local de token após o
refresh, por `PocketBaseExtension.hasSession`, não autorização. Não há DTO de refresh, escritas separadas,
espera por persistência durável ou atomicidade entre HTTP e storage.

`sessionChanges` continua observando presença local sem expor o token nem executar
HTTP a cada evento. O sucesso do sign-in já escreve um token recebido do backend.
Presença local não constitui garantia de autorização de recursos financeiros.

`SessionBloc`, em `session/presentation/bloc/`, começa em `Initial` e recebe
`SessionStartedEvent` do proprietário. `Loading`, `Authenticated`,
`Unauthenticated` e `Failure` são estados sealed sem token. O handler `droppable`
inicia uma única observação por instância e registra `authStore.onChange` antes da leitura
inicial. A leitura só publica enquanto o estado continuar `Loading`: um evento
mais recente, inclusive falha do watch, tem precedência sobre o resultado antigo.

O handler aguarda `emit.onEach`, usando o lifecycle nativo para cancelar a
subscription no fechamento, sem campo de subscription ou override de `close`.
Fechar não cancela o refresh já iniciado; `isClosed`/`emit.isDone`
impedem resultados tardios. Falhas HTTP esperadas do refresh preservam os erros
em `SessionFailure`, sem `addError`. Falhas inesperadas de leitura/watch usam `addError` e `Failure`,
sem detalhes internos ou suposição de token ausente. O watch continua ativo após
falhas recuperáveis e pode publicar uma presença posterior, sem retry automático
de leitura. Presenças repetidas não duplicam estados prontos.

`sessionModule` registra repository por contrato e Bloc por factory.
Para esta observação contínua, o único proprietário é `AppWidget`, que recebe
`bloc: inject<SessionBloc>`, inicia em `initState`, fecha no descarte e substitui
somente quando a factory muda. Não há singleton de Bloc nem uma instância por
tela. `AppScreen` é apenas o splash visual e não possui operação ou fechamento.
A splash Flutter reutiliza cópias exatas das imagens nativas, incluindo margens
transparentes: caixa de 288dp no Android e 168 pontos no iOS, centralizada sem
`SafeArea` para acompanhar o centro nativo. Testes de assets verificam igualdade
com os arquivos de origem e registro no bundle; não montam UI.

Login, cadastro, redefinição e troca de senha encaminham a ação `next`
explicitamente ao próximo campo por `onEditingComplete` e `FocusNode` pertencente
ao mixin do formulário. Não dependem da ordem automática de botões auxiliares;
ações finais continuam usando a submissão existente.

O listener de Root agenda navegação depois do frame e valida instância, estado
atual e navigator key antes do efeito. Entrada protegida a frio passa pelo splash;
presença resolve `/` para Dashboard e ausência/falha resolve para Welcome. Um token
novo em Welcome/Sign-in abre Dashboard; perda/falha de observação em rota protegida
volta a Welcome. Cadastro, reenvio e callback públicos são preservados. Essa decisão
visual não prova autorização remota e não limpa storage em falha de observação.

`app_module.dart` ativa Session, Welcome, Information, Authentication, Dashboard, Settings,
User e Expense, além das dependências de Metrics. Authentication e
Expense têm um único módulo sem path por feature; seus binds são root-owned e
as URLs completas permanecem inalteradas. User mantém seu módulo de dependências
compartilhadas existente. Logout resolve o contrato de Authentication sem ativar
uma rota irmã. Blocs de
tela continuam registrados por factory nos módulos de suas features, exceto
Sign-in, cujo Bloc pertence ao `provide` da página.
`test/app_module_test.dart` verifica todos os destinos de `RouteEnum` e a resolução
de Dashboard e logout sem ativar rotas irmãs. O teste visual composto de Root
e os flows Session/Root foram removidos. Falhas/leitura pendente do storage
continuam verificadas no bootstrap e na factory; Session cobre erros de refresh,
sem API de fixtures
ou bypasses de segurança no app.

### User: Repository E Perfil Com Bloc

`IUserRepository` fica em `user/application/repositories/` e retorna diretamente
`Future<UserEntity>` em `getById`/`update` e `Future<void>` em `delete`.
`UserException`, em `application/exceptions/`, transporta os erros esperados.

A Dashboard consulta o perfil por esse mesmo contrato, já integrado ao PocketBase.
Falha do perfil, tanto na carga completa quanto na atualização ao voltar de User
ou Settings, leva à tela de erro global, sem publicar conteúdo parcial ou assumir
um usuário ausente. `UserException` preserva a mesma `ErrorsEntity`, inclusive
vazia; falhas inesperadas usam fallback seguro e `addError`. Resultados de ciclos
substituídos ou encerrados não alteram o estado nem reportam falhas tardias.
Sucesso na atualização do perfil preserva os dados financeiros confirmados;
retry após falha recarrega a Dashboard completa. Nome vazio continua exibindo
`Cordato` somente na apresentação. Esta alteração não migra Metrics nem modifica
o tratamento existente da consulta auxiliar do histórico de despesas.
O repository concreto fica em `user/infrastructure/repositories/` e recebe
diretamente o PocketBase pronto compartilhado, sem HTTP/storage próprios ou
data sources. O binding existente pelo contrato resolve essa instância do SDK.

`PocketBaseExtension`, no core infrastructure, expõe `userId()`
como leitura do auth record atual, sem cache ou gestão de sessão. A extension
lança `MissingAuthenticatedUserException` para ID nulo/vazio ou composto só por
espaços e preserva o valor original nos demais casos. Essa exceção pertence à
application do core e contém o `ErrorsEntity` de identidade ausente. O repository
usa a extension diretamente em cada operação, sem converter essa falha em
`UserException`. O contrato pode lançar ambas as exceções; UserBloc, EditBloc e
DashboardBloc preservam seus erros como falhas esperadas, sem reportá-las como
erros inesperados. Nenhuma dessas operações de validação gerencia sessões.
O getter `hasSession` da mesma extension consulta apenas se o token local não está
vazio, sem validar JWT, exigir record ou realizar HTTP.
O SDK codifica o ID no caminho `collections/users/records/<id>` via `getOne`,
`update` e `delete`. Update envia JSON plano somente com nome/avatar fornecidos
e devolve a entidade da resposta, sem normalização oculta. `PocketBaseMapper`
preserva ordem, mensagens e metadados dos erros em `UserException`; falhas de
transporte usam fallback. Parsing inválido e erros inesperados encapsulados pelo
SDK propagam sem serem convertidos em falhas esperadas. O repository não gerencia
sessões nem captura seus snapshots: falhas, inclusive HTTP 401, são mapeadas sem
limpar o AuthStore, inclusive para exclusão.

`UserResponse` interpreta o record nativo PocketBase diretamente, sem envelope
JSON:API. `UserEntity` não possui o antigo campo `status`; `verified` não é
convertido em status nem usado como autorização local. Nome vazio é preservado
no domínio e exibido como `Cordato` somente pela apresentação, inclusive na
Dashboard, sem persistir esse fallback. Avatar textual vazio vira ausência de
seed em infrastructure, preservando o fallback visual baseado no ID.

Exclusão aguarda o método `delete` nativo, sem revalidar um status 204 específico.
Após sucesso, o SDK limpa o AuthStore se ID/coleção correspondem à conta excluída;
Session observa essa mudança. Update também atualiza o auth record correspondente
pelo comportamento nativo do SDK. Não há limpeza de todo o storage nem espera por
exclusão durável: os callbacks do AsyncAuthStore continuam assíncronos. Falhas
remotas não confirmam sucesso. Esses efeitos nativos comparam ID/coleção, não
token/identidade do snapshot; não há garantia adicional contra respostas antigas
de update/delete após novo login do mesmo usuário. Não há booleano: conclusão
sem exceção é suficiente para o consumidor.

`UserBloc`, em `presentation/screens/user/bloc/`, substitui os commands de
consulta, avatar e exclusão. Um único handler `droppable` coordena os três eventos:
operações pendentes descartam novas consultas e mutações, inclusive concorrentes
de outro tipo, sem fila ou cancelamento HTTP. Estados sealed distinguem consulta,
perfil pronto, salvamento de avatar, exclusão e seus resultados. A disponibilidade
das ações deriva do estado. Falhas de mutação preservam o perfil confirmado;
`UserException` preserva a mesma `ErrorsEntity`, inclusive vazia. Falhas inesperadas
usam `addError` e fallback seguro. Fechamento impede publicações tardias.

Avatar delega a seed original ao repository e só confirma se a entidade retornada
contiver a mesma seed. Falha ou resposta divergente permite nova tentativa manual,
sem retry automático. Conclusão de `delete` publica sucesso e bloqueia novas
operações; exceções publicam falha. Sucesso não navega nem mostra toast: Session
observa a limpeza do token.

`UserScreen` recebe a factory estável `bloc: inject<UserBloc>`, cria em `initState`,
fecha em `dispose` e substitui/fecha somente se a factory mudar. O módulo registra
Bloc por factory e repository pelo contrato, sem data sources. `BlocConsumer`
separa renderização dos toasts únicos. Erro de consulta usa `ErrorScreen` com retry
e acesso à confirmação de exclusão; skeleton é excluído da semântica.

O mixin possui somente estado visual da seed ainda não confirmada e o timer de
dois segundos. Gerar outra seed reinicia o debounce. Troca de factory, saída,
edição de nome e confirmação de exclusão cancelam o timer. Diálogos e retornos
de edição conferem o dono atual antes de enviar eventos. Salvar/excluir bloqueia
as demais ações. A volta da edição só recarrega após uma mutação confirmada.
Previews mantêm uma factory estável; somente a tela fecha o Bloc.

`EditBloc`, em `presentation/screens/edit/bloc/`, substitui o último command de
User. `EditSubmittedEvent(name)` delega o nome original ao contrato. Os estados
sealed são `Initial`, `Submitting`, `Success(user)` e `Failure(errors)`.
`droppable` descarta envios iguais ou diferentes durante uma operação. Sucesso
bloqueia novas submissões; falha permite retry manual, preserva os erros esperados
e usa `addError` com fallback seguro para falhas inesperadas. Fechamento não
cancela HTTP, mas impede estados e feedback tardios.

`EditScreen` recebe `bloc: inject<EditBloc>` por factory, cria e fecha a instância
e substitui seu proprietário somente se a factory mudar. O formulário mantém a
entrada e os erros por campo: exige de 2 a 32 caracteres Unicode após trim e rejeita nome igual ao inicial,
faz trim somente ao enviar e preserva a entrada após falha. Botão e teclado usam
o mesmo guard. Erros PocketBase 400 com `/name` e erros 422 legados pelo pointer de nome ficam no campo; editar limpa esse
erro, e somente erros restantes aparecem em toast. Sucesso mostra o feedback
existente e devolve a entidade da API pelo callback de navegação já existente,
uma única vez. O perfil recarrega ao receber esse resultado confirmado.

User não depende mais de CommandIt. Repository e Blocs mantêm testes unitários;
o teste visual composto do módulo e os flows de perfil/edição foram removidos.
Dashboard compõe os contratos de aplicação financeiros.

Verificação da migração de User para PocketBase (03/11/2026): `flutter pub get`
concluído; `flutter analyze` sem issues; verificação focada com
`flutter test test/architecture test/features/user test/features/dashboard test/app_module_test.dart --reporter failures-only`
com 186 testes aprovados; `flutter test --reporter failures-only` com 798 testes aprovados.
Os testes usam clients mockados ou transporte HTTP simulado, sem acesso ao serviço.
`dart run tool/widget_preview.dart` compilou e serviu o catálogo, encerrado por
timeout de 45 segundos sem cliente conectado; sem validação visual manual.
Sem alteração no backend, deploy ou homologação real de regras e cascata.

### Metrics: Repository E Consulta Com Bloc

`IMetricsRepository` fica em `metrics/application/repositories/` e retorna
`Future<ExpenseMetricsEntity> getExpenses({startDate, endDate, groupBy})`.
`MetricsException` transporta `ErrorsEntity` nas falhas esperadas. A implementação
em `metrics/infrastructure/repositories/` recebe diretamente o PocketBase pronto
compartilhado, sem wrapper HTTP/CRUD, data source, storage próprio ou operações de escrita.

O repository consulta `collections/metrics/records` com filtro
`start_date` por mês civil completo. `_isCompleteMonth` valida o período sem
conversão de fuso: ambas as datas devem delimitar o mesmo mês; ambas ausentes
selecionam o mês atual. Datas incompletas, intervalos parciais e múltiplos meses
falham antes do HTTP com `MetricsException`, sem arredondar a seleção.
A consulta usa `PocketBase.send<Map<String, dynamic>>` nativo no endpoint relativo
`/api/collections/metrics/records`, com `page: 1`, `perPage: 2`, `skipTotal: true`
e valor do filtro escapado por `PocketBase.filter`. `getList` não é usado aqui:
seus defaults de `items` ausente/nulo esconderiam respostas inválidas como mês
sem despesas. O cast estrito do envelope fica no repository; autenticação, URL,
transporte e decodificação JSON continuam a cargo do SDK.

A view é criada por migration aditiva, inclusive no bootstrap de bancos novos,
sem reaplicar ou alterar a inicial em instalações existentes. Agrupa por `owner`
e mês de `occurred_on`, somando `CAST(amount AS INTEGER)` no SQLite. Somas são
expostas como texto decimal para não passar por float/JSON numérico no transporte.
Categorias vêm em um array JSON com valores textuais em centavos e percentuais
numéricos arredondados a duas casas, em ordem de valor decrescente e categoria
como desempate. O id é o menor id das despesas do grupo e pode mudar ao excluir
essa despesa. Campos e regras da view são inferidos/persistidos pelo PocketBase;
`listRule` e `viewRule` exigem usuário verificado da coleção `users` e o próprio
`owner`. Escritas ficam bloqueadas. Isso define autorização no servidor, não uma
garantia implementada ou homologada pelo Flutter.

O DTO interpreta records planos, sem JSON:API. O repository não soma despesas,
não recalcula percentuais e não lê o proprietário do storage; autenticação pertence
ao SDK. Não filtra proprietário no Flutter nem gerencia sessões em 401.
Só uma resposta nativa com `items`
vazio representa mês sem despesas, retornando total zero e categorias vazias
quando agrupadas. Mais de um record ou período diferente do solicitado lança
`FormatException`. Agrupamento omitido continua produzindo `categories: null` na
entidade; agrupado preserva array imutável, ordem e categorias desconhecidas.
Percentuais continuam `double`, pois não são dinheiro. A UI, os cards e a
navegação para despesas filtradas por categoria/mês não são alterados.

Não há migração ou classificação dos registros existentes: `category` vazio não
vira `other`, e despesas sem data não pertencem a um mês. A view não é materializada
nem emite realtime; recargas existentes atualizam os dados após mutações. A soma
deve caber em INTEGER de 64 bits do SQLite; overflow causa falha, não conversão
silenciosa para centavos em ponto flutuante. Regras, precisão e desempenho reais
exigem homologação operacional autorizada antes de declarar a migração implantada.

Respostas HTTP de erro viram `MetricsException`, preservando mensagens, ordem,
status, code, pointer e parameter, por `PocketBaseMapper`. Transporte usa fallback seguro. Parsing
inválido (`TypeError`/`FormatException`) e falhas inesperadas propagam, sem catch
genérico que as transforme em erro de negócio ou sucesso vazio.

`ExpenseMetricsBloc`, em `metrics/presentation/bloc/`, substitui o command de
consulta compartilhada, sem criar uma screen artificial. Recebe
`ExpenseMetricsRequestedEvent` com filtros opcionais e delega os valores sem
normalização. Estados sealed distinguem `Initial`, `Loading`, `Success(data)` e
`Failure(errors)`. Somente sucesso expõe métricas; zero, categorias ausentes e
categorias vazias permanecem resultados válidos, não falhas.

O handler usa `restartable`: uma consulta nova invalida o resultado anterior,
sem cancelar HTTP. Sucessos e falhas obsoletos ou posteriores ao fechamento não
publicam estados. `MetricsException` preserva a mesma `ErrorsEntity`; falhas
inesperadas usam `addError` e fallback seguro. Sucesso permite refresh e falha
permite retry manual, sem request automática na criação ou retry automático.

O módulo registra o repository pelo contrato e o Bloc por factory independente.
Os dois previews consumidores usam BlocBuilder e PreviewResourceWidget como único
dono do fechamento. Metrics não depende mais de CommandIt. A Dashboard mantém sua
própria coordenação pelo contrato: preserva o erro esperado de Metrics quando a
leitura paralela o envolve em `ParallelWaitError`, sem adicionar um Bloc
intermediário à Dashboard.

A distribuição visual mantém até três categorias com total positivo por página,
em ordem estável de valor decrescente. `ExpenseMetricsPagesExtension` decide,
sem depender de Flutter, se a última página de um conjunto com múltiplas páginas
tem uma categoria isolada. Somente nesse caso, `ExpenseMetricsGridWidget`
preenche a linha inferior com `ExpenseMetricsTipCardWidget`. A dica não integra
a coleção de categorias, não altera a paginação ou os indicadores e não existe
em uma distribuição com apenas uma categoria, nem em páginas com dois ou três
cards financeiros.

O card informativo é puramente visual, sem imagem, valores ou ação de toque.
Preserva raio, borda, espaçamento e posição do ícone/título dos cards de categoria,
com ícone estático de informação do core e cores neutras do tema. O título ocupa
até uma linha e a descrição até três no tamanho padrão; fonte ampliada remove
esses limites. Sua altura é medida antes de calcular a altura compartilhada das
páginas, para acomodar o texto sem recorte. Semântica permanece informativa, não
de botão, e páginas inativas continuam excluídas da leitura acessível.

Testes unitários da regra cobrem quantidades de zero a dezoito categorias,
filtros de totais não positivos, transições de quantidade e preservação dos dados
e da paginação. Previews manuais incluem o card isolado, as últimas páginas de
quatro, sete e dez categorias, temas claro/escuro e largura reduzida com fonte
ampliada; não há testes de UI nesta mudança.

### Remoção De Insight

A feature Insight foi removida: domínio, contrato, repository, Bloc, módulo,
seção da Dashboard, previews e testes próprios. Dashboard consulta somente
Metrics e Expense para o conteúdo financeiro. As duas consultas continuam em
paralelo, sem publicação parcial, preservando falhas tipadas e retry manual.
Registros históricos de Insight abaixo não representam código disponível nem
autorizam restaurar a feature.

Verificação histórica da remoção de Insight, anterior à remoção dos testes de UI:
`flutter pub get` concluído; `flutter analyze` sem issues;
`flutter test test/architecture test/features/dashboard test/app_module_test.dart test/features/core/infrastructure/clients/http/interceptors/session_interceptor_test.dart`
com 80 aprovados. Após limpar diretórios vazios residuais, a repetição global
`flutter test --reporter failures-only` teve 939 aprovados e uma falha já registrada
em `expense_screen_test.dart:319`, na sugestão de descrição. A primeira execução
também detectou o diretório vazio de Insight; esse bloqueio foi corrigido, sem
enfraquecer o teste arquitetural. `dart run tool/widget_preview.dart` compilou e
serviu o catálogo, encerrado por timeout sem cliente conectado. Sem validação
visual, execução Maestro ou alteração no backend nesta remoção.

### Expense: Repository, Formulário E Listagem Com Bloc

`IExpenseRepository` fica em `expense/application/repositories/`. Consulta por ID,
criação e atualização retornam `Future<ExpenseEntity>`; listagem retorna
`Future<ExpensePageEntity>`; exclusão retorna `Future<void>`. `ExpenseException`
transporta os erros esperados. O repository concreto fica em
`expense/infrastructure/repositories/` e recebe diretamente o PocketBase pronto
compartilhado, sem HTTP/storage próprios, data source, Either ou dependência de
outro contexto financeiro. CRUD usa `getOne`, `create`, `update` e `delete`;
listagem e sugestões usam `getList`. SDK e records permanecem em infrastructure.

Sugestões usam `suggestions({required String query})`, retornando uma lista imutável
de `ExpenseSuggestionEntity` com ID, descrição, categoria tipada obrigatória e
centavos opcionais positivos.
O adapter atual sempre preenche os centavos pelo record do histórico:
`ExpenseSuggestionResponse` interpreta `id`, `description`, `amount` e `category`
nativos. Categoria é convertida por `ExpenseCategoryEnum.value`, sem fallback.
O repository consulta `collections/expenses/records` com `description ~ <valor>`,
escapando o valor com `PocketBase.filter` para impedir injeção de expressões.
Usa `page: 1`, `perPage: 30`, `skipTotal: true`, projeção dos quatro campos e
ordenação `-occurred_on,-created,-id`. Deduplica descrições sem diferenciar caixa,
mantendo a primeira ocorrência, seu valor e sua categoria; não busca todo o histórico para
deduplicação global. Sem histórico, não há sugestões. Não há IA ou endpoint
customizado. A autorização continua nas regras do backend. Parsing inválido
propaga como nas demais operações, sem resultado parcial ou valor inventado.

`ExpenseSuggestionsBloc` é independente de consulta/submissão do gasto. Processa
eventos concorrentemente com geração latest-wins: uma entrada/invalidação nova
impede publicação de operações antigas, inclusive durante o debounce de 300 ms.
A política inicial é consultar a partir de 3 caracteres. Invalidar impede o HTTP
do debounce obsoleto; chamadas já iniciadas não são fisicamente canceladas. Estados
sealed distinguem idle/loading/success/failure e identificam a revisão da consulta.
Uma ponte local de apresentação conclui Futures do `optionsBuilder` por resultado,
invalidação ou fechamento e cancela subscriptions; não executa HTTP ou debounce.

O novo Bloc é fornecido exclusivamente pelo `provide` da rota `/expense` com
`addBloc`; Modular cria e fecha a instância. Screen e formulário recebem-na, sem
duplicar bind ou owner. `ExpenseBloc` mantém o lifecycle anterior pela screen.
Somente cadastro consulta sugestões. A origem manual/automática do valor e a
seleção pertencem ao formulário: resposta recebida não preenche campos, seleção
não salva, valores manuais não são sobrescritos e data civil é preservada.
Aceitar uma sugestão aplica sua categoria no formulário, substituindo inclusive
uma categoria manual anterior; receber a resposta sem selecionar não altera campos.

O core oferece `AutocompleteTextFieldWidget<T>` sobre `RawAutocomplete`, compondo
o `TextFieldWidget` existente com foco externo opcional. Não conhece Expense ou
rede. Um controller interno sincroniza valores com o controller emprestado;
renovar o motor nativo ao recuperar foco/concluir composição preserva o campo
por GlobalKey, sem editar artificialmente o texto ou recriar a cada tecla. O campo
padrão não força o encerramento de composição IME. Recursos externos não são
descartados e trocas de controller/foco transferem listeners.

GET/POST/PATCH/DELETE usam o endpoint relativo `collections/expenses/records`, ID
codificado no caminho, JSON plano, descrição original e centavos inteiros.
Criação lê `pocketBase.userId()` a cada operação, rejeita ID nulo/vazio ou só com
espaços e envia `owner` original, categoria selecionada, valor, descrição e data.
Ausência de identidade propaga `MissingAuthenticatedUserException` do core,
preservada por ExpenseBloc como falha esperada, sem conversão local no repository.
O contrato recebe `ExpenseCategoryEnum`, com `.other` como padrão na criação;
infrastructure serializa seu `value` no JSON do PocketBase. O Bloc encaminha a
seleção do evento, usando `.other` na criação quando ausente, e preserva a entidade
confirmada pela API, sem recategorização otimista.
Não grava storage nem envia timestamps administrativos. Falhas na leitura de
identidade propagam sem HTTP ou sucesso. Atualização envia somente valor, descrição, categoria e data
fornecidos, sem trocar proprietário ou normalizar o formulário. Categoria ausente
é omitida do PATCH; `.other` explícito é enviado como `other`. Criação preserva a
data civil fornecida e usa o dia atual somente quando ausente, mantendo o contrato
existente. A codificação é `YYYY-MM-DD 00:00:00.000Z`, sem converter fuso. O DTO lê
o record plano e devolve uma data civil local pelos componentes UTC retornados,
sem `toLocal()`. Exclusão usa o sucesso nativo do SDK, sem exigir exatamente 204.
Mutações confirmadas notificam o widget mensal pelo client compartilhado; falhas
remotas ou de parsing não notificam. O repository não gerencia sessões, inclusive
em HTTP 401; não captura snapshots nem limpa o AuthStore.

Listagem preserva ordem, filtros opcionais e fallback de pageSize não positivo
para 30. Usa `page`/`perPage`, `sort` padrão `-occurred_on,-id` e uma expressão
`filter` com categoria e limites civis escapados. O fim inclusivo usa `<` à
meia-noite do dia seguinte; não há complementação de limites ausentes.
O contrato recebe `int page = 1`; infrastructure mapeia os records do `getList`
e deriva `int? nextPage` de `page`/`totalPages` do SDK. `ExpensePageEntity` contém
somente itens imutáveis e o número da próxima página. Não há DTO próprio de página,
URLs de continuação, parsing de query ou reconstrução de links. ExpensesBloc mantém
os filtros e os envia em cada página; refresh volta à página 1. Os previews e a
Dashboard consomem o mesmo contrato puro, sem tipos do SDK.

`AmountValueObject.create` retorna o valor diretamente e rejeita centavos não
positivos com `ArgumentError`, preservando igualdade por centavos e sem dependência
de erros de aplicação. DTOs devolvem entidades diretamente. Respostas inválidas
(casts, datas, categorias ou centavos não positivos) propagam sem virar falha
esperada ou página parcial. Defaults de metadados/itens ausentes da lista seguem o
SDK; não há fallback para data/categoria inválidas de um record. Erros HTTP são
convertidos por `PocketBaseMapper`, preservando ordem, mensagens, status, code,
pointer e parameter em `ExpenseException`; transporte usa fallback seguro.
Error/FormatException encapsulados pelo SDK e falhas inesperadas propagam sem
catch genérico.

`ExpenseBloc`, em `presentation/screens/expense/bloc/`, substitui consulta,
criação e atualização. Estados sealed distinguem inicial, consulta, dados prontos,
submissão e suas falhas/sucesso. Consultas usam `restartable`: o ID mais recente
vence. Submissões são filtradas por `canSubmit` antes de `restartable`: intenções
durante envio são descartadas sem invalidar o handler ativo; trocar o contexto
do formulário permite substituir um handler obsoleto ainda pendente. Sucesso
bloqueia novo envio, exceto criação contínua explicitamente solicitada por hold.
Falhas preservam a entrada e permitem retry manual. Uma troca de ID invalida o
resultado da submissão anterior, sem cancelar a operação remota.

`ExpenseScreen` possui a factory estável `bloc: inject<ExpenseBloc>`, cria em
`initState`, fecha no descarte e substitui somente quando a factory muda.
Erro de consulta usa `ErrorScreen` e retry. O formulário mantém controllers,
validação, trim da descrição, centavos, data civil e estado dos pickers; não fecha
o Bloc recebido da tela. `BlocConsumer` renderiza loading e entrega efeitos únicos:
400 PocketBase e 422 legado por pointer conhecido vão ao campo; os demais erros
vão ao toast. Sucesso
contínuo limpa o formulário somente após confirmação remota. A navegação fica nos
widgets responsáveis, pelas extensões de `BuildContext`, sem callbacks de entrada
em `ExpenseScreen` ou `ExpenseFormWidget`: voltar faz `pop`, edição devolve a
entidade confirmada por `pop(expense)` e criação faz `pop(expense)` quando
`returnToPrevious` é verdadeiro, ou `navigate` para Dashboard nos demais casos.
`ExpenseScreen` e `ExpenseFormWidget` não recebem `onExpensesChanged`; a Dashboard
aguarda o resultado tipado da rota e atualiza somente se uma entidade confirmada
for retornada. Após cadastro contínuo, voltar pelo botão ou pelo sistema devolve
a última entidade salva, derivada do estado do Bloc, inclusive se a tentativa
seguinte falhar ou estiver pendente. Sair sem salvar não sinaliza alteração;
consulta de edição não é confundida com mutação. Não há cópia local do resultado
ou store global para comunicar a mudança.

`ExpensesBloc`, em `presentation/screens/expenses/bloc/`, possui os snapshots
imutáveis de lista, filtros, continuação e estados de execução. Refresh/filtros
usam `restartable` e revisão para invalidar páginas antigas. Paginação descarta
novas intenções enquanto há operação ativa, mas uma página de uma consulta nova
pode substituir uma página obsoleta ainda pendente. Os links permanecem opacos;
IDs repetidos são deduplicados, com ordenação estável por data civil decrescente.
Falha de página preserva itens e continuação para retry manual. Retorno da edição
atualiza a lista ou remove o item quando deixa de corresponder aos filtros.
`ExpensesScreen` não recebe callbacks de navegação ou de alteração. Seu mixin
abre a edição por `context.pushNamed<ExpenseEntity>` e volta por `context.pop`.
Os argumentos da rota de listagem contêm somente período e categoria. Dashboard
e o card de categoria de Metrics aguardam o retorno da listagem e recarregam suas
consultas, inclusive ao voltar sem alterações, evitando interceptar o botão do
sistema ou o gesto de retorno para transportar um sinal de mudança.

Exclusão usa `droppable`, bloqueia consultas/mutações concorrentes e remove o item
somente quando o contrato conclui. Falha mantém o item e permite nova confirmação.
Se os filtros externos mudarem durante a exclusão, somente a última intenção fica
pendente e é consultada depois da mutação, sem sobrepor leitura e escrita.
O mixin da listagem possui somente scroll, diálogo de confirmação e navegação de
edição; não mantém cópia local dos dados ou do loading. Factory, filtros e descarte
invalidam retornos de diálogos/edições antigos. A tela é dona do fechamento do Bloc.
Os Blocs preservam `ExpenseException.errors`, reportam inesperadas por `addError`
com fallback seguro e verificam fechamento/handler invalidado antes de publicar.
Isso não cancela HTTP ou desfaz mutações já iniciadas.

Recadastro por long press ou ação semântica usa `ExpensesBloc` →
`IExpenseRepository.create`, sem chamar o Bloc/formulário de cadastro ou importar
Root/Metrics. A UI captura a data local ao confirmar e o evento a representa como
meia-noite UTC pelos componentes civis, sem conversão de fuso. Copia descrição,
centavos e categoria, inclusive `other`, sem reutilizar o ID nem alterar o original.
`droppable` e `isBusy` bloqueiam submissões e outras mutações simultâneas; consultas
durante o POST aguardam a conclusão, preservando somente a última intenção.
A criação invalida páginas obsoletas pela revisão e, após sucesso, solicita a
primeira página com os filtros preservados. Falha desse GET é falha de consulta,
nunca falha/retry da criação confirmada. Identidade ausente preserva a exceção
esperada compartilhada do core, sem limpeza própria de sessão ou telemetry.

`ExpenseReregistrationWidget` recebe o Bloc da listagem sem possuir seu fechamento.
Reutiliza o scaffold e botões compartilhados; loading e bloqueio de back derivam
do estado do Bloc, com drag/barreira desabilitados na rota modal. Seu listener
fecha somente a bottom-sheet atual pelo Navigator local (o `context.pop` do Modular
7.1.1 prioriza páginas declarativas). O mixin aguarda esse retorno para mostrar
um único toast de sucesso/falha com mensagens locais do formatter de Expense.
O ID da confirmação aberta é apenas coordenação visual, não cópia de dados ou
loading. A atualização do widget mensal permanece no repository existente.

O módulo registra os dois Blocs por factory, sem commands ou data source. Previews
usam factories estáveis ou `PreviewResourceWidget` como único dono do recurso.
Testes unitários de Bloc cobrem concorrência, retry e fechamento; o teste de
módulo verifica bindings e repository real sobre HTTP mockado. Testes de UI
e flows de criação/listagem/exclusão foram removidos.

Dashboard agora compõe somente resultados diretos de User, Metrics e
Expense, sem Either. Uma falha no histórico continua sendo desconhecimento do
limite inicial, não um histórico vazio confirmado. Falhas esperadas isoladas nas
seções preservam a `ErrorsEntity` mesmo envolvidas em `ParallelWaitError`.
Previews e testes consumidores usam entidades/resultados diretos.

Os estados vazios de Dashboard e da listagem de Expense usam `EmptyStateWidget`
do core, um componente puramente visual configurado por ícone, título e descrição
opcional. Cada tela fornece o espaço restante com `SliverFillRemaining`, mantendo
rolagem, refresh e expansão para textos ampliados. O componente não conhece Bloc,
repositories, filtros, ações ou rotas; não possui controllers nem lifecycle próprio.
Dashboard deriva `isEmpty` somente de fase pronta, lista vazia e total mensal zero;
`hasNoExpenseHistory` só é verdadeiro após sucesso vazio do histórico e é preservado
no refresh de perfil. Na listagem, `isEmpty` exige leitura concluída, ausência de
itens e de continuação, em estado pronto ou exclusão confirmada; `hasFilters` apenas
deriva a presença de filtros. Falhas e operações pendentes não viram estados vazios.

Verificação da migração de Expense para PocketBase (03/11/2026):
`flutter pub get` concluído; `flutter analyze` sem issues após corrigir a posição
de um import novo; verificação focada com
`flutter test test/architecture test/features/expense test/features/dashboard test/app_module_test.dart test/features/core/infrastructure/clients/http/interceptors/session_interceptor_test.dart --reporter failures-only`
com 336 testes aprovados; `flutter test --reporter failures-only` com 821 testes
aprovados; `git diff --check` sem problemas. Os testes usam clients mockados ou
transporte simulado, sem homologação real de autorização ou persistência.
`dart run tool/widget_preview.dart` compilou e serviu o catálogo; encerrado por
timeout de 45 segundos sem cliente conectado, sem validação visual manual.
Naquela etapa, Dashboard e Metrics ainda não haviam sido migradas; o endpoint de agregações permanecia
incompatível com o PocketBase atual. Sem alteração no schema/runtime do backend,
migração de dados ou deploy. Alterações paralelas em três widgets visuais do core
foram preservadas fora do escopo desta tarefa.

### Clients Compartilhados

`main.dart` aguarda `createDependencies` de `lib/factory.dart` antes de `runApp`.
`createDependencies` configura o observer e aguarda `PocketBaseFactory.create`,
que cria `FlutterSecureStorage` e lê a sessão persistida.
`createAppModule` encaminha somente o SDK pronto a `createCoreModule`, que
registra `PocketBase` por `addInstance`, sem expor storage na DI.
Os repositories recebem o SDK diretamente,
sem Future de inicialização. A leitura segura bloqueia a montagem visual do app;
falhas propagam antes de montar o ModularApp, sem limpar credenciais, presumir
ausência de sessão ou tentar novamente automaticamente. Não há tela de retry
de inicialização nesta etapa.
Não há singleton global estático nem wrapper dos métodos de coleção.

`BASE_URL` padrão: `https://pocketbase.cordato.cloud`. O SDK acrescenta `/api/` aos
endpoints. A factory passa a configuração diretamente ao SDK, sem validação ou
normalização próprias. Configure a raiz do PocketBase, sem o sufixo `/api/`.

O SDK configura o header de autenticação a partir do token válido do AuthStore.
Não foram reintroduzidos logging HTTP, refresh automático, retry ou o antigo
SessionInterceptor. Não use o SDK compartilhado para destinos externos nem
registre tokens, RecordAuth, AuthStoreEvent, senhas ou URLs com token em logs.
O transporte usa o lifecycle padrão do SDK, sem conexão persistente compartilhada.

`PocketBaseFactory` aguarda a leitura segura e fornece seu conteúdo inicial ao
`AsyncAuthStore` oficial, com callbacks de gravação e exclusão diretamente por
`FlutterSecureStorage`. Não há `IStorageClient`, wrapper de storage ou consumidor
do storage legado em Expense.
Não há classe AuthStore própria, fila própria ou bind separado de autenticação.
O SDK serializa token e usuário nas propriedades `token` e `model` de um JSON
único na chave `@cordato.pocketbase_auth`; chaves e formatos anteriores não são
migrados. A restauração não valida a sessão no servidor. Falhas da leitura inicial
propagam; o parsing dos dados persistidos segue o comportamento padrão do SDK.

Por simplificação explicitamente aprovada, a memória e o stream `onChange` são
atualizados antes de concluir as operações assíncronas de storage. `save` e `clear`
retornam void; não há Future `persistence` ou rollback. Aguardar autenticação não
confirma gravação durável, e limpar a sessão em memória não confirma exclusão
durável. Falhas dos callbacks de escrita/exclusão são assíncronas e não propagam
ao Future de autenticação. Essas semânticas substituem as garantias anteriores
de espera do login/logout; não as apresente como preservadas pelo SDK.

A fila interna do SDK serializa persistência, não requests remotos. Authentication
e Session foram migradas sem alterar contratos de application, Blocs, telas ou
rotas. Seus repositories recebem o PocketBase inicializado, sem HTTP próprio,
storage direto ou DTOs de sign-in/refresh. Authentication delega às operações
nativas do SDK; cadastro não cria sessão, logout usa `authStore.clear()` e troca
de senha usa o ID do auth record. O logout pós-troca continua pertencendo ao Bloc.
Os repositories adotam a semântica de sucesso do SDK, sem conferir novamente
status 200/204 específicos que os métodos tipados não expõem.

`PocketBaseMapper` converte `ClientException` para `ErrorsEntity`, preservando
status real, ordem e code dos campos, pointer escapado e parameter original.
Falhas sem status recebem fallback seguro; Error e FormatException encapsulados
pelo SDK são propagados. A apresentação continua usando suas mensagens locais.

Session consulta presença no AuthStore e valida no servidor por `authRefresh`.
O método é chamado diretamente no PocketBase compartilhado e faz auto-save nativo.
Por simplificação aprovada, não há client temporário nem proteção contra respostas
tardias: sucesso pode sobrescrever logout ou novo login, e HTTP 401 limpa o AuthStore
atual. Requests simultâneos compartilham o mesmo Future de refresh; não há retry
automático. HTTP 403 e falhas de rede preservam o AuthStore e lançam SessionException,
inclusive quando tardios. Parsing/defaults seguem o SDK sem validação adicional de
token/ID; o retorno consulta a presença local do token por `hasSession`.
A observação usa `authStore.onChange` e sua
assinatura é cancelada pelo lifecycle já existente do SessionBloc.

Os repositories de todas as features usam agora o SDK. Os testes do core também
foram adaptados à factory sem parâmetro de storage e ao observer atual. A leitura,
escrita e exclusão seguras são simuladas no canal do plugin; o HTTP usa
`http.runWithClient` com `MockClient`, sem servidor local ou mudança da factory
de produção. Testes de logs usam lifecycle, eventos e falhas reais dos Blocs,
preservam as verificações de privacidade e restauram o observer global. O mock
órfão de `IStorageClient` foi removido, sem restaurar seu contrato legado.
Testes de comportamento das features foram preservados. Por solicitação explícita,
testes exclusivos de HTTP/Dio, incluindo os cenários de transporte de Session e
User, e seus mocks/fakes foram removidos. A cobertura atual verifica os contratos
do SDK e as semânticas de sessão descritas aqui, não as antigas garantias de
persistência/isolamento do client removido. Os testes arquiteturais não foram enfraquecidos.
Os testes de Authentication/Session foram migrados para o SDK real com transporte
mockado por `package:http/testing.dart`, dependência somente de desenvolvimento.
Não há rede real, testes de UI ou restauração da abstração HTTP antiga. Foram
incluídos testes de DI isolada e composição Authentication/Session pelo AuthStore.
User também usa o SDK real com transporte mockado, incluindo DI isolada,
conversão estrita, metadados dos erros, preservação da sessão em 401 e observação de exclusão
por Session. Contratos, Blocs, telas, previews e ownership permanecem preservados.
Expense também usa o SDK real com transporte mockado, com DI isolada, CRUD,
filtros civis, categorias, sugestões, erros nativos e notificações ao widget.
A paginação foi simplificada para números com seus contratos, consumidores,
previews e testes; os cenários antigos de links foram substituídos pelos de página.
Metrics também usa SDK real com transporte mockado, preservando meses completos,
parsing estrito do envelope, centavos textuais, agregações remotas, erros nativos
e publicação do widget com a revisão capturada antes do HTTP. O contrato, Blocs,
telas e previews permanecem. DI isolada e composição global passam sem visitar
rotas irmãs. A análise e a suíte Flutter completas passam; isso não representa
build nativo ou homologação do PocketBase real.

## Composição, Rotas E Bootstrap

O bootstrap instala `Observer`, baseado em `TalkerBlocObserver`, somente
em debug e antes da criação dos Blocs. Ele recebe uma instância de Talker criada
localmente em `lib/factory.dart`, sem logger global ou wrapper de client. Registra
criação, fechamento, tipos de eventos e transições, sem imprimir
o conteúdo de eventos ou estados. Erros inesperados registram somente o tipo e
stack trace, sem a mensagem potencialmente sensível. Não há logs de change
duplicando transições nem instalação do observer em profile/release.

Módulos usam `createModule` do Modular 7, pertencem à feature e registram
interfaces para implementações. Authentication e Expense têm um módulo por
feature sem path: repository, validators, factories e rotas no mesmo registro.
Não fragmente em módulos dependencies/form/list/routes para resolver a DI.
Os endpoints são URLs completas de `RouteEnum`; o root continua compondo os
módulos sem alterar os caminhos públicos.

O padrão para estado de página novo ou explicitamente migrado é `provide` com
`BlocScopedExtension.addBloc`, em `core/presentation/extensions/`. A extension
aceita `Function constructor`, preservando tear-offs com dependências obrigatórias
resolvidas pelo injector, e delega stream/fechamento a `addStreamable`.
Não cria BaseBloc, repository intermediário ou store global.

```dart
context.route(
  RouteEnum.authenticationSignIn.path,
  provide: (scope) => scope.addBloc<SignInBloc>(SignInBloc.new),
  child: (context, _) => SignInScreen(
    bloc: context.read<SignInBloc>(),
    emailValidation: inject<EmailValidation>(),
    passwordValidation: inject<PasswordValidation>(),
  ),
);
```

O escopo da página é o único dono: cria uma instância por montagem, preserva-a
em rebuild e chama `close()` ao desmontar. A screen recebe a instância e mantém
`BlocBuilder`/`BlocConsumer` e listeners explícitos, sem fechamento manual ou
`BlocProvider(create:)` que assuma um segundo ownership. `context.read` neste
exemplo é a extensão do Modular; evite ambiguidade com extensões do flutter_bloc.
Testes e previews podem usar um escopo externo ou `PreviewResourceWidget` como
dono, sem tornar a screen dependente do roteador para renderizar.

Hoje Sign-in e `ExpenseSuggestionsBloc` usam esse padrão. SignUpBloc, ResendEmailBloc, CallbackBloc
e os demais Blocs de tela ainda são factories com ownership pelas screens;
SessionBloc permanece global e pertence a `AppWidget`. Não declare migração
completa nem altere outros lifecycles incidentalmente.

Módulos com `path` ativam binds por feature; módulos sem `path` registram
dependências root-owned compartilhadas. Um consumidor entre features não pode
depender de uma rota irmã ativa. Authentication e Expense não usam `path: '/'`:
no Modular 7.1.1, binds são indexados pelo path e features irmãs com o mesmo path
sobrescrevem registros. O módulo sem path evita colisão, disponibiliza o repository
para logout e preserva factories, sem tornar Blocs singletons. Perde-se o descarte
automático dos binds por saída da feature; telas ainda não migradas fecham seus
Blocs; os provides de Sign-in e sugestões fecham suas instâncias por página.
Outros módulos com paths exclusivos não foram reorganizados.

`test/app_module_test.dart` monta a composição real, verifica resolução sem
ativar rotas de Authentication/Expense e abre criação, edição, listagem e Settings.
Não confunda rotas registradas com DI funcional nem widget tests com E2E nativo.

Rotas definidas nas features e no catálogo:

| Rota                            | Destino                                                                           |
| ------------------------------- | --------------------------------------------------------------------------------- |
| `/`                             | AppScreen: aguarda validação inicial via auth-refresh quando há token persistido. |
| `/welcome`                      | Boas-vindas.                                                                      |
| `/authentication/sign-in`       | SignInScreen com Bloc.                                                            |
| `/authentication/sign-up`       | Cadastro.                                                                         |
| `/authentication/confirm`       | Espera/reenvio da verificação.                                                    |
| `/authentication/confirm-email` | Callback de confirmação por link.                                                 |
| `/dashboard`                    | Composição financeira.                                                            |
| `/settings`                     | Configurações.                                                                    |
| `/user` e `/user/edit`          | Perfil e edição de nome.                                                          |
| `/expense`                      | Criação sem ID ou edição com ID.                                                  |
| `/expenses`                     | Listagem paginada.                                                                |

Todos os destinos do catálogo estão registrados na composição atual.
Isso não comprova DI nem execução bem-sucedida no dispositivo.
Navegação nova usa extensões de BuildContext (`pushNamed`, `replace`, `pop`,
`navigate`) no widget responsável, não `Modular.to`. Sign-in não recebe callbacks
de navegação; `SignUpFooterWidget` substitui a rota diretamente pelo contexto.
Argumentos de rota contêm dados, não funções. A edição devolve `ExpenseEntity`
confirmada por `pop(expense)`. Listagem não recebe `onExpensePressed`,
`onBackPressed` ou `onExpensesChanged`; seu mixin usa o próprio `context`.
Dashboard e Metrics recarregam ao retornar da listagem, inclusive sem mutação,
sem flags de alteração transportadas pela rota e sem interceptar o voltar nativo.
Callbacks locais entre widgets de composição não são callbacks de rota.
Outros callbacks legados exigem migração conjunta de todos os consumidores.

Root contém `AppScreen`, o splash visual, e `AppWidget`, proprietário do
SessionBloc e das decisões globais de navegação. A abertura sem token resolve
ausência local; com token, aguarda auth-refresh e sua persistência.

`main.dart` inicializa o binding Flutter, aguarda `createDependencies` de
`lib/factory.dart` e monta ModularApp sem depender de serviços remotos. A factory
concentra a criação das dependências de bootstrap e configura o observer de debug;
os demais bindings permanecem nos módulos.
Não há client de crash reporting ou push remoto registrado
no core; os handlers padrão do Flutter e da plataforma são preservados.
`addError` usa o mecanismo de Bloc, sem envio automático a serviços externos.

Notificações locais foram removidas, incluindo client, plugin, botão da
Dashboard, permissão Android e configuração iOS.

## Interface, Dart E Previews

- Dart `^3.13.2`, primary constructors para declarações elegíveis, campos
  imutáveis com tipo explícito e `final`, preservando `const` e super parameters.
  Construtores com lifecycle exigem avaliação semântica, não conversão mecânica.
- Imports da aplicação usam `package:cordato/`; UI usa `material_ui`, não novos
  imports de `flutter/material.dart`. Imports Flutter especializados são válidos.
- Widgets novos são públicos, `final`, com sufixo `Widget` e arquivo próprio.
- Estado efêmero de entrada/animação fica local; execução e resultado ficam no
  Bloc. Controllers, timers e listeners possuem dono e descarte explícitos.
- Mixins de estado usam `on State<Widget>`; helpers usam seu próprio `context`.
  Mixins de lógica visual pura usam `on StatelessWidget`, sem lifecycle.
- Tema: `context.colors`, `context.typography` e `context.radius`; Material 3,
  Inter e localização pt-BR. Não duplique tokens ou extensões compartilhadas.
- Reutilize botões, fields, BounceWidget, ImageWidget e ErrorScreen do core.
  Assets são centralizados em AssetEnum e declarados no pubspec.
- Ícones explícitos usam `Icons` e `IconData` do Material, renderizados pelo
  `IconWidget` estático do core. O renderer é StatelessWidget e preserva tamanho,
  cores do tema e semântica, sem controllers ou callbacks pós-frame.
  Não há dependência de biblioteca de ícones animados nem scopes/listeners de
  pressão, hover ou teclado para disparar animações. O bounce compartilhado dos
  botões permanece independente da renderização estática dos ícones.
- Preserve rolagem, acessibilidade, texto ampliado e redução de movimento.
  Skeletons e imagens decorativas não duplicam mensagens semânticas.
- Previews usam `@CordatoPreview`, wrappers reais de tema/localização/toast e
  fakes de catálogo sem rede ou storage. Não importe mocktail em `lib/`.
- Previews respeitam o ownership do fluxo: Sign-in recebe uma instância de um
  dono externo; telas ainda não migradas continuam donas de sua factory. Recursos
  externos usam um único dono, como PreviewResourceWidget. `.widget_preview/` é local.
- Código novo não recebe comentários; decisões são registradas em Markdown.

### Cabeçalho Recolhível: Expense E Information

`CollapsibleHeaderWidget`, em `core/presentation/widgets/headers/`, é um sliver
opt-in baseado em `SliverPersistentHeader` fixado no topo. Seu delegate mantém
um único título, interpola tipografia/posição conforme o deslocamento e oculta
gradualmente a descrição. A expansão depende de retornar à região inicial da
rolagem, não de inverter o sentido do gesto. `HeaderWidget` e as telas fora de
Expense/Information permanecem inalterados.

O componente recebe o widget de navegação da feature, sem conhecer Modular,
Bloc, repositories ou resultados de operações. Não cria ScrollController,
AnimationController ou estado global. A matemática de progresso fica em
`CollapsibleHeaderTransition`, Dart puro em `core/presentation/animations/`, com
limites para overscroll e movimento reduzido. A preferência `disableAnimations`
seleciona os extremos da interpolação, sem animações intermediárias de título
ou opacidade. A rolagem nativa continua funcionando.

As extensões expandida e recolhida consideram largura disponível, tipografia,
direção do texto e TextScaler. Fontes grandes podem aumentar a altura da barra
compacta em vez de truncar o título. TextPainters temporários são descartados.
O título mantém uma única semântica de cabeçalho; a descrição deixa a árvore
semântica ao desaparecer. O fundo opaco acompanha o tema do Scaffold.
`expandedContentMaxWidth` limita opcionalmente a largura de título/descrição
expandidos, mantendo o alinhamento com uma coluna de leitura sem deslocar o
botão de voltar. O título recolhido usa a largura da barra superior.

Em Novo/Editar gasto, `ExpenseFormWidget` usa uma única
`CustomScrollView` com o cabeçalho e os campos em slivers. O botão de cadastrar,
cadastro contínuo ou atualizar continua fixo fora da rolagem. Campos, validação,
controllers de entrada, sugestões, Blocs e seus proprietários permanecem os
mesmos. O botão de voltar entrega o mesmo resultado que a barra anterior e o
PopScope da screen continua tratando o retorno do sistema. Durante carregamento
ou falha de consulta, a barra original fica fora do skeleton/feedback para
preservar o voltar. Arrastar mantém a dispensa de teclado já existente.

`ExpensesScreen` também usa o cabeçalho como primeiro sliver da listagem, sem
AppBar separado. Mantém seu ScrollController e listener de paginação, o
RefreshIndicator com rolagem sempre disponível, a remoção de filtros com retorno
ao topo, os agrupamentos por data, as ações de edição/exclusão e os estados de
carregamento, falha e vazio. Os chips de filtro permanecem abaixo do cabeçalho
e rolam com os itens; somente o cabeçalho é fixado. Seu voltar continua usando
o mesmo handler local, sem callbacks novos nos argumentos da rota.

Não se adiciona espaço artificial para forçar o recolhimento. Se os campos e o
cabeçalho cabem na tela, o título permanece expandido; a progressão está limitada
à rolagem efetivamente disponível. Termos, Privacidade e Ajuda também adotam o
componente pelo `InformationPageWidget`, permitindo validar o movimento com
conteúdo naturalmente longo. A seleção de texto, a largura máxima de leitura,
o acesso público e o comportamento dos accordions permanecem preservados.
Testes unitários cobrem progresso, reversão, opacidade, mudança de extensões e
movimento reduzido, sem montar UI. Previews manuais incluem os extremos, temas,
fonte ampliada, largura reduzida, formulários em tela baixa, carregamento e
Information em telas baixas/largas e com movimento reduzido.
Validação visual em dispositivo, teclado real e aprovação do movimento continuam
necessárias antes de expandir o padrão a outras telas.

## Arquitetura Dos Testes

Testes espelham a produção e validam comportamento observável. A referência é
a suíte de Authentication/Sign-in, não os testes legados de commands/data sources.

```text
test/
  architecture/
  features/<feature>/
    domain/
    application/exceptions/
    infrastructure/repositories/
    infrastructure/responses/
    presentation/screens/<screen>/
      bloc/<screen>_bloc_test.dart
  support/<feature>/
    mocks/
    fakes/
```

### Contratos, Repositories E Clients

Application testa comportamento das exceções, como identidade dos erros
transportados; não precisa de implementação falsa de regra só para preencher
uma camada. Domain testa invariantes e tipos puros sem UI ou adapters.

Repositories migrados são testados com SDK real e transporte mockado via
`package:http/testing.dart`. Verifique payload exato, ausência de normalização,
parsing, erros nativos, metadados, defeitos inesperados e concorrência de sessão.
Sign-in atualiza o AuthStore e sign-out limpa sua memória sem HTTP; a persistência
não é aguardada pelo SDK. Factory/bootstrap testam leitura segura com storage
mockado e Futures controlados.

DTOs próprios ainda existentes têm testes de contrato JSON e parsing inválido.
Os DTOs de sign-in/refresh e o client HTTP próprio foram removidos, sem restaurar
data sources ou abstrações de transporte para os repositories migrados.

### Bloc

Use `bloc_test` com mock do contrato de aplicação, não do HTTP. Cubra:

- Estado inicial e ausência de request automática.
- Sequência submitting/success e delegação exata dos parâmetros.
- Mesma ErrorsEntity na falha esperada, inclusive vazia, sem reporte inesperado.
- Fallback e `addError` para falha inesperada, sem detalhes internos na UI.
- Envios duplicados ou diferentes durante request pendente descartados.
- Bloqueio depois do sucesso e retry somente após intenção manual em falha.
- Fechamento durante sucesso, falha esperada ou inesperada pendente sem estado tardio.
- Independência de instâncias pertencentes a telas diferentes.

Controle pendências com Completer e sinais do stream; não use sleeps arbitrários
para provar ordenação. Cancele toda subscription e feche os Blocs criados pelo teste.

### Limite Da Suíte

O projeto não mantém testes de UI: telas, widgets, goldens, integração visual
ou Maestro. Os flows, scripts auxiliares e servidores de fixtures foram removidos.
Não adicionar Python ao projeto. Previews continuam como ferramenta manual,
não como validação automatizada.

Preserve testes unitários de lógica de apresentação, incluindo Blocs,
validadores, formatadores e extensões. Debounce usa `fake_async`, sem montagem
de widgets. Testes de módulos verificam catálogo, resolução de dependências
e independência de factories sem renderizar telas. Não comprovam navegação
nativa, aparência, acessibilidade ou lifecycle visual.

### Doubles E Fixtures

Use mocktail; cada mock, fake ou adapter público tem arquivo próprio sob
`test/support/<feature>/mocks/` ou `fakes/`. Não declare classes auxiliares em
`*_test.dart`, não use barrels e não coloque suporte de teste em `lib/`.
Reutilize o double por contrato, não suas instâncias mutáveis entre suítes.
Stubs, dados do cenário e teardown pertencem ao próprio teste.
Imports de suporte são relativos explícitos; produção usa `package:cordato/`.

### Testes Arquiteturais

O contrato desejado verifica imports de todos os contextos relevantes,
isolamento de domain/application, apresentação sem adapters e dependências
entre features. Scanners devem reportar arquivo, import e regra violada.
Ausência de feature planejada não é erro. DI exige testes próprios:
inspecionar strings de RouteEnum não prova resolução de dependências Modular.

A suíte atual ainda não garante integralmente esse contrato. Possui checks
Supabase/RPC históricos, helper que reconhece apenas contextos financeiros e
exceção específica para o contrato de Authentication em application. As listas
atuais incluem Dio, PocketBase e HTTP entre SDKs proibidos. Migrações devem atualizar os checks
para a regra geral de contratos de aplicação, não liberar infrastructure na UI.

## Estado Atual E Migração

O repository e o contrato de Authentication já seguem o novo desenho.
Sign-in, Sign-up, reenvio e callback têm Bloc, estados sealed e testes unitários.
O módulo de Authentication possui teste próprio de DI do callback, sem montar UI.
Os fluxos de Authentication e a observação Session/Root usam o novo desenho;
isso não significa que todo o aplicativo esteja migrado ou componha seus destinos.

| Área                  | Situação encontrada                                                                                                                     |
| --------------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| Sign-in               | Bloc no `provide` da rota via extension do core; screen recebe instância sem fechar.                                                    |
| Cadastro              | SignUpBloc por factory, lifecycle da tela e confirmação por navegação de contexto.                                                      |
| Reenvio               | ResendEmailBloc por factory, cooldown e feedback no mixin da tela.                                                                      |
| Callback              | CallbackBloc por factory, latest-link-wins e navegação/feedback no listener da tela.                                                    |
| Logout                | LogoutBloc em Settings, contrato de Authentication e navegação global por sessão preservada.                                            |
| Session               | Contrato em application, repository direto em infrastructure e SessionBloc contínuo.                                                    |
| User                  | Contrato/repository migrados; perfil, avatar e exclusão com UserBloc; edição de nome com EditBloc; sem commands.                        |
| Metrics               | Contrato em application, repository direto em infrastructure e ExpenseMetricsBloc por factory, sem Either/data source/commands.         |
| Insight               | Removido do aplicativo, incluindo composição, seção da Dashboard, previews e testes próprios.                                           |
| Expense               | ExpenseBloc e ExpensesBloc por factory; CRUD, cadastro contínuo, filtros e paginação; sem Either/data source/commands.                  |
| Dashboard             | Bloc agregado sobre contratos de aplicação e resultados diretos dos contextos consultados, sem Either.                                  |
| Bootstrap e Root      | AppWidget é dono do SessionBloc; AppScreen apenas visual; handler CommandIt removido do bootstrap.                                      |
| Dependências/core     | CommandIt, Either, Dio e client HTTP/storage próprios removidos; testes do core alinhados à factory PocketBase e ao observer atuais. |
| Composição global     | Todos os destinos registrados; Authentication e Expense sem path, sem colisão de binds; logout resolve o contrato no injector raiz.     |
| Navegação de despesas | Contexto local e resultados tipados na edição; listagem sem callbacks de rota; consumidores recarregam em qualquer retorno da listagem. |
| Testes de UI          | Removidos, incluindo Maestro, scripts e servidores de fixtures; previews manuais preservados.                                           |

Última verificação registrada da migração do client: `flutter analyze` sem
problemas e `flutter test --reporter failures-only` com **1401 testes aprovados**.
Não repetida nesta revisão exclusivamente documental; não comprova build nativo
ou homologação remota. Resultados das etapas anteriores são históricos.

Verificação histórica após remover a suíte visual: `flutter pub get` concluído,
`flutter analyze` sem problemas e `flutter test --reporter expanded` com
**733 aprovados, sem falhas**. O teste de conversão de erros de autenticação
agora exige a ordem original da resposta. Os testes de debounce do Bloc de
sugestões usam `fake_async`, sem UI. Nenhum código do aplicativo foi alterado.

Verificação histórica após consolidar Authentication e Expense sem path,
anterior à remoção dos testes de UI:
`flutter analyze` sem problemas; `flutter test` com **917 aprovados, sem falhas**.
O teste global de logout antes pendente passou; novos testes cobrem os binds
root-owned e a abertura real de cadastro, edição, listagem e Settings em widget.
O launcher de previews compilou/serviu sem cliente conectado e atingiu timeout;
isso não valida visualmente o catálogo. Nenhum E2E foi executado.

### Histórico De Verificações

Os resultados abaixo registram etapas anteriores, não o estado atual da suíte
ou da composição. Referências a commands, rotas desativadas e bloqueios já
resolvidos não constituem instruções para restaurar o desenho antigo.

Após a revisão de testes e a migração do Firebase Messaging para registro por
FID, a suíte completa passou com 907 testes, incluindo 10 de arquitetura e 15 do
MessagingClient. `flutter pub get` e `flutter analyze` concluíram sem problemas.
Build, entrega real de push e navegação E2E não foram validados.
Não restaure dependências antigas apenas para esconder
a migração incompleta; também não declare comportamento de módulo desativado
como disponível no app em execução.

Os registros a seguir descrevem resultados históricos das migrações, anteriores
à revisão da suíte completa acima.

Na migração de Sign-up, `flutter pub get` concluiu e o lote focado de arquitetura,
application/infrastructure de Authentication, validators e telas Sign-in/Sign-up
passou (120 testes). `flutter analyze` e `flutter test` completos continuam
bloqueados pelos consumidores legados de CommandIt, `Either` e `response<T>`;
o módulo atual compõe cadastro com factory, mas não corrige a composição global.

Na migração de Resend-email, `flutter pub get` e a análise focada da tela/Bloc e
seus testes concluíram sem problemas. O lote focado acima, incluindo reenvio,
passou com 143 testes (23 novos). `flutter analyze` global encontrou 568 problemas
nos consumidores legados; `flutter test` completo também falhou por essas
dependências removidas. A migração não altera callback, logout ou composição global.

Na migração de Callback, `flutter pub get` concluiu e a análise focada do módulo,
da tela/Bloc e dos testes passou sem problemas. O lote focado de arquitetura e
Authentication passou com 172 testes, incluindo 29 novos de callback/DI/rotas.
A fixture local passou em verificação HTTP de 204, 403, 500, URL completa,
retenção/liberação e isolamento de endpoints. `flutter analyze` global continua
com 564 problemas legados e `flutter test` completo falha por referências
removidas, como `Either` e CommandIt. Nenhum flow Maestro foi executado em dispositivo.

Na migração de Logout, `flutter pub get` concluiu e a análise focada de Settings,
seus testes e o check arquitetural passou sem problemas. `flutter test
test/architecture test/features/authentication test/features/settings` passou com
195 testes, incluindo 23 novos de Logout/Settings. O teste de módulo verifica
factories independentes e a espera da revogação remota seguida de `storage.clear`.
A fixture passou em verificação HTTP de login, erro remoto, sucesso, retenção/
liberação e Bearer. A análise global permanece bloqueada pelo legado, assim como
`flutter test` completo. `LogoutCommand` e a dependência cruzada de apresentação
foram removidos; Authentication não usa mais commands, mas Session/Root e demais
features permanecem em migração. Os flows E2E de logout não foram executados.

Na migração de Session, `flutter pub get` concluiu e a análise focada de Session,
Root, bootstrap/composição e seus testes passou sem problemas. O lote de
arquitetura, Authentication, Settings, Session, Root e storage passou com 250
testes, incluindo 49 novos de Session/Root. A verificação adicional de
`session_interceptor_test.dart` foi bloqueada pelo import legado de Expense que
ainda depende de `Either`. A análise global encontrou 550 problemas, inclusive
testes do handler CommandIt removido e consumidores antigos de `Either`/
`response<T>`; `flutter test` completo também falhou. Não houve execução E2E em
dispositivo. Os caminhos dos subflows/scripts novos foram conferidos, o que não
constitui validação de sintaxe ou execução Maestro.

Na primeira rodada de User, `flutter pub get` concluiu e a análise focada de
domain/application/infrastructure e seus testes passou sem problemas. Os testes
focados cobrem payload, parsing, ID, erros HTTP e propagação de falhas inesperadas,
além da ordem/espera da exclusão e limpeza. O comando `flutter test
test/architecture test/features/authentication test/features/settings
test/features/session test/features/root test/features/user/application
test/features/user/infrastructure test/features/user/domain` passou com 289 testes.
A análise e a suíte globais continuam
bloqueadas por `Either`, `response<T>` e CommandIt nos consumidores legados;
os testes dos commands de User e de Dashboard foram adaptados, mas sua execução
continua bloqueada por essas dependências. Nenhum E2E foi executado nesta rodada.

Na segunda rodada de User, `flutter pub get` concluiu. A análise focada da tela,
Bloc, preview e testes passou sem problemas. O lote focado da primeira rodada,
acrescentando `test/features/user/presentation/screens/user`, passou com 344 testes
(55 adicionais, incluindo 32 de Bloc, 22 de tela e um check arquitetural).
`flutter test test/features/user/user_module_test.dart` foi executado e bloqueado
na compilação por CommandIt da rota `edit`, não por um teste de DI aprovado.
A análise e a suíte globais também continuam bloqueadas pelo legado. Foram removidos
somente os cenários obsoletos de UserCommand do teste do handler CommandIt legado;
erros esperados/inesperados de User agora são verificados pelo mecanismo do Bloc.
A fixture de User passou em verificações HTTP locais de perfil, avatar, respostas
401/422/503, exclusão 204, liberação e isolamento de endpoints. Isso não valida
Maestro nem os seletores em dispositivo. Nenhum E2E foi executado nesta rodada.

Na terceira rodada de User, `flutter pub get` concluiu e a análise focada de toda
a feature, testes/suporte de User e check arquitetural passou sem problemas.
`flutter test test/architecture test/features/authentication test/features/settings
test/features/session test/features/root test/features/user` passou com 374 testes,
incluindo 11 de EditBloc, 18 de EditScreen e o teste composto de módulo anteriormente
bloqueado. O command e seus testes legados foram removidos; o check arquitetural
agora impede commands em todo User. A análise e a suíte globais continuam bloqueadas
pelo legado de outras features (`Either`, `response<T>` e CommandIt), sem novos
problemas identificados em User. A fixture compartilhada passou em verificações
HTTP locais de nome 422/200, perfil preservado, compatibilidade do avatar, Bearer
e retenção/liberação. Nenhum flow E2E foi executado em dispositivo.

Na simplificação de `delete` para `Future<void>`, `flutter pub get` e a análise
focada de User, seu suporte/testes e o preview consumidor de Dashboard concluíram
sem problemas. `flutter test test/architecture test/features/user` passou com
137 testes. Análise e testes globais foram executados e continuam falhando pelos
consumidores legados de outras features. Não houve execução E2E nesta alteração.

Na primeira rodada de Metrics, `flutter pub get` concluiu. A análise focada de
application/infrastructure/domain, fakes de preview, seus testes/suporte e check
arquitetural passou sem problemas. O comando `flutter test test/architecture
test/features/authentication test/features/settings test/features/session
test/features/root test/features/user test/features/metrics/application
test/features/metrics/infrastructure test/features/metrics/domain
test/features/metrics/presentation/extensions` passou com 456 testes. A cobertura
inclui filtros opcionais, datas civis, centavos grandes sem perda de precisão,
categorias, parsing inválido, erros HTTP, falhas inesperadas e espera da resposta.

Os testes de módulo/command de Metrics e do Bloc consumidor de Dashboard foram
executados, mas continuam bloqueados na compilação por CommandIt e pelo Either
dos demais contextos financeiros. A análise e a suíte globais também falham
nesses consumidores legados. Não foram restauradas dependências antigas nem
declarados DI, UI, previews ou E2E aprovados em execução nesta rodada.

Na substituição do command de Metrics, `flutter pub get` concluiu. `dart analyze`
de Metrics, testes/suporte, check arquitetural e dos dois previews consumidores
passou sem problemas. `flutter test test/architecture test/features/metrics`
passou com 106 testes, incluindo 14 de Bloc e o teste de módulo com repository
real sobre HTTP mockado. A análise global encontrou 334 problemas e `flutter test`
global terminou com 606 testes aprovados e 22 falhas, incluindo compilação legada
por Either/CommandIt/response, testes antigos de headers e referência não resolvida
a `userDependenciesModule` fora do escopo. Não houve execução visual dos previews
ou E2E; a Dashboard ainda importa os contratos financeiros legados.

Na primeira rodada de Insight, `flutter pub get` concluiu. A análise focada de
domain/application/infrastructure, fake de preview, testes/suporte e check
arquitetural passou sem problemas. `flutter test test/architecture
test/features/metrics test/features/insight/application
test/features/insight/infrastructure test/features/insight/domain` passou com 134
testes, incluindo 28 de Insight. A cobertura verifica filtros opcionais, conteúdo
e ordem, períodos, onboarding, lista vazia, parsing inválido, erros HTTP, falhas
inesperadas e espera da resposta.

Os testes de módulo/command de Insight e do consumidor Dashboard foram executados,
mas falharam na compilação por CommandIt e pelo Either ainda usado em Expense.
O teste novo do módulo não constitui DI aprovada enquanto o command o bloquear.
`flutter analyze` global encontrou 288 problemas; `flutter test` global terminou
com 626 testes aprovados e 21 falhas, incluindo bloqueios de compilação e os
testes antigos de headers. Não houve execução visual dos previews ou E2E, nem
restauração de dependências legadas. Nenhum Bloc foi criado em Insight nesta rodada.

Na segunda rodada de Insight, `flutter pub get` concluiu. `dart analyze
lib/features/insight test/features/insight test/support/insight
test/architecture/bounded_context_dependencies_test.dart` passou sem problemas.
`flutter test test/architecture test/features/metrics test/features/insight` passou
com 152 testes, incluindo 17 de InsightsBloc e o teste de módulo anteriormente
bloqueado, agora verificando factories independentes sobre repository real e
client HTTP mockado. O command e seus testes legados foram removidos; a regra
arquitetural impede commands em Insight. A análise global encontrou 284 problemas
fora de Insight; a suíte global terminou com 644 testes aprovados e 19 falhas,
incluindo compilação legada e testes antigos de headers. Não houve execução visual
dos previews ou E2E. Dashboard ainda depende dos contratos legados de Expense.

Na primeira rodada de Expense, `flutter pub get` concluiu. A análise focada de
application/domain/infrastructure, fakes de preview, Dashboard, testes/suporte
correspondentes, SessionInterceptor e check arquitetural passou sem problemas.
O lote abaixo passou com 380 testes, incluindo CRUD, parsing, erros HTTP,
paginação, centavos, datas civis, coordenação da Dashboard e autenticação Bearer:

```bash
flutter test test/architecture test/features/expense/application test/features/expense/infrastructure test/features/expense/domain test/features/expense/presentation/extensions test/features/expense/presentation/screens/expense/validators test/features/dashboard/presentation/screens/dashboard/bloc test/features/metrics test/features/insight test/features/core/infrastructure/clients/http/interceptors/session_interceptor_test.dart
```

`flutter analyze` global encontrou 75 problemas; `flutter test` global terminou
com 831 testes aprovados e 11 falhas. Permanecem bloqueados os commands, telas e
teste de módulo de Expense por CommandIt removido; testes antigos de response e
do handler CommandIt, headers e a referência `userDependenciesModule` também
continuam pendentes. A análise global ainda reporta um import não utilizado em
Insight fora do escopo. Os testes dos commands foram adaptados ao novo contrato,
não validados em execução. Não houve execução visual de previews ou E2E.

O código financeiro existente inclui formulário compartilhado de criação/edição,
listagem com paginação/filtros/gestos, métricas e insights na Dashboard, além de
perfil e avatar. São comportamentos a preservar durante migrações, não modelos
de camadas a replicar. Em particular:

- Preserve centavos, datas civis, filtros explícitos e continuações opacas.
- Preserve seleção mensal da Dashboard. Cadastro recarrega após resultado
  confirmado; listagem recarrega ao retornar, inclusive sem alteração.
- Preserve dados de entrada em falha e efeitos de sucesso únicos.
- Preserve ownership, rolagem, acessibilidade e proteção contra respostas obsoletas.

Migre por fluxo completo: contrato em application, repository em infrastructure,
resultados/exceções, Bloc e estados, screen/lifecycle, bindings e todos os testes
consumidores. Remova intermediários legados apenas quando não houver consumidores.
Não faça essa migração inteira incidentalmente em uma tarefa localizada.

## Verificação

Para alterações Flutter, execute quando aplicável:

```bash
flutter pub get
flutter analyze
flutter test
```

Verificações focadas:

```bash
flutter test test/architecture
flutter test test/features/authentication/infrastructure/repositories
flutter test test/features/authentication/presentation/screens/sign_in/bloc
flutter test test/app_module_test.dart
flutter test test/features/expense/expense_module_test.dart
flutter test test/features/metrics/presentation/bloc
flutter test test/features/authentication/presentation/screens/sign_up
flutter test test/features/authentication/presentation/screens/resend_email
flutter test test/features/authentication/presentation/screens/callback test/features/authentication/authentication_callback_module_test.dart
flutter test test/features/settings
flutter test test/features/session
```

Registre comandos, resultado e causa de bloqueios. Teste focado aprovado não
implica suíte ou app aprovados. Documentação pura pode ser revisada sem executar
Flutter; não invente resultado de análise, testes ou execução no dispositivo.

## Revisão De Documentação

- `ARCHITECTURE.md`: decisões, camadas, contratos, estado de migração e testes.
- `AGENTS.md`: regras operacionais para implementar e revisar essas decisões.
- `README.md`: produto, pré-requisitos, início rápido e limitações atuais.
- `android/README.md`: build, assinatura e verificação de release Android.
- `.opencode/skills/cordato-*/SKILL.md`: orientações locais alinhadas às regras.
- `openspec/README.md`: precedência, histórico e mapa de specs vigentes/legadas.

Mudanças estruturais atualizam os documentos afetados na mesma alteração.
Histórico de OpenSpec não substitui o código atual nem redefine estas decisões.
