## 1. Conferência do checkout e contrato

- [x] 1.1 Conferir `git status`, orientações de `backend/AGENTS.md`, bootstrap, handler de saúde e testes existentes; preservar o trabalho Go anterior e demais alterações locais.
- [x] 1.2 Confirmar no PocketBase 0.41.1 o registro da rota customizada, ordem da autorização e limite público de body, sem substituir middlewares ou rotas nativas.

## 2. Aceite em application

- [x] 2.1 Criar o caso de uso em `internal/application/audio/`, com entrada própria para bytes, teto único de 2.097.152 bytes, validação de conteúdo não vazio e falhas próprias; sem SDK, HTTP de transporte, persistência ou goroutine.
- [x] 2.2 Cobrir aplicação com testes unitários para vazio, abaixo do limite, limite exato, excesso e repetição sem efeitos; não criar domínio financeiro, repositories ou adapters vazios.

## 3. Transporte HTTP e composição

- [x] 3.1 Implementar handler em `internal/infrastructure/http/audio/` com parsing MIME de `audio/mp4`, parâmetros válidos, rejeição de outros tipos e suporte apenas a `Content-Encoding` ausente/identity.
- [x] 3.2 Implementar leitura limitada até EOF/erro, usando o limite da aplicação sem confiar somente em `Content-Length`; mapear vazio/leitura inválida para `400`, excesso para `413` e tipo/codificação para `415`.
- [x] 3.3 Registrar `POST /api/collections/audio/process` no bootstrap com `RequireAuth("users")` e verificação de e-mail antes da leitura; preservar os endpoints existentes e não criar collection `audio`.
- [x] 3.4 Delegar conteúdo completo uma única vez ao caso de uso e retornar `202` com `{"status":"accepted"}`; não devolver mídia, IDs, acompanhamento ou indicação de processamento concluído.

## 4. Testes de contrato e fronteiras

- [x] 4.1 Cobrir `401` sem token/token inválido e `403` para outra coleção/usuário não verificado, comprovando ausência de leitura e de invocação do caso de uso.
- [x] 4.2 Cobrir MIME ausente, inválido, aliases e formatos não suportados, multipart/JSON, variação de caixa, parâmetros válidos e codificação não suportada.
- [x] 4.3 Cobrir vazio, limite exato e excesso com tamanho conhecido e desconhecido, incluindo leitura parcial com erro e reader que comprove limite efetivo sem alocação proporcional ao fluxo excessivo.
- [x] 4.4 Usar reader/sinais controlados para comprovar que `202` e a delegação só ocorrem após leitura completa; usar bytes sintéticos para explicitar que não há validação de codec/container/duração.
- [x] 4.5 Verificar resposta de aceite, envelope seguro de erros, ausência de vazamento de conteúdo/credenciais e ausência de escrita de arquivos, collections ou despesas.
- [x] 4.6 Adicionar teste arquitetural Go para imports de application e isolamento de código de teste, mantendo eventuais doubles compartilhados em arquivos próprios.
- [x] 4.7 Ampliar o smoke opcional `TestLocalServerLifecycle` com aceite `202` e rejeição da rota por HTTP real, preservando loopback, dados temporários, encerramento dos processos e suíte padrão sem portas.

## 5. Documentação e verificação

- [x] 5.1 Atualizar `backend/README.md`, `backend/AGENTS.md` e `ARCHITECTURE.md` com contrato binário, status, layout e limites: sem inspeção real, IA, processamento, persistência, acompanhamento ou integração Flutter.
- [x] 5.2 Executar em `backend/`: `go test -count=1 ./...`, `go test -race ./...` e `go vet ./...`; registrar resultados e bloqueios sem enfraquecer testes existentes.
- [x] 5.3 Executar o smoke local opcional com `CORDATO_HTTP_SMOKE=1 go test -count=1 -run '^TestLocalServerLifecycle$' -v ./internal/compatibility`, registrar resultados e limites; não iniciar serviços existentes ou usar SMTP/IA reais.
- [x] 5.4 Executar `sh -n docker/entrypoint.sh` e `git diff --check`; revisar que Flutter, dependências mobile, migrations, Dockerfile, entrypoint e Compose não foram alterados e que não houve deploy ou chamadas pagas.

## Evidências de execução (09/11/2026)

- Alterações locais anteriores em documentação e no backend Go preservadas; nenhum commit ou reset realizado.
- `go test -count=1 ./...`: aprovado, incluindo application, HTTP em memória, arquitetura, compatibilidade e bootstrap.
- `go test -race ./...`: aprovado, sem corridas detectadas.
- `go vet ./...`: aprovado.
- `CORDATO_HTTP_SMOKE=1 go test -count=1 -run '^TestLocalServerLifecycle$' -v ./internal/compatibility`: aprovado; aceite `202`, rejeições `401`/`415` e cenários anteriores passaram no executável em loopback, com dados temporários e encerramento via SIGTERM. O binário filho usa build normal, sem instrumentação de race.
- `sh -n docker/entrypoint.sh` e `git diff --check`: aprovados.
- `openspec validate add-pocketbase-audio-intake --strict`: aprovado.
- Sem bloqueios encontrados. Flutter, dependências mobile, migrations e runtime Docker preservados; sem deploy, SMTP/IA reais ou chamadas pagas. Testes não comprovam inspeção de mídia, processamento, TLS, integração Flutter ou disponibilidade remota.
