## ADDED Requirements

### Requirement: Rota customizada sem collection persistida

O executável Go SHALL disponibilizar `POST /api/collections/audio/process` pelo roteador nativo do PocketBase, sem criar collection `audio`, alterar schema ou substituir rotas nativas existentes.

#### Scenario: Coexistência com recursos existentes
- **WHEN** o executável Go registra a rota de áudio
- **THEN** saúde, autenticação, CRUD de despesas e métricas permanecem disponíveis em seus contratos atuais
- **AND** nenhuma migration ou collection é criada para o áudio

### Requirement: Autenticação e verificação antes da leitura

O endpoint SHALL aceitar somente identidade autenticada da coleção `users` com e-mail verificado. A autorização SHALL ocorrer antes de consumir o body ou executar o caso de uso.

#### Scenario: Credencial ausente ou inválida
- **WHEN** a requisição não contém token válido
- **THEN** retorna `401` no envelope nativo PocketBase
- **AND** não lê o body nem executa o caso de uso

#### Scenario: Identidade válida de outra coleção
- **WHEN** um superusuário ou outra coleção auth envia token válido
- **THEN** retorna `403`, sem ler o body ou executar o caso de uso

#### Scenario: Usuário não verificado
- **WHEN** um token válido pertence a `users`, mas `verified=false`
- **THEN** retorna `403`, sem ler o body ou executar o caso de uso

### Requirement: Transporte binário M4A declarado

O endpoint SHALL receber diretamente no body os bytes de uma gravação finalizada, com tipo base `audio/mp4`. O contrato do consumidor futuro SHALL ser M4A/AAC-LC, sem multipart, JSON, base64 ou streaming de captura. O servidor SHALL interpretar o tipo por parsing MIME padrão, aceitar parâmetros sintaticamente válidos e suportar somente `Content-Encoding` ausente ou `identity`.

#### Scenario: Tipo suportado
- **WHEN** usuário autorizado envia corpo não vazio dentro do limite com `Content-Type: audio/mp4`
- **THEN** o conteúdo segue para aceite após leitura completa

#### Scenario: Variações válidas de MIME
- **WHEN** o tipo base é `audio/mp4` com variação de caixa ou parâmetros MIME sintaticamente válidos
- **THEN** o header é aceito sem prometer validação do codec informado

#### Scenario: Tipo ausente, malformado ou não suportado
- **WHEN** falta `Content-Type`, seu parsing falha ou o tipo base é diferente de `audio/mp4`, incluindo `audio/aac`, `audio/m4a`, `audio/wav`, JSON, multipart ou octet-stream
- **THEN** retorna `415` sem consumir o body ou executar o caso de uso

#### Scenario: Codificação de transporte não suportada
- **WHEN** o body declara `Content-Encoding` diferente de `identity`
- **THEN** retorna `415` antes da leitura e não tenta descomprimir conteúdo

### Requirement: Limite efetivo e leitura completa

O endpoint SHALL aceitar de 1 até **2.097.152 bytes**, inclusive, usando leitura limitada e verificando o fluxo efetivo sem confiar somente em `Content-Length`. O caso de uso SHALL rejeitar entradas vazias e acima do teto independentemente do handler. O endpoint SHALL retornar `400` para corpo vazio ou falha de leitura e `413` para excesso; nenhuma dessas falhas SHALL produzir `202`.

#### Scenario: Corpo vazio
- **WHEN** a leitura termina normalmente sem bytes
- **THEN** retorna `400` e não publica aceite

#### Scenario: Tamanho exatamente no limite
- **WHEN** o fluxo termina normalmente com exatamente 2.097.152 bytes e headers válidos
- **THEN** o tamanho é aceito e a requisição retorna `202`

#### Scenario: Tamanho declarado excessivo
- **WHEN** `Content-Length` informa valor acima do teto e os requisitos anteriores foram satisfeitos
- **THEN** retorna `413` sem carregar o corpo inteiro em memória

#### Scenario: Excesso sem tamanho declarado
- **WHEN** a requisição não informa tamanho total e o fluxo ultrapassa o teto
- **THEN** retorna `413` com leitura limitada, sem alocação proporcional ao restante do fluxo

#### Scenario: Corpo válido sem tamanho declarado
- **WHEN** uma requisição sem `Content-Length` termina normalmente dentro do limite
- **THEN** retorna `202` somente depois do EOF

#### Scenario: Leitura interrompida
- **WHEN** o reader entrega alguns bytes e termina com erro de leitura ou de transferência incompleta
- **THEN** retorna `400` sem aceitar o trecho parcial nem expor o erro bruto

