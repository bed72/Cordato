enum RouteEnum(final String path, {final bool authenticated = false}) {
  app('/'),
  welcome('/welcome'),
  expense('/expense', authenticated: true),
  settings('/settings', authenticated: true),
  dashboard('/dashboard', authenticated: true),
  authenticationSignIn('/authentication/sign-in'),
  authenticationSignUp('/authentication/sign-up'),
  authenticationConfirm('/authentication/confirm'),
  authenticationConfirmEmail('/authentication/confirm-email');

  static Set<String> authenticatedPaths() => values
      .where((route) => route.authenticated)
      .map((route) => route.path)
      .toSet();
}
