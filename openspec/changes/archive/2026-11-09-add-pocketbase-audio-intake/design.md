## Context

O executável em `backend/cmd/cordato/` usa PocketBase 0.41.1 como biblioteca, com Go 1.27+, roteador e autenticação nativos. O bootstrap fica em `internal/platform/pocketbase/`; existem testes HTTP em memória e um teste opcional do executável real em loopback. O runtime Docker continua usando o executável oficial e não será alterado.

Foi aprovado receber gravações finalizadas em M4A/AAC-LC, produzidas futuramente pelo pacote Flutter `record`, enviando seus bytes no body. Não foi autorizada integração Flutter nesta mudança. A Function TypeScript `audio-processor` é referência histórica de intenção, não um contrato a portar: Appwrite, storage, FFmpeg/FFprobe, IA, regras financeiras e persistência ficam fora deste incremento.

## Goals / Non-Goals

**Goals:**

- Disponibilizar uma entrada autenticada com validações pequenas, explícitas e testáveis.
- Limitar a leitura efetiva a 2 MiB, rejeitando excesso mesmo sem tamanho declarado.
- Separar transporte, aceite em application e composição, sem dependência de PocketBase nas camadas internas.
- Preservar APIs, migrations e demais testes existentes.

**Non-Goals:**

- Transcrever, interpretar, cadastrar despesas ou executar tarefas em background.
- Persistir áudio, arquivos temporários, jobs, status ou identificadores de acompanhamento.
- Detectar codec, validar container, decodificar mídia ou garantir limite de duração.
- Implementar fila, retry, deduplicação/idempotência persistente, realtime, notificações, quotas ou serviços separados.
- Instalar `record`, substituir a POC de fala ou alterar qualquer consumidor Flutter.
- Alterar Dockerfile, Compose, entrypoint, migrations, serviço remoto ou fazer chamadas pagas.

## Decisions

### 1. Rota customizada com aparência de recurso PocketBase

Usar `POST /api/collections/audio/process`, registrada no roteador nativo. O nome segue a preferência aprovada, mas a rota é uma operação customizada: não existe collection `audio`, não há `/records` nem chamada de CRUD gerado. Manter rotas existentes, inclusive `/api/health` e `/api/cordato/health`.

Alternativas: `/api/cordato/...` isolaria melhor o namespace customizado, mas não corresponde à convenção escolhida. Criar uma collection apenas para obter a URL introduziria persistência e semântica de records desnecessárias.

### 2. Body binário, sem multipart

O body contém somente os bytes da gravação. O tipo suportado é `audio/mp4`; não aceitar aliases como `audio/m4a`, `audio/aac`, `application/octet-stream`, JSON ou multipart. Usar parsing MIME padrão para aceitar variações de caixa e parâmetros sintaticamente válidos sem mudar o tipo base. Parâmetros como `codecs` não comprovam o codec real.

Aceitar somente ausência de `Content-Encoding` ou `identity`; rejeitar outras codificações com `415`, sem descompressão implícita. Não interpretar base64 ou receber nome de arquivo, owner, data financeira ou outros metadados no body.

Alternativa: multipart não é necessário para um único conteúdo sem metadados. AAC/ADTS de `record.startStream` é outro contrato e não será aceito como `audio/aac`; a futura integração utilizará gravação finalizada, não streaming de captura.

### 3. Autorização antes do consumo do body

Reutilizar o carregador de token e `RequireAuth("users")` do PocketBase. Exigir também `verified=true`. Ausência/token inválido retorna `401`; identidade válida de outra coleção ou usuário não verificado retorna `403`. Os testes precisam comprovar que esses cenários não consomem o body nem invocam o caso de uso.

Não receber identidade em parâmetros e não consultar/gravar collections neste fluxo. O cliente autenticado não ganha permissão de escrita por enviar áudio.

### 4. Leitura limitada e validação completa antes do aceite

O teto inclusivo é **2.097.152 bytes**, definido uma única vez no contrato de aceite. Aplicar limite de body da rota por APIs públicas do PocketBase/Go; o handler não depende somente de `Content-Length` e não usa leitura ilimitada seguida de checagem.

Sequência: autorização → headers de formato → leitura limitada até EOF ou erro → caso de uso → resposta. Se o tamanho declarado já exceder o limite, rejeitar sem alocar o conteúdo; caso contrário, verificar o tamanho efetivamente lido. Erro de leitura/incompletude retorna `400`, excesso retorna `413`, corpo vazio retorna `400`, tipo/codificação não suportados retornam `415`.

O caso de uso revalida tamanho não vazio e teto para não depender do transporte. Ele recebe dados próprios, não `RequestEvent`, `http.Request`, readers HTTP, SDKs ou records. Nenhum `202` pode ser emitido enquanto a leitura estiver pendente ou após erro parcial.

Os timeouts e rate limits nativos continuam ativos. Não introduzir gerenciador de concorrência de jobs: não há trabalho retido ou assíncrono nesta etapa.

### 5. Clean Architecture proporcional ao comportamento existente

Organização pretendida:

