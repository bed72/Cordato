# Registro de implementação

> Registro histórico, não o estado atual do checkout. Consulte
> [openspec/README.md](../../README.md). Os contratos atuais retornam Future e
> exceções; somente Sign-in usa ownership Modular. Dashboard e Metrics agora
> recarregam em todo retorno da listagem, mesmo sem mutação. Os resultados abaixo
> não comprovam suíte global ou E2E atuais.

## Escopo e baseline

- Cancelamento HTTP retirado por solicitação explícita do usuário durante a
  implementação. Core HTTP permanece inalterado; Expense.get recebeu sort opcional
  na correção posterior descrita abaixo.
- Working tree inicial limpo. A change referenciada
  `introduce-exception-http-insight` não existe neste checkout; o piloto usa os
  contratos executáveis Either atuais, sem migração global de exceções.
- Baseline: `flutter analyze` sem issues; `flutter test` com 750 sucessos e duas
  falhas de transporte HTTP, código retornando 500 e testes esperando 0.
- Durante a execução apareceram atualizações de Firebase, Material, Cupertino e
  Syncfusion no pubspec/lock além das dependências Bloc adicionadas. Foram
  preservadas, sem migrar Firebase Messaging nesta change.

## Implementação

- Um DashboardBloc por tela, criado pela factory da rota e fechado exclusivamente
  pelo lifecycle da screen. Previews de tela usam a mesma implementação.
- Coordenação única das intenções financeiras, filtro anterior ao restartable,
  identidade de ciclo, User independente e proteção de emissões após await.
- Falha financeira encerra logicamente o ciclo imediatamente. Requests antigas
  continuam na rede, mas não alteram dados, loading, mês, erro ou telemetry.
- Retorno com alteração substitui imediatamente o ciclo; retorno sem alteração
  não envia intenção financeira. Navegação continua fora do Bloc.
- Cabeçalho e seções recebem dados/status, sem commands. Mantidos os contratos
  de navegação, BRL, datas civis, seis recentes e estados vazios.
- GetFirstExpenseMonthCommand e seus testes exclusivos removidos. O teste do
  fallback global mantém cobertura de User e demais commands; histórico passa a
  ter cobertura no Bloc, não depende mais de CommandIt.
- Mocks públicos já existentes em test/support foram reutilizados, sem doubles
  locais nem testes de widgets/Modular.

## Verificação

- `flutter pub get`: passou.
- Testes do Bloc: 32 cenários passaram, incluindo Futures controlados, ciclos
  substituídos, falhas antigas, recuperação, User, fechamento e paginação histórica.
- `flutter test`: 766 sucessos e as mesmas duas falhas HTTP do baseline:
  - `http_client_test.dart`: returns an unknown failure for a Dio transport exception.
  - `signed_url_status_test.dart`: returns status zero on connection failure.
- `flutter test test/architecture`: seis testes passaram; domínio agora também
  bloqueia Dio/Bloc/flutter_bloc/bloc_concurrency, e apresentação bloqueia Dio.
- `flutter analyze`: somente dez infos de deprecated_member_use em Messaging e
  seus testes, surgidos com a atualização externa de Firebase. Nenhum issue da Dashboard.
- `openspec validate migrate-dashboard-to-bloc --strict`: passou após revisão do escopo.
- `git diff --check`: whitespace no pubspec.yaml de atualização externa; não foi
  descartado ou reformatado trabalho fora da migração.

## Validação visual pendente

Maestro listou simuladores iOS e Chromium, todos com connected=false. Inspeção do
Chromium retornou elementos vazios (schema ios), sem app/hierarquia utilizável.
O viewer foi informado em http://127.0.0.1:9999/. Não se afirma validação de fluxos
autenticados, skeletons ou navegação pelo Maestro. Requer iniciar dispositivo/app
com sessão de teste para concluir a tarefa 5.4. O catálogo de previews foi adaptado,
mas não substitui essa validação.

