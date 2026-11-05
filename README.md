# Cordato

Aplicativo Flutter de finanças pessoais e familiares.

> Cada pessoa é dona dos próprios dados. A família é uma lente de leitura,
> nunca dona do dinheiro ou autorizada a escrever nos dados de outro membro.

## Verificação atual

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
- Bloc com eventos concretos e estados sealed imutáveis. Sign-in usa ownership
  pelo escopo Modular; telas ainda não migradas mantêm ownership local. Formulário
  mantém entrada e validação, sem copiar loading ou resultado do Bloc.
- Testes de repository, Bloc, widget, composição Modular e E2E junto à feature/tela.

CommandIt, Either, data sources de delegação e repositories concretos em
application descritos em documentos históricos não são alternativas aprovadas
para código novo nem dependências a restaurar.

Leia [ARCHITECTURE.md](ARCHITECTURE.md) para decisões e fronteiras e
[AGENTS.md](AGENTS.md) para convenções de contribuição.

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

| Parte | Estado atual |
| --- | --- |
| Backend em `backend/` | Contas, despesas próprias e view mensal de métricas; contrato nativo PocketBase. |
| Cliente Flutter em `lib/` | Authentication, Session, User, Expense e Metrics usam endpoints nativos PocketBase. |
| Sugestões | GET filtrado do histórico pessoal de despesas, sem endpoint customizado. |
| Metrics e Dashboard | Total e distribuição mensal por categoria calculados em SQL na view `metrics`; UI e navegação preservadas. |
| Budget e Family | Planejados; não implementados no backend atual nem nas features Flutter. |
| Integração e operação | Aplicação da migration da view, homologação integrada e validação no Dokploy ainda pendentes. |

