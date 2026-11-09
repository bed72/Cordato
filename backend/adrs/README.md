# Decisões arquiteturais do backend

ADRs registram **por que** uma escolha foi feita, suas alternativas e consequências.
A arquitetura atual está em [ARCHITECTURE.md](../ARCHITECTURE.md); operação e
evidências ficam em [README.md](../README.md).

Os registros iniciais são retrospectivos das decisões já adotadas neste checkout.
A data indica o registro documental, não a data de implantação ou validação remota.

## Índice

| ADR | Decisão | Status |
| --- | --- | --- |
| [0001](0001-pocketbase-como-biblioteca-e-runtime-separado.md) | PocketBase como biblioteca local, preservando runtime Docker oficial | Aceito |
| [0002](0002-arquitetura-proporcional-e-composicao-manual.md) | Camadas proporcionais, composição manual e nomes contextualizados por pacote | Aceito |
| [0003](0003-isolamento-de-testes-por-fronteira.md) | Unitários junto do código; integração, E2E e arquitetura em `tests/` | Aceito |
| [0004](0004-aceite-de-audio-sem-processamento.md) | Entrada binária autenticada e limitada, sem processamento ou persistência | Aceito |
| [0005](0005-ferramentas-locais-e-colecao-bruno.md) | Makefile e coleção Bruno com ambientes isolados e permissões explícitas | Substituído por ADR-0006 |
| [0006](0006-secrets-nativos-bruno-e-fallback-cli.md) | Secrets nativos na interface Bruno, com fallback de processo na CLI | Substituído por ADR-0008 |
| [0007](0007-requests-declarativas-e-pre-requisitos.md) | Payloads visíveis e pré-requisitos explícitos por requisição Bruno | Substituído por ADR-0008 |
| [0008](0008-bruno-somente-login-e-upload-local.md) | Apenas login/upload locais, ambiente privado preenchível e token em memória | Aceito |

## Como registrar

1. Copiar [template.md](template.md) para `NNNN-titulo-em-kebab-case.md`, usando o
   próximo número disponível, sem renumerar os registros existentes.
2. Explicitar contexto, decisão, alternativas e consequências; registrar somente
   escolhas relevantes, não cada detalhe de implementação.
3. Começar como **Proposto**. Marcar **Aceito** somente após aprovação explícita ou
   quando documentar retrospectivamente uma decisão já adotada e autorizada.
4. Atualizar o índice e os documentos afetados quando a decisão for aceita.
5. Para mudar uma decisão aceita, criar novo ADR referenciando o anterior. Marcar
   o anterior como **Substituído por ADR-NNNN** e preservar seu contexto histórico.

Estados: **Proposto**, **Aceito**, **Rejeitado** e **Substituído por ADR-NNNN**.
Correções editoriais podem atualizar o próprio registro sem mudar sua decisão.
Não incluir segredos, dados pessoais, áudio ou tokens. Aprovar um ADR não autoriza
deploy, migração de dados ou alterações fora do escopo solicitado.
