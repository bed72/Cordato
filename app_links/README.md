# Links de verificação do Cordato

Destino único para Android App Links e iOS Universal Links:

```text
https://app.cordato.cloud/authentication/confirm-email?token={TOKEN}
```

O callback Flutter já aceita exatamente um `token` na query, confirma pelo
endpoint nativo do PocketBase e não cria sessão. Não usar o endereço do painel
`/_/#/auth/...`, um redirect HTTP para ele ou um esquema customizado como destino
do e-mail. Links antigos continuam apontando para o navegador; solicitar novo
e-mail após atualizar o template.

## Gerar os arquivos públicos

Execute na raiz do repositório:

```sh
dart run tool/app_links.dart "$APPLE_APPLICATION_IDENTIFIER" "$ANDROID_APP_SIGNING_SHA256"
```

Esses valores são identificadores públicos, não credenciais:

- `APPLE_APPLICATION_IDENTIFIER`: `PREFIX.com.bed.cordato`, conforme o entitlement
  `application-identifier` do app assinado. O prefixo geralmente é o Team ID, mas
  pode ser diferente em contas antigas. Não inventar o prefixo.
- `ANDROID_APP_SIGNING_SHA256`: SHA-256 do certificado que **assina o aplicativo
  instalado**, com 32 pares hexadecimais separados por `:`. Para Google Play,
  usar o certificado de **App Signing**, não apenas o de upload. Para APK direto,
  usar o certificado de release. Argumentos adicionais permitem mais certificados
  de distribuição durante rotação. Não autorizar certificado debug em produção.

O gerador valida o formato antes de escrever e cria, em `build/app_links/`:

```text
.well-known/assetlinks.json
.well-known/apple-app-site-association
```

O diretório gerado é ignorado pelo Git. O gerador não faz rede, deploy, leitura de
keystore ou configuração Apple. Não há página alternativa ou confirmação no
navegador; a confirmação permanece no app.

## Publicação e ordem de ativação

1. Hospedar os arquivos gerados em **`app.cordato.cloud`**, com HTTPS válido.
   Publicar `.well-known` inclusive se o provedor normalmente omitir pastas ocultas.
   Preservar rotas e conteúdo já existentes nesse domínio: não substituir o site
   inteiro por este diretório.
2. Servir ambos os arquivos de associação com HTTP **200**, sem autenticação,
   redirects ou sufixo `.json` no arquivo Apple, com `Content-Type: application/json`.
3. Desabilitar registro de query strings no proxy, CDN e servidor para o caminho
   de confirmação. Não adicionar analytics, session replay ou recursos externos.
   O projeto não fornece página web para esse caminho; a proteção dos logs
   continua sendo responsabilidade da infraestrutura.
4. No Apple Developer, habilitar **Associated Domains** para `com.bed.cordato` e
   regenerar os profiles de assinatura. O projeto já referencia
   `Runner/Runner.entitlements` em Debug/Profile/Release, contendo
   `applinks:app.cordato.cloud`. O esquema legado `trocado` não precisa ser removido.
   Android já declara `autoVerify`, host e caminho exatos no manifest/resources.
5. Instalar builds assinados com esses identificadores e verificar a associação.
   Só então publicar o backend atualizado, com autorização operacional separada:
   a migration `1793577600_users_verification_app_link.js` troca somente o destino
   do template de verificação de `users`, preservando assunto, HTML, dados,
   settings e templates de `_superusers`. Não reaplicar a migration inicial.
   Se o template tiver destino personalizado não reconhecido, a migration falha
   para exigir revisão, em vez de sobrescrever silenciosamente.
6. Solicitar novo e-mail e validar o link real. Entrega SMTP e abertura no app
   continuam exigindo homologação; testes unitários não comprovam essas etapas.

Sem os identificadores reais, hospedagem e assinatura autorizada, os arquivos
locais **não ativam** a abertura automática do app.

## Homologação manual

- Android 12+: `adb shell pm verify-app-links --re-verify com.bed.cordato`, depois
  `adb shell pm get-app-links com.bed.cordato`; conferir domínio `verified`.
- Testar no Android um link HTTPS sem especificar pacote/Activity, para não
  contornar a resolução do sistema. Usar somente token fictício nos comandos.
- No iOS, reinstalar o build após publicar AASA e testar tocando no link em Mail
  ou Notes. Digitar o endereço no Safari não equivale a tocar em Universal Link;
  preferências do usuário e cache da CDN Apple também influenciam a abertura.
- Nas duas plataformas, testar app encerrado e aberto, confirmação válida,
  token inválido/expirado, query com tokens duplicados e ausência do app.
- Sem o app, não há fallback fornecido pelo projeto nem confirmação automática.
  Não registrar tokens reais em logs, capturas ou relatórios.

Referências: [Android App Links](https://developer.android.com/training/app-links/verify-android-applinks),
[Universal Links](https://developer.apple.com/documentation/xcode/supporting-universal-links-in-your-app),
[PocketBase 0.41.1 migrations](https://pocketbase.io/docs/js-migrations/).

## Verificação local desta alteração

- `flutter pub get`: concluído.
- `flutter analyze`: sem problemas.
- `flutter test`: 745 testes aprovados, incluindo geração das associações,
  validação de identificadores e coerência das configurações nativas.
- `plutil -lint ios/Runner/Runner.entitlements ios/Runner/Info.plist ios/Runner.xcodeproj/project.pbxproj`: aprovado.
- Em `backend/`, `sh -n docker/entrypoint.sh` e `git diff --check`: aprovados.

Migration revisada conforme documentação oficial 0.41.1; não executada em runtime
PocketBase. Sem build nativo, deploy, alteração remota, envio SMTP ou homologação
em dispositivo. Identificador Apple e certificados de distribuição não foram
fornecidos; nenhum arquivo de associação de produção foi gerado com valores
fictícios.
