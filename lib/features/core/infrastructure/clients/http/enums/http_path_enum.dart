enum HttpPathEnum({
  required final String path,
  required final bool authenticated,
}) {
  user(path: 'users', authenticated: true),
  expenses(path: 'expenses', authenticated: true),
  logout(path: 'authentication/sign-out', authenticated: true),
  expenseMetrics(path: 'metrics/expenses', authenticated: true),
  signIn(path: 'collections/users/auth-with-password', authenticated: false),
  signUp(path: 'authentication/sign-up', authenticated: false),
  resendEmailVerification(
    path: 'authentication/email-verification/resend',
    authenticated: false,
  ),
}
