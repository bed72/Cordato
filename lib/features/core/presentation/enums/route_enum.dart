enum RouteEnum(final String path, {final bool authenticated = false}) {
  app('/'),
  welcome('/welcome'),
  user('/user', authenticated: true),
  expense('/expense', authenticated: true),
  expenses('/expenses', authenticated: true),
  settings('/settings', authenticated: true),
  userEdit('/user/edit', authenticated: true),
  dashboard('/dashboard', authenticated: true),
  authenticationSignIn('/authentication/sign-in'),
  authenticationSignUp('/authentication/sign-up'),
  authenticationConfirm('/authentication/confirm'),
  authenticationConfirmEmail('/authentication/confirm-email'),
  authenticationPasswordRecovery('/authentication/password-recovery'),
  authenticationResetPassword('/authentication/reset-password');

  static Set<String> authenticatedPaths() => values
      .where((route) => route.authenticated)
      .map((route) => route.path)
      .toSet();
}