O launcher de previews compilou e serviu em localhost, sem cliente conectado.
Registrou “Null check operator used on a null value” sem stack suficiente para
atribuir a origem; isso não foi tratado como validação visual bem-sucedida.
O processo de preview iniciado nesta sessão foi encerrado, preservando os arquivos
gerados locais. A opção --web-port não existe nesse launcher; a execução válida
usou somente `dart run tool/widget_preview.dart`.

## Comparação de complexidade

Baseline executável: 571 linhas no mixin + 52 no command de limite = 623 linhas.
Nova coordenação: 274 no Bloc + 62 no estado + 10 nos eventos + 85 no mixin de
lifecycle/navegação = 431 linhas, incluindo estado explícito e eventos.
Foram eliminados os cinco commands da Dashboard, validações de snapshots de
início/terminal, listeners de execução/results, Listenable.merge e microtasks
de recarga pendente. O mixin não mantém dados nem fases financeiras.

Na implementação inicial o piloto reduziu a coordenação em aproximadamente 31%, sem somar os cortes nas
seções. Não é recomendação para expandir Bloc a outras telas antes da validação
visual pendente. Cancelamento de rede continua um trabalho futuro separado.

## Correção após reprodução com histórico grande

O log real fornecido pelo usuário mostrou a consulta do limite percorrendo todo
o histórico em páginas de 30 até atingir HTTP 429. A cobertura anterior validava
a varredura, mas não seu custo de rede; isso era insuficiente.

O backend local já aceita `sort=occurred_on` e `page[size]=1`, confirmado em
GetAllExpenseRequest e na ordenação do EloquentExpenseRepository. A consulta
do limite agora faz exatamente essa leitura, sem seguir next. Expense repository
e data source recebem sort opcional sem alterar chamadas existentes; o parâmetro
explícito prevalece sobre sort da continuação. Não houve alteração no backend
nem implementação de cancelamento HTTP.

A rota também fornece factory estável por tear-off; uma nova closure a cada
rebuild não deve reinicializar o Bloc no didUpdateWidget.

Testes de regressão verificam cinco leituras na abertura, independentemente do
tamanho do histórico, nenhuma continuação para limite, datas civis, erro auxiliar,
delegação e serialização de sort. As três suítes afetadas passaram (121 testes).
Suíte completa após a correção: 770 sucessos, as mesmas duas falhas HTTP do
baseline. Analyzer mantém somente os dez avisos externos de Messaging. OpenSpec
strict passou. Validação no simulador com a nova versão ainda não foi realizada.

cached_query não foi adicionado: cache/deduplicação pode reduzir recargas da
mesma chave, mas não corrige uma primeira carga que percorre cursores diferentes.

## Navegação direta nos widgets de ação

Por solicitação do usuário, DashboardScreen e seus descendentes deixaram de
receber callbacks de navegação. Avatar, menu, FAB, “Ver tudo” e cards de categoria
chamam context.pushNamed diretamente. O módulo somente registra dependências e
compõe a tela. Notificações fica desabilitado enquanto não houver destino real.

BlocProvider.value compartilha o Bloc da screen sem assumir seu fechamento.
Retornos de User/Settings reconsultam User sob montagem e identidade válidas.
Cadastro/listagem preservam o mês e somente solicitam recarga no retorno quando
houve mutação confirmada, incluindo hold. Metrics recebe período civil e notifica
onExpensesChanged sem importar Dashboard ou seu Bloc.

Análise das features alteradas passou; análise global mantém os dez avisos
preexistentes de Messaging. Suíte completa: 770 sucessos e as mesmas duas falhas
HTTP preexistentes. Maestro listou o simulador conectado, mas inspect_screen
falhou com RangeError de profundidade máxima 32; interação permanece não validada.

## Refatoração após revisão de legibilidade

- Preservadas todas as alterações locais encontradas, inclusive mudanças de
  formatação/ordenação durante a revisão. Nenhum contrato de repository, core
  HTTP, dependência ou rota foi alterado nesta etapa.
