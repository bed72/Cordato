enum SupabaseTableEnum {
  budgets('budgets'),
  profiles('profiles'),
  pushTokens('push_tokens');

  final String value;

  const SupabaseTableEnum(this.value);
}
