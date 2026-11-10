# Hello World

Exemplo importável com somente nós nativos:

```text
Enviar saudação (Inject) → Exibir saudação (Debug)
```

## Importar e executar

1. Abra https://worker.cordato.cloud/admin/ e faça login.
2. No menu do editor, escolha **Import** e selecione o arquivo `flows.json`
   desta pasta, ou cole seu conteúdo.
3. Confirme a importação e confira a aba **Hello World** antes de usar **Deploy**.
4. Abra a barra lateral **Debug**.
5. Clique no botão à esquerda do nó **Enviar saudação**.
6. A mensagem **Hello, world!** deve aparecer no Debug como `msg.payload`.

O disparo é exclusivamente manual: não há execução automática na inicialização,
timer, endpoint HTTP, rede, acesso a arquivos ou credenciais. O Debug exibe somente
a saudação fictícia na barra lateral, não no console do servidor.
Não é necessário rebuild ou alteração das variáveis do Dokploy.

## Exportar alterações

No editor, selecione somente a aba deste exemplo e use **Export → current flow**,
com JSON formatado. Substitua o `flows.json` desta pasta após revisar o conteúdo.
Não inclua outros flows ou segredos. Se importar novamente, confira os avisos de
IDs existentes para não duplicar ou sobrescrever alterações sem intenção.

A estrutura JSON foi verificada localmente, sem iniciar o Node-RED. Importação,
disparo e exibição no painel precisam ser conferidos na instância publicada.
