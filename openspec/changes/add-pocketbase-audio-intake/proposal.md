## Why

O backend Go do Cordato já preserva os recursos nativos do PocketBase e foi validado localmente por HTTP. O próximo incremento é definir uma entrada autenticada para áudio do futuro gravador Flutter, sem antecipar IA, processamento assíncrono ou persistência.

## What Changes

- Adicionar `POST /api/collections/audio/process` ao roteador nativo do executável Go, sem criar uma collection `audio`.
- Receber bytes diretamente no body, com `Content-Type: audio/mp4`, para gravação finalizada M4A/AAC-LC do pacote Flutter `record`.
- Exigir autenticação da coleção `users` e e-mail verificado.
- Validar tipo declarado, corpo não vazio, leitura completa e limite inclusivo de 2 MiB, sem depender de `Content-Length`.
- Responder `202` com `{"status":"accepted"}` somente após validar todo o upload; descartar os bytes após a requisição.
- Separar handler HTTP, caso de uso de aceite e composição, seguindo Clean Architecture proporcional ao escopo, com testes de contrato e fronteiras.
- Documentar expressamente que aceite não comprova mídia válida, processamento, despesa criada ou conclusão futura.

## Capabilities

### New Capabilities

- `pocketbase-audio-intake`: contrato HTTP de recebimento autenticado de áudio binário, validações limitadas, semântica de aceite sem processamento e isolamento arquitetural.

### Modified Capabilities

Nenhuma. A nova rota é aditiva e não altera os contratos nativos de autenticação, despesas, métricas ou migrations.

## Impact

- Código futuro limitado ao backend Go em `backend/`, especialmente `internal/application/`, `internal/infrastructure/http/` e composição em `internal/platform/pocketbase/`.
- Testes Go de aplicação, HTTP em memória e ampliação do teste opcional do executável em loopback; nenhum teste visual.
- Documentação futura em `backend/README.md`, `backend/AGENTS.md` e `ARCHITECTURE.md`, indicando contrato e limites de validação.
- Sem dependências de IA, FFmpeg/FFprobe, storage, filas, plugins Flutter, ORM ou framework de DI.
- Sem mudanças no Flutter, instalação do pacote `record`, migrations, Dockerfile, entrypoint, Compose, dados existentes ou deploy. A rota existirá no executável Go; o runtime Docker oficial permanecerá inalterado.
