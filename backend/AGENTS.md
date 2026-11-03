# Cordato — orientações para agentes

- Esta pasta `backend/` contém o serviço PocketBase independente do aplicativo Flutter, publicado pelo Dokploy. Não adicionar dependências do Flutter ou Node ao runtime do backend.
- Documentação e mensagens ao usuário em português.
- Não ler, imprimir, versionar ou sobrescrever arquivos com segredos. `.env.example` pode conter somente exemplos fictícios.
- Não versionar binários PocketBase, `pb_data`, arquivos enviados, backups ou logs.
- Preservar dados e configurações privadas existentes. Não alterar serviços remotos, volumes ou credenciais sem autorização específica.
- Não executar deploy, push, iniciar infraestrutura ou baixar executáveis sem solicitação.
- A configuração usa PocketBase 0.41.1, migrations e APIs nativas, sem hooks e sem worker. Conferir a documentação oficial da versão antes de alterar contratos.
- Authentication, Session, User, Expense e Metrics usam APIs nativas. Metrics lê `metrics`, view somente leitura por proprietário/mês: somas inteiras e percentuais são calculados em SQL, centavos são expostos como texto para preservar precisão. Sugestões de despesas são GETs filtrados do histórico, sem endpoint customizado. Não recriar endpoints JSON:API, revogação remota ou callbacks antigos por referência à documentação do cliente. Consultar os limites de integração em `../ARCHITECTURE.md`; insights, orçamento e família não estão implementados nesta configuração.
- Usuários gerenciam somente a própria conta e despesas. Proteger propriedade, campos administrativos e exclusão em cascata com regras/schema nativos.
- Configuração, decisões e limites de validação estão no README. Não alegar build, testes nativos, integração ou deploy sem evidência. As migrations iniciais são exclusivas para banco novo; não reaplicar em instâncias existentes.
- Execute comandos desta pasta `backend/`. Não há suíte de testes automatizados neste backend por decisão do projeto; não adicionar Python ou recriar testes sem solicitação. Verificações locais: `sh -n docker/entrypoint.sh` e `git diff --check`.
- Build, containers e validações operacionais exigem autorização própria. Validar saúde HTTP não comprova permissões, entrega de e-mail ou recuperação de backups.
