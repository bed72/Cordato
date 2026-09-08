enum RouteEnum {
  root('/'),
  budget('/budget'),
  welcome('/welcome'),
  dashboard('/dashboard'),
  authenticationCallback('/callback'),
  authenticationMagicLink('/authentication/magic-link'),
  authenticationConfirmationCode('/authentication/confirmation-code');

  final String path;

  const RouteEnum(this.path);
}
