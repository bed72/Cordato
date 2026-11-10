# Cordato — worker Node-RED

- Serviço independente, sem alterações implícitas no Flutter ou PocketBase.
- Escopo: infraestrutura Node-RED 5.0.9 / Node.js 24, sem bibliotecas adicionais, endpoints de flows ou integração de áudio/Gemini/PocketBase.
- Documentação em português. Não adicionar comentários ao código, `var` ou identificadores chamados `result`.
- Editor e Admin API exigem autenticação. Não criar senha padrão, acesso anônimo ou fallback que desabilite autenticação/criptografia.
- Não ler, imprimir, versionar ou sobrescrever segredos. `.env.example` contém somente exemplos; valores reais pertencem ao ambiente privado local/Dokploy.
- Preservar `/data`, flows e credenciais. A imagem semeia `flows.json` somente quando ausente; nunca sobrescrever automaticamente ou apagar volumes para atualizar.
- Versionar flows após exportação e revisão. Não versionar `*_cred.json`, backups, logs ou dados pessoais.
- Flows importáveis ficam em `flows/<nome>/flows.json`, com README próprio e exportação completa da funcionalidade. `worker/flows.json` continua como base inicial do container; não carregar exemplos automaticamente nem agregar/sobrescrever flows existentes.
- Não instalar módulos pela paleta ou Function sem tarefa explícita. Dependências futuras exigem versões fixadas na imagem.
- Não executar deploy, push, build, containers ou mudanças remotas sem autorização específica.
- Verificações desta pasta: `node --check settings.js`, `node --test test/*.test.js`, `sh -n docker/entrypoint.sh`, `shellcheck docker/entrypoint.sh` e `git diff --check`.
- Com Docker disponível, validar os dois pares Compose usando `config --quiet` e variáveis fictícias; nunca imprimir configuração resolvida com segredos reais.
- Registrar bloqueios. Testes de configuração não comprovam login, HTTPS, persistência em containers, deploy ou integração de áudio.