```text
backend/
  cmd/cordato/main.go
  internal/
    application/
      audio/                  # Caso de uso de aceite, limite e erros próprios
    infrastructure/
      http/
        audio/                # Handler, parsing MIME, leitura limitada e mapeamento HTTP
    platform/pocketbase/       # Bootstrap e composição manual existentes
```

Dependências: handler → application; composição → ambos e PocketBase. Definir uma interface pequena do caso de uso no pacote HTTP consumidor se necessária para testar delegação e bloqueios, sem interfaces genéricas, prefixos `I` obrigatórios ou interface espelhando cada struct.

Não criar `domain/` vazio, entidade financeira, repository, porta de IA ou diretórios de persistência sem comportamento. Recebimento e limite de upload são regras de aceite desta aplicação, não um domínio financeiro artificial. A camada de domínio será criada quando houver regras de negócio independentes para modelar. Isso preserva a regra de dependências da [referência de Clean Architecture](https://golang.com.br/tutoriais/go-clean-architecture/) sem copiar toda a árvore do tutorial.

Não mover o endpoint de saúde nem refatorar código existente sem necessidade da nova composição. Não adicionar Echo, Chi, framework de DI ou dependências externas para validar MIME/body.

### 6. Semântica limitada do 202

Responder exatamente `{"status":"accepted"}` com `202` após aceite válido. Trata-se de contrato preparatório, explicitamente sem processamento nesta entrega: o áudio é descartado após a requisição e não há tarefa que continuará depois dela. O nome `/process` reserva a intenção futura, não comprova execução atual.

Não retornar `processed`, ID de job, ID de despesa, `Location` de acompanhamento ou promessa de conclusão. Não criar goroutine vazia. A evolução para processamento real exigirá nova mudança para lifecycle, concorrência, timeout, tratamento de falhas e comunicação do resultado.

Alternativa: `204` descreveria melhor o descarte atual, mas o `202` foi escolhido explicitamente como contrato incremental. Documentar essa limitação é obrigatório para não induzir o consumidor a considerar uma despesa criada.

### 7. Privacidade e erros

Erros usam o envelope nativo PocketBase, com mensagens locais seguras, sem serializar erros de leitura ou conteúdo recebido. Não logar body, áudio, credenciais, cabeçalhos de autenticação ou dados financeiros, nem adicionar campos de áudio aos logs de atividade. Não devolver mídia em respostas. Os bytes pertencem apenas à execução da requisição; não usar caches, variáveis globais, disco ou coleções.

### 8. Testes por fronteira

- Application: entrada vazia, abaixo do limite, exatamente no limite, excesso e ausência de dependências externas/efeitos.
- HTTP em memória com PocketBase real: autenticação, verificação, parsing MIME, headers, leitura com tamanho conhecido/desconhecido, excesso, erro parcial e sequência antes do `202`.
- Usar reader controlado/contadores para comprovar leitura limitada, não consumo em rejeições prévias e ausência de aceite antes do EOF, sem sleeps arbitrários.
- Mídia de teste explicitamente sintética. Como não há inspeção, bytes não decodificáveis dentro do limite com `audio/mp4` também são aceitos; testar e documentar esse limite em vez de alegar validação M4A real.
- Adaptar o teste opcional `TestLocalServerLifecycle` para executar um aceite e uma rejeição por HTTP real no binário compilado. A suíte padrão continua sem abrir portas.
- Teste arquitetural Go verifica que application não importa PocketBase, HTTP de transporte, infrastructure ou código de teste; produção não importa doubles. Suporte compartilhado, se necessário, fica em arquivos próprios de teste.

## Risks / Trade-offs

- [Tipo declarado não comprova mídia] → Contrato aceita somente declaração e tamanho; não afirmar validação de codec, duração, integridade ou conteúdo. IA futura terá sua própria fronteira de falha.
- [202 sem processamento pode confundir] → Resposta e documentação falam apenas em aceite; proibir promessa de conclusão e integração Flutter nesta etapa.
- [Memória cresce com uploads simultâneos] → Leitura limitada por requisição, sem retenção posterior e com limites nativos preservados. O teto de 2 MiB não é uma garantia de consumo total do processo; limites globais exigem medição/decisão posterior.
- [Namespace reservado de collections] → Rota explícita e teste de coexistência com APIs nativas; não criar collection homônima ou sobrescrever handlers gerados.
- [Mudanças Go anteriores ainda não commitadas] → Preservar o trabalho existente; esta proposta depende desse checkout, sem autorizar reset ou substituição do runtime oficial.

## Migration Plan

Sem migração de banco ou dados. Implementar e testar apenas no executável Go local. Atualizar documentação do backend e arquitetura ao implementar; não descrever a rota como publicada no Dokploy. Remover a rota/composição reverte este incremento sem alterar dados. Build/container, deploy e alterações remotas continuam exigindo autorização específica.

## Open Questions

Nenhuma bloqueante para o recebimento. Modelo de IA, persistência financeira, acompanhamento de resultado, idempotência e garantias assíncronas são decisões futuras, não tarefas implícitas desta mudança.
