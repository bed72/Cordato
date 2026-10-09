enum HttpPathEnum({
  required final String path,
  required final bool authenticated,
}) {
  user(path: 'users', authenticated: true),
  expenses(path: 'expenses', authenticated: true),
  insights(path: 'insights', authenticated: true),
  logout(path: 'authentication/sign-out', authenticated: true),
  signIn(path: 'authentication/sign-in', authenticated: false),
  signUp(path: 'authentication/sign-up', authenticated: false),
  resendEmailVerification(
    path: 'authentication/email-verification/resend',
    authenticated: false,
  ),
}
