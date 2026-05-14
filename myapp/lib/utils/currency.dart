const double _eurToDzd = 155.0;

/// Convertit un prix EUR en DZD et retourne une chaîne formatée
String formatDzd(double eurPrice) {
  final dzd = (eurPrice * _eurToDzd).round();
  // Formatage avec espace comme séparateur de milliers
  final s = dzd.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(s[i]);
  }
  return '${buffer.toString()} DZD';
}

/// Convertit un montant string EUR en DZD formaté
String formatDzdFromString(String eurStr) {
  final eur = double.tryParse(eurStr) ?? 0.0;
  return formatDzd(eur);
}
