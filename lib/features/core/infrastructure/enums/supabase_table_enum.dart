enum SupabaseTableEnum {
  budgets('budgets'),
  expenses('expenses'),
  profiles('profiles'),
  pushTokens('push_tokens');

  final String value;

  const SupabaseTableEnum(this.value);
}
