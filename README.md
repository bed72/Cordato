# Cordato

Aplicativo Flutter de finanças pessoais, exclusivamente local com Localstore.
Estado documental revisado em **22/11/2026**.

## Estado atual

- Perfil local único: nome e seed de avatar, sem conta, ID ou e-mail.
- Despesas manuais: criação, edição, exclusão, filtros, paginação e sugestões
  baseadas no histórico local.
- Resumo mensal e distribuição por categoria calculados a partir das despesas
  locais, com dinheiro em centavos inteiros de BRL.
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
O código do app não exige credenciais de runtime, mas instalar dependências
requer acesso Git HTTPS ao repositório privado
[`bed72/localstore`](https://github.com/bed72/localstore). Configure sua
autenticação Git antes de `flutter pub get`; não coloque tokens no pubspec.

### Inicialização e persistência

`main` monta o app sem preparar perfil ou storage. O `appModule` compõe o
`coreModule`, que registra
`addInstance<Localstore>(Localstore.instance)`. Repositories recebem a mesma
instância pelo Modular e usam o SDK diretamente, sem client de persistência.

Localstore vem do fork privado `bed72/localstore`, com `ref: main` no pubspec
e commit resolvido fixado no lockfile, não da versão 1.4.0 do pub.dev.
Para buscar atualizações da main, execute `flutter pub upgrade localstore` e
versione o lockfile; `pub get --enforce-lockfile` preserva a revisão resolvida.
Não há factory, schemas ou abertura/fechamento de banco. O SDK usa arquivos
JSON em Documents no Android/iOS; o fallback de diretório corrente serve a
testes host, não representa suporte a apps desktop. Não há migração dos dados
anteriores de ToStore ou mudança do formato JSON ao adotar o fork.

O fork aguarda as escritas, propaga erros de filesystem/JSON e substitui
arquivos com temporário, flush e rename no mesmo filesystem. Não há garantia
de durabilidade após queda de energia, criptografia, transação entre documentos
ou coordenação entre processos/isolates. Falhas não disparam reset ou retry.

### Perfil e despesas

O UserRepository cria o perfil na primeira leitura, se ainda não existir:
coleção `user`, documento `profile` com campos `name` e `avatar`, nome inicial
`Cordato` e seed aleatória persistida. Atualizações preservam campos omitidos
e gravam o documento completo, sem merge atômico entre updates concorrentes.
Não há inicializador externo nem exclusão de conta.

Despesas usam coleção `expenses`, com ID gerado pelo SDK, valor inteiro positivo,
categoria padrão `other`, descrição opcional e data civil obrigatória.
O repository define hoje quando
a data de criação não é fornecida. Datas preservam os componentes do calendário,
sem deslocamento de fuso. O repository aplica trim à descrição, preservando
o comportamento anterior. Filtros, ordenação, paginação e sugestões são
processados em Dart sobre a coleção completa, sem IA.
Updates gravam o documento completo; não há merge atômico entre updates
concorrentes.

Metrics lê a mesma coleção e agrega por mês/categoria em Dart, sem coleção
própria ou cache. As entidades mensal e de categoria usam `total` em centavos.
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

O app solicita atualização ao iniciar e após o Future de mutação de despesas.
No fork, o Future aguarda a escrita antes de solicitar essa atualização.
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
                 repository em infrastructure → Localstore / client nativo do core
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

A conferência após a limpeza de 22/11/2026 encontrou 56 dos 63 arquivos de testes de features
com espelhamento exato. Há nomes/caminhos legados e suítes separadas por
responsabilidade; os sete casos estão detalhados em
[ARCHITECTURE.md](ARCHITECTURE.md#organização-e-espelhamento-dos-testes).
Isso não é uma medição de cobertura. Esta revisão documental não move testes.

## Verificação e pendências

Última execução registrada em 22/11/2026, após a limpeza de código morto.
Localstore permanece no fork privado `bed72/localstore`, commit `ac66df2`:

| Comando | Resultado |
| --- | --- |
| `flutter pub get` | Concluído. |
| `flutter analyze` | Sem problemas. |
| `flutter test --reporter failures-only` | 845 testes aprovados. |
| `actionlint .github/workflows/android-release.yml` | Sem problemas. |
| `dart run tool/test_home_widget_native.dart` | 39 testes Android e 27 iOS aprovados. |
| `plutil -lint ios/Runner/Info.plist ios/Runner/Runner.entitlements` | Sem problemas. |

Esses resultados não comprovam build nativo, navegação real, renderização dos
widgets ou prontidão para publicação. O helper Git foi conferido localmente
com uma credencial fictícia, sem acesso à rede. A Action, o build assinado e
o acesso remoto do CI ao fork não foram executados; o secret continua pendente.

Estado após a limpeza e pendências externas:

- Welcome foi removida, incluindo composição, arquivos, constante da rota e
  referências nos testes. Seu antigo fluxo por e-mail não está disponível.
- Constantes/associações de autenticação, ferramenta de app links e declarações
  de microfone foram removidas. O manifest principal Android também não declara
  acesso à rede; debug/profile mantêm sua configuração de desenvolvimento.
- O workflow Android não passa mais `BASE_URL`. O scheme `cordato` e o App Group
  permanecem para o widget nativo.
- O release precisa de `LOCALSTORE_READ_TOKEN` no ambiente `android-release`,
  com leitura de Contents em `bed72/localstore`. O workflow está preparado,
  mas esse secret ainda não foi cadastrado; o `GITHUB_TOKEN` de Cordato não
  concede automaticamente acesso ao outro repositório privado.
- Backup/restauração, builds atuais, homologação em dispositivo, assinatura iOS
  e revisão de distribuição continuam separados da aprovação dos testes.
- O espelhamento de nomes/pastas dos testes ainda não é integral.
