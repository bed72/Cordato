# Cordato

Aplicativo Flutter de finanças pessoais, exclusivamente local, em transição
para Drift/SQLite. Estado documental revisado em **23/11/2026**.

## Transição de persistência

Esta etapa entrega a fundação Drift em
`lib/features/core/infrastructure/clients/database/`, com schema versão 1,
foreign keys, perfil único e despesas vinculadas com `ON DELETE CASCADE`.
O `coreModule` registra o client como singleton lazy, sem abertura assíncrona no
`main`. UserRepository, ExpenseRepository e MetricsDao já usam Drift. User usa `id`, `name`
e `seed`; despesas usam IDs inteiros em contratos/UI e vínculo interno com perfil.
Não migra dados de Localstore/ToStore.
Os arquivos de dados legados não são lidos nem apagados por esta fundação.

Nas duas tabelas, o ID é inteiro `AUTOINCREMENT`, gerado pelo SQLite;
`expenses.profile_id` também é inteiro. IDs confirmados não são reutilizados após
exclusões no mesmo banco. A seed continua aleatória.
Sem usuários, o schema não publicado foi consolidado na versão 1, sem migrações
de versões SQLite experimentais anteriores. Inclui default de data civil local
`date('now', 'localtime')` e CHECK de categorias alinhado ao CategoryEnum por
teste arquitetural. Datas explícitas continuam prevalecendo.
Arquivos experimentais incompatíveis, inclusive versões 2/3 ou versões 1 com
outras definições, precisam ser recriados manualmente. O app não apaga arquivos,
não faz downgrade nem reset automático.

Metrics e a composição global agora consultam o mesmo SQLite de User/Expense.
O app e o suporte de testes não importam mais Localstore. Metrics não exige
View ou tabela própria.

O contrato aprovado é um perfil local com ID, nome e seed. Inicialmente:
ID novo, nome `Cordato` e seed aleatória. Editar nome/seed preserva o ID.
No futuro, apagar os dados removerá o perfil e despesas por cascade e criará
outro perfil padrão com novos ID/seed numa única transação. A exclusão ainda não
está implementada. O banco começa vazio e UserRepository cria o perfil na primeira
consulta, sem inicialização no main ou no client.

O client abre SQLite sob demanda em Application Support/cordato.sqlite, em
isolate separado. Resolver o singleton não abre o arquivo nem cria perfil.
A coordenação de fechamento assíncrono pelo root permanece pendente; a API atual
de registro do Modular não expõe callback de descarte. Não há IA, views, criptografia, backup ou garantia de
apagamento físico adicionados nesta etapa.

```bash
flutter pub get
dart run build_runner build
flutter test test/features/core/infrastructure/clients/database/ --reporter failures-only
```

