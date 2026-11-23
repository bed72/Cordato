# Revisão antes da publicação do repositório

Data: **23/11/2026**. Revisão local, sem alterar visibilidade, fazer push,
reescrever histórico ou testar credenciais em serviços externos.
Este documento não contém os valores encontrados.

## Escopo e método

- Gitleaks **8.30.1**, distribuição oficial macOS arm64, com SHA-256 conferido
  contra os checksums da mesma release.
- Diretório atual: arquivos versionados, novos e configurações locais ignoradas.
  Dependências, caches de SDK, `.git` e artefatos gerados foram excluídos desse
  scan de diretório. Configurações sensíveis ignoradas foram verificadas também
  por inventário específico.
- Histórico: `gitleaks git` com `--log-opts="--all --full-history"`, incluindo
  **230 commits** alcançáveis pelas referências Git locais.
- Redação integral de valores na saída do scanner (`--redact=100`) e inspeção
  complementar offline. Relatórios brutos não foram incluídos no repositório.
- Inspeção complementar de **4.816 blobs históricos**, dos quais **4.718**
  identificados como texto, para marcadores de chave privada e JWT administrativo.
  Nenhum bloco de chave privada ou JWT `service_role` foi encontrado nessa análise.
- Revisão de atribuições sensíveis nos `.env.example` históricos: os campos de
  senha/chave examinados estavam vazios; os textos restantes eram comentários.

Esses números descrevem o estado local da revisão. Não houve fetch de referências
remotas adicionais, validação de serviços, auditoria de Actions/artifacts,
releases, issues, PRs, forks, backups, máquinas externas ou objetos Git
inacessíveis pelas referências examinadas. Detectores não garantem ausência de
segredos ou de falhas de autorização.

## Resultado

### Código atual e arquivos locais

O scan do diretório atual apontou **uma ocorrência**:

| Local                                                           | Classificação                                                                                          | Ação                                                                                                   |
| --------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------ |
| `lib/features/settings/domain/value_objects/support_pix.dart:4` | Chave Pix de recebimento usada pelo recurso público de apoio; não é credencial de API ou autenticação. | Preservada. Confirmar que o responsável deseja manter públicos a chave Pix e os dados do destinatário. |

Há material de assinatura Android no disco local:

- `android/key.properties` contém valores de senha e configuração de assinatura.
- `android/cordato-release.jks` contém o keystore de release.
- Ambos estão ignorados pelo Git e não foram encontrados como arquivos
  versionados no histórico de caminhos analisado.
- `opencode.json` também está ignorado; o scanner não apontou credenciais nele.

Não incluir esses arquivos em commits, uploads manuais, screenshots ou artifacts
do site. Estar ignorado protege contra inclusão comum, não contra `git add -f`,
cópias de diretório ou vazamento fora do Git. Nenhum desses arquivos foi alterado.

### Histórico: itens que exigem decisão antes de publicar

O scan histórico apontou **13 ocorrências**. Seis são configurações de cliente
antigas, e sete são a chave Pix e fixtures/validação de testes.

| Local histórico                                                                 | Referência     | Classificação e cuidado                                                                                                                                                                                             |
| ------------------------------------------------------------------------------- | -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `android/app/google-services.json:18`                                           | `669152a2a2be` | Chave de API Google/Firebase de configuração do cliente. Excluída da árvore atual, mas ainda presente no histórico.                                                                                                 |
| `lib/features/core/infrastructure/clients/firebase/firebase_options.dart:42,51` | `669152a2a2be` | Outras ocorrências de configuração Google/Firebase. Mesma necessidade de conferir restrições, uso e projeto associado.                                                                                              |
| `.vscode/launch.json:11,22,33`                                                  | `86234f6c0bc7` | JWT Supabase de papel `anon`, repetido em três configurações. O payload, decodificado offline sem verificar assinatura, declara expiração em 2126. Isso não comprova que o serviço ou a chave ainda estejam ativos. |

Chaves Firebase e Supabase `anon` são normalmente distribuídas em aplicativos
clientes: **não equivalem, por si só, a senha administrativa ou `service_role`**.
Ainda assim, tornam o projeto associado identificável e utilizável conforme as
permissões configuradas. Remover o código de integração não desativa os serviços.

Antes de mudar a visibilidade:

1. **Google/Firebase:** confirmar o projeto e as chaves associados. Se não são
   mais usados, revogar/desativar as chaves pertinentes. Se continuam necessários,
   revisar restrições de API/aplicativo, quotas, regras de acesso aos dados e uso
   em outros serviços Google. Não presumir que uma chave Firebase possa ser usada
   sem restrições em APIs pagas.
2. **Supabase:** confirmar se o projeto antigo está ativo e se deve continuar
   acessível. Revisar RLS, políticas de tabelas/Storage e permissões anônimas.
   Se o serviço foi descontinuado, tratar sua desativação e os dados antigos
   separadamente. Não trocar a chave de assinatura/JWT incidentalmente, pois
   isso pode invalidar sessões e afetar outros consumidores.
3. Se algum valor tiver sido usado como segredo ou tiver permissões indevidas,
   **revogar/rotacionar primeiro**. Limpar o histórico não substitui essa medida.
4. Decidir explicitamente se é necessário remover valores do histórico.
   Isso exige planejamento para todas as referências afetadas, coordenação de
   clones/PRs e autorização para reescrita/force-push. Nada disso foi feito.

**A publicação ainda depende dessas confirmações externas.** A revisão local não
declara o repositório livre de riscos nem valida as políticas dos serviços antigos.

### Demais ocorrências históricas

- `support_pix.dart`: endereço Pix de recebimento, não segredo de autenticação.
- Testes antigos de `pocketbase_factory_test.dart`: JWTs sintéticos, sem identidade
  de conta e com assinatura de fixture, não assinatura válida comprovada.
- `backend/tests/run_container_tests.py` e `backend/tests/test_setup.py`:
  chave de criptografia configurada para os processos de teste. Não foi encontrada
  como valor preenchido nos arquivos `.env.example` históricos examinados.
- `sign_in_screen_test.dart`: literal de senha em matriz de validação de formulário,
  sem evidência nesse cenário de que seja credencial de produção.

Esses achados não justificam restaurar backend, autenticação ou seus testes no app.
Não foram criadas regras amplas para ignorar esses nomes no scanner.

## Licenciamento

Foi adicionada `LICENSE`, MIT, com **Copyright (c) 2026 Gabriel Ramos**.
O site declara a mesma licença para o código de autoria do projeto.
Fontes, ícones, trechos derivados e dependências conservam suas licenças.
Em particular, MIT do repositório não substitui as condições de Syncfusion nem
comprova elegibilidade para uma licença Community/comercial.

## Próximos passos

- [ ] Confirmar restrições, necessidade ou desativação das chaves Google/Firebase antigas.
- [ ] Confirmar estado e autorização anônima do projeto Supabase antigo.
- [ ] Confirmar que dados pessoais/Pix, imagens e metadados de autoria podem ser públicos.
- [ ] Confirmar direitos de distribuição dos materiais de terceiros.
- [ ] Se necessário, autorizar separadamente rotação e eventual limpeza de histórico.
- [ ] Rodar novamente o scan após novos commits e antes de alterar a visibilidade.

Nenhuma credencial foi revogada ou testada remotamente. A visibilidade permanece
sob controle do responsável; a revisão não faz commit, push ou deploy.
