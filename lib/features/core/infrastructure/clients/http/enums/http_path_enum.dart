enum HttpPathEnum({
  required final String path,
  required final bool authenticated,
  final bool requiresId = false,
  final bool acceptsId = false,
}) {
  user(path: 'users', authenticated: true, requiresId: true),
  expenses(path: 'expenses', authenticated: true, acceptsId: true),
  logout(path: 'authentication/sign-out', authenticated: true),
  signIn(path: 'authentication/sign-in', authenticated: false),
  signUp(path: 'authentication/sign-up', authenticated: false),
  resendEmailVerification(
    path: 'authentication/email-verification/resend',
    authenticated: false,
  ),
}
