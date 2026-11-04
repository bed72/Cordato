## Why

Dados pessoais ainda não permite que uma pessoa autenticada altere a própria senha. Além disso, a validação Flutter diverge do PocketBase, causando rejeições remotas que poderiam ser explicadas antes do envio.

## What Changes

- Adicionar a ação **Alterar senha** em Dados pessoais e uma tela com senha atual, nova senha e confirmação.
- Unificar a regra de senha criada no app com o backend: 6–16 caracteres, pelo menos uma letra minúscula ASCII, uma maiúscula ASCII e um número ASCII.
- Aplicar a regra compartilhada no cadastro, na recuperação e na troca; revisar também os consumidores existentes do mesmo validator, incluindo sign-in, sem duplicar políticas.
- Rejeitar localmente nova senha igual à atual e confirmação diferente da nova, com mensagens nos respectivos campos.
- Usar o PATCH nativo autenticado de `users`, exigindo a senha atual.
- Após a alteração, encerrar a sessão local e solicitar novo login. Se a limpeza local falhar, permitir repetir somente o logout, nunca a alteração já confirmada.
- Impedir exposição das senhas nos estados e logs e adicionar testes unitários do fluxo e da política compartilhada.

## Capabilities

### New Capabilities

- `authenticated-password-change`: alteração autenticada da própria senha a partir de Dados pessoais, erros de formulário e encerramento da sessão.
- `shared-password-policy`: política de senha Flutter consistente com PocketBase, compartilhada entre os formulários existentes e o novo fluxo.

### Modified Capabilities

Nenhuma spec existente precisa ser modificada. O logout continua local e aguardado; as descrições históricas de Supabase não serão restauradas.

## Impact

- `authentication`: contrato e repository, nova tela/Bloc/rota, validações, formatação e previews.
- `user`: ação de navegação em Dados pessoais, sem migração incidental do lifecycle existente.
- `core`: catálogo de rotas e proteção do logger HTTP para payloads sensíveis de alteração de senha.
- Testes unitários de validação, infraestrutura, Bloc, formatter, rotas/DI e arquitetura; sem testes de UI.
- Documentação vigente: `AGENTS.md`, `ARCHITECTURE.md` e `README.md` conforme os contratos e o estado do produto implementados.
- Backend permanece com API, schema e regras atuais. Não inclui migrations, alteração de dados, deploy, dependências novas ou implementação nesta etapa de proposta.
