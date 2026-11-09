# ADR-0004 — Aceite de áudio sem processamento

- Status: Aceito
- Data do registro: 2026-11-09
- Natureza: registro retrospectivo de decisão adotada
- Escopo: contrato local `POST /api/collections/audio/process`

## Contexto

A futura captura Flutter precisa de um contrato de entrada, mas IA, interpretação,
persistência financeira e lifecycle assíncrono ainda não foram definidos.
O incremento autorizado limita-se ao recebimento autenticado e limitado.

## Decisão

Registrar a operação customizada no roteador PocketBase, sem collection `audio`.
Exigir token de `users` e e-mail verificado antes da leitura. Receber bytes diretamente
no body com MIME base `audio/mp4`, parâmetros válidos e Content-Encoding ausente
ou `identity`. O futuro consumidor usará gravação finalizada M4A/AAC-LC.

Aceitar conteúdo não vazio até 2.097.152 bytes inclusive, com teto único em application,
limite público no transporte e leitura efetivamente limitada mesmo sem Content-Length.
Headers inválidos são rejeitados antes da leitura. Delegar somente após EOF sem erro,
uma única vez, e revalidar vazio e tamanho no caso de uso.

Retornar `202` com `{"status":"accepted"}` como aceite preparatório; descartar os bytes
após a requisição. Não inspecionar container, codec ou duração; não processar,
transcrever, persistir, criar despesa, fila, job ou acompanhamento. Não há conclusão
futura garantida. Erros usam envelope nativo seguro, sem áudio ou credenciais em logs.

## Alternativas consideradas

- Multipart ou base64/JSON: não são necessários para um único conteúdo sem metadados.
- Aliases de MIME ou streaming de captura AAC: representam outro contrato,
  diferente da gravação finalizada escolhida.
- `204`: descreveria melhor o descarte, mas `202` foi escolhido explicitamente para
  o contrato incremental, exigindo documentação clara da ausência de processamento.
- Introduzir FFmpeg, IA, storage ou fila: anteciparia decisões e efeitos fora do escopo.

## Consequências

- Autorização, declaração de formato, tamanho e leitura são validados; mídia real não.
- Bytes sintéticos não decodificáveis podem ser aceitos segundo esse contrato.
- Não há IDs, deduplicação persistente ou indicação de despesa criada.
- O limite é por upload; limites globais de memória exigem decisão e medição futuras.
- Processamento real e integração Flutter exigem nova mudança, sem rollout implícito.

## Referências

- [Contrato e status HTTP](../ARCHITECTURE.md#entrada-de-áudio)
- [Caso de uso](../internal/application/audio/usecase.go)
- [Testes HTTP](../tests/integration/infrastructure/http/audio/handler_test.go)