Versione `database_client.g.dart` após alterar tabelas. Detalhes e precedência
dos contratos estão em [ARCHITECTURE.md](ARCHITECTURE.md#fundação-drift).

### Resumo das decisões implementadas

- Banco único lazy, com execução SQL em isolate e foreign keys habilitadas.
- Categorias fixas definidas pelo enum de Expense e protegidas por CHECK no SQLite.
- IDs int gerados pelo banco; seed de avatar aleatória, independente do ID.
- Criação/edição de Expense usam RETURNING sem SELECT preparatório; delete usa
  linhas afetadas. Refresh do widget ocorre após confirmação da mutação.
- SuggestionsDao executa uma consulta SQL: filtra, ordena, limita às 30
  correspondências e só então deduplica. Matching literal usa cordato_lower,
  preservando Unicode e parâmetros vinculados.
- Data omitida usa default local do SQLite; data explícita preserva o dia civil.
- `_hasUpdates` distingue campo omitido de descrição vazia ou categoria other.
- MetricsDao filtra perfil/mês e agrega centavos por categoria em uma única
  consulta SQL parametrizada. Total e percentuais derivam dos mesmos grupos.

Contratos detalhados ficam na [arquitetura](ARCHITECTURE.md#persistência).
Resultados atuais estão em [Verificação e pendências](#verificação-e-pendências);
as etapas anteriores foram consolidadas no
[histórico Drift](docs/history/drift-transition.md).

## Licença e publicação do código

Este projeto é distribuído sob a [licença MIT](LICENSE), com copyright de
**Gabriel Ramos**. Dependências, fontes, ícones e outros materiais de terceiros
mantêm suas próprias licenças; a MIT não as substitui. Os avisos do site estão em
[`site/public/third-party-notices.txt`](site/public/third-party-notices.txt) e a
fonte Inter em [`site/public/fonts/OFL.txt`](site/public/fonts/OFL.txt).
Pacotes como Syncfusion continuam sujeitos às condições de seus fornecedores.

Antes de tornar o repositório público, consulte a
[revisão de credenciais de 23/11/2026](docs/security/publication-review-2026-11-23.md).
Excluir uma chave do código atual ou adicioná-la ao `.gitignore` não a remove do
histórico. A revisão não altera visibilidade nem autoriza reescrita do Git.

## Estado atual

- Perfil local único em SQLite: ID interno estável, nome e seed de avatar,
  sem conta autenticada ou e-mail.
- Despesas manuais: criação, edição, exclusão, filtros, paginação e sugestões
  baseadas no histórico local.
- Resumo mensal e distribuição por categoria com dinheiro em centavos inteiros
  de BRL, derivados das despesas SQLite.
- Entrada na Dashboard, sem autenticação.
- Widget Android/iOS com resumo do mês e atalho para Nova despesa.
- Configurações com Perfil local, Informações e Apoio voluntário via Pix.
- Termos, Privacidade e Ajuda com conteúdo local.

Authentication, Session, Welcome, PocketBase, backend, worker, gravação de áudio e IA foram
removidos. Exportação CSV e compartilhamento também foram removidos. Budget e
Family são planejados, não funcionalidades disponíveis.

**Não há sincronização, importação remota, exportação ou backup/restauração pelo
app.** Dados podem ser perdidos ao desinstalar ou trocar de dispositivo. Cópias
do sistema dependem do dispositivo; arquivos exportados anteriormente não são
backups restauráveis. Não há garantia adicional de criptografia ou recuperação.

## Site público

O site do Cordato fica em [`site/`](site/README.md), no mesmo repositório do app.
Contém apresentação, Política de Privacidade, Termos e Ajuda, sem login, exclusão
de conta ou backend. É HTML/CSS estático, sem framework, JavaScript ou build para
publicar; não é Flutter Web e não participa da compilação Android/iOS.

```bash
node site/tools/serve.mjs
```

Os documentos web refletem a versão local e distinguem os registros técnicos
da hospedagem dos dados armazenados pelo aplicativo. O site não lê o banco local.
Alterações em app e site podem ser revisadas no mesmo PR.

A CI do site usa `.github/workflows/site-test.yml`. A publicação estática usa
`.github/workflows/site-pages.yml`, manual e somente na `main`, sem alterar o
release Android. O upload usa diretamente `site/public/`, sem instalar npm.
GitHub Pages, domínio e DNS exigem configuração externa; a cópia do site não
publica nem muda a visibilidade do repositório. Consulte
[`site/deploy/README.md`](site/deploy/README.md).
O destino escolhido para o site é o endereço gratuito
`https://bed72.github.io/Cordato/`, sem domínio personalizado ou alteração de DNS.

## Desenvolvimento

Requisitos: Flutter **>=3.50.0**, Dart **^3.14.0**, ferramentas nativas da
plataforma. Android exige JDK 21 e SDK configurados; iOS exige macOS/Xcode.
As versões efetivamente resolvidas estão em `pubspec.lock`.

```bash
flutter pub get
flutter analyze
flutter test --reporter failures-only
flutter run
```

O app atual não precisa de servidor, credenciais de runtime ou `BASE_URL`.
Os testes não montam UI; a execução em dispositivo é uma verificação separada.
As dependências da fundação Drift são públicas. O legado usava acesso Git HTTPS
ao repositório privado
[`bed72/localstore`](https://github.com/bed72/localstore). O checkout atual não
exige esse acesso para instalar dependências. O workflow Android ainda contém
uma exigência legada de secret; consulte o [guia Android](android/README.md).
Não coloque tokens no pubspec.

### Inicialização e persistência

`main` monta o app sem preparar perfil ou storage. O `appModule` compõe o
`coreModule`, que registra `DatabaseClient` como singleton lazy. UserRepository
recebe essa instância pelo construtor e inicializa o perfil sob demanda.
MetricsDao recebe o mesmo banco compartilhado, sem inicializar perfil.

O client usa `Application Support/cordato.sqlite`. As consultas de sugestões
dependem da função Unicode registrada no setup; executors nativos injetados usam
`setup: DatabaseClient.configureConnection`. O client não importa DAOs das features.
Não há leitura ou exclusão de arquivos Localstore legados.

### Perfil e despesas

O UserRepository já usa a tabela `profiles` em SQLite. A primeira leitura cria,
em transação, ID inteiro atribuído pelo SQLite, nome Cordato e seed aleatória.
Somente a seed usa Random.secure (16 bytes em hexadecimal). Leituras seguintes
preservam o perfil. Updates transacionais alteram somente nome/seed fornecidos,
preservando ID e campos omitidos. Não há normalização, cache adicional,
inicializador externo nem exclusão de conta.

Falhas operacionais de storage geram mensagem segura; erros de SQL, constraints,
corrupção ou programação não viram defaults e não disparam retry/reset automático.
UserResponse converte registros tipados sem expor Drift no domínio ou apresentação.

Despesas usam tabela `expenses`, com ID inteiro gerado pelo SQLite, valor inteiro positivo,
categoria padrão `other`, descrição opcional e data civil obrigatória.
O SQLite define hoje no fuso local quando
a data de criação é omitida. Datas explícitas preservam os componentes do calendário,
sem deslocamento de fuso. O repository aplica trim à descrição, preservando
o comportamento anterior. Filtros, ordenação, paginação e sugestões são
processados em SQL, sem IA. Sugestões usam uma única consulta
por um DAO, com busca literal Unicode no SQL, limite de 30 correspondências e
deduplicação posterior por janela. Não há loop de paginação em Dart.
Criação vincula o perfil por INSERT SELECT RETURNING; update usa UPDATE RETURNING
e delete verifica linhas afetadas, cada um sem SELECT preparatório. Se User ainda não o
inicializou, retorna falha segura de perfil ausente, sem criar outro perfil;
o usuário pode tentar novamente manualmente. Não foi adicionado bootstrap no
atalho ou formulário.
O formulário mostra uma sugestão por vez; o X fecha a sugestão sem aplicar
seus dados. Selecioná-la continua preservando a data do formulário.
Updates transacionais gravam somente campos fornecidos e preservam os demais.
O widget recebe pedido de refresh somente após commit. IDs ausentes e falhas
operacionais têm mensagens locais; erros SQL/corrupção não geram defaults.

Metrics agrega a tabela SQLite usada por Expense em uma consulta no MetricsDao,
com filtro por perfil/mês e SUM/GROUP BY por categoria.
Seu contrato mensal permanece somente leitura, sem tabela própria, View ou cache.
As entidades usam `total` em centavos; percentuais são calculados no repository.
Sem filtros usa o mês civil atual; filtros explícitos exigem um mês completo.
Um mês vazio retorna zero apenas após leitura bem-sucedida. Falhas não viram
zero nem disparam retry automático.

## Widget da tela inicial

Android usa RemoteViews; iOS usa a extensão WidgetKit `AddExpenseWidget`.
Instale uma compilação nativa e adicione **Adicionar despesa** pela galeria
do sistema. Hot reload não instala ou atualiza a extensão.

O toque abre Dashboard → Nova despesa, sem login. Uma criação já aberta mantém
a entrada; edição por ID não é confundida com criação. O resumo mostra somente
o mês atual, independentemente do filtro histórico da Dashboard.

O fluxo solicita atualização ao iniciar e após confirmação das mutações SQLite.
Create/update aguardam commit; delete aguarda a instrução atômica. Publicar um
novo resumo consulta Metrics sobre as despesas SQLite, preservando revisões nativas.
Não há consulta HTTP ou cadastro em background, refresh periódico ou retry
automático. Falhas preservam o último resumo válido; mês incompatível mostra
**Abra para atualizar**. A virada do mês depende do agendamento nativo.

O snapshot compartilhado contém somente mês e centavos inteiros na chave JSON
`monthly_summary`, sem perfil ou credenciais. Revisões bloqueiam publicações
obsoletas. `setMonthly` habilita a publicação nativa;
não representa autenticação ou sessão.

No Flutter, Root usa `WidgetLaunchBloc` e `WidgetSyncBloc`, seus eventos/estados
e os contratos `IWidgetLaunchRepository` e `IWidgetSyncRepository`. Arquivos usam
`widget_*`, sem prefixo `home_`. O plugin `home_widget`, o parâmetro nativo
`homeWidget=true` e os nomes Android/iOS não foram renomeados.

Android permite redimensionamento conforme a grade do launcher. iOS oferece
famílias pequena e média. Temas, tamanhos compactos, valores longos, texto
ampliado, toques repetidos e virada do mês precisam de conferência manual.

Para distribuição iOS, Runner e AddExpenseWidget precisam da mesma equipe de
assinatura e do App Group `group.com.bed.cordato`; a extensão usa o identificador
`com.bed.cordato.AddExpenseWidget`. O registro na conta Apple e os provisioning
profiles são externos ao código.

Testes unitários das políticas nativas, sem UI:

```bash
dart run tool/test_home_widget_native.dart
```

Use `android` ou `ios` para selecionar uma plataforma. Não execute instâncias
concorrentes de `dart run`: os build hooks compartilham artefatos.
A limpeza de 22/11/2026 passou nos 39 testes Android e 27 testes iOS.

## Configurações, informações e apoio

Settings não possui Bloc, logout ou seção Dados. A tela **Pague-me um café**
(`/settings/support`) exibe QR Code Pix estático de valor livre e permite copiar
o código. O pagamento acontece no banco; o app não processa nem confirma
pagamentos. Confira chave e destinatário no aplicativo bancário.

Termos e Privacidade estão na versão **2.1, de 21/11/2026**, e a Ajuda acompanha
o uso local. O conteúdo está em
`lib/features/information/presentation/content/information_content.dart`.
Suporte e privacidade: `developer.bed@gmail.com`, Gabriel Ramos.
O suporte não tem acesso remoto ao banco local.

Revisão jurídica, publicação web e declarações do Google Play permanecem
verificações externas; textos e testes não comprovam conformidade ou aprovação.

## Arquitetura e contribuição

```text
Screen/Widget → Bloc → contrato em application
                            ↑
                 repository em infrastructure → DatabaseClient (User/Expense)
                                             → MetricsDao → DatabaseClient
                                             → client nativo do core
```

Domain e contratos são puros. Repositories retornam `Future<T>` e falhas
esperadas por exceções de aplicação. Não há wrapper genérico de CRUD, Either,
commands ou data sources intermediários.

Consulte:

- [ARCHITECTURE.md](ARCHITECTURE.md): composição, armazenamento, contratos,
  ownership e rotas.
- [AGENTS.md](AGENTS.md): convenções obrigatórias de implementação e testes.
- [android/README.md](android/README.md): assinatura, builds e release manual.
- [openspec/README.md](openspec/README.md): precedência e leitura das specs históricas.
- [Histórico da transição](docs/history/local-transition.md): verificações
  anteriores e funcionalidades substituídas.

Previews manuais usam tema e localização reais:

```bash
dart run tool/widget_preview.dart
```

`.widget_preview/` não é versionado. Compilar o catálogo não equivale a inspecionar
a interface.

### Organização dos testes

Testes de implementação devem espelhar `lib/features/` em `test/features/`,
mantendo caminho e nome do arquivo com sufixo `_test.dart`. Mocks e recursos
compartilhados ficam em `test/support/<feature>/`. Testes arquiteturais,
ferramentas e políticas nativas têm organização própria.

Há nomes/caminhos legados e suítes separadas por responsabilidade, detalhados em
[ARCHITECTURE.md](ARCHITECTURE.md#organização-e-espelhamento-dos-testes).
Isso não é uma medição de cobertura.

## Verificação e pendências

Verificação da consolidação do schema v1 em 23/11/2026:

| Comando | Resultado |
| --- | --- |
| `flutter pub get` | Concluído. |
| `dart run build_runner build` | Concluído; geração Drift validada. |
| `flutter analyze` | Sem problemas. |
| `flutter test --reporter failures-only` | 947 passando. |

Testes verificam criação do schema 1, alinhamento CHECK/enum, bloqueio de
categorias inválidas, sequências, foreign keys e reabertura/isolate.
Testes/fixtures exclusivos das migrações experimentais foram removidos.
Metrics tem testes reais de agregação, limites civis, overflow, falhas,
revisões/publicação nativa, reabertura e execução em isolate. A composição
verifica Expense → Metrics → Root e Dashboard sem montar UI.
Dados e sequências, rollback de transações, Unicode, parâmetros literais,
contagem de instruções e notificação após commit têm testes focados reais.
Isso não comprova build nativo, UI, durabilidade auditada ou prontidão de release.

### Pendências, sem autorização implícita para implementação

1. Coordenar inicialização do perfil antes de criação por atalho/formulário;
   hoje Expense não cria perfil e retorna `profile_not_found` quando ausente.
2. Definir fechamento assíncrono do banco pelo root.
3. Implementar a operação de apagar dados/recriar perfil, coordenação de
   operações pendentes e limpeza do widget. Cascade preparado não entrega a UI.
4. Revisar o passo legado de `LOCALSTORE_READ_TOKEN` no workflow Android;
   a dependência atual não o exige, mas o YAML ainda o exige.
5. Tratar separadamente views, IA offline, backup/restauração, builds atuais,
   assinatura iOS, testes de dispositivo e revisão de distribuição.

Scheme `cordato`, App Group e contratos nativos permanecem. Histórico de
comandos e decisões: [Drift](docs/history/drift-transition.md) e
[transição local anterior](docs/history/local-transition.md).