- Eventos concretos substituem enum de intenção e offset público; todos os
  consumidores foram atualizados na mesma alteração.
- Seis flags de execução/erro foram substituídas por uma fase financeira e dois
  status auxiliares. `recoveryFailed` explicita a espera de User após outra falha,
  sem liberar retry ou aceitar resultados irmãos.
- Separados início do ciclo, preparação do período, consultas das três seções e
  conclusão da recuperação. O handler de User não finaliza mais fases financeiras.
  A recuperação aguarda a leitura vigente pelo stream e revalida ciclo/emitter.
- Future.wait com eagerError encerra a espera na primeira falha. Publicações
  posteriores exigem ciclo, emitter e fase válidos; requisições não são canceladas.
- Falhas tipadas de finanças, User e histórico preservam a mesma ErrorsEntity,
  inclusive listas vazias e metadados. Exceções inesperadas usam erro desconhecido.
- Mantidos primary constructors, imports package:cordato, enums com sufixo Enum,
  UI com material_ui, mixin restrito ao lifecycle/refresh e ausência de comentários
  de código. Sem BaseBloc, estado global, testes de widgets ou novos doubles.
- A melhoria é no modelo e na separação de responsabilidades, não em minimizar
  linhas: a coordenação anterior tinha 257 linhas no Bloc; agora são 281, com
  métodos menores, fases explícitas e preservação de erros.

### Verificação desta revisão

- Baseline focal antes da alteração: 32 testes do Bloc passaram.
- `flutter pub get`: passou, sem introdução de dependências.
- Testes do Bloc: 44 cenários passaram; 12 novos cobrem transições emitidas,
  recuperação, falhas preservadas, substituição de User e fechamento durante espera.
- `flutter analyze lib/features/dashboard test/features/dashboard`: sem issues.
- `flutter analyze`: os mesmos dez infos de deprecated_member_use de Messaging
  já registrados, sem novos findings da Dashboard.
- `flutter test`: 782 sucessos e as mesmas duas falhas HTTP anteriores, ambas
  esperando status 0 e recebendo 500 em http_client_test.dart e signed_url_status_test.dart.
- `flutter test test/architecture`: seis testes passaram.
- `openspec validate migrate-dashboard-to-bloc --strict`: passou.
- `git diff --check` limitado aos arquivos/diretórios desta revisão: passou.
- Maestro encontrou iPhone 17 Pro conectado, mas inspect_screen novamente
  falhou com `RangeError: Value exceeds the maximum depth of 32`. Não foi possível
  validar os fluxos visuais; tarefa 5.4 permanece pendente, sem afirmar cobertura.

## Simplificação da orquestração após segunda revisão

- Bloc reduzido de 284 para 244 linhas, sem transferir código para novos arquivos.
  Removidos encaminhamentos de início, preparação e conclusão; a sequência fica
  no handler. As três consultas financeiras ficam juntas, no mesmo helper.
- Removidos IDs opacos que duplicavam o cancelamento lógico do restartable.
  Cada emitter é exclusivo do handler; isDone, fechamento e fase válida protegem
  resultados e falhas. Isso não cancela transporte nem dispensa os guards pós-await.
- Recuperação não observa o próprio stream. Uma barreira de conclusão de User
  permanece enquanto leituras são substituídas; somente a vigente a libera.
  Fechamento também a libera, sem permitir publicação pelo handler invalidado.
- copyWith apenas copia atributos. Limpeza de dados é explícita no início do
  handler; erros anuláveis são substituídos/limpos explicitamente por callbacks.
- Preservadas convenções, contratos e alterações externas, sem novas dependências,
  Blocs, mixins ou coordenadores.
- 47 testes da Dashboard e seis de arquitetura passaram. Os três novos cenários
  verificam recuperação com User novo antes do antigo concluir, recuperações
  sucessivas e ausência de limpeza implícita ao copiar fase/status.
