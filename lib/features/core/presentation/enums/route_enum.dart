enum RouteEnum(final String path, {final bool authenticated = false}) {
  app('/'),
  welcome('/welcome'),
  user('/user', authenticated: true),
  informationHelp('/information/help'),
  informationTerms('/information/terms'),
  expense('/expense', authenticated: true),
  informationPrivacy('/information/privacy'),
  expenses('/expenses', authenticated: true),
  settings('/settings', authenticated: true),
  userEdit('/user/edit', authenticated: true),
  dashboard('/dashboard', authenticated: true),
  authenticationSignIn('/authentication/sign-in'),
  authenticationConfirm('/authentication/confirm'),
  settingsSupport('/settings/support', authenticated: true);

  static Set<String> authenticatedPaths() => values
      .where((route) => route.authenticated)
      .map((route) => route.path)
      .toSet();
}
