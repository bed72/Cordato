# Cordato

Aplicativo Flutter de finanças pessoais e familiares.

Configurações inclui a tela “Pague-me um café”, em `/settings/support`, com
mensagem de apoio voluntário e QR Code Pix estático de valor livre na própria tela,
renderizado com `pretty_qr_code`. “Copiar Pix” copia o código para pagar no banco.
O título e a descrição rolam com o conteúdo, sem recolher ao lado do botão de voltar;
voltar, o card de apoio e “Copiar Pix” permanecem fixos.
O QR Code se adapta ao espaço disponível entre 144 e 220 pixels lógicos,
limitado também pela largura, para reduzir a necessidade de rolagem.
Telas menores e texto ampliado continuam permitindo rolar o conteúdo superior;
se o card exceder 60% da área acima do botão, seu texto pode rolar separadamente,
mantendo “Copiar Pix” acessível.
Não há confirmação de pagamento
ou consulta bancária no app; a chave e o destinatário exigem conferência no banco.

### Exportar despesas

Em **Configurações → Conta → Exportar despesas**, o app consulta todo o histórico
do próprio usuário e gera um CSV no dispositivo para o compartilhamento nativo
Android/iOS. Exige internet e a tela ativa durante a preparação; não há filtros,
dados de familiares/perfil, processamento em background ou seletor “Salvar como”.
Histórico vazio mostra um aviso; falhas permitem tentar novamente sem compartilhar
um arquivo parcial.

O CSV contém Identificador, Data, Descrição, Categoria e Valor (BRL), com UTF-8/BOM,
separador `;`, data civil `dd/MM/yyyy` e decimal com vírgula, sem perda por `double`.
Categorias usam os valores estáveis (`food`, `other`, etc.). Textos potencialmente
interpretados como fórmulas recebem proteção somente na cópia exportada.
A leitura paginada não é um snapshot transacional contra mudanças simultâneas.

Arquivos ficam no cache privado; parciais/abandonados são descartados. Anexos
entregues ao compartilhamento são conservados por pelo menos 24 horas enquanto o
cache existir e limpos em exportações posteriores, sem prazo exato de remoção.
Destinos dependem do sistema e dos apps instalados; o retorno do compartilhamento
não comprova entrega ou salvamento durável. Dados enviados a outros aplicativos
ficam fora do controle de Cordato.

Verificação desta funcionalidade: `flutter pub get`, `flutter analyze` sem problemas
e `flutter test --reporter failures-only` com **1531 testes aprovados**. Não houve
build nativo, conferência visual Android/iOS/iPad, abertura no Excel ou homologação
remota nesta implementação.

> Cada pessoa é dona dos próprios dados. A família é uma lente de leitura,
> nunca dona do dinheiro ou autorizada a escrever nos dados de outro membro.

## Client e verificação atual

**Repositories migrados; análise e suíte Flutter globais aprovadas.** A infraestrutura
agora usa o SDK oficial PocketBase 0.25.3, compartilhado por DI e com persistência
no `flutter_secure_storage`. Dio, talker_dio_logger e o client HTTP próprio foram
removidos. Authentication, Session, User, Expense e Metrics já usam o SDK compartilhado,
com testes de comportamento e DI migrados. `lib/` não referencia o HTTP/storage
removidos. Os testes do core foram adaptados à factory e ao observer atuais;
não houve build nativo ou homologação remota. Testes exclusivos do HTTP/Dio antigo
e seus mocks/fakes foram removidos por solicitação explícita.

