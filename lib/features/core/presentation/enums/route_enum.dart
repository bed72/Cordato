enum RouteEnum(final String path) {
  root('/'),
  budget('/budget'),
  expense('/expense'),
  welcome('/welcome'),
  settings('/settings'),
  dashboard('/dashboard'),
  authenticationCallback('/callback'),
  authenticationMagicLink('/authentication/magic-link'),
  authenticationConfirmationCode('/authentication/confirmation-code'),
}
