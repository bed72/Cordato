enum HttpPathEnum({
  required final String path,
  required final bool authenticated,
}) {
  user(path: 'users', authenticated: true),
  expenses(path: 'expenses', authenticated: true),
  expenseMetrics(path: 'metrics/expenses', authenticated: true),
  userRecords(path: 'collections/users/records', authenticated: true),
  authRefresh(path: 'collections/users/auth-refresh', authenticated: true),
  expenseRecords(path: 'collections/expenses/records', authenticated: true),
  signIn(path: 'collections/users/auth-with-password', authenticated: false),
  signUp(path: 'collections/users/records', authenticated: false),
  resendEmailVerification(
    path: 'collections/users/request-verification',
    authenticated: false,
  ),
  confirmEmailVerification(
    path: 'collections/users/confirm-verification',
    authenticated: false,
  ),
}
