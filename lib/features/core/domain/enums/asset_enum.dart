enum AssetEnum {
  logo(alt: 'Logo Trocado', source: 'assets/images/logo.webp');

  final String alt;
  final String source;

  const AssetEnum({required this.alt, required this.source});
}