- pub get passou; análise focal sem issues. Análise global mantém os mesmos dez
  infos de Messaging. Suíte completa: 785 sucessos e as mesmas duas falhas HTTP
  preexistentes de status 500 versus 0. OpenSpec strict e diff check focal passaram.
- Maestro conseguiu inspecionar a Dashboard no iPhone conectado nesta revisão,
  sem RangeError. O build do simulador não foi atualizado por esta execução;
  inspeção não é validação dos fluxos da versão alterada. Tarefa 5.4 segue pendente.

## Carga atômica aprovada pelo usuário

O usuário dispensou publicação independente das seções e aprovou a alternativa
mais simples: loading, conteúdo completo ou erro, com retry como carga normal.
Esta decisão substitui as políticas anteriores de falha imediata, User independente,
barreira de conclusão, status auxiliares e fases de recuperação descritas no histórico.

- Um handler restartable atende todos os eventos, com filtro antes de cancelar.
  Cargas financeiras consultam User/limite em paralelo e depois as três seções
  em paralelo; somente a conclusão publica ready ou failure. São cinco leituras
  também na troca de mês, aceitando esse custo para manter uma sequência única.
- User/Settings com conteúdo pronto relê somente User e preserva os dados
  financeiros; em loading/erro substitui a carga inteira sem aguardar a anterior.
- Removidos barreira, status auxiliares, fases especiais, copyWith e helper inicial
  do Bloc. Estado normaliza o mês atual e a seleção inicial. Durante validação,
  o usuário retirou o relógio opcional; alteração preservada e datas determinísticas
  passaram a ser configuradas somente nos testes pelo emit do Bloc.
- Falhas auxiliares usam fallbacks. Falha de histórico conserva a seleção e
  desabilita a seta anterior; vazio bem-sucedido ajusta seleção para o mês atual.
  Left financeiro conserva a ErrorsEntity original, incluindo lista vazia/metadados.
- Bloc: 244 para 175 linhas na revisão final, incluindo ajustes locais de estilo;
  estado: 78 para 33 linhas. Sem mover coordenação para arquivos novos.
- Testes reescritos para o comportamento aprovado: 36 cenários passaram, incluindo
  publicação única, espera das seções em falha, limites civis, cinco leituras,
  fallbacks, retry normal, perfil, substituição e fechamento.
- pub get passou. Análise focal limpa; análise global mantém somente dez infos
  preexistentes de Messaging. Suíte completa: 774 sucessos e as mesmas duas falhas
  HTTP antigas (status 500 recebido versus 0 esperado). Seis testes arquiteturais
  passaram. OpenSpec strict e diff check focal passaram.
- Build iOS debug para simulador passou. Aplicativo atualizado instalado e aberto
  pelo Maestro sem clearState/clearKeychain. A inspeção inicialmente apresentou
  RangeError, mas funcionou após launchApp e mostrou Welcome sem sessão autenticada.
  Não foram executados fluxos financeiros ou login sem credenciais fornecidas;
  a tarefa 5.4 permanece pendente para a versão autenticada, sem alegar validação
  visual da Dashboard.

## Fechamento nativo e mês padrão no state

- Mantido somente _opened como controle local de abertura única. Removidos
  _closing, _closeFuture e override de close; isClosed/emit.isDone protegem
  conclusões após fechamento pelo próprio Bloc.
- DashboardState() captura a data uma vez e fornece o mês civil padrão para
  referência e seleção. O Bloc inicializa com super(DashboardState()).
- Retirada do teste a exigência de Future idêntico em chamadas repetidas de close;
  preservados os cenários de fechamento com histórico ou seções pendentes,
  verificando isClosed imediato e ausência de publicações tardias.
- 36 testes da Dashboard passaram. Análise global mantém somente os dez infos
  antigos de Messaging. Suíte completa: 774 sucessos e as mesmas duas falhas HTTP
  preexistentes de status 500 versus 0. Sem alterações visuais nesta etapa.