Trocar apenas `BASE_URL` não integra o aplicativo ao PocketBase. Autenticação,
erros, paginação, datas e recursos disponíveis possuem contratos diferentes.
O Flutter mantém `HttpClient`/`IHttpClient` com Dio, interceptors e o contrato HTTP
anterior nas operações não migradas. O SDK PocketBase não está integrado. O login
e o cadastro aceitam erros nativos PocketBase (400 por campo ou mensagem geral). Mantenha
`/api/` na base, por exemplo `https://pocketbase.cordato.cloud/api/`. Esta adaptação
não representa homologação integrada nem migração das sessões existentes.
Veja os [limites da integração](ARCHITECTURE.md#backend-pocketbase-e-limite-de-integração).

User consulta, altera e exclui a conta por `collections/users/records/{id}`.
Nome e avatar usam JSON plano; avatar permanece uma seed textual, sem upload.
Nome vazio é exibido como `Trocado`, sem gravar esse fallback. A edição exige
2–32 caracteres após trim e reconhece erros nativos de nome no campo.
A exclusão aguarda HTTP 204 e a limpeza local do storage; Session redireciona.
A cascata das despesas está configurada no backend e requer homologação real.

### Alterar senha

Dados pessoais oferece **Alterar senha**, com senha atual, nova senha e
confirmação. Cadastro, login, recuperação e troca compartilham a regra de
**6–16 caracteres**, com minúscula ASCII, maiúscula ASCII e número ASCII.
A entrada é preservada, inclusive espaços; a contagem usa code points Unicode.
A nova senha não pode ser igual à atual e a confirmação precisa coincidir.

A alteração usa PATCH nativo autenticado de `users`. Após sucesso, a sessão local
é encerrada e o app abre o login com “Senha alterada. Entre novamente”. Se a
limpeza local falhar, **Tentar novamente** repete somente o logout, sem reenviar
a alteração. Senhas não são armazenadas nos estados nem impressas nos logs HTTP.
Não inclui mudança no backend, deploy ou homologação em dispositivo.

Verificação após desfazer os ajustes de teclado/rolagem: `flutter analyze` sem
problemas; 634 testes focados aprovados.
A suíte completa teve 1277 aprovados e as cinco falhas já registradas nas descrições
de categorias de Expense. O catálogo de previews compilou/serviu sem cliente
conectado; revisão visual, teclado e fluxo real em dispositivo continuam pendentes.
Detalhes em [verification.md](openspec/changes/add-authenticated-password-change/verification.md).

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
transacionais, sem backups próprios do banco, anúncios, analytics ou assinatura.
O conteúdo distingue os resumos financeiros do próprio usuário de analytics de
comportamento e não declara ausência de logs técnicos ou de retenção em terceiros.
Conforme a [documentação do Resend](https://resend.com/security/gdpr), seus dados
são armazenados nos EUA; mensagens/logs têm retenção de 30 dias nos planos Free,
Pro e Scale e backups próprios de 7 dias. Configuração da conta, provedores de
hospedagem e eventuais exceções precisam ser conferidos antes da publicação.

Pendências de lançamento, não resolvidas pelas telas:

- Revisar juridicamente os documentos e as bases legais, incluindo tratamento
  de adolescentes e mecanismo aplicável à transferência internacional do Resend.
  O DPA europeu do provedor não comprova, por si só, atendimento à LGPD/ANPD.
- Confirmar faixas de público-alvo no Play Console, sem direcionamento a crianças;
  isso não equivale a declarar automaticamente classificação indicativa ou idade mínima.
- Auditar retenção de logs da hospedagem, atendimento de suporte e controles de
  rastreamento de e-mails no Resend; a ausência de analytics no app não comprova
  que rastreamento de aberturas/cliques esteja desativado no provedor.
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

Refinamento visual dos resumos: `InformationSummaryWidget` substitui o card
compacto com ícone lateral por uma composição vertical de largura integral,
tipografia de corpo, espaçamento maior e superfície/borda do tema. A Ajuda não
repete links de Termos e Privacidade no rodapé; os acessos pela Welcome e pelas
Configurações permanecem. `flutter pub get` e `flutter analyze` passaram; o mesmo
lote focado acima teve 48 aprovados. Os previews isolados dos resumos compilaram
e foram servidos até o timeout de 60 segundos, sem cliente conectado ou inspeção
visual. A suíte completa não foi repetida neste refinamento; as cinco falhas
anteriores de Expense permanecem fora do escopo.

## Estado Do Projeto

**O checkout está em transição arquitetural. Testes de composição não substituem
a validação da navegação em dispositivo.**

Authentication já possui contrato em application e repository em infrastructure.
Sign-in, cadastro e reenvio usam Bloc, controle de submissões concorrentes, falhas tipadas
e testes de Bloc/tela. Cadastro mantém erros por campo, retry manual e navegação
para confirmação sem criar sessão. Ao abrir a confirmação após o cadastro, o
primeiro envio de verificação é automático; cooldown de 60 segundos começa após
sucesso. Falha informa que a conta foi criada e permite retry manual imediato,
sem repetir o cadastro nem criar sessão.
Cadastro envia `email`, `password` e `passwordConfirm` para
`collections/users/records`, sem token. A resposta 200 é um record; o contrato
consome somente a conclusão, sem persistir dados ou autenticar. O envio de e-mail
usa uma operação separada (`collections/users/request-verification`, 204),
disparada automaticamente pela confirmação e manualmente pelo botão Reenviar.
O ResendEmailBloc bloqueia o botão durante envio e cooldown; o cliente não garante
entrega na caixa de entrada.
Confirmação por link usa Bloc: recebe `token` pela query, envia POST para
`collections/users/confirm-verification` e trata 204 como sucesso e 400 como
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
Authentication. `signOut` aguarda a limpeza local do storage, sem request HTTP
ou revogação do JWT no servidor. Mantém confirmação, loading e retry manual em
falha de storage. O redirecionamento continua global por sessão.
Recuperação de senha usa o link “ou recupere sua conta” no sign-in, com somente
“conta” clicável. O envio por `collections/users/request-password-reset` exige
HTTP 204 e abre a etapa “Confira seu e-mail”, com mensagem neutra quanto à
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
formulário, aguarda `signOut()` para encerrar qualquer sessão local; falha de
storage bloqueia a ação e permite retry. Nova senha segue as regras do cadastro
e precisa coincidir com a confirmação. O POST
`collections/users/confirm-password-reset` envia `token`, `password` e
`passwordConfirm`, exige 204 e não autentica nem persiste sessão. Sucesso volta
automaticamente ao sign-in com toast; token inválido/expirado também redireciona.
Erros de campo ou rede preservam a tela e a entrada. O PocketBase invalida os
tokens de autenticação anteriores e pode marcar a conta como verificada conforme
seu contrato nativo. Token e senhas não ficam nos estados dos Blocs. O logger
omite as operações de recuperação e URLs com token, e mascara Authorization.

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
`AppScreen` apenas mostra o splash. Ao abrir com token persistido, faz POST
`collections/users/auth-refresh` e aguarda ID/token renovados no storage. Sem
token, não chama a API. 401 invalida somente o token enviado; 403 e falhas de rede
preservam o storage e levam ao fallback seguro, sem fingir sessão validada.
Chamadas simultâneas compartilham o refresh, sem retry automático. Uma mudança
recente do token tem precedência sobre a resposta antiga, com verificações antes
das gravações; o storage não oferece comparação/gravação transacional.
Falhas de storage não confirmam ausência: Root usa Welcome como fallback seguro
e mantém a observação. O interceptor também reconhece records nativos protegidos
de users/expenses, mas isso não migra seus repositories/payloads legados.

User já possui contrato em application, `UserException` e repository em
infrastructure usando HTTP/storage diretamente, sem `Either` ou data sources.
Consulta, nome, avatar e exclusão mantêm seus contratos de API; exclusão confirmada
aguarda a limpeza do storage. A tela de perfil agora usa `UserBloc` para consulta,
avatar e exclusão, com lifecycle próprio, debounce de dois segundos, confirmação
de exclusão, feedback único e bloqueio de operações concorrentes. A edição do
nome usa `EditBloc`, preservando validação, trim no formulário, erros 422 por
campo, entrada após falha e retorno do perfil atualizado após sucesso. User não
usa mais commands. Os testes de repository usam clients mockados, e os de
Bloc/tela usam o contrato do repository mockado. O teste composto do módulo
verifica os dois Blocs, edição e retorno com recarga do perfil.

Na Dashboard, nome e avatar usam o mesmo contrato de User/PocketBase e são
consultados novamente ao voltar de dados pessoais ou configurações. Falhas nessa
consulta levam à tela de erro global, inclusive durante atualização; não são
tratadas como ausência de usuário. Retry é manual e recarrega a Dashboard completa.
Nome vazio continua exibindo `Trocado`.

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
infrastructure chamando HTTP diretamente, sem Either ou data source. Consulta
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
infrastructure com HTTP/storage diretos, sem Either ou data source. Usa CRUD nativo
em `collections/expenses/records`, centavos inteiros positivos, datas civis e
filtros/paginação PocketBase. Criação lê o ID atual do storage para `owner` e envia
categoria selecionada, com `other` como padrão quando ausente; atualização envia
somente os campos fornecidos, incluindo categoria, sem trocar proprietário.
A data escolhida é enviada como meia-noite UTC e lida como
data civil, sem conversão de fuso. Consulta,
criação e atualização retornam entidades; exclusão retorna `Future<void>` e só
conclui após HTTP 204. `AmountValueObject.create` retorna o valor diretamente e
rejeita centavos não positivos com `ArgumentError`. Parsing e falhas inesperadas
propagam. `ExpenseBloc` substitui consulta/criação/edição e `ExpensesBloc` substitui
listagem/exclusão, com estados sealed, factories estáveis e lifecycle das telas.
Mantém validação, erros PocketBase 400 e legados 422 por campo, retry manual,
cadastro contínuo por hold,
filtros, paginação opaca e confirmação de exclusão sem remoção otimista. Consultas
obsoletas não sobrescrevem filtros recentes; mutações pendentes bloqueiam duplicatas.
Listagem navega diretamente pelo `BuildContext`, sem callbacks nos argumentos de
rota; Dashboard e métricas recarregam ao retornar da listagem, mesmo sem alteração.
Expense não depende mais de CommandIt. Dashboard consome resultados diretos de
todos os contextos consultados.

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

Os testes de responses cobrem DTOs e exceções HTTP atuais, sem `Either` ou
`response<T>`. Messaging expõe `register()` e `onRegistered` com stream de FIDs,
sem usar as APIs depreciadas de token.
Todos os destinos de `RouteEnum` estão registrados em `app_module.dart`, incluindo
Dashboard, Settings, User e Expense. Testes de composição verificam as rotas e a
resolução das dependências sem visitar módulos irmãos. Authentication e Expense
usam um único módulo sem path por feature, com URLs completas e binds root-owned;
isso elimina a colisão no escopo `/` e disponibiliza o contrato para logout.

Verificação atual após remover testes de UI, Maestro e servidores de fixtures:
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

O código existente inclui os seguintes fluxos, cuja disponibilidade depende da
conclusão da migração e da composição dos módulos:

- Boas-vindas, validação inicial de token persistido via auth-refresh e observação da sessão.
- Entrada/cadastro com e-mail e senha, confirmação por link e reenvio com cooldown.
- Perfil, edição do nome, avatar gerado com salvamento após dois segundos e
  exclusão da conta.
- Criação/edição de despesas, valor em centavos, data civil e cadastro contínuo
  por hold; listagem paginada com filtros de período/categoria e gestos de edição/exclusão.
- Dashboard mensal com métricas por categoria e seis despesas recentes.
- Configurações e sign-out com limpeza local aguardada, sem HTTP ou revogação remota.
- Tema claro/escuro, componentes compartilhados e previews.

`budget` e `family` são planejados, sem features Flutter implementadas.
`identity` não reproduz o backend legado; `chat` está fora do escopo.
O backend PocketBase tem schema e migrations neste repositório, em `backend/`.
As descrições dos fluxos Flutter acima não comprovam suporte pelo novo backend.

## Stack

- Flutter com Dart `^3.13.2` e primary constructors.
- `bloc`, `flutter_bloc` e `bloc_concurrency` para apresentação assíncrona.
- `flutter_modular` 7 para composição, DI e rotas.
- Material 3 via `material_ui`, fonte Inter e localização pt-BR.
- Dio para HTTP JSON:API e `flutter_secure_storage` para persistência segura.
- `flutter_test`, `bloc_test`, `mocktail` e `fake_async` para testes sem UI.

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

A API padrão **do cliente ainda não migrado** é `https://app.cordato.cloud/api/`.
Para outra base compatível com esse contrato:

```bash
flutter run --dart-define=BASE_URL=https://api.exemplo.com/api/
```

Preserve o prefixo `/api/`. `BASE_URL` é definido no build; reinicie o app após
alterá-lo. Confira também os overrides de `.vscode/launch.json`.

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

| Camada | Padrão |
| --- | --- |
| Domain/application | Regras puras e exceções, sem SDKs. |
| Infrastructure/repository | Mocks dos clients; payload, parsing, erros e persistência. |
| Bloc | Repository mockado; estados, concorrência, retry e fechamento. |
| Modular/rotas | Catálogo e resolução de dependências/factories sem montar UI. |
| Architecture | Imports, fronteiras de contextos e direção das dependências. |

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
flutter test test/architecture test/features/expense test/features/dashboard test/features/metrics test/features/core/infrastructure/clients/http/interceptors/session_interceptor_test.dart
```

### Histórico De Migrações E Verificações

Os números e bloqueios abaixo registram etapas anteriores; não descrevem o
checkout atual. O resultado vigente está em **Estado do projeto** e a referência
de implementação é `ARCHITECTURE.md`, não os comandos/rotas históricos.

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

Esta seção descreve o **código Flutter atual**, não o contrato PocketBase.
As regras e a autenticação do novo serviço estão em
[`backend/README.md`](backend/README.md#coleções).

O repository de Authentication usa endpoints nativos PocketBase para autenticação
e verificação e persiste token/ID por `IStorageClient`, aguardando ambas as escritas antes de concluir.
Não há garantia transacional entre elas. Bloc e UI não recebem token nem DTO.
Falhas esperadas viram `AuthenticationException`; erros inesperados propagam,
e o Bloc fornece fallback seguro e `addError` sem conhecer SDKs de telemetria.

Session valida o token persistido ao abrir por auth-refresh e observa mudanças
locais para entrada e redirecionamento global. Não há refresh periódico, retry
automático de requests ou guard Modular. Um 401 protegido remove
somente o token enviado se ainda for o armazenado, preservando o ID.
Sign-out aguarda a limpeza local de todo o storage seguro, sem HTTP.
Confirmação de e-mail envia token por POST sem Bearer e não cria sessão.

O `talker_bloc_logger` usa o Talker compartilhado por meio de `AppBlocObserver`,
instalado no bootstrap somente em debug. Registra criação, fechamento, tipos de
eventos e transições, sem imprimir os dados completos; erros inesperados mostram
somente tipo e stack trace, omitindo mensagens potencialmente sensíveis.
Verificação da configuração: `flutter pub get` concluído, `flutter analyze` sem
issues e 20 testes focados de arquitetura/logger aprovados. A suíte completa teve
1014 aprovados e 5 falhas fora deste escopo: descrições de categorias com 4 palavras,
enquanto os testes exigem 5–6. `git diff --check` passou.

O logger HTTP debug está configurado sem bodies/headers; não use credenciais reais
em capturas compartilhadas. O logger não é instalado em release. Não adicione
segredos ao código ou fixtures. Valores financeiros são centavos inteiros de BRL,
e datas financeiras preservam seus componentes civis, sem conversão de fuso.

## Notificações E Release

Notificações locais possuem client no core. Não há integração de push remoto
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