`BASE_URL` passa a ser a raiz do PocketBase, por padrão
`https://pocketbase.cordato.cloud`, sem o sufixo `/api/`. A factory passa a URL diretamente
ao SDK, sem validação ou normalização próprias.
O bootstrap aguarda `createDependencies` de `lib/factory.dart`, que configura o
observer de debug e aguarda `PocketBaseFactory.create`. Esta cria o Secure Storage
e aguarda a leitura segura da sessão antes de `runApp`.
`createAppModule` e `createCoreModule` recebem somente o SDK
pronto; a DI compartilha um único `PocketBase` diretamente com os repositories.
Falhas de leitura propagam antes da montagem do app, sem limpeza de credenciais
ou retry automático; não há tela de retry de inicialização nesta etapa. A nova chave
`@cordato.pocketbase_auth` não importa sessões anteriores: será necessário login.
O `AsyncAuthStore` oficial persiste por callbacks de `FlutterSecureStorage`
diretamente na factory, sem adapter próprio. Expense não usa mais storage legado.
Mudanças de sessão em memória não aguardam escrita/exclusão segura; não há confirmação durável
de login/logout nem propagação dessas falhas ao Future de autenticação. Veja
[Clients Compartilhados](ARCHITECTURE.md#clients-compartilhados).

Authentication usa os métodos nativos para login, cadastro, verificação,
recuperação e troca de senha, mantendo os contratos da apresentação. Session
valida pelo endpoint nativo de auth-refresh via `send` e `RecordAuth` do SDK
compartilhado e observa o AuthStore. Refresh tardio não restaura logout nem
sobrescreve login novo: token, record e mudanças da sessão são verificados antes
de salvar ou limpar. Um 401 limpa somente a sessão de origem ainda atual.
Erros nativos preservam campos e status para
os formatadores locais. Essa etapa não altera UI, navegação ou backend.
Troca de senha lê a identidade por `pocketBase.userId()`, sem validação duplicada,
snapshots ou limpeza em 401. Ausência de identidade é falha esperada no Bloc;
o logout explícito permanece separado e ocorre após sucesso da alteração.

Configurações mantém somente “Sair”, pelo `authStore.clear()` nativo. Não há
saída global, endpoint customizado ou hook de logout. A limpeza local não revoga
cópias do JWT no servidor nem confirma exclusão durável no storage. A proteção
contra refresh tardio permanece no Flutter, sem alteração do backend ou deploy.

Verificação local: `flutter pub get`, `flutter analyze` sem problemas e
`flutter test --reporter failures-only` com **1629 testes aprovados**. Não houve
build nativo ou homologação remota.

User usa `getOne`, `update` e `delete` nativos com o ID do auth record atual,
sem storage próprio. Nome/avatar continuam mapeados para entidades puras.
O SDK atualiza o auth record na edição e limpa a sessão após excluir a conta
correspondente; Session observa essa limpeza sem confirmação durável do storage.
Erros de campo e 401 são mapeados no repository sem gerenciar ou limpar sessões,
sem alterar contratos, Blocs ou UI.

Expense usa CRUD e sugestões pelo SDK compartilhado, com `owner` do auth record
atual na criação. Listagem recebe número de página e retorna `nextPage`, sem URLs
ou parsing de query; filtros ficam no Bloc e são reenviados em cada página.
Centavos inteiros, categorias, datas civis e notificações ao widget são preservados.
Não há gestão de sessão no repository; falhas nativas são mapeadas e ausência de
identidade usa a exceção compartilhada do core.

Metrics consulta a view mensal pelo `PocketBase.send` nativo, sem wrapper. Essa
operação preserva o envelope bruto para rejeitar `items` ausente/nulo: os defaults
de `getList` não podem transformar resposta inválida em total zero. Mantém meses
civis completos, centavos textuais, agregações do servidor e sincronização mensal
do widget, sem gerir sessões ou alterar UI/navegação.

Última verificação registrada da migração, não repetida nesta revisão documental:
`flutter analyze` sem problemas e
`flutter test --reporter failures-only` com **1401 testes aprovados**. Os testes
da factory simulam o canal do storage e o transporte HTTP, sem servidor local;
os do observer verificam lifecycle e privacidade pelo fluxo real dos Blocs,
sem chamadas diretas a métodos protegidos. O mock órfão do storage removido foi
excluído. A correção dos testes do core não exigiu alteração de produção.
Não houve build nativo, execução visual ou acesso ao backend real.

### Histórico da migração do client

Os registros abaixo descrevem etapas anteriores, não pendências atuais do transporte.

Histórico da verificação de Metrics: `flutter analyze lib test/features/metrics` sem problemas;
`flutter test test/features/metrics test/features/dashboard test/features/root
test/architecture test/app_module_test.dart --reporter failures-only` com 345
testes aprovados. Naquela etapa, a análise global apontava 29 problemas em testes legados do core;
a suíte global teve 1381 aprovados e 4 falhas de carregamento nesses testes
(módulo core, observer, storage legado e factory PocketBase). Não foram alterados
nesta etapa. Não houve build nativo, execução visual ou acesso ao backend real.

Histórico da verificação de Expense e da paginação simplificada: análise focada sem problemas;
`flutter test test/features/expense test/features/dashboard test/architecture
--reporter failures-only` com 528 testes aprovados. `flutter analyze` global ainda
reporta 80 problemas em Metrics e testes legados do core. A suíte global teve 1314
testes aprovados e 7 falhas de carregamento em Metrics, core e composição global.
Essas pendências anteriores não foram alteradas nesta etapa; não houve build,
execução visual ou validação contra o PocketBase remoto.

Verificação da migração Authentication/Session: `flutter pub get` concluído;
320 testes focados (features, infraestrutura, DI e arquitetura) aprovados. A análise
focada não encontrou problemas. `flutter analyze` reportou 211 problemas nos
consumidores HTTP restantes. `flutter test --reporter failures-only` teve 1034
testes aprovados e 7 falhas de carregamento/compilação em User, Expense, Metrics
e composição global. Esses bloqueios decorrem da remoção anterior do HTTP próprio.
Não houve build do app nem homologação remota. O histórico abaixo
não representa uma verificação do estado transitório atual.

O teste isolado de `createCoreModule` controla a leitura do storage por
`Completer`: comprova espera pela restauração antes da composição, resolução
síncrona das mesmas instâncias e propagação da falha antes da montagem do módulo.

Verificação da composição com instâncias prontas: `flutter pub get` concluído;
320 testes focados de arquitetura, core, Authentication e Session aprovados.
`flutter analyze` e `test/app_module_test.dart` continuam bloqueados pelos imports
da infraestrutura HTTP removida em User, Expense, Metrics e testes legados.

As cinco falhas de contagem de palavras nas descrições de categorias de Expense
foram corrigidas, preservando a regra de cinco ou seis palavras. `flutter pub get`
e `flutter analyze` concluíram sem problemas; `flutter test --reporter failures-only`
passou com 1292 testes. Menções a essas falhas nas verificações abaixo são históricas.

## Barra inferior do sistema

A barra de navegação do Android é transparente, sem divisor ou fundo de contraste
solicitado pelo app. Dashboard, Despesas e páginas de informação permitem rolagem
por trás da barra e do indicador de início do iOS, com espaçamento final baseado
na área segura. Formulários, ações fixas e modais preservam suas áreas seguras;
a configuração da status bar superior não mudou. O app usa o edge-to-edge padrão
do Flutter para o target Android atual.

Verificação: `flutter pub get` concluído, `flutter analyze` sem problemas e
`flutter test --reporter failures-only` com 1292 testes aprovados. A conferência
visual em Android com gestos/três botões e iPhone permanece pendente.

## Widget da tela inicial

Android e iOS possuem um widget pequeno com o mês atual por extenso, o total gasto
nesse mês e a ação **+ Nova despesa**. O botão segue o DS: retangular com raio 14,
fundo primário, texto sobre primário e conteúdo centralizado. Sua altura é
adaptada ao espaço nativo; toda a área do widget continua clicável.
O mês começa com maiúscula, o valor tem peso bold e o conteúdo fica agrupado no
centro vertical, sem separar o resumo da ação nas extremidades. As cores
acompanham o tema do sistema. iOS oferece famílias pequena e média, com composição
vertical e horizontal, respectivamente.
No iOS, a ação preserva **+ Nova despesa**, com fonte de 13 pontos, altura de 44
e raio 14; no médio, sua largura é de 136 pontos.
Android permite redimensionamento nos dois eixos, com limites solicitados ao launcher. A partir
de 300dp de largura, quando mais largo que alto, o resumo e a ação ficam lado a
lado; formatos quadrados ou altos preservam a composição vertical agrupada.
Android solicita altura mínima de redimensionamento de 56dp para permitir uma
linha da grade. Abaixo de 150dp,
usa espaçamentos e botão menores e exibe apenas o mês no título; o launcher
continua decidindo os tamanhos finais segundo sua grade.
Na composição de uma linha (menos de 96dp), a moeda permanece junto ao número.
Se a largura também for menor que 300dp, a ação usa somente **+** em um botão
quadrado de 32dp, com as mesmas cores, raio de 8dp, ícone vetorial centralizado e 12dp de distância
do resumo. Os demais tamanhos preservam **+ Nova despesa**.
Tocar em qualquer área continua abrindo Nova despesa.
O padding horizontal permanece em 16dp, inclusive no formato baixo; somente o
vertical diminui para caber em uma linha, sem encostar o resumo ou a ação nas
bordas. Na variante estreita com botão compacto, a fonte parte de 15; o formato baixo largo
preserva 16. Nas composições verticais, a fonte parte de 19 e tem limite de
acessibilidade de 21, sem mudar o formato horizontal regular.
Adicione **Adicionar despesa** pela galeria de widgets
do celular após instalar uma nova compilação; hot reload não instala o componente.
No iOS pequeno o valor parte de 16, com limite de acessibilidade de 18; no médio
parte de 18, limitado a 22. A composição segue explicitamente `widgetFamily`,
não uma inferência pela largura, e sua identidade muda com a família para refazer
o layout ao alternar tamanhos. O espaço entre resumo e botão no pequeno é de 10
pontos, sem mudar a altura da ação. No Android, o formato horizontal regular
mantém fonte bold de 22, limitada a 26. A largura real do texto é medida antes da
renderização. Se necessário, **R$** passa para uma linha própria e somente o
número é reduzido até caber, sem abreviações, reticências ou perda de centavos.
No compacto baixo do Android, moeda e número ficam juntos com ajuste de fonte
para preservar a altura. Valores extremos podem exigir fonte pequena; o valor
completo também fica na descrição de acessibilidade. “Abra para atualizar”
mantém sua tipografia menor e até duas linhas.

No iOS, o modo full color preserva as cores do DS. Nos modos accented/vibrant
(incluindo aparência tingida/transparente), o botão usa fundo com opacidade de
16% e texto na cor primária do sistema: o WidgetKit pode tingir ambos de branco,
mas a diferença de opacidade mantém o rótulo visível. O raio continua em 14.
Após instalar a compilação nativa, confira a troca de pequeno para médio.
O usuário confirmou que adicionar diretamente o médio pela galeria funciona no
simulador. O atalho retangular de redimensionamento continua pendente nessa
instância: os logs registram ambas as famílias no catálogo, mas a ação
`change-widget-size-medium` termina com `endingGridSizeClass: small`, sem pedido
de timeline média. A causa da transição não foi resolvida; não é falta de um
layout médio. Use a galeria para adicionar o tamanho desejado enquanto isso.
Hot reload não atualiza a extensão ou seu catálogo.

O toque abre Dashboard → Nova despesa. Se necessário, o app solicita login antes
de continuar. Uma criação já aberta é preservada, sem duplicar o formulário ou
apagar a entrada. Edição não é confundida com criação. O total é o último valor
mensal sincronizado do PocketBase, nunca o acumulado de todos os meses ou o filtro
histórico da Dashboard. Autenticação, consulta de métricas do mês atual e mutações
bem-sucedidas de despesas atualizam o resumo. Falhas mantêm o último valor válido;
somente uma consulta vazia bem-sucedida representa R$ 0,00.

Sem resumo do mês atual, o valor é substituído por **Abra para atualizar**. Ao sair
da conta, o resumo é removido. O widget não compartilha credenciais nem executa
cadastros ou consultas HTTP em background. A virada do mês é renderizada localmente
por timeline no iOS e alarme não exato/eventos de data no Android, sujeitos ao
agendamento do sistema operacional.

A integração usa `home_widget`, RemoteViews no Android e uma extensão WidgetKit
SwiftUI no iOS. O target `AddExpenseWidget` é dependência do Runner e é incorporado
nas três configurações de build. Para distribuir no iOS, configure a mesma equipe
de assinatura para Runner e AddExpenseWidget e um provisioning profile para
`com.bed.cordato.AddExpenseWidget`. Habilite também o App Group
`group.com.bed.cordato` nos dois App IDs/perfis de assinatura no Apple Developer.
Os entitlements estão configurados nos targets; o registro do grupo e a emissão
dos perfis precisam ser feitos na conta Apple. Somente mês e centavos inteiros
são compartilhados com a extensão, em uma única chave JSON `monthly_summary`.

AppWidget recebe factories de SessionBloc, HomeWidgetLaunchBloc e
HomeWidgetSyncBloc, sem clients diretos. Os Blocs possuem as observações por
contratos de repository; o widget mantém somente composição e navegação.

A conferência manual deve cobrir app encerrado/aberto, com e sem sessão, login
seguido do formulário, toques repetidos com entrada não salva, edição já aberta,
voltar/salvar para Dashboard e temas claro/escuro nas duas plataformas.
Confira também total do mês atual com a Dashboard em um mês passado, zero real,
falha de sincronização, limpeza no logout e virada do mês. Para o layout agrupado,
confira formatos compacto, baixo, largo e alto no Android, famílias pequena e
média no iOS, alternância entre famílias, aparência full color/tingida/transparente,
valores longos, fonte ampliada e o estado **Abra para atualizar**.

Testes unitários nativos executam a lógica de produção de formatação e adaptação,
sem montar widgets: `dart run tool/test_home_widget_native.dart` executa JUnit
no Android e XCTest no macOS com o mesmo arquivo Swift usado pela extensão iOS.
Use o argumento `android` ou `ios` para executar somente uma plataforma. Android
exige JDK 21 e SDK configurados; os testes Swift exigem macOS com Xcode. Não
execute duas instâncias de `dart run` simultaneamente: os build hooks do projeto
compartilham artefatos nativos. Os testes cobrem zero, centavos, negativos,
fronteiras de 15 milhões, limites Int64/Long, composição por tamanho e ajuste
de fonte. A renderização real continua exigindo conferência manual.

Verificação da implementação: `flutter pub get` concluído, `flutter analyze`
sem problemas e `flutter test --reporter failures-only` com 1401 testes aprovados.
`dart run tool/test_home_widget_native.dart` passou com 36 testes JUnit e 26
testes XCTest. O runner foi ajustado para carregar o framework e o overlay Swift
do XCTest fornecidos pelo Xcode; a tentativa inicial sem esses caminhos falhou.
Builds debug Android e iOS Simulator passaram; a extensão está presente no bundle
iOS. A validação visual e de toques em aparelho/simulador permanece pendente.
Após o último ajuste fino de fontes e espaçamento, `flutter pub get`,
`flutter analyze`, `flutter test test/architecture --reporter failures-only`
(34 testes), `dart run tool/test_home_widget_native.dart` (36 JUnit + 26 XCTest),
`flutter build apk --debug` e
`flutter build ios --simulator --debug --no-codesign` passaram. A suíte Flutter
completa não foi repetida nessa rodada focada. O atalho de troca de tamanho
do SpringBoard permanece sem correção confirmada; adicionar o médio pela
galeria foi confirmado pelo usuário.
Android habilita Kotlin integrado do AGP e acesso nativo nas JVMs do wrapper e
do daemon. O Flutter 3.50.0 ainda emite um aviso sobre KGP no `home_widget` 0.10.0
por detectar a declaração por regex, mesmo no ramo condicional desativado.
A inspeção dos plugins em runtime confirmou KGP externo ausente; o aviso restante
é um falso positivo do tooling, sem bloqueio de compilação. Não foi alterado o
cache do pub nem desabilitada a validação de dependências.
A falha Android ao iniciar o subprocesso Flutter foi diagnosticada pelo stack
trace como falha de `spawn helper`, com um daemon anterior à atualização do JDK
embutido no Android Studio. Após `./android/gradlew -p android --stop`,
`flutter build apk --debug` passou duas vezes, inclusive reutilizando o daemon,
sem precisar desabilitá-lo ou alterar permanentemente o JDK do Flutter.

## Arquitetura

Authentication/Sign-in é a referência obrigatória para desenvolvimento e testes:

```text
Screen/Form -> Bloc -> contrato de repository (application)
                         -> repository (infrastructure)
                         -> SDK PocketBase / clients do core
```

- Organização por feature, sem camadas ou abstrações vazias.
- Domain com entidades e regras puras; application com contratos e exceções.
- Repositories concretos em `infrastructure/repositories/`, com acesso direto ao
  SDK PocketBase compartilhado, sem wrappers de CRUD. A persistência de sessão
  pertence ao AuthStore configurado na factory, não aos repositories.
- Retorno por `Future<T>`; falhas esperadas por exceção de aplicação, sem Either.
- Bloc com eventos concretos e estados sealed imutáveis. Sign-in usa ownership
  pelo escopo Modular; telas ainda não migradas mantêm ownership local. Formulário
  mantém entrada e validação, sem copiar loading ou resultado do Bloc.
- Testes unitários de repository, Bloc, validação, formatação, arquitetura e
  composição Modular, sem montar UI. Conferência visual por previews manuais.

CommandIt, Either, data sources de delegação e repositories concretos em
application descritos em documentos históricos não são alternativas aprovadas
para código novo nem dependências a restaurar.

Leia [ARCHITECTURE.md](ARCHITECTURE.md) para decisões e fronteiras e
[AGENTS.md](AGENTS.md) para convenções de contribuição.

## Worker Node-RED

A pasta [`worker/`](worker/README.md) contém a infraestrutura independente do
Node-RED 5.0.9, preparada para Docker Compose local e deploy posterior no Dokploy.
Editor com login obrigatório, segredos por ambiente, volume persistente e flows
versionados; sem bibliotecas adicionais. O flow importável em
[`worker/flows/audio/`](worker/flows/audio/README.md) recebe uma despesa por áudio,
valida sessão, interpreta por IA Chat Completions e cadastra pela API nativa PocketBase, com logs
de metadados sem conteúdo pessoal. A lógica pertence aos nós Function do JSON:
importação/edição e Deploy no editor bastam; rebuild é só para infraestrutura.
Exige infraestrutura de upload da imagem Cordato e importação manual;
integração de áudio ainda não homologada. O usuário confirmou o Hello World anterior
no painel; isso não comprova áudio. O flow responde `202` após validar upload/sessão
e continua em memória, sem fila persistente. Flutter envia pela seta e informa somente
o aceite; o usuário recarrega as despesas depois. Sem deploy nesta mudança.

## Backend PocketBase

O backend adotado é **PocketBase 0.41.1**, isolado em [`backend/`](backend/README.md),
com Compose, imagem e migrations próprias. Usa APIs e regras nativas,
sem Node, hooks ou worker. No Dokploy, usar `backend/compose.yml` com contexto de
build em `backend/`. Ele não depende do build Flutter e não deve receber arquivos
ou segredos do aplicativo.

A configuração foi trazida do repositório backend anterior; nenhum banco, volume,
segredo ou histórico Git foi transferido. A migração do aplicativo para PocketBase
inclui Authentication, Session, User (consulta de perfil, nome, avatar e exclusão)
e Expense (CRUD, listagem e sugestões por histórico). Metrics e a distribuição
mensal da Dashboard usam a view nativa `metrics`.

| Parte                     | Estado atual                                                                                               |
| ------------------------- | ---------------------------------------------------------------------------------------------------------- |
| Backend em `backend/`     | Contas, despesas próprias e view mensal de métricas; contrato nativo PocketBase.                           |
| Cliente Flutter em `lib/` | Authentication, Session, User, Expense e Metrics usam endpoints nativos PocketBase.                        |
| Sugestões                 | GET filtrado do histórico pessoal de despesas, sem endpoint customizado.                                   |
| Metrics e Dashboard       | Total e distribuição mensal por categoria calculados em SQL na view `metrics`; UI e navegação preservadas. |
| Budget e Family           | Planejados; não implementados no backend atual nem nas features Flutter.                                   |
| Integração e operação     | Aplicação da migration da view, homologação integrada e validação no Dokploy ainda pendentes.              |

Trocar apenas `BASE_URL` não integra o aplicativo ao PocketBase. Autenticação,
erros, paginação, datas e recursos disponíveis possuem contratos diferentes.
O Flutter usa o SDK PocketBase compartilhado, sem Dio, interceptors ou client HTTP
próprio. Login e cadastro aceitam erros nativos PocketBase (400 por campo ou mensagem
geral). Configure somente a raiz do serviço, por exemplo
`https://pocketbase.cordato.cloud`, sem `/api/`: o SDK acrescenta esse trecho aos endpoints.
Uma base terminada em `/api/` duplica o caminho e pode impedir o login. Esta adaptação
não representa homologação integrada nem migração das sessões existentes.
Veja os [limites da integração](ARCHITECTURE.md#backend-pocketbase-e-limite-de-integração).

User consulta, altera e exclui a conta por `collections/users/records/{id}`.
Nome e avatar usam JSON plano; avatar permanece uma seed textual, sem upload.
Nome vazio é exibido como `Cordato`, sem gravar esse fallback. A edição exige
2–32 caracteres após trim e reconhece erros nativos de nome no campo.
A exclusão aguarda `delete` do SDK, que limpa o AuthStore correspondente;
Session redireciona sem aguardar a exclusão durável no Secure Storage.
A cascata das despesas está configurada no backend e requer homologação real.

### Alterar senha

Dados pessoais oferece **Alterar senha**, com senha atual, nova senha e
confirmação. Cadastro, login, recuperação e troca compartilham a regra de
**6–16 caracteres**, com minúscula ASCII, maiúscula ASCII e número ASCII.
A entrada é preservada, inclusive espaços; a contagem usa code points Unicode.
A nova senha não pode ser igual à atual e a confirmação precisa coincidir.

A alteração usa PATCH nativo autenticado de `users`. Após sucesso, a sessão local
é encerrada e o app abre o login com “Senha alterada. Entre novamente”. Se a
operação de logout falhar, **Tentar novamente** repete somente o logout, sem
reenviar a alteração. Isso não detecta falhas assíncronas da persistência do
AuthStore. Senhas não são armazenadas nos estados e não há logging HTTP.
Não inclui mudança no backend, deploy ou homologação em dispositivo.

Verificação após desfazer os ajustes de teclado/rolagem: `flutter analyze` sem
problemas; 634 testes focados aprovados.
A suíte completa teve 1277 aprovados e as cinco falhas já registradas nas descrições
de categorias de Expense. O catálogo de previews compilou/serviu sem cliente
conectado; revisão visual, teclado e fluxo real em dispositivo continuam pendentes.
Detalhes em [verification.md](openspec/changes/archive/2026-11-09-add-authenticated-password-change/verification.md).

## Cabeçalho Recolhível — Piloto

Novo/Editar gasto e a listagem de despesas possuem um título que acompanha a
rolagem: sai da posição
expandida, diminui e se alinha ao botão de voltar; a descrição desaparece
gradualmente. Ele expande ao retornar perto do topo, não ao simplesmente inverter
o gesto. Nos formulários, o botão de ação continua fixo e os fluxos de cadastro,
cadastro contínuo,
edição e retorno permanecem preservados. Quando o conteúdo cabe inteiro na tela,
não é criada rolagem artificial apenas para animar o cabeçalho.

O componente compartilhado `CollapsibleHeaderWidget` usa slivers nativos,
tipografia do tema e dimensões medidas para fonte ampliada, sem pacote novo,
Bloc de animação ou controller manual na produção. A redução de movimento é
respeitada. Carregamento e erro de Expense mantêm a barra de voltar original.
Termos, Política de Privacidade e Ajuda também usam o componente, para validar
o movimento em páginas naturalmente longas. A seleção de texto e a coluna de
leitura de até 680 pixels permanecem preservadas. As outras telas e o
`HeaderWidget` comum ainda não adotam o piloto.

Verificação: `flutter pub get` concluído, `flutter analyze` sem problemas e
`flutter test test/architecture test/features/core/presentation/animations
test/features/expense/presentation/screens/expense
test/features/expense/presentation/screens/expenses
test/features/expense/expense_module_test.dart test/app_module_test.dart
--reporter failures-only` com 130 aprovados. A suíte completa teve 1208 aprovados
e as mesmas cinco falhas preexistentes nas descrições de categorias de Expense.
`dart run tool/widget_preview.dart` compilou e serviu o catálogo, encerrando por
timeout de 60 segundos sem cliente conectado ou inspeção visual. Os previews
incluem estados expandido/recolhido, temas claro/escuro, fonte ampliada, movimento
reduzido e os formulários em tela baixa. `git diff --check` passou. A aprovação
visual do piloto e a validação com teclado em dispositivo ainda estão pendentes.

A listagem mantém filtros, agrupamentos, paginação, refresh por gesto,
edição/exclusão e feedbacks anteriores. Os filtros rolam abaixo do cabeçalho;
não são fixados no topo. Verificação desta aplicação: `flutter pub get`
concluído, `flutter analyze` sem problemas e o lote focado de arquitetura,
transição do core, Information, formulários/listagem de Expense, composição do
módulo e composição global teve 143 aprovados. A suíte completa manteve 1208
aprovados e as mesmas cinco falhas anteriores em categorias de Expense.
`dart run tool/widget_preview.dart` compilou e serviu o catálogo até o timeout
de 45 segundos, sem cliente conectado ou inspeção visual. `git diff --check`
passou. Previews da listagem incluem tela baixa e movimento reduzido.

Verificação após aplicar em Information: `flutter pub get` concluído,
`flutter analyze` sem problemas e `flutter test test/architecture
test/features/core/presentation/animations test/features/information
test/features/expense/presentation/screens/expense
test/features/expense/expense_module_test.dart test/app_module_test.dart
--reporter failures-only` com 109 aprovados. A suíte completa manteve 1208
aprovados e as mesmas cinco falhas anteriores em categorias de Expense.
`dart run tool/widget_preview.dart` compilou e serviu os previews, encerrando
por timeout de 45 segundos sem cliente conectado ou inspeção visual.
`git diff --check` passou. O movimento pode ser conferido abrindo Termos ou
Privacidade pela Welcome; a aprovação visual ainda está pendente.

## Mensagens De Erro Na Interface

Campos, toasts e telas de erro usam mensagens locais em português, sem expor
títulos, descrições ou diagnósticos retornados pelo backend. A cobertura inclui
entrada, cadastro, confirmação/reenvio e recuperação de senha, perfil/nome/avatar,
despesas e logout. Dashboard e Metrics mantêm o feedback local que já utilizavam.
Erros originais continuam preservados em infraestrutura, exceções e estados;
formatadores puros da apresentação escolhem os textos por status, código, campo
e operação, com fallback seguro para respostas desconhecidas. Navegação, API,
ownership dos Blocs e comportamento de submissão não foram alterados.

Verificação local: `flutter pub get` concluído; `flutter analyze` sem problemas.
O lote de arquitetura, formatadores compartilhados, responses HTTP,
Authentication, User, Settings, formatadores de Expense e telas lógicas de
cadastro/listagem de despesas aprovou 516 testes unitários, sem montar UI.
`flutter test --reporter failures-only` teve 1158 aprovados e as mesmas cinco
falhas preexistentes nas descrições de categorias em
`test/features/expense/presentation/extensions/expense_category_extension_test.dart`;
esse arquivo e os textos correspondentes não foram alterados. `git diff --check`
passou. Não houve homologação em dispositivo ou chamadas ao backend real.

## Informações Públicas

O módulo `information` oferece Termos de uso, Política de Privacidade e Ajuda
como telas nativas com conteúdo local. A Welcome preserva seu rodapé original,
com navegação somente nos links existentes de termos e privacidade, sem Ajuda.
As Configurações oferecem os três acessos. Todas as rotas são públicas:
`/information/terms`,
`/information/privacy` e `/information/help`. Não há WebView, consulta remota,
Bloc ou repository nesta feature. O contato selecionável de suporte e privacidade
é `developer.bed@gmail.com`, sob responsabilidade de Gabriel Ramos.

Termos e privacidade têm resumo, seções numeradas, versão e data; Ajuda agrupa
perguntas sobre conta, despesas e exclusão. O conteúdo está em
`lib/features/information/presentation/content/information_content.dart`.
Alterações editoriais devem atualizar versão/data e manter consistência entre
documentos, ajuda, comportamento real e futura versão web.

Premissas informadas pelo responsável: Hostinger no Brasil, Resend para mensagens
transacionais, sem anúncios, analytics ou assinatura.
O conteúdo distingue os resumos financeiros do próprio usuário de analytics de
comportamento e não declara ausência de logs técnicos ou de retenção em terceiros.
Conforme a [documentação do Resend](https://resend.com/security/gdpr), seus dados
são armazenados nos EUA; mensagens/logs têm retenção de 30 dias nos planos Free,
Pro e Scale e backups próprios de 7 dias. Configuração da conta, provedores de
hospedagem e eventuais exceções precisam ser conferidos antes da publicação.

A versão 1.1 dos documentos, de 12/11/2026, inclui o envio opcional de áudio,
o worker e o processamento por IA, com OpenRouter e Gemini como configuração
padrão, possível transferência internacional e ausência de garantia de retenção
zero. Explica a limpeza temporária local, processamento em memória e que aceite
não comprova cadastro. Não confirma qual configuração está publicada.
Termos, política e ajuda deixam de afirmar ausência de backups: a migration inicial
prevê backups semanais com até três cópias; execução, retenção efetiva e recuperação
continuam dependendo de conferência operacional, sem alteração do backend.

Pendências de lançamento, não resolvidas pelas telas:

- Revisar juridicamente os documentos e as bases legais, incluindo tratamento
  de adolescentes e mecanismo aplicável à transferência internacional do Resend
  e dos operadores de IA. Confirmar endpoint, modelo, provedores, países,
  retenção e configurações de privacidade efetivos antes de publicar o recurso
  de áudio; a descrição da configuração padrão não substitui essa conferência.
  O DPA europeu do provedor não comprova, por si só, atendimento à LGPD/ANPD.
- Confirmar faixas de público-alvo no Play Console, sem direcionamento a crianças;
  isso não equivale a declarar automaticamente classificação indicativa ou idade mínima.
- Auditar retenção de logs da hospedagem, atendimento de suporte e controles de
  rastreamento de e-mails no Resend; a ausência de analytics no app não comprova
  que rastreamento de aberturas/cliques esteja desativado no provedor.
- Conferir agendamento, execução, retenção e exclusão nos backups em operação,
  incluindo cópias dos provedores; homologar restauração antes de prometer recuperação.
- Homologar exclusão de conta/despesas e definir o procedimento operacional de
  verificação de identidade, prazos e atendimento das solicitações por e-mail.
- Publicar as páginas Angular em outro projeto e cadastrar as URLs de privacidade
  e do recurso de solicitação de exclusão no Play Console. Nenhuma URL foi inventada.
- Preencher Segurança dos dados e a declaração de recursos financeiros de acordo
  com a operação real. Textos nativos não comprovam aprovação pelo Google Play.

Fontes oficiais consultadas em 04/11/2026:
[Dados do usuário](https://support.google.com/googleplay/android-developer/answer/10144311?hl=pt-BR),
[Exclusão de contas](https://support.google.com/googleplay/android-developer/answer/13327111?hl=pt-BR),
[Recursos financeiros](https://support.google.com/googleplay/android-developer/answer/13849271?hl=pt-BR)
e [DPA do Resend](https://resend.com/legal/dpa). Apoio voluntário via Pix fica
fora desta entrega e exige avaliação própria antes de ser disponibilizado.

Verificação local em 04/11/2026: `flutter pub get` concluído; `flutter analyze`
sem problemas; `flutter test test/architecture test/features/information
test/app_module_test.dart test/features/core/presentation/enums
test/features/settings --reporter failures-only` com 48 testes aprovados.
`flutter test --reporter failures-only` teve 1081 aprovados e as mesmas cinco
falhas já documentadas na contagem de palavras das descrições de viagens,
serviços, transporte, investimentos e assinaturas em
`test/features/expense/presentation/extensions/expense_category_extension_test.dart`.
Esses arquivos não foram alterados. `dart run tool/widget_preview.dart` compilou
e serviu o catálogo incluindo Information, encerrando por timeout de 60 segundos
sem cliente conectado ou inspeção visual. `git diff --check` passou. Não houve
deploy, publicação web, homologação em dispositivo ou validação jurídica.

Refinamento visual dos resumos: `SummaryCardWidget` do core, usado diretamente
pelos documentos e previews de Information e pela tela de apoio de Settings, substitui o card
compacto com ícone lateral por uma composição vertical de largura integral,
tipografia de corpo, espaçamento maior e superfície/borda do tema. A Ajuda não
repete links de Termos e Privacidade no rodapé; os acessos pela Welcome e pelas
Configurações permanecem. `flutter pub get` e `flutter analyze` passaram; o mesmo
lote focado acima teve 48 aprovados. Os previews isolados dos resumos compilaram
e foram servidos até o timeout de 60 segundos, sem cliente conectado ou inspeção
visual. A suíte completa não foi repetida neste refinamento; as cinco falhas
anteriores de Expense permanecem fora do escopo.

## Estado Do Projeto

**O transporte das features existentes usa o SDK PocketBase. A adoção de escopo
de página para Blocs continua parcial; testes de composição não substituem
homologação remota ou validação da navegação em dispositivo.**

Authentication já possui contrato em application e repository em infrastructure.
Sign-in, cadastro e reenvio usam Bloc, controle de submissões concorrentes, falhas tipadas
e testes unitários de Bloc e repository. Cadastro mantém erros por campo, retry
manual e navegação para confirmação sem criar sessão. Ao abrir a confirmação após o cadastro, o
primeiro envio de verificação é automático; cooldown de 60 segundos começa após
sucesso. Falha informa que a conta foi criada e permite retry manual imediato,
sem repetir o cadastro nem criar sessão.
Cadastro envia `email`, `password` e `passwordConfirm` para
`collections/users/records` pelo método `create` do SDK, sem criar sessão. O contrato
consome somente a conclusão, sem persistir dados ou autenticar. O envio de e-mail
usa uma operação separada (`requestVerification` do SDK),
disparada automaticamente pela confirmação e manualmente pelo botão Reenviar.
O ResendEmailBloc bloqueia o botão durante envio e cooldown; o cliente não garante
entrega na caixa de entrada.
Confirmação por link usa Bloc: recebe `token` pela query, envia POST para
`collections/users/confirm-verification` via `confirmVerification`, com sucesso
definido pelo SDK e erro 400 tratado como
inválido/expirado, sem criar sessão. Resultados obsoletos são ignorados.
Para confirmar no app, o template de verificação da coleção `users` deve apontar
para `https://app.cordato.cloud/authentication/confirm-email?token={TOKEN}`.
A única migration `backend/pb_migrations/1793491200_initial.js`, exclusiva para
banco novo, configura esse destino e mantém os destinos administrativos nativos.
As migrations incrementais foram consolidadas e removidas; bancos existentes
não são atualizados por esta revisão. Android e iOS já declaram o
domínio. O gerador `tool/app_links.dart` prepara somente os arquivos de associação;
publicação, certificados, profiles Apple e
homologação em dispositivo ainda são necessários. Consulte
[app_links/README.md](app_links/README.md) para a ordem de ativação. Nenhuma
alteração local comprova deploy, entrega de e-mail ou abertura automática do app.
Logout usa `LogoutBloc` na apresentação de Settings, consumindo o contrato de
Authentication. `signOut` limpa o AuthStore em memória, sem request HTTP
ou revogação do JWT no servidor. Mantém confirmação, loading e tratamento de
falhas do contrato, mas não aguarda nem confirma exclusão durável no storage.
O redirecionamento continua global por sessão.
Recuperação de senha usa o link “ou recupere sua conta” no sign-in, com somente
“conta” clicável. O envio usa `requestPasswordReset` do SDK em
`collections/users/request-password-reset` e abre a etapa “Confira seu e-mail”,
com mensagem neutra quanto à
existência da conta. Reenvio compartilha o cooldown de 60 segundos da verificação,
iniciado somente após sucesso; falhas permitem retry manual imediato. As duas
etapas compartilham o Bloc da rota para preservar cooldown e e-mail durante rebuilds.
Na confirmação do envio, campo de e-mail e botão Reenviar ficam habilitados somente
fora do cooldown e do envio. É possível corrigir o endereço e reenviar com a mesma
validação do formulário inicial. Falhas preservam a edição e permitem retry imediato;
erros remotos de e-mail aparecem no campo e os demais são exibidos em toast.
Verificação da edição no reenvio (03/11/2026): `flutter pub get` concluído,
`flutter analyze` sem problemas, lote focado de Authentication/arquitetura/logger
com 193 testes aprovados e `flutter test --reporter failures-only` com 954 aprovados.
`git diff --check` aprovado. Sem homologação visual ou envio real de e-mail.

O link `https://app.cordato.cloud/authentication/reset-password?token={TOKEN}`
abre somente o app e exige exatamente um token não vazio. Antes de habilitar o
formulário, aguarda `signOut()` para encerrar a sessão em memória, sem aguardar
exclusão durável; falhas assíncronas de storage não bloqueiam a ação. Nova senha
segue as regras do cadastro e precisa coincidir com a confirmação. O POST
`collections/users/confirm-password-reset` envia `token`, `password` e
`passwordConfirm` pelo método `confirmPasswordReset` do SDK e não cria sessão.
Sucesso volta automaticamente ao sign-in com toast; token inválido/expirado também redireciona.
Erros de campo ou rede preservam a tela e a entrada. O PocketBase invalida os
tokens de autenticação anteriores e pode marcar a conta como verificada conforme
seu contrato nativo. Token e senhas não ficam nos estados dos Blocs. Não há logger
HTTP; o observer de debug não imprime payloads, credenciais ou URLs com token.

A inicial consolidada `backend/pb_migrations/1793491200_initial.js` configura
o destino do template de recuperação de `users` para o app, mantendo destinos
administrativos nativos. Publicar as associações atualizadas geradas
por `tool/app_links.dart`, instalar o app atualizado e só então fazer o deploy
autorizado do backend com banco novo. Sem o app não há página web alternativa. Entrega real de
e-mail, aplicação da migration e abertura dos links ainda exigem homologação.

Verificação local da recuperação (03/11/2026): `flutter pub get` concluído,
`flutter analyze` sem problemas e `flutter test --reporter failures-only` com
952 testes aprovados. O lote focado de Authentication/HTTP/arquitetura/links e
composição passou antes dos últimos cenários adicionais. `dart run
tool/widget_preview.dart` compilou e serviu os previews, sem cliente conectado,
encerrando por timeout de 45 segundos; isso não comprova validação visual.
Em `backend/`, `sh -n docker/entrypoint.sh` e `git diff --check` passaram.
Não houve build nativo, execução da migration, deploy ou envio de e-mail real.

Authentication não possui mais apresentação baseada em commands; isso não
significa que todas as demais features já foram migradas.

Sign-in é o piloto de escopo de página do Modular V7: a extension `addBloc` do
core registra o Bloc no `provide` da rota, que cria e fecha a instância. A tela
recebe o Bloc pronto e mantém `BlocConsumer`. O novo `ExpenseSuggestionsBloc`
também pertence ao escopo da rota; os demais fluxos continuam com ownership pelas
telas e Session permanece sob ownership global de `AppWidget`.

Session também usa contrato em application, repository direto em infrastructure
e Bloc. `AppWidget` é o único dono da observação contínua e do fechamento;
`AppScreen` apenas mostra o splash, usando as mesmas imagens e margens da abertura
nativa: 288dp no Android e 168 pontos no iOS, centralizadas na área completa.
Login, cadastro e redefinição de senha possuem destino explícito para “Próximo”
no teclado; a troca de senha já usa esse comportamento. A validação visual é
manual, sem adicionar flows ou testes de UI ao projeto.
Ao abrir com token persistido, faz POST
`collections/users/auth-refresh` pelo PocketBase compartilhado. O SDK salva a
resposta no AuthStore sem aguardar persistência durável. Sem token, não chama a
API. HTTP 401 limpa o AuthStore atual; 403 e rede preservam a sessão e falham.
Chamadas simultâneas compartilham o refresh, sem retry automático. Não há client
temporário ou proteção contra respostas antigas: sucesso tardio pode sobrescrever
logout/novo login e 401 tardio pode limpar uma sessão nova. Parsing/defaults seguem
o SDK; a presença local de token é consultada por `pocketBase.hasSession`, sem
validar autorização. Falha na leitura inicial de storage propaga antes de montar
o app; não há interceptor HTTP próprio.

User já possui contrato em application, `UserException` e repository em
infrastructure usando o PocketBase compartilhado diretamente, sem `Either` ou
data sources. Consulta, nome, avatar e exclusão usam o ID do auth record atual;
exclusão confirmada limpa o AuthStore pelo SDK, sem espera durável do storage.
A tela de perfil usa `UserBloc` para consulta,
avatar e exclusão, com lifecycle próprio, debounce de dois segundos, confirmação
de exclusão, feedback único e bloqueio de operações concorrentes. A edição do
nome usa `EditBloc`, preservando validação, trim no formulário, erros PocketBase
400 e legados 422 por
campo, entrada após falha e retorno do perfil atualizado após sucesso. User não
usa mais commands. Os testes de repository usam SDK real com transporte mockado,
e os de Bloc usam o contrato do repository mockado. O teste composto do módulo
verifica os dois Blocs, edição e retorno com recarga do perfil.

Na Dashboard, nome e avatar usam o mesmo contrato de User/PocketBase e são
consultados novamente ao voltar de dados pessoais ou configurações. Falhas nessa
consulta levam à tela de erro global, inclusive durante atualização; não são
tratadas como ausência de usuário. Retry é manual e recarrega a Dashboard completa.
Nome vazio continua exibindo `Cordato`.

O total de gastos da Dashboard conta de zero até o valor confirmado em 700 ms
a cada carga ou atualização de métricas, inclusive troca de mês e retorno de
despesas. Rebuilds sem novos dados não reiniciam a animação. Durante a consulta,
o total anterior permanece visível; sem valor anterior, aparece `—`, nunca um
zero confirmado. Somente os cards usam skeleton. Movimento reduzido mostra o
total diretamente, e leitores de tela recebem o valor final, sem anunciar cada
passo. A animação usa centavos inteiros e não recalcula agregações financeiras.
Verificação: `flutter pub get` concluído, `flutter analyze` sem issues e
`flutter test --reporter failures-only` com 1292 aprovados. O catálogo existente
`Dashboard / Total animado` cobre atualização, mesmo total, troca de mês e
movimento reduzido para conferência manual. `dart run tool/widget_preview.dart`
compilou e serviu o catálogo, mas registrou `Null check operator used on a null
value` e encerrou por timeout de 60 segundos, sem cliente conectado; a animação
não foi validada visualmente pelo agente.

Dashboard e listagem de despesas compartilham o `EmptyStateWidget` do core:
ícone, título e descrição opcional centralizados, sem card ou seta, com visual
discreto de selo. Textos curtos cabem em uma linha no tamanho padrão e podem
quebrar com fonte ampliada. Dashboard vazia não exibe total zerado nem seções
redundantes: distingue histórico confirmado vazio de um mês sem gastos; falha na
consulta do histórico não vira primeiro uso. Na listagem, filtros sem resultados
têm mensagem própria; excluir a última despesa mostra o mesmo componente somente
após sucesso e sem páginas pendentes. Carregamento e falhas preservam seus estados.
As telas mantêm cabeçalhos, navegação, rolagem e atualização por gesto, com o selo
centralizado no espaço restante. Previews incluem temas claro/escuro, primeiro
gasto, mês vazio, filtros sem resultados e texto ampliado.
Verificação: `flutter pub get` concluído; `flutter analyze` sem issues;
`flutter test test/architecture test/features/dashboard test/features/expense/presentation/screens/expenses`
com 104 aprovados. A suíte completa teve 1036 aprovados e mantém as 5 falhas
anteriores nas descrições de categorias de Expense. `dart run tool/widget_preview.dart`
compilou e serviu o catálogo, encerrado por timeout de 60 segundos sem cliente
conectado ou validação visual pelo agente. `git diff --check` passou.

Metrics também usa contrato em application, `MetricsException` e repository em
infrastructure usando `PocketBase.send` diretamente, sem Either, wrapper ou data source. Consulta
`collections/metrics/records` por mês civil completo. Sem datas,
usa o mês atual; intervalos parciais, incompletos ou de vários meses são rejeitados,
sem truncamento silencioso. Total mensal, valores por categoria e percentuais vêm
do PocketBase: não há soma ou cálculo de percentual no Flutter. Centavos chegam
como texto e são convertidos diretamente para `int`; percentuais são numéricos.
Mês sem registro retorna total zero e agrupamento vazio; falhas e respostas
inválidas não são tratadas como ausência de despesas. A UI e a navegação filtrada
por categoria/mês permanecem intactas. `ExpenseMetricsBloc`
substitui o command, com estados sealed, falhas tipadas, retry manual e precedência
da consulta mais recente. O módulo fornece instâncias por factory e os previews
consumidores usam BlocBuilder. Dashboard mantém seu próprio Bloc sobre o contrato,
sem migrar os demais contextos financeiros.

A distribuição exibe todas as categorias com total positivo, inclusive quando
existe somente uma. O carrossel agrupa até três por página sem descartar uma
categoria restante; páginas únicas com um card não reservam uma linha inferior vazia.
Quando a última página de um carrossel com várias páginas possui somente uma
categoria (quatro, sete, dez categorias etc.), o espaço inferior recebe um card
informativo neutro, sem imagem, valor ou ação de toque. Ele mostra o ícone de
informação, o título “Entenda seus gastos” e “Toque em uma categoria para ver as
despesas do período.” Não adiciona páginas ou categorias fictícias. Uma única
categoria no total e páginas com dois ou três cards mantêm o layout anterior.
O título tem no máximo uma linha e a descrição três no tamanho padrão; fonte
ampliada permite mais linhas, com a altura considerada no cálculo do carrossel.

Verificação da dica: `flutter pub get` concluído, `flutter analyze` sem problemas
e `flutter test test/architecture test/features/metrics test/features/dashboard
--reporter failures-only` com 226 aprovados. A suíte completa teve 1184 aprovados
e as mesmas cinco falhas preexistentes nas descrições de categorias de Expense.
`dart run tool/widget_preview.dart` compilou e serviu o catálogo com os novos
previews, encerrando por timeout de 60 segundos sem cliente conectado ou inspeção
visual. `git diff --check` passou. Não houve alteração de API, backend, agregações
financeiras ou navegação das categorias.

Verificação: `flutter pub get` concluído, `flutter analyze` sem issues e 186 testes
de arquitetura, Metrics e Dashboard aprovados. A suíte completa mantém as 5 falhas
nas descrições de categorias de Expense (1014 aprovados). O catálogo de previews
compilou e foi servido, sem cliente conectado, até o timeout de 45 segundos;
não houve validação visual. `git diff --check` passou.

A inicial consolidada `backend/pb_migrations/1793491200_initial.js` cria a view
diretamente como `metrics`, com as mesmas regras e consulta, em banco novo.
Esta revisão não oferece atualização incremental de instalações existentes.
O cliente não usa fallback para `metrics/expenses`. A definição das regras de proprietário
está versionada, mas ainda requer homologação no PocketBase real.

Verificação local desta integração: `flutter pub get` concluído, `flutter analyze`
sem problemas, lote focado de Metrics/Dashboard/HTTP/arquitetura/composição com
262 testes aprovados e `flutter test --reporter failures-only` com 885 aprovados.
Não houve execução visual, aplicação da migration, validação de permissões no
PocketBase real ou deploy.

A feature Insight foi removida do aplicativo, incluindo módulo, consultas HTTP,
seção da Dashboard, previews e testes próprios. Referências nas verificações
históricas abaixo não representam funcionalidade disponível.

Expense também usa contrato em application, `ExpenseException` e repository em
infrastructure com o SDK PocketBase direto, sem Either ou data source. Usa CRUD nativo
em `collections/expenses/records`, centavos inteiros positivos, datas civis e
filtros/paginação PocketBase. Criação lê o ID atual do auth record para `owner` e envia
categoria selecionada, com `other` como padrão quando ausente; atualização envia
somente os campos fornecidos, incluindo categoria, sem trocar proprietário.
A data escolhida é enviada como meia-noite UTC e lida como
data civil, sem conversão de fuso. Consulta,
criação e atualização retornam entidades; exclusão retorna `Future<void>` e
segue o sucesso nativo do SDK. `AmountValueObject.create` retorna o valor diretamente e
rejeita centavos não positivos com `ArgumentError`. Parsing e falhas inesperadas
propagam. `ExpenseBloc` substitui consulta/criação/edição e `ExpensesBloc` substitui
listagem/exclusão/recadastro, com estados sealed, factories estáveis e lifecycle das telas.
Mantém validação, erros PocketBase 400 e legados 422 por campo, retry manual,
cadastro contínuo por hold,
filtros, paginação por números e confirmação de exclusão sem remoção otimista. Consultas
obsoletas não sobrescrevem filtros recentes; mutações pendentes bloqueiam duplicatas.
Listagem navega diretamente pelo `BuildContext`, sem callbacks nos argumentos de
rota; Dashboard e métricas recarregam ao retornar da listagem, mesmo sem alteração.
Expense não depende mais de CommandIt. Dashboard consome resultados diretos de
todos os contextos consultados.

Na listagem, mantenha uma despesa pressionada para abrir “Recadastrar” (também
disponível por ação de acessibilidade). “Voltar” cancela; “Cadastrar” salva direto,
sem formulário, copiando descrição, valor e categoria com a data civil de hoje.
A original permanece intacta e gastos iguais no mesmo dia são permitidos.
Durante o envio, os botões e o fechamento ficam bloqueados; ao concluir, a folha
fecha e mostra um toast com título e descrição, inclusive em falha. Não há retry
automático. Após sucesso, a listagem recarrega a primeira página sem mudar filtros:
se hoje estiver fora do intervalo ativo, a nova despesa não aparece nessa consulta.
Falha na recarga não desfaz o cadastro nem repete a escrita. Previews em
“Expense / Recadastro” permitem exercitar sucesso, falha e envio lento sem rede.

O formulário de despesa oferece um campo Categoria somente leitura, preenchido
com Outros no cadastro e com a categoria salva na edição. A bottom-sheet reutiliza
o item de menu compartilhado com ícone, nome e descrição curta, ordenação alfabética
e Outros no final. A seleção usa borda e fundo suave nas cores das métricas e só
é aplicada pelo botão Confirmar fixo no rodapé; dispensar a folha não altera o
formulário. Cadastro contínuo retorna a Outros. O Bloc encaminha a categoria
selecionada ao repository na criação e na edição; infrastructure envia seu valor
no JSON nativo do PocketBase. Edição sem mudança de categoria omite esse campo,
enquanto selecionar Outros envia `other` explicitamente. A entidade confirmada
pela API continua sendo a fonte do resultado, sem atualização otimista.
Selecionar uma sugestão do histórico preenche também sua categoria, inclusive
Outros, substituindo a seleção anterior do formulário.

Verificação da integração de categorias: `flutter pub get` concluído e
`flutter analyze` sem issues. O lote `flutter test test/architecture
test/features/expense/infrastructure
test/features/expense/presentation/screens/expense/bloc
test/features/expense/application test/features/expense/expense_module_test.dart`
aprovou 234 testes. `flutter test` aprovou 1009 testes e encontrou cinco falhas
preexistentes na contagem de palavras das descrições de viagens, serviços,
transporte, assinaturas e investimentos em `expense_category_extension_test.dart`;
esses textos e testes não foram alterados nesta integração.
`dart run tool/widget_preview.dart` compilou e iniciou o servidor web, mas atingiu
o timeout de 120 segundos sem cliente conectado; não houve inspeção visual.

Verificação da etapa anterior de UI: `flutter pub get` concluído, `flutter analyze` sem issues,
`flutter test` com 977 testes aprovados e o lote `test/architecture` +
`test/features/expense` com 309 aprovados. `dart run tool/widget_preview.dart`
compilou e serviu o catálogo; a execução foi encerrada pelo timeout de 60 segundos,
sem cliente conectado ou validação visual. `git diff --check` sem erros.

No novo gasto, Descrição oferece autocomplete do histórico pessoal com
`RawAutocomplete` nativo e o mesmo `TextFieldWidget` do core. A busca começa em
3 caracteres, após 300 ms;
respostas antigas são ignoradas e falhas não bloqueiam cadastro manual. Selecionar
preenche a descrição, a categoria e o valor opcional; valores confirmados manualmente são
preservados, com ação explícita para usar o sugerido. A data não muda e selecionar
não salva nem configura recorrência. Edição não consulta sugestões.
A consulta usa GET com filtro por descrição, valores escapados e até 30 despesas
ordenadas por data decrescente, criação e ID. Descrições repetidas, ignorando caixa,
mantêm o valor e a categoria da ocorrência mais recente retornada. A projeção
consulta `id,description,amount,category`; categoria ausente, vazia ou inválida
não vira Outros nem um resultado parcial. Não há deduplicação global,
IA, previsão ou classificação automática. Sem histórico, a lista fica vazia.
Não há migração de registros antigos, fallback para categoria/data vazias,
alteração de schema, deploy ou homologação real nesta integração.

Verificação da categoria nas sugestões: `flutter pub get` concluído e
`flutter analyze` sem issues. O lote de arquitetura, domain/infrastructure de
Expense e Blocs do formulário aprovou 271 testes. `flutter test` teve 1065 aprovados
e as mesmas 5 falhas anteriores nas descrições de categorias. O catálogo de previews
compilou e foi servido até o timeout de 45 segundos, sem cliente conectado ou
inspeção visual pelo agente. `git diff --check` passou.

Os testes de responses cobrem conversão estrita de records e JSON do SDK em
entidades puras, sem `Either` ou `response<T>`. Messaging remoto foi removido.
Todos os destinos de `RouteEnum` estão registrados em `app_module.dart`, incluindo
Dashboard, Settings, User e Expense. Testes de composição verificam as rotas e a
resolução das dependências sem visitar módulos irmãos. Authentication e Expense
usam um único módulo sem path por feature, com URLs completas e binds root-owned;
isso elimina a colisão no escopo `/` e disponibiliza o contrato para logout.

Verificação histórica após remover testes de UI, Maestro e servidores de fixtures:
`flutter pub get` concluído, `flutter analyze` sem problemas e `flutter test`
com **733 aprovados, sem falhas**. A expectativa invertida da ordem de erros
de autenticação foi corrigida; o teste de UI de sugestões citado abaixo foi
removido com a suíte visual. O código do aplicativo não foi alterado.

Verificação histórica após remover Insight, anterior à remoção dos testes de UI:
`flutter pub get` concluído e `flutter analyze`
sem problemas. O lote de arquitetura, Dashboard, composição global e
SessionInterceptor passou com **80 testes**. A suíte global repetida terminou
com **939 aprovados e uma falha preexistente** em
`expense_screen_test.dart:319` (`manual amount survives suggestion until explicit replacement`),
que não encontrou `Usar descrição`. O catálogo de previews compilou e serviu,
mas encerrou por timeout sem cliente conectado; não houve validação visual ou E2E.

Verificação histórica anterior à remoção de integrações remotas e Insight:
**`flutter analyze` sem problemas; `flutter test`
com 1006 aprovados, sem falhas**, incluindo arquitetura, core, Expense e composição
real. Build iOS de debug para simulador aprovado com API de fixtures isolada.
Os quatro flows de sugestões passaram no iPhone 17 Pro / iOS 26.5: descrição e
valor, descrição sem valor, falha com cadastro manual e loading não bloqueante.
Android e backend real não foram exercitados. O catálogo de previews compilou e
serviu; a execução foi encerrada por timeout sem cliente conectado, sem validação
visual do catálogo.
Os detalhes estão em [Estado atual e migração](ARCHITECTURE.md#estado-atual-e-migração).

O código existente inclui os seguintes fluxos, com rotas e dependências compostas;
a operação contra o serviço real ainda exige homologação:

- Boas-vindas, validação inicial de token persistido via auth-refresh e observação da sessão.
- Entrada/cadastro com e-mail e senha, confirmação por link e reenvio com cooldown.
- Perfil, edição do nome, avatar gerado com salvamento após dois segundos e
  exclusão da conta.
- Criação/edição de despesas, valor em centavos, data civil e cadastro contínuo
  por hold; listagem paginada com filtros de período/categoria e gestos de edição/exclusão.
- Dashboard mensal com métricas por categoria e seis despesas recentes.
- Configurações e sign-out com limpeza do AuthStore em memória, sem HTTP,
  revogação remota ou espera por persistência durável.
- Tema claro/escuro, componentes compartilhados e previews.

`budget` e `family` são planejados, sem features Flutter implementadas.
`identity` não reproduz o backend legado; `chat` está fora do escopo.
O backend PocketBase tem schema e migrations neste repositório, em `backend/`.
As descrições dos fluxos Flutter acima não comprovam suporte pelo novo backend.

## Stack

- Flutter `>=3.50.0` com Dart `^3.14.0` e primary constructors.
- `bloc`, `flutter_bloc` e `bloc_concurrency` para apresentação assíncrona.
- `flutter_modular` 7 para composição, DI e rotas.
- Material 3 via `material_ui`, fonte Inter e localização pt-BR.
- SDK oficial `pocketbase` para autenticação, coleções e transporte HTTP nativo.
- `AsyncAuthStore` com `flutter_secure_storage` para persistência segura da sessão.
- `talker_bloc_logger` para observação de Blocs somente em debug, sem logger HTTP.
- `flutter_test`, `bloc_test`, `mocktail` e `fake_async` para testes sem UI.

## Desenvolvimento

### Atualização para Flutter 3.50

O mínimo do projeto é Flutter 3.50.0/Dart 3.14.0, com a mesma versão Flutter
fixada no release do GitHub. Material/Cupertino e seus delegates vêm dos pacotes
standalone; `flutter_localizations` não é dependência direta do app, mas ainda
aparece transitivamente no lockfile. Animações customizadas respeitam tanto
`disableAnimations` do Android quanto `reduceMotion` do iOS.

O SDK PocketBase 0.26 limpa o AuthStore automaticamente por padrão. A factory
desativa essa opção por `autoClearAuthStore(false)` para preservar os contratos
existentes de sessão, sem alterar repositories ou restaurar interceptors.
O SDK não envia token localmente expirado no header de autenticação; isso não
altera a presença local da sessão nem adiciona retry ou refresh automático.

Verificação desta atualização: `flutter pub get --enforce-lockfile`,
`flutter analyze` sem problemas, `flutter test --reporter failures-only`
com 1620 testes aprovados e `flutter test test/architecture --reporter failures-only`
com 70 testes aprovados. `actionlint .github/workflows/android-release.yml`
e `git diff --check` passaram. `dart run tool/test_home_widget_native.dart`
passou com 39 testes JUnit e 27 XCTest. Builds
`flutter build apk --release --dart-define=BASE_URL=https://pocketbase.cordato.cloud`
e `flutter build ios --simulator --debug --no-codesign` passaram.
As 19 falhas iniciais de sessão com PocketBase 0.26 foram resolvidas pela
configuração nativa, preservando as expectativas existentes dos testes.
Permanecem avisos Android de DSL legada e KGP no `home_widget`.
Não foram executados o workflow remoto, build iOS de distribuição nem
homologação em aparelho de áudio, acessibilidade, widget e callbacks em release.

### Build Android assinado no GitHub

O workflow manual [Android release](.github/workflows/android-release.yml) gera
um AAB assinado da `main`, após análise e testes, sem publicar no Google Play.
Lê a versão visível do `pubspec.yaml` e substitui somente o código do build por
`GITHUB_RUN_NUMBER + 5`: a primeira execução gera `1.0.0 (6)`, acima do build
`1.0.0 (5)` em teste interno. Alterar a versão para `1.0.1` ou `1.1.0` não reinicia
o contador nem exige commits automáticos do CI.

Configuração dos quatro secrets de upload no environment `android-release`,
download do artefato, reexecuções e limites do contador estão no
[guia Android](android/README.md#github-actions-aab-assinado-sob-demanda).

### Verificação local

Na raiz do projeto:

```bash
flutter pub get
flutter analyze
flutter test
```

Os bloqueios de migração dos registros históricos foram resolvidos na migração
do client. Não restaure dependências antigas ou silencie checks diante de regressões.

Para executar em Android/iOS:

```bash
flutter run
```

A raiz padrão do PocketBase é `https://pocketbase.cordato.cloud`.
Para outra instância:

```bash
flutter run --dart-define=BASE_URL=https://pocketbase.exemplo.com
```

Não acrescente `/api/`: esse trecho pertence ao SDK. `BASE_URL` é definido no build;
encerre a execução e inicie novamente após alterá-lo, sem depender de hot reload.
Confira também os overrides locais de `.vscode/launch.json`, ignorados pelo Git.

O envio de áudio usa outra origem HTTPS, `WORKER_URL`, com padrão
`https://worker.cordato.cloud`. Para configurar ambos no build:

```bash
flutter run --dart-define=BASE_URL=https://pocketbase.exemplo.com --dart-define=WORKER_URL=https://worker.exemplo.com
```

Informe somente as origens, sem `/api`, credenciais ou query. Configure um worker
confiável ligado à mesma instância PocketBase: o app envia a ele o JWT do usuário.

### Backend Local

Consulte [`backend/README.md`](backend/README.md) para configuração e verificação
isoladas do PocketBase. O Compose atual depende da rede externa do Dokploy; não
é uma configuração local pronta para conectar o Flutter.

As ferramentas do ambiente PHP anterior foram removidas. Não use as instruções
antigas de Lerd/mkcert como setup do PocketBase. O projeto não usa Python nem
mantém servidores de fixtures HTTP para testes de UI.

### Previews

```bash
dart run tool/widget_preview.dart
```

Abra a URL impressa. O launcher contorna a descoberta inicial vazia do previewer
no Flutter 3.47.6/3.47.7; se necessário, atualize o painel após a análise inicial.
Previews usam o tema real, pt-BR e fakes locais, sem rede/storage. Não substituem
testes de contrato. `.widget_preview/` não deve ser versionado.
Preserve um único proprietário de recursos: Sign-in recebe um Bloc externo;
as telas ainda não migradas continuam criando/fechando sua factory. Use
`PreviewResourceWidget` para um recurso externo ao lifecycle da tela.

Os ícones explícitos usam os ícones padrão do Material pelo renderer estático
`IconWidget`, sem biblioteca de ícones animados, controllers ou listeners de
interação para animação. Cores do tema, tamanhos, semântica e estados desabilitados
são preservados. O grupo `Core / Ícones` inclui um preview dos controles.
Após a troca, pare e execute o app novamente; hot reload não substitui a mudança
de dependência e do lifecycle do renderer. A melhoria de desempenho ainda precisa
ser conferida em dispositivo, sem benchmark nesta alteração.

Verificação dos ícones estáticos: `flutter pub get` concluído e `flutter analyze`
sem issues. `flutter test --reporter failures-only` aprovou 1009 testes e manteve
as cinco falhas de contagem de palavras das descrições de categorias já registradas
acima. O lote `flutter test test/architecture
test/features/metrics/presentation/extensions/expense_category_metrics_extension_test.dart
test/features/core/presentation/widgets/toast/toast_icons_test.dart` aprovou 56
testes; `flutter test
test/features/expense/presentation/extensions/expense_category_extension_test.dart
--name 'Expense category Material icons'` aprovou outros 19.
`dart run tool/widget_preview.dart` compilou o catálogo; o servidor foi encerrado
após a recompilação, sem cliente conectado ou inspeção visual.

### Modular V7 E Navegação

- Estado de página novo ou explicitamente migrado usa `provide` e a extension
  `BlocScopedExtension`, em `core/presentation/extensions/bloc_scoped_extension.dart`.
  O Modular cria e fecha o Bloc; a screen recebe a instância e mantém `flutter_bloc`.
- Apenas Sign-in foi migrado para esse ownership. Session permanece global sob
  `AppWidget`; os demais fluxos de tela ainda possuem factories locais.
- Contratos compartilhados entre features precisam de módulos sem `path`.
  Módulos com `path` ativam seus binds apenas enquanto a feature está em uso.
- Authentication e Expense mantêm um módulo por feature, sem `path` e sem
  fragmentação dependencies/form/list. Não use `path: '/'` em módulos irmãos;
  os binds colidem. Blocs registrados com `add` continuam factories, não singletons.
- Widgets/mixins navegam pelo próprio `BuildContext`; argumentos de rota levam
  dados, não callbacks. Edição devolve a entidade confirmada pelo resultado tipado.
- Ao retornar da listagem, Dashboard e Metrics recarregam mesmo sem alteração;
  o retorno do cadastro continua condicionado à entidade confirmada.

Consulte [composição e rotas](ARCHITECTURE.md#composição-rotas-e-bootstrap) para
o exemplo de `provide`, ownership, estado de migração e limites de DI.

## Testes

| Camada                    | Padrão                                                         |
| ------------------------- | -------------------------------------------------------------- |
| Domain/application        | Regras puras e exceções, sem SDKs.                             |
| Infrastructure/repository | SDK real com transporte mockado; payload, parsing, erros e efeitos no AuthStore. |
| Bloc                      | Repository mockado; estados, concorrência, retry e fechamento. |
| Modular/rotas             | Catálogo e resolução de dependências/factories sem montar UI.  |
| Architecture              | Imports, fronteiras de contextos e direção das dependências.   |

Testes espelham os caminhos de `lib/`; doubles públicos ficam em arquivos
próprios de `test/support/`, sem classes auxiliares nos arquivos `*_test.dart`.
Testes de UI (telas, widgets, goldens e Maestro) e seus servidores de fixtures
foram removidos por decisão do projeto. Não adicionar Python. Testes de lógica
de apresentação, incluindo Blocs, validadores e formatadores, permanecem.

```bash
flutter test test/architecture
flutter test test/features/authentication/infrastructure/repositories
flutter test test/features/authentication/presentation/screens/sign_in/bloc
flutter test test/app_module_test.dart
flutter test test/features/authentication/presentation/screens/sign_up
flutter test test/features/authentication/presentation/screens/resend_email
flutter test test/features/authentication/presentation/screens/callback test/features/authentication/authentication_callback_module_test.dart
flutter test test/features/settings
flutter test test/features/session
flutter test test/features/user
flutter test test/architecture test/features/metrics
flutter test test/architecture test/features/expense test/features/dashboard test/features/metrics test/features/core
```

### Histórico De Migrações E Verificações

Os números e bloqueios abaixo registram etapas anteriores; não descrevem o
checkout atual. A última verificação registrada está em **Client e verificação
atual** e a referência de implementação é `ARCHITECTURE.md`, não os comandos/rotas históricos.

Na migração de reenvio, Bloc/tela tiveram 23 testes novos aprovados; o lote focado
de arquitetura, Authentication, Settings, Session, Root e storage tem 250 testes aprovados. A análise focada está
limpa, mas análise/suíte globais continuam bloqueadas pelo legado.

O antigo E2E de callback usava fixture na porta 8768 e incluía sucesso, link
inválido, falha e loading, sem execução em dispositivo. Naquela etapa, callback
teve 29 testes novos de Bloc, tela, DI e rotas aprovados; os testes de UI e
flows foram removidos posteriormente.

O antigo E2E de logout usava fixture local na porta 8769 para o cenário Success,
sem execução em dispositivo. Os testes Flutter de Settings/Logout então incluíam
Bloc, tela e módulo com repository real sobre clients mockados. Testes de UI,
flows e servidores de fixtures foram removidos posteriormente.

Session/Root têm 49 testes novos aprovados, incluindo o ciclo de sign-in/token/
logout com repositories e Blocs reais sobre clients mockados. Os antigos
flows de Session/Root reutilizavam a fixture de logout na porta 8769 e foram
removidos posteriormente. A suíte do SessionInterceptor voltou a passar após migrar o repository
de Expense; a suíte global ainda não está aprovada.
Dependem de build compilável e módulos de sessão/destinos ativos; sua existência
não significa validação em dispositivo. Não há suíte Flutter `integration_test`.

O lote focado de arquitetura, Authentication, Settings, Session, Root, User e das
camadas migradas de Metrics passou com 456 testes. A análise focada está limpa.
Após substituir o command, `flutter test test/architecture test/features/metrics`
passou com 106 testes, incluindo Bloc e módulo. A análise focada de Metrics e dos
dois previews consumidores estava limpa. A Dashboard foi desbloqueada na primeira
rodada de Expense; não houve execução visual de previews ou E2E.
Os antigos flows de perfil e edição de nome usavam fixture local na porta 8770,
sem execução em dispositivo; foram removidos posteriormente.
Análise e suíte globais permanecem bloqueadas pelo legado.

Na primeira rodada de Insight, arquitetura, Metrics e as camadas migradas de
Insight passaram com 134 testes, incluindo 28 de Insight. A análise focada dessas
camadas estava limpa; módulo/command e Dashboard estavam bloqueados pelo legado.
Após substituir o command, `flutter test test/architecture test/features/metrics
test/features/insight` passou com 152 testes, incluindo 17 de InsightsBloc e o teste
de módulo anteriormente bloqueado. A análise de toda a feature e seus testes está
limpa nessa rodada. A análise e a suíte globais continuam falhando no legado;
a dependência de Either da Dashboard foi removida na rodada de Expense.

Na primeira rodada de Expense, o lote focado de arquitetura, camadas migradas de
Expense, validators, DashboardBloc, Metrics, Insight e SessionInterceptor passou
com 380 testes. A análise focada dessas camadas e consumidores está limpa.
Na segunda rodada, os cinco commands de Expense foram removidos. Testes de Bloc,
tela, DI e rotas verificam sucesso/falha, concorrência, descarte, paginação e retorno
da edição com a entidade confirmada por HTTP. Os antigos flows de criação e
listagem/exclusão usavam fixture isolada na porta 8771, sem execução em dispositivo;
foram removidos posteriormente.
As rotas globais não foram reativadas. Análise/suíte globais seguem bloqueadas por
testes antigos de responses/CommandIt, referência inexistente a
`userDependenciesModule` e expectativas dos testes de HeadersInterceptor.

Verificação da segunda rodada de Expense:

- `flutter pub get`: concluído, sem restaurar dependências legadas.
- `flutter analyze lib/features/expense test/features/expense test/architecture/expense_presentation_test.dart`:
  sem issues.
- O comando focado acima de arquitetura, Expense, Dashboard, Metrics, Insight e
  SessionInterceptor passou com **435 testes**.
- `flutter analyze` e `flutter test`: executados, ainda falham nos bloqueios fora
  de Expense descritos acima; a análise também aponta deprecações Firebase e um
  import não usado em Insight, sem alteração incidental dessas áreas.
- `dart run tool/widget_preview.dart`: servidor iniciado e encerrado sem abrir
  navegador; não houve validação visual dos previews.
- Smoke HTTP da fixture local: autorização, consulta, criação, edição, exclusão e
  estatísticas aprovados; isso não é execução Maestro em dispositivo.

Após remover os callbacks de navegação de `ExpenseScreen` e `ExpenseFormWidget`,
voltar e sucesso usam diretamente as extensões de `BuildContext` nos widgets.
A edição devolve a entidade confirmada; a criação preserva `returnToPrevious` e
o cadastro contínuo não navega.
`flutter analyze lib/features/expense test/features/expense` passou sem issues;
o mesmo lote focado passou com **438 testes**, incluindo navegação real em router.
`flutter analyze` e `flutter test` globais foram repetidos e mantêm os bloqueios
externos listados acima. Não houve execução Maestro nesta alteração.

`onExpensesChanged` também foi removido de `ExpenseScreen`, do formulário e dos
argumentos usados pela Dashboard para criação. A Dashboard aguarda uma despesa
confirmada como resultado da rota; cancelar sem salvar não recarrega os dados.
Após cadastro por hold, voltar pelo botão ou pelo sistema devolve a última despesa
salva mesmo após outra tentativa falha ou ainda pendente, sem flag local espelhando
o resultado do Bloc. Testes de navegação e do botão da Dashboard cobrem esse retorno.
A análise focada de Expense e do consumidor da Dashboard passou sem issues; o
mesmo comando focado de testes passou com **447 testes**. Os bloqueios globais
preexistentes e a ausência de validação Maestro permanecem.

## API, Sessão E Segurança

O Flutter usa o SDK oficial PocketBase compartilhado pela DI. As regras de
autorização e a configuração do serviço estão em
[`backend/README.md`](backend/README.md#coleções).

`PocketBaseFactory.create` aguarda a leitura do Secure Storage antes de `runApp`
e configura o `AsyncAuthStore` oficial na chave `@cordato.pocketbase_auth`.
Não há `IStorageClient`, chaves separadas de token/ID ou migração de sessões antigas.
Authentication delega autenticação e verificação aos métodos nativos do SDK.
Memória e `onChange` são atualizados antes de concluir a persistência assíncrona;
login/logout não confirmam gravação/exclusão durável, não fazem rollback e não
recebem falhas de escrita pelo Future da operação. Bloc e UI não recebem token nem DTO.
Falhas esperadas viram `AuthenticationException`; erros inesperados propagam,
e o Bloc fornece fallback seguro e `addError` sem conhecer SDKs de telemetria.

Session valida o token persistido ao abrir por auth-refresh e observa mudanças
locais para entrada e redirecionamento global. Não há refresh periódico, retry
automático de requests ou guard Modular. Um 401 de auth-refresh limpa o AuthStore
atual; não há proteção contra respostas antigas após logout/novo login.
Sign-out chama `authStore.clear()` localmente, sem HTTP ou espera durável.
Confirmação de e-mail usa `confirmVerification(token)` e não cria sessão;
endpoint, payload e headers pertencem ao SDK.

O `talker_bloc_logger` usa uma instância local de Talker pelo `Observer`,
instalado por `createDependencies` somente em debug. Registra criação, fechamento,
tipos de eventos e transições, sem imprimir os dados completos; erros inesperados mostram
somente tipo e stack trace, omitindo mensagens potencialmente sensíveis.
Não há logger HTTP, Dio, interceptors próprios, wrapper de CRUD ou refresh
automático. Não use o PocketBase compartilhado para origens externas. Não adicione
segredos ao código ou fixtures. Valores financeiros são centavos inteiros de BRL,
e datas financeiras preservam seus componentes civis, sem conversão de fuso.

## Notificações E Release

Notificações locais e seu client foram removidos. Não há integração de push remoto
ou crash reporting. O bootstrap não depende de configuração de serviços remotos.
O iOS usa Swift Package Manager para os plugins Flutter.

Verificação histórica após remover a integração remota, anterior à remoção dos
testes de UI:

- `flutter pub get` e `flutter analyze`: concluídos, sem issues na análise.
- `flutter test`: 988 testes passaram e um falhou em
  `test/features/expense/presentation/screens/expense/expense_screen_test.dart:319`
  (`manual amount survives suggestion until explicit replacement`), por não
  encontrar `Usar descrição`. A repetição isolada reproduziu a falha; o fluxo
  de sugestões não foi alterado nesta remoção.
- `plutil -lint`: projeto Xcode, Info.plist e entitlements válidos.
- `flutter build ios --simulator --debug`: concluído.
- `flutter build apk --debug`: excedeu 120 segundos durante `assembleDebug`,
  sem resultado conclusivo para Android.

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
## Gravação de áudio na Dashboard

Mantenha o botão de adicionar gasto pressionado para abrir a gravação de áudio.
Soltar mantém a captura; X descarta e a seta finaliza. O toque curto continua
abrindo o formulário. O widget e suas animações permanecem iguais. Ao atingir
30 segundos, a gravação para e a barra aguarda seta ou X.

Usa `record` para gravar AAC em arquivo `.m4a` temporário, sem transcrição nem
logs de conteúdo. O áudio temporário é removido ao finalizar ou descartar o fluxo.
O app não interpreta nem cadastra despesas; isso pertence ao worker.

O fluxo usa `AudioBloc` → `IAudioRepository` / `AudioRepository` →
`RecordingClient`, com uma única família de eventos de captura, sem transcrição
ou conversão intermediária de notificações. Os nomes de código usam áudio;
o visual, os gestos e as animações da barra permanecem preservados.

A seta finaliza e envia o áudio ao worker, usando multipart no campo `file`
(`audio/mp4`, até 2 MiB), data civil local e JWT atual. Usa `http`/`http_parser`
somente na infraestrutura desse envio, sem client HTTP genérico.
Após validar upload e sessão, o worker retorna `202`; o app mostra
“Áudio recebido para processamento”, não “Despesa cadastrada”.
Não há polling, retry ou atualização automática: recarregue as despesas depois.
O processamento é em memória; reinícios podem perder áudios já aceitos e falhas
posteriores ficam somente nos logs seguros. Se o envio ficar sem confirmação,
confira suas despesas antes de reenviar para evitar duplicação.

Há testes unitários da captura e apresentação lógica, sem testes de UI.
Android/iOS reais, builds nativos e o endpoint ainda precisam de validação.

Verificação local da integração (10/11/2026): `flutter pub get` e `flutter analyze`
concluídos, `flutter test --reporter failures-only` com 1.608 testes aprovados.
O worker passou 195 testes locais com IA configurável por `AI_BASE_URL`, `AI_MODEL`
e `AI_API_KEY`, usando OpenRouter por padrão; detalhes e limites no seu README.
