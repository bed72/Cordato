# ADR-0001 — PocketBase como biblioteca local e runtime separado

- Status: Aceito
- Data do registro: 2026-11-09
- Natureza: registro retrospectivo de decisão adotada
- Escopo: módulo Go, executável local e runtime Docker

## Contexto

O backend usa PocketBase 0.41.1, suas APIs e migrations JavaScript. Uma operação
customizada de áudio precisa ser composta no executável Go, sem reimplementar
autenticação, CRUD ou trocar implicitamente o serviço existente no Dokploy.

## Decisão

Usar a mesma versão do PocketBase como biblioteca no módulo `cordato/backend`,
com Go 1.27+, entrada em `cmd/cordato/` e configuração em `internal/bootstrap/`.
Preservar suporte às migrations JS por `jsvm` e `migratecmd`, sem hooks JS ou worker.
Não registrar o atualizador do binário oficial no executável customizado.

O Docker continua usando o executável oficial. Não alterar Dockerfile, entrypoint,
Compose, volumes ou serviço remoto como efeito colateral de mudanças Go locais.
Dados locais usam diretórios descartáveis separados de bancos e volumes reais.

## Alternativas consideradas

- Substituir imediatamente o runtime Docker pelo Go customizado: exigiria build,
  rollout e validações operacionais fora do escopo autorizado.
- Portar migrations para Go: mudança desnecessária para o incremento atual e com
  risco sobre o histórico já definido.
- Implementar a operação em hooks JavaScript ou serviço separado: adicionaria outro
  caminho de execução e operação sem necessidade atual.

## Consequências

- APIs nativas e schema permanecem como fonte dos contratos existentes.
- A rota de áudio local não fica disponível remotamente por existir no repositório.
- Atualizações exigem revisar dependências, testes e recompilar o executável.
- O rollout Go, se aprovado futuramente, precisa de decisão e evidências próprias.
- A migration inicial continua exclusiva para banco novo; esta decisão não migra dados.

## Referências

- [Bootstrap](../internal/bootstrap/bootstrap.go)
- [Módulo Go](../go.mod)
- [Execução local](../README.md#executável-go-local)
