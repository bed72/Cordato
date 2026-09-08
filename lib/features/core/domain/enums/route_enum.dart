enum RouteEnum {
  root('/'),
  welcome('/welcome'),
  dashboard('/dashboard'),
  budget('/budget'),
  authenticationCallback('/callback'),
  authenticationConfirmationCode('/authentication/confirmation-code'),
  authenticationMagicLink('/authentication/magic-link');

  final String path;

  const RouteEnum(this.path);
}
