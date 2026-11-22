# Histórico da transição local

Este documento preserva os principais resultados das etapas anteriores.
**Não descreve pendências atuais nem autoriza restaurar funcionalidades.**
O estado vigente está no [README](../../README.md) e na
[arquitetura](../../ARCHITECTURE.md).

## Linha de evolução

1. O app usou HTTP próprio e depois SDK PocketBase, com autenticação, sessão e
   persistência por Secure Storage.
2. Houve integração de áudio/worker/IA e infraestrutura independente de backend.
3. A branch `tostore` iniciou uma versão exclusivamente local, removendo contas,
   sessão, PocketBase, backend, worker e áudio.
4. Perfil e despesas passaram ao ToStore. CSV chegou a existir na transição,
   mas foi removido depois, junto ao compartilhamento sem consumidores.
5. Root passou a abrir Dashboard sem sessão, e Metrics passou a agregar despesas
   locais. A composição voltou a passar na análise e na suíte globais.
6. O ToStore passou a ser registrado diretamente no módulo raiz, sem repasse
   entre módulos e sem singleton global manual.
7. Durante a revisão documental, Welcome foi removida em paralelo da composição
   e dos arquivos da feature. A suíte desta sessão antecede essa remoção.

Não há migração de dados PocketBase ou de sessões anteriores. Não há backup
restaurável pelo app, mesmo que um CSV tenha sido exportado em versões anteriores.

## Resultados registrados nas etapas locais

| Etapa | Resultado registrado na época |
| --- | --- |
| Fundação ToStore | 20 testes focados aprovados; análise global com 775 ocorrências; arquitetura com 83 aprovados e 2 falhas por arquivos de autenticação removidos. |
| User local | 186 testes focados aprovados; análise global com 727 ocorrências e as mesmas 2 falhas de arquitetura. |
| Settings/Information locais | 57 testes da feature e 244 na regressão; análise global com 632 ocorrências. |
| Root local | 80 testes focados e 324 na regressão; análise global com 559 ocorrências. |
| Expense/CSV locais | 637 testes de regressão; análise com 515 ocorrências; suíte global com 985 aprovados e 15 falhas legadas. |
| Remoção de CSV/compartilhamento | 612 testes de regressão; análise global com 515 ocorrências fora do escopo. |
| Manutenção de testes removidos | 913 aprovados e 3 falhas de carregamento em Metrics/composição; análise com 61 ocorrências. |
| Dashboard sem áudio | 531 testes focados; suíte com 900 aprovados e 3 falhas de carregamento; análise com 25 ocorrências. |
| Metrics local/composição | Análise limpa; 689 testes focados e 946 globais aprovados. |
| Registro do ToStore no módulo raiz | `flutter pub get` concluído; `flutter analyze` sem problemas; 946 testes globais aprovados. |

Os números são retratos de etapas diferentes, não contagens cumulativas.
Os bloqueios de compilação/análise acima não apareceram na última verificação.
Nenhum resultado comprova build nativo atual, UI, backup ou prontidão de release.

O registro detalhado de Expense/CSV permanece em
[verification.md](../../openspec/changes/migrate-expense-to-tostore/verification.md);
o comportamento de CSV descrito ali foi posteriormente removido.

## Histórico anterior à versão local

Specs e changes do OpenSpec preservam decisões e checklists de suas respectivas
épocas, incluindo sessão, autenticação, áudio, CSV, Insight e mecanismos de
commands já substituídos. Consulte o [índice](../../openspec/README.md).
Os textos anteriores dos guias raiz e seus logs completos permanecem no histórico
Git; não são instruções atuais de execução ou implementação.

Builds debug Android/iOS Simulator e testes de políticas nativas foram registrados
em etapas anteriores à versão local. A adição direta do widget médio pela galeria
iOS foi confirmada pelo usuário naquela etapa; o atalho de redimensionamento do
SpringBoard permaneceu sem correção confirmada. Não há homologação atual da versão
local por esses registros.
