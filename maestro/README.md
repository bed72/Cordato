# Testes com Maestro

Os fluxos desta pasta validam a interface e a navegacao do Cordato em um app
instalado em um dispositivo ou emulador.

## Pre-requisitos

1. Inicie um dispositivo Android ou simulador iOS.
2. Instale ou execute o app com as configuracoes obrigatorias:

```bash
flutter run \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=...
```

O identificador esperado pelo fluxo e `com.bed.cordato`.

## Executar

Execute o fluxo inicial:

```bash
maestro test maestro/welcome_authentication.yaml
```

Execute todos os fluxos da pasta:

```bash
maestro test maestro/
```

Execute somente os testes de smoke:

```bash
maestro test --include-tags smoke maestro/
```

O fluxo `welcome_authentication.yaml` limpa o estado local antes de iniciar e
nao chama o backend. Ele cobre a tela de boas-vindas, a navegacao para o login e
as validacoes de e-mail obrigatorio e invalido.
