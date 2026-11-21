enum RouteEnum(final String path, {final bool authenticated = false}) {
  app('/'),
  welcome('/welcome'),
  user('/user'),
  informationHelp('/information/help'),
  informationTerms('/information/terms'),
  expense('/expense', authenticated: true),
  informationPrivacy('/information/privacy'),
  expenses('/expenses', authenticated: true),
  settings('/settings', authenticated: true),
  userEdit('/user/edit'),
  dashboard('/dashboard', authenticated: true),
  authenticationSignIn('/authentication/sign-in'),
  authenticationSignUp('/authentication/sign-up'),
  authenticationConfirm('/authentication/confirm'),
  settingsSupport('/settings/support', authenticated: true),
  authenticationConfirmEmail('/authentication/confirm-email'),
  authenticationPasswordRecovery('/authentication/password-recovery'),
  authenticationChangePassword(
    '/authentication/change-password',
    authenticated: true,
  ),
  authenticationResetPassword('/authentication/reset-password');

  static Set<String> authenticatedPaths() => values
      .where((route) => route.authenticated)
      .map((route) => route.path)
      .toSet();
}
