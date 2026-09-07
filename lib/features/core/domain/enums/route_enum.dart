enum RouteEnum {
  root('/'),
  welcome('/welcome'),
  dashboard('/dashboard'),
  authenticationCallback('/callback'),
  authenticationConfirmationCode('/authentication/confirmation-code'),
  authenticationMagicLink('/authentication/magic-link');

  final String path;

  const RouteEnum(this.path);
}
