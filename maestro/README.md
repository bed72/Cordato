# Testes com Maestro

Os fluxos desta pasta validam a interface e a navegacao do Cordato em um app
instalado em um dispositivo ou emulador.

## Pre-requisitos

1. Inicie um dispositivo Android ou simulador iOS.
2. Instale ou execute o app (`BASE_URL` e opcional; o padrao e
   `https://api.cordato.cloud/api/`):

```bash
flutter run --dart-define=BASE_URL=https://api.exemplo.com/api/
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
nao chama a API. Ele ainda usa textos e botoes do fluxo anterior e precisa ser
atualizado antes de validar a tela de sign-in atual.
