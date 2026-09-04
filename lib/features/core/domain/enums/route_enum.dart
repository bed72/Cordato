enum RouteEnum {
  root('/'),
  welcome('/welcome'),
  dashboard('/dashboard'),
  authenticationCallback('/callback'),
  authenticationMagicLink('/authentication/magic-link');

  final String path;

  const RouteEnum(this.path);
}
