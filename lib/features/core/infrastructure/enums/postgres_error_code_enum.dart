enum PostgresErrorCodeEnum {
  exclusionViolation('23P01');

  final String value;

  const PostgresErrorCodeEnum(this.value);
}
