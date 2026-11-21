enum RouteEnum(final String path, {final bool authenticated = false}) {
  app('/'),
  user('/user'),
  welcome('/welcome'),
  settings('/settings'),
  userEdit('/user/edit'),
  settingsSupport('/settings/support'),
  informationHelp('/information/help'),
  informationTerms('/information/terms'),
  expense('/expense', authenticated: true),
  informationPrivacy('/information/privacy'),
  expenses('/expenses', authenticated: true),
  dashboard('/dashboard'),
  authenticationSignIn('/authentication/sign-in'),
  authenticationSignUp('/authentication/sign-up'),
  authenticationConfirm('/authentication/confirm');

  static Set<String> authenticatedPaths() => values
      .where((route) => route.authenticated)
      .map((route) => route.path)
      .toSet();
}
