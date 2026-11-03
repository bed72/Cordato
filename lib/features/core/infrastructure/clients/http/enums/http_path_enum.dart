enum HttpPathEnum({
  required final String path,
  required final bool authenticated,
}) {
  user(path: 'users', authenticated: true),
  expenses(path: 'expenses', authenticated: true),
  signUp(path: 'collections/users/records', authenticated: false),
  userRecords(path: 'collections/users/records', authenticated: true),
  authRefresh(path: 'collections/users/auth-refresh', authenticated: true),
  expenseRecords(path: 'collections/expenses/records', authenticated: true),
  signIn(path: 'collections/users/auth-with-password', authenticated: false),
  expenseMetrics(
    path: 'collections/metrics/records',
    authenticated: true,
  ),
  resendEmailVerification(
    path: 'collections/users/request-verification',
    authenticated: false,
  ),
  confirmEmailVerification(
    path: 'collections/users/confirm-verification',
    authenticated: false,
  ),
  requestPasswordReset(
    path: 'collections/users/request-password-reset',
    authenticated: false,
  ),
  confirmPasswordReset(
    path: 'collections/users/confirm-password-reset',
    authenticated: false,
  ),
}
