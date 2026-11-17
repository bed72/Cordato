# Proposal

## Why

O Flutter já possui Dio e cookies persistidos, mas os adapters de backend anteriores foram removidos e Authentication e Session continuam sem implementação de produção. O próximo passo é disponibilizar infraestrutura Appwrite para entrada sem senha por OTP de e-mail, sem antecipar a migração das telas.

## What Changes

- Introduzir contrato de aplicação e repository para solicitar OTP, confirmar código e encerrar a sessão atual, sem métodos de senha ou cadastro separado.
- Implementar restauração e observação de sessão por cookies e consulta autenticada de `/account`.
- Compartilhar uma coordenação mínima das operações de sessão entre repositories, independente de apresentação e sem dependência direta entre Authentication e Session.
- Registrar infraestrutura de produção na DI, com testes de contratos, transporte, persistência, concorrência e resolução isolada.
- Substituir a especificação histórica de logout por comportamento de infraestrutura Appwrite; não migrar Settings nesta etapa.
- Substituir o contrato antigo pelo único `IAuthenticationRepository`, sem nomes públicos com OTP, interface paralela ou contrato legado, conforme correção explícita do usuário na step 1.
- A escolha de produto é OTP no lugar de senha; a remoção física das telas, Blocs e rotas fica para a mudança de apresentação. Seus consumidores dos métodos removidos permanecem incompatíveis até essa migração; não criar stubs ou sucesso fictício.

## Capabilities

### New Capabilities

- `email-otp-authentication`: contrato e transporte para emissão de desafio de e-mail e criação de sessão sem senha.
- `cookie-session`: validação, restauração, persistência e observação da sessão Appwrite com proteção de concorrência.

### Modified Capabilities

- `authentication-session-logout`: revogação da sessão Appwrite atual, limpeza local e isolamento das camadas, substituindo requisitos históricos de Supabase/commands sem alterar UI.

## Impact

- Application/infrastructure e composição de Authentication, Session e capacidade compartilhada de sessão no core; testes sem UI e documentação do estado de transição.
- REST Appwrite: `POST /account/tokens/email`, `POST /account/sessions/token`, `GET /account` e `DELETE /account/sessions/current`, preservando `/v1` do endpoint configurado.
- Reutilização de Dio, `PersistCookieJar`, `CookieManager`, `OriginInterceptor` e `ResponseMapper`; sem SDK Appwrite, API key administrativa, novo wrapper CRUD, logs ou storage seguro adicional.
- Não altera telas, widgets, Blocs, rotas, navegação, cooldown visual ou Settings; não migra User, Expense, Metrics, exportação, áudio, dados, backend ou worker.
- Não entrega login utilizável na interface nem comprova execução completa do app ou homologação remota. Outros contratos de backend seguem sem adapters.
