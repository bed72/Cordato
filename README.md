# Cordato

Aplicativo Flutter de finanças pessoais, em transição para uma versão
exclusivamente local com ToStore. Estado documental revisado em **22/11/2026**.

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

O app atual não precisa de servidor, credenciais ou `BASE_URL`.
Os testes não montam UI; a execução em dispositivo é uma verificação separada.

### Inicialização e persistência

`main` aguarda `createDependencies` antes de `runApp`. O bootstrap:

1. Obtém o diretório persistente de suporte do aplicativo.
2. Abre o banco `cordato` com `ToStoreFactory.create` e o schema de despesas.
3. Inicializa somente as chaves ausentes do perfil local.
4. Entrega o banco pronto a `createAppModule`.

**Somente o módulo raiz recebe o ToStore por parâmetro** e registra
`addInstance<ToStore>(database)`. Não há repasse entre módulos nem singleton
global manual. Repositories recebem a mesma instância por injeção de dependências.
`coreModule` não recebe o banco.

A factory usa durabilidade `durable` e desativa logs diagnósticos do SDK.
Falhas de preparação propagam antes de montar o app, sem retry, reset ou fallback
para banco vazio. A instância pertence ao bootstrap, não às rotas.

### Perfil e despesas

O perfil usa `profile.name` e `profile.avatar`, com nome inicial `Cordato` e seed
aleatória persistida. Atualizações de nome/avatar são independentes; atualizar
ambos não é uma operação atômica. Não há exclusão de conta.

Despesas têm ID automático, valor inteiro positivo, categoria padrão `other`,
descrição opcional e data civil obrigatória. O repository define hoje quando
a data de criação não é fornecida. Datas preservam os componentes do calendário,
sem deslocamento de fuso. O SDK aplica seu trim nativo aos campos textuais.
Sugestões usam o histórico, sem IA.

Metrics agrega o mesmo banco por mês e categoria, sem tabela própria ou cache.
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

O app solicita atualização ao iniciar e após mutações reconhecidas de despesas.
Não há consulta HTTP ou cadastro em background, refresh periódico ou retry
automático. Falhas preservam o último resumo válido; mês incompatível mostra
**Abra para atualizar**. A virada do mês depende do agendamento nativo.

O snapshot compartilhado contém somente mês e centavos inteiros na chave JSON
`monthly_summary`, sem perfil ou credenciais. Revisões bloqueiam publicações
obsoletas. O nome legado `setMonthlySessionActive` habilita a publicação nativa;
não representa autenticação ou sessão.

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
concorrentes de `dart run`: os build hooks compartilham artefatos. Os testes
nativos não foram repetidos nesta atualização documental.

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
                 repository em infrastructure → ToStore / client nativo do core
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

## Verificação e pendências

Última verificação em 22/11/2026, após concluir a remoção de Welcome:

| Comando | Resultado |
| --- | --- |
| `flutter pub get` | Concluído. |
| `flutter analyze` | Sem problemas. |
| `flutter test --reporter failures-only` | 946 testes aprovados. |

Esses resultados não comprovam build nativo, navegação real, renderização dos
widgets ou prontidão para publicação.

Pendências observadas no checkout, sem correção de código nesta revisão:

- Welcome foi removida, incluindo composição, arquivos, constante da rota e
  referências nos testes. Seu antigo fluxo por e-mail não está disponível.
- `RouteEnum` conserva constantes antigas de autenticação; elas não significam
  rotas disponíveis.
- O manifest Android mantém `RECORD_AUDIO` e app links antigos de autenticação.
  A ferramenta `tool/app_links.dart` também conserva associações antigas.
  Isso não representa funcionalidade de áudio ou autenticação disponível.
- O workflow Android ainda passa `BASE_URL` legado. Esse parâmetro não configura
  o ToStore e não indica dependência remota do app local.
- Backup/restauração, builds atuais, homologação em dispositivo, assinatura iOS
  e revisão de distribuição continuam separados da aprovação dos testes.
