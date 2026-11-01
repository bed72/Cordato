# Cordato — orientações para agentes

- Esta pasta `backend/` contém o serviço PocketBase independente do aplicativo Flutter, publicado pelo Dokploy. Não adicionar dependências do Flutter ou Node ao runtime do backend.
- Documentação e mensagens ao usuário em português.
- Não ler, imprimir, versionar ou sobrescrever arquivos com segredos. `.env.example` pode conter somente exemplos fictícios.
- Não versionar binários PocketBase, `pb_data`, arquivos enviados, backups ou logs.
- Preservar dados e configurações privadas existentes. Não alterar serviços remotos, volumes ou credenciais sem autorização específica.
- Não executar deploy, push, iniciar infraestrutura ou baixar executáveis sem solicitação.
- A configuração usa PocketBase 0.41.1, migrations e APIs nativas, sem hooks e sem worker. Conferir a documentação oficial da versão antes de alterar contratos.
- O Flutter ainda consome o contrato anterior. Não recriar endpoints JSON:API, revogação remota ou callbacks antigos por referência à documentação do cliente. Consultar os limites de integração em `../ARCHITECTURE.md`; métricas, insights, sugestões, orçamento e família não estão implementados nesta configuração.
- Usuários gerenciam somente a própria conta e despesas. Proteger propriedade, campos administrativos e exclusão em cascata com regras/schema nativos.
- Configuração, decisões e limites de validação estão no README. Não alegar build, testes nativos, integração ou deploy sem evidência. As migrations iniciais são exclusivas para banco novo; não reaplicar em instâncias existentes.
- Execute comandos desta pasta `backend/`. Testes rápidos: `python3 -m unittest discover -s tests -v`. Testes nativos são opt-in com `POCKETBASE_TEST_BINARY` e usam somente bancos descartáveis; não iniciam servidor.
- `tests/run_container_tests.py` é opt-in e exige autorização para iniciar containers locais. Usa Podman já disponível, imagens locais (`--pull=never`), fixtures fictícias, recursos exclusivos, sem saída de rede ou portas publicadas. Remove somente os recursos que criou. Não equivale a teste no Dokploy ou envio real de e-mail.
