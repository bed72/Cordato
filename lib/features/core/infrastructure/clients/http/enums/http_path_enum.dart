enum HttpPathEnum(final String path, {final bool requiresAuth = false}) {
  signIn('authentication/sign-in'),
  signUp('authentication/sign-up'),
  logout('authentication/sign-out', requiresAuth: true),
  expenses('expenses', requiresAuth: true),
  resendEmailVerification('authentication/email-verification/resend'),
}
