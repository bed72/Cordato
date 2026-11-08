## Why

O usuário precisa obter uma cópia utilizável de todo o seu histórico de despesas, sem depender das páginas carregadas no aplicativo. Exportar CSV pelo compartilhamento nativo oferece portabilidade para planilhas e outros aplicativos sem criar um serviço de geração de arquivos no backend.

## What Changes

- Adicionar “Exportar despesas” à seção Conta de Configurações.
- Consultar todo o histórico próprio pelo SDK PocketBase, sem seleção de período, categoria ou dados familiares.
- Gerar no dispositivo um CSV compatível com Excel brasileiro, com Identificador, Data, Descrição, Categoria e Valor (BRL).
- Abrir o compartilhamento nativo Android/iOS, sem implementar “Salvar como” ou selecionar uma pasta.
- Exibir “Preparando exportação…” durante a preparação, impedir disparos concorrentes e permitir nova tentativa manual após falha.
- Informar ausência de despesas sem gerar arquivo; nunca compartilhar uma exportação parcial após falha.
- Tratar precisão monetária, caracteres especiais, fórmulas de planilha e arquivos temporários com dados pessoais.

## Capabilities

### New Capabilities

- `expense-csv-export`: exportação de todo o histórico próprio em CSV e compartilhamento a partir de Configurações, incluindo formato, isolamento, concorrência, falhas e privacidade.

### Modified Capabilities

Nenhuma. A entrada adicional em Configurações é especificada pela nova capacidade; as opções existentes permanecem preservadas, sem reintroduzir elementos históricos da spec de Settings.

## Impact

- Flutter: Settings (composição, novo Bloc de página e repository de coordenação), Expense (contrato de leitura própria para exportação e implementação SDK) e core (contrato/adapter da capacidade nativa de compartilhamento e temporários).
- Dependências propostas: `csv`, `share_plus` e `path_provider`, após verificar compatibilidade com o toolchain Android/iOS atual.
- API existente: leitura paginada de `collections/expenses/records`, com filtro explícito de proprietário e autorização mantida no PocketBase.
- Sem endpoint novo, alterações de schema, deploy, importação, dados de perfil, exportação familiar, ZIP, processamento em background ou funcionamento offline.
- Testes unitários de infraestrutura, serialização, Bloc, DI e arquitetura; previews/conferência nativa manuais, sem testes de UI.
