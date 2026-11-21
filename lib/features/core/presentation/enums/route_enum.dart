enum RouteEnum(final String path) {
  app('/'),
  user('/user'),
  welcome('/welcome'),
  settings('/settings'),
  userEdit('/user/edit'),
  settingsSupport('/settings/support'),
  informationHelp('/information/help'),
  informationTerms('/information/terms'),
  expense('/expense'),
  informationPrivacy('/information/privacy'),
  expenses('/expenses'),
  dashboard('/dashboard'),
  authenticationSignIn('/authentication/sign-in'),
  authenticationSignUp('/authentication/sign-up'),
  authenticationConfirm('/authentication/confirm');

  final bool authenticated = false;

  static Set<String> authenticatedPaths() => values
      .where((route) => route.authenticated)
      .map((route) => route.path)
      .toSet();
}
