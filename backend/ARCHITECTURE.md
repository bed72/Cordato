# Arquitetura do backend Go

## Escopo e fontes de verdade

O módulo `cordato/backend` é independente do aplicativo Flutter. Usa Go 1.27+
e PocketBase 0.41.1 como biblioteca no executável local `cmd/cordato/`.

- [README.md](README.md): instalação, execução, contratos operacionais e evidências.
- [AGENTS.md](AGENTS.md): regras de manutenção e segurança.
- [adrs/README.md](adrs/README.md): decisões arquiteturais e alternativas.
- [tests/README.md](tests/README.md): estratégia e comandos de testes.
- [Arquitetura Flutter](../ARCHITECTURE.md#backend-pocketbase-e-limite-de-integração): consumidores e limites de integração.

Este documento descreve o checkout, não comprova implantação. O runtime Docker
continua usando o executável oficial PocketBase, sem a rota de áudio do Go local.
Alterar Dockerfile, entrypoint, Compose, dados ou serviço remoto exige tarefa e
autorização próprias.

## Estrutura

```text
backend/
  cmd/cordato/
    main.go
  internal/
    bootstrap/
      bootstrap.go
      bootstrap_test.go
    application/audio/
      usecase.go
      usecase_test.go
    infrastructure/http/audio/
      handler.go
  tests/
    architecture/
    integration/
      bootstrap/
      infrastructure/http/audio/
      pocketbase/
    e2e/server/
    support/pocketbase/
  bruno/
    environments/
  tool/
  Makefile
  pb_migrations/
  docker/
  adrs/
  go.mod
  go.sum
```

Criar somente pacotes com responsabilidade concreta. Não existem camadas vazias
de domínio, ports ou persistência. O nome do pacote dá contexto aos tipos:
`audio.UseCase` é o único caso de uso atual de `application/audio`.

## Composição e dependências

```text
cmd/cordato/main.go
  └─ internal/bootstrap
       ├─ PocketBase, configuração e plugins de migrations
       ├─ application/audio.UseCase
       └─ infrastructure/http/audio.Register
            ├─ PocketBase HTTP e autorização
            └─ application/audio.Input e falhas
```

| Pacote | Responsabilidade | Limites |
| --- | --- | --- |
| `cmd/cordato` | Entrada do processo e chamada de `Start` | Sem regras de aplicação ou parsing HTTP |
| `internal/bootstrap` | Composition root: configurar PocketBase e conectar implementações | Não é client de infraestrutura nem caso de uso |
| `internal/application/audio` | Validar o aceite com tipos próprios, limite e falhas | Sem PocketBase, HTTP, persistência ou suporte de teste |
| `internal/infrastructure/http/audio` | Autorizar, interpretar headers, ler body limitado e traduzir falhas | Não persiste, processa ou interpreta áudio |

O handler depende de application. `Acceptor` é uma interface pequena definida
no pacote HTTP consumidor, implementada por `audio.UseCase`; a composição injeta
essa implementação. Não há framework de DI, repository genérico ou adapter
intermediário de CRUD.

Quando existir apenas um caso de uso no pacote, usar `UseCase`, `usecase.go`
e `usecase_test.go`. Se surgirem operações distintas, usar nomes específicos com
sufixo `UseCase`; não transformar o tipo em um agrupamento de responsabilidades.
Repositories só devem ser introduzidos quando houver necessidade concreta de
persistência, com contrato pequeno do lado consumidor e adapter em infrastructure.

A referência [Clean Architecture em Go](https://golang.com.br/tutoriais/go-clean-architecture/)
orienta a regra de dependências e a composição manual, não exige copiar sua árvore
inteira nem substituir as capacidades nativas do PocketBase.

## PocketBase e bootstrap

O bootstrap configura a chave `POCKETBASE_ENCRYPTION_KEY`, modo não dev,
`automigrate=false`, plugins `jsvm` e `migratecmd` e diretórios locais isolados.
A chave configurada deve ter exatamente 32 bytes; uma falha interrompe o bootstrap
antes de continuar sua inicialização. Hooks JavaScript ficam desabilitados.

`jsvm` mantém suporte às migrations JavaScript existentes; não é runtime Node
nem autorização para hooks ou worker. O atualizador do executável oficial não é
registrado no binário customizado. A atualização da biblioteca requer revisão
da versão, dependências, testes e recompilação.

As rotas, middlewares, timeouts e rate limits nativos permanecem disponíveis,
incluindo `/api/health` e `/_/`. A saúde customizada da POC foi removida.
O fluxo customizado de áudio registra sua rota no hook `OnServe`.

## Dados e APIs nativas

`pb_migrations/1793491200_initial.js` é a única migration inicial, consolidada e
exclusiva para banco novo. Inclui schema, regras, settings e links de autenticação.
Não reaplicar em instalações existentes nem usar reset ou sincronização de histórico
para simular atualização. Evoluções de schema exigem novas migrations.

- `users`: autenticação, verificação e gerenciamento da própria conta pelas APIs nativas.
- `expenses`: CRUD com propriedade por usuário verificado, proteção do owner e cascata.
- `metrics`: view mensal somente leitura, isolada por proprietário, com cálculos SQL.

Dinheiro é representado em centavos inteiros. Totais de métricas são expostos como
texto decimal para preservar precisão; percentuais são proporções, não dinheiro.
Não recriar rotas JSON:API, logout remoto ou repositories de repasse dessas APIs.
Contratos dos campos e limites de precisão estão no [README](README.md#coleções).

## Entrada de áudio

`POST /api/collections/audio/process` é uma operação customizada, sem collection
`audio`, disponível somente no executável Go local.

Sequência obrigatória:

1. Carregar a identidade nativa e exigir `RequireAuth("users")`.
2. Exigir e-mail verificado e validar headers antes de ler o body.
3. Aplicar `apis.BodyLimit` com o teto definido em application.
4. Ler até EOF ou erro, sem confiar somente em `Content-Length`.
5. Delegar uma única vez o conteúdo completo para `audio.UseCase.Execute`.
6. Retornar `202` com `{"status":"accepted"}` após aceite válido.

O body é binário, com tipo base `audio/mp4`. Parsing MIME aceita variações de
caixa e parâmetros válidos; aliases, multipart, JSON e base64 não fazem parte do
contrato. `Content-Encoding` deve estar ausente ou ser `identity`, sem descompressão.
O futuro consumidor enviará gravação finalizada M4A/AAC-LC; não há integração Flutter
ou instalação do pacote `record` nesta entrega.

O tamanho aceito é de 1 até 2.097.152 bytes, inclusive. O limite também protege
fluxos sem tamanho declarado; a leitura usa no máximo um byte adicional para
detectar excesso. Application revalida vazio e tamanho, independentemente do HTTP.
Esse teto é por upload, não uma garantia de limite global de memória do processo.

| Status | Condição |
| --- | --- |
| `202` | Leitura completa e aceite válido |
| `400` | Vazio, erro de leitura ou transferência incompleta |
| `401` | Token ausente ou inválido |
| `403` | Outra coleção auth ou e-mail não verificado |
| `413` | Excesso declarado ou efetivamente lido |
| `415` | MIME ou codificação não suportados |

Erros usam envelope nativo PocketBase e mensagens seguras. Não serializar erros
brutos nem registrar/devolver áudio, tokens ou credenciais.

`202` é um aceite preparatório, não processamento: os bytes são descartados ao fim
da requisição. Não há inspeção de container, codec, integridade ou duração,
FFmpeg/FFprobe, transcrição, IA, fila, persistência, goroutine de processamento,
despesa, realtime, ID de job ou conclusão futura garantida. Repetições apenas
repetem o aceite, sem deduplicação persistente.

## Testes e limites de evidência

- Unitários próximos do código: regra de aceite e CLI sem bootstrap do banco.
- `tests/integration/bootstrap`: configuração segura e automigrate desabilitado.
- `tests/integration/pocketbase`: migrations, autenticação, CRUD e isolamento.
- `tests/integration/infrastructure/http/audio`: autorização, headers, limites,
  falhas parciais, espera por EOF, delegação e ausência de persistência.
- `tests/e2e/server`: binário real com HTTP em loopback, dados temporários e SIGTERM;
  habilitado somente por `CORDATO_HTTP_SMOKE=1`.
- `tests/architecture`: restrições de imports e fronteiras entre produção e testes.
- `tests/support/pocketbase`: helpers compartilhados, proibidos na produção.

A suíte padrão não abre portas nem usa SMTP real. Os testes que alteram ambiente,
diretório corrente ou migrations globais não executam em paralelo dentro do pacote.
Fixtures e doubles específicos têm arquivos próprios no pacote consumidor.

Testes locais não comprovam TLS/Traefik, SMTP real, mídia válida, processamento
futuro, containers, homologação Flutter ou disponibilidade remota. Evidências datadas
e comandos efetivamente executados ficam no README, não nos ADRs.

## Ferramentas de desenvolvimento

O `Makefile` centraliza execução local e verificações, sem deploy, reset ou geração
automática de secrets. `make run` usa somente loopback e `.temp/cordato/pb_data`,
com arquivo privado carregado explicitamente. Arquivos `.env.*.example` não contêm
credenciais reais; `.env.*.local` permanece ignorado e não é lido pelos testes.

A coleção `bruno/` contém somente login nativo de users e upload binário de áudio,
por solicitação explícita. Não há produção, refresh, cadastro, CRUD, opt-ins ou
login automático. O script compartilhado apenas restringe origem a loopback,
define timeout. Login descarta a sessão anterior e guarda o novo token em memória;
upload exige esse login explícito. A conta precisa estar verificada no banco local.
Não há helper de preparação de usuário ou alteração das regras de autenticação.

O ambiente versionado `example` declara URL e nomes de Secrets, sem valores.
Por solicitação explícita de preenchimento local, o ambiente privado `development.bru`
ignorado pode conter entradas locais em texto simples. Não versionar ou copiar
esses dados para reports. A CLI aceita somente variáveis `CORDATO_DEVELOPMENT_*`.
O Body do login permanece visível e seus placeholders são resolvidos preservando
caracteres da senha. Upload recebe arquivo selecionado, sem gerar bytes na coleção.
Os ADRs 0005–0007 registram estratégias anteriores, não requisitos para restaurar
requests removidas. A cobertura negativa Go das APIs permanece intacta.

Node.js e CLI Bruno são apenas ferramentas de desenvolvimento em `tool/`, fora
do runtime Go/Docker. O parser instalado valida a coleção offline, sem instalar
dependências no projeto. Na CLI Bruno 4.0.0, paths de body binário são lidos antes
da interpolação: o alvo de upload prepara uma coleção temporária mínima com o
caminho resolvido, mantém sandbox safe e remove seu próprio workspace ao terminar.
Os bytes do áudio e secrets não são copiados para os arquivos temporários.

`make test-bruno` habilita o E2E local existente para executar as duas requests
com usuário, banco e arquivo sintético temporários; verifica contagem, asserções
e status HTTP. Reports omitindo headers/bodies também são temporários.
Configuração em [bruno/README.md](bruno/README.md). Scripts são testados offline;
isso não equivale a automação visual da aplicação desktop.

## Evolução

Novas capacidades devem manter dependências apontando para dentro e interfaces
proporcionais ao comportamento. Mudanças de contrato atualizam consumidores e
testes na mesma tarefa. Decisões duradouras são registradas em `adrs/`, com contexto,
alternativas e consequências; propostas não representam implementação aprovada.
Uma decisão futura de IA, persistência ou rollout exige seu próprio escopo e não
é consequência implícita do nome `/process`.
