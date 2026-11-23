# Histórico da transição local

Este documento preserva os principais resultados das etapas anteriores.
**Não descreve pendências atuais nem autoriza restaurar funcionalidades.**
O estado vigente está no [README](../../README.md) e na
[arquitetura](../../ARCHITECTURE.md).

## Linha de evolução

1. O app usou HTTP próprio e depois SDK PocketBase, com autenticação, sessão e
   persistência por Secure Storage.
2. Houve integração de áudio/worker/IA e infraestrutura independente de backend.
3. A branch `tostore` iniciou uma versão exclusivamente local, removendo contas,
   sessão, PocketBase, backend, worker e áudio.
4. Perfil e despesas passaram ao ToStore. CSV chegou a existir na transição,
   mas foi removido depois, junto ao compartilhamento sem consumidores.
5. Root passou a abrir Dashboard sem sessão, e Metrics passou a agregar despesas
   locais. A composição voltou a passar na análise e na suíte globais.
6. O ToStore passou a ser registrado diretamente no módulo raiz, sem repasse
   entre módulos e sem singleton global manual.
7. Durante a revisão documental, Welcome foi removida em paralelo da composição
   e dos arquivos da feature. Uma etapa posterior removeu a constante de rota e
   referências nos testes; análise limpa e 946 testes aprovados após essa conclusão.
8. Em 22/11/2026, Localstore substituiu ToStore em User, Expense e Metrics,
   injetado diretamente pelo Modular, sem client de persistência, fork ou
   migração de dados antigos. Filtros, paginação e agregação passaram a Dart.
   As limitações de confirmação de escrita e leitura de JSON do SDK foram aceitas.
9. A criação do perfil padrão passou ao UserRepository, em um documento com nome
   e avatar; o inicializador separado e sua chamada no `main` foram removidos.
   Root e seus testes/mocks passaram de `HomeWidget*` para `Widget*`, preservando
   nomes e contratos do plugin e das implementações nativas.
10. O pacote do pub.dev foi substituído pelo fork privado `bed72/localstore`,
    fixado no commit `ac66df2`. O fork aguarda as escritas e propaga JSON inválido,
    substituindo as limitações aceitas da versão 1.4.0. O workflow foi preparado
    para autenticar a dependência com secret de leitura; o cadastro do secret
    permanece pendente, sem execução remota do release.
11. A limpeza de código morto removeu componentes sem consumidores, o Bloc
    exclusivo de previews/testes de Metrics, parsers/formatadores remotos sem
    produtor local, dependência de grid sem uso e configurações de autenticação,
    microfone e backend. A categoria de presentes permanece, com imagem de Outros.
    Main e previews não deixaram arquivos Dart desconectados em lib.
12. Em 23/11/2026, iniciou-se a transição para Drift/SQLite. User e Expense foram
    migrados, com IDs inteiros, DAO SQL de sugestões e schema 2 com default de
    data local. Metrics/composição permaneceram bloqueados pelo legado.
    Decisões e resultados dessa etapa estão em [drift-transition.md](drift-transition.md).

Não há migração de dados PocketBase ou de sessões anteriores. Não há backup
restaurável pelo app, mesmo que um CSV tenha sido exportado em versões anteriores.

## Resultados registrados nas etapas locais

| Etapa | Resultado registrado na época |
| --- | --- |
| Fundação ToStore | 20 testes focados aprovados; análise global com 775 ocorrências; arquitetura com 83 aprovados e 2 falhas por arquivos de autenticação removidos. |
| User local | 186 testes focados aprovados; análise global com 727 ocorrências e as mesmas 2 falhas de arquitetura. |
| Settings/Information locais | 57 testes da feature e 244 na regressão; análise global com 632 ocorrências. |
| Root local | 80 testes focados e 324 na regressão; análise global com 559 ocorrências. |
| Expense/CSV locais | 637 testes de regressão; análise com 515 ocorrências; suíte global com 985 aprovados e 15 falhas legadas. |
| Remoção de CSV/compartilhamento | 612 testes de regressão; análise global com 515 ocorrências fora do escopo. |
| Manutenção de testes removidos | 913 aprovados e 3 falhas de carregamento em Metrics/composição; análise com 61 ocorrências. |
| Dashboard sem áudio | 531 testes focados; suíte com 900 aprovados e 3 falhas de carregamento; análise com 25 ocorrências. |
| Metrics local/composição | Análise limpa; 689 testes focados e 946 globais aprovados. |
| Registro do ToStore no módulo raiz | `flutter pub get` concluído; `flutter analyze` sem problemas; 946 testes globais aprovados. |
| Substituição por Localstore | `flutter pub get` concluído; `flutter analyze` sem problemas; 909 testes globais aprovados. |
| Perfil inicial no UserRepository | `flutter pub get` concluído; `flutter analyze` sem problemas; 904 testes globais aprovados. |
| Renomeação de Root para Widget | `flutter pub get` concluído; `flutter analyze` sem problemas; 904 testes globais aprovados. |
| Fork privado Localstore | `flutter pub get` concluído; análise limpa; 911 testes globais aprovados; actionlint aprovado; helper Git conferido com credencial fictícia, sem rede. |
| Limpeza de código morto | `flutter pub get` concluído; análise limpa; 845 testes Flutter, 39 Android e 27 iOS aprovados; actionlint e plutil aprovados. Sem build completo do app ou homologação visual. |

Os números são retratos de etapas diferentes, não contagens cumulativas.
Os bloqueios das etapas anteriores não apareceram na verificação de 22/11/2026
registrada na tabela. A transição posterior para Drift voltou a introduzir
bloqueios intermediários, descritos no registro separado de 23/11/2026.
Nenhum resultado comprova build nativo atual, UI, backup ou prontidão de release.
As execuções acima precedem a revisão documental e não homologam edições
posteriores de código no checkout. A revisão de nomes/pastas contou 64 arquivos
de testes de features, 57 com espelhamento exato; essa contagem não é cobertura
e não representa reorganização dos sete casos restantes.

O registro detalhado de Expense/CSV permanece em
[verification.md](../../openspec/changes/migrate-expense-to-tostore/verification.md);
o comportamento de CSV descrito ali foi posteriormente removido.

## Histórico anterior à versão local

Specs e changes do OpenSpec preservam decisões e checklists de suas respectivas
épocas, incluindo sessão, autenticação, áudio, CSV, Insight e mecanismos de
commands já substituídos. Consulte o [índice](../../openspec/README.md).
Os textos anteriores dos guias raiz e seus logs completos permanecem no histórico
Git; não são instruções atuais de execução ou implementação.

Builds debug Android/iOS Simulator e testes de políticas nativas foram registrados
em etapas anteriores à versão local. A adição direta do widget médio pela galeria
iOS foi confirmada pelo usuário naquela etapa; o atalho de redimensionamento do
SpringBoard permaneceu sem correção confirmada. Não há homologação atual da versão
local por esses registros.