#### Scenario: Leitura ainda pendente
- **WHEN** o reader controlado ainda não entregou EOF ou erro
- **THEN** nenhum `202` foi enviado e o caso de uso não recebeu conteúdo parcial

#### Scenario: Caso de uso invocado fora do HTTP
- **WHEN** o caso de uso recebe diretamente entrada vazia ou acima de 2 MiB
- **THEN** devolve falha de aplicação correspondente sem depender do PocketBase ou do handler

### Requirement: Aceite sem processamento nesta etapa

Após validar completamente o upload, o endpoint SHALL retornar `202` e JSON `{"status":"accepted"}`. Nesta entrega o áudio SHALL ser descartado após a requisição, sem gravação em disco/storage/banco, fila, goroutine de processamento, chamada de IA, criação de despesa ou evento realtime. O contrato SHALL documentar que não existe conclusão futura garantida nem acompanhamento.

#### Scenario: Aceite concluído
- **WHEN** um usuário autorizado envia conteúdo declarado suportado, não vazio e dentro do limite, e a leitura termina sem erros
- **THEN** recebe `202` e `{"status":"accepted"}`
- **AND** não recebe ID de job, ID de despesa, URL de acompanhamento ou declaração de processamento concluído

#### Scenario: Nenhum efeito persistente
- **WHEN** uma requisição válida é aceita
- **THEN** não existem áudio ou metadados persistidos, despesa criada, tarefa pendente ou chamada externa decorrentes do aceite
- **AND** repetir a requisição apenas repete o aceite, sem promessa de deduplicação

### Requirement: Limite explícito de inspeção

O endpoint SHALL validar somente autenticação, declaração de formato, leitura e tamanho. Ele SHALL NOT inspecionar container, decodificar áudio, comprovar AAC-LC ou garantir duração de 60 segundos. Ele SHALL NOT introduzir FFmpeg, FFprobe ou dependências equivalentes nesta entrega.

#### Scenario: Bytes sintéticos com tipo suportado
- **WHEN** conteúdo sintético não decodificável é enviado dentro do limite com declaração `audio/mp4` válida e autorização suficiente
- **THEN** o endpoint aceita a requisição segundo as validações desta etapa
- **AND** a documentação não descreve esse aceite como prova de mídia válida

### Requirement: Fronteiras arquiteturais e privacidade

O fluxo SHALL separar handler em infrastructure, caso de uso em application e composição no bootstrap. Application SHALL usar somente tipos próprios e dependências Go puras, sem PocketBase, HTTP de transporte, infrastructure ou código de teste. Nenhuma camada SHALL logar ou devolver áudio, credenciais ou erros brutos. A mudança SHALL NOT criar repositories, interfaces de IA, entidades financeiras ou diretórios vazios sem responsabilidade implementada.

#### Scenario: Aplicação testada isoladamente
- **WHEN** os testes invocam o caso de uso de aceite
- **THEN** não precisam inicializar servidor, SDK, banco, storage ou provedor externo

#### Scenario: Delegação do handler
- **WHEN** os pré-requisitos HTTP são satisfeitos e a leitura termina normalmente
- **THEN** o handler delega uma única vez ao caso de uso com o conteúdo completo
- **AND** o caso de uso não recebe objetos HTTP ou PocketBase

#### Scenario: Feedback sem vazamento
- **WHEN** ocorre rejeição de entrada ou erro de leitura
- **THEN** o erro HTTP usa envelope PocketBase e mensagem segura
- **AND** áudio, body, tokens e mensagens brutas não aparecem na resposta ou em novos logs

### Requirement: Verificação automatizada e escopo local

A mudança SHALL manter testes unitários de aplicação, testes HTTP com PocketBase real em memória, verificações arquiteturais e cobertura opcional do executável por HTTP em loopback. Os testes SHALL usar conteúdo sintético e dados temporários. A implementação SHALL preservar o Flutter, migrations e runtime Docker existentes e SHALL NOT exigir chamadas pagas ou serviços remotos.

#### Scenario: Suíte padrão
- **WHEN** `go test ./...` executa sem habilitar o smoke HTTP opcional
- **THEN** os cenários de contrato são exercitados sem abrir portas, chamar IA ou SMTP real
- **AND** os testes existentes continuam passando

#### Scenario: Executável em loopback
- **WHEN** o smoke opcional é habilitado
- **THEN** o binário real é testado com um aceite `202` e uma rejeição da nova rota em porta efêmera local
- **AND** o servidor é encerrado e os dados temporários são descartados

#### Scenario: Nenhum rollout implícito
- **WHEN** a implementação local é concluída
- **THEN** não houve alteração no Flutter, instalação de `record`, mudança de migration ou substituição do executável Docker
- **AND** nenhuma disponibilidade remota do endpoint é alegada sem deploy autorizado
