final class EmailVerificationUrlValueObject._(final String value) {
  static EmailVerificationUrlValueObject? tryParse(
    String? value, {
    required String baseUrl,
  }) {
    if (value == null) return null;

    final url = Uri.tryParse(value);
    final base = Uri.tryParse(baseUrl);
    if (url == null ||
        base == null ||
        url.scheme != 'https' ||
        base.scheme != 'https' ||
        url.host != base.host ||
        url.port != base.port ||
        url.userInfo.isNotEmpty ||
        url.hasFragment ||
        !RegExp(r'^/api/email-verification/[A-Za-z0-9-]+/[A-Za-z0-9-]+$')
            .hasMatch(url.path) ||
        url.queryParametersAll.length != 2 ||
        url.queryParametersAll['expires']?.length != 1 ||
        url.queryParametersAll['signature']?.length != 1 ||
        !RegExp(r'^\d+$').hasMatch(url.queryParameters['expires'] ?? '') ||
        !RegExp(r'^[a-fA-F0-9]+$')
            .hasMatch(url.queryParameters['signature'] ?? '')) {
      return null;
    }
    return EmailVerificationUrlValueObject._(value);
  }

  @override
  int get hashCode => value.hashCode;

  @override
  bool operator ==(Object other) =>
      other is EmailVerificationUrlValueObject && other.value == value;
}
