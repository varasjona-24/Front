class CountryOption {
  const CountryOption({
    required this.code,
    required this.name,
    required this.regionKey,
  });

  final String code;
  final String name;
  final String regionKey;
}

class CountryCatalog {
  const CountryCatalog._();

  static const List<CountryOption> all = [
    // Latino
    CountryOption(code: 'AR', name: 'Argentina', regionKey: 'latino'),
    CountryOption(code: 'BO', name: 'Bolivia', regionKey: 'latino'),
    CountryOption(code: 'BR', name: 'Brasil', regionKey: 'latino'),
    CountryOption(code: 'CL', name: 'Chile', regionKey: 'latino'),
    CountryOption(code: 'CO', name: 'Colombia', regionKey: 'latino'),
    CountryOption(code: 'CR', name: 'Costa Rica', regionKey: 'latino'),
    CountryOption(code: 'CU', name: 'Cuba', regionKey: 'latino'),
    CountryOption(
      code: 'DO',
      name: 'Republica Dominicana',
      regionKey: 'latino',
    ),
    CountryOption(code: 'EC', name: 'Ecuador', regionKey: 'latino'),
    CountryOption(code: 'SV', name: 'El Salvador', regionKey: 'latino'),
    CountryOption(code: 'GT', name: 'Guatemala', regionKey: 'latino'),
    CountryOption(code: 'HN', name: 'Honduras', regionKey: 'latino'),
    CountryOption(code: 'MX', name: 'Mexico', regionKey: 'latino'),
    CountryOption(code: 'NI', name: 'Nicaragua', regionKey: 'latino'),
    CountryOption(code: 'PA', name: 'Panama', regionKey: 'latino'),
    CountryOption(code: 'PY', name: 'Paraguay', regionKey: 'latino'),
    CountryOption(code: 'PE', name: 'Peru', regionKey: 'latino'),
    CountryOption(code: 'PR', name: 'Puerto Rico', regionKey: 'latino'),
    CountryOption(code: 'UY', name: 'Uruguay', regionKey: 'latino'),
    CountryOption(code: 'VE', name: 'Venezuela', regionKey: 'latino'),

    // Anglo
    CountryOption(code: 'CA', name: 'Canada', regionKey: 'anglo'),
    CountryOption(code: 'GB', name: 'Reino Unido', regionKey: 'anglo'),
    CountryOption(code: 'IE', name: 'Irlanda', regionKey: 'anglo'),
    CountryOption(code: 'US', name: 'Estados Unidos', regionKey: 'anglo'),

    // Europeo
    CountryOption(code: 'AT', name: 'Austria', regionKey: 'europeo'),
    CountryOption(code: 'BE', name: 'Belgica', regionKey: 'europeo'),
    CountryOption(code: 'CH', name: 'Suiza', regionKey: 'europeo'),
    CountryOption(code: 'CZ', name: 'Chequia', regionKey: 'europeo'),
    CountryOption(code: 'DE', name: 'Alemania', regionKey: 'europeo'),
    CountryOption(code: 'DK', name: 'Dinamarca', regionKey: 'europeo'),
    CountryOption(code: 'ES', name: 'Espana', regionKey: 'europeo'),
    CountryOption(code: 'FI', name: 'Finlandia', regionKey: 'europeo'),
    CountryOption(code: 'FR', name: 'Francia', regionKey: 'europeo'),
    CountryOption(code: 'GR', name: 'Grecia', regionKey: 'europeo'),
    CountryOption(code: 'HU', name: 'Hungria', regionKey: 'europeo'),
    CountryOption(code: 'IT', name: 'Italia', regionKey: 'europeo'),
    CountryOption(code: 'NL', name: 'Paises Bajos', regionKey: 'europeo'),
    CountryOption(code: 'NO', name: 'Noruega', regionKey: 'europeo'),
    CountryOption(code: 'PL', name: 'Polonia', regionKey: 'europeo'),
    CountryOption(code: 'PT', name: 'Portugal', regionKey: 'europeo'),
    CountryOption(code: 'RO', name: 'Rumania', regionKey: 'europeo'),
    CountryOption(code: 'RU', name: 'Rusia', regionKey: 'europeo'),
    CountryOption(code: 'SE', name: 'Suecia', regionKey: 'europeo'),
    CountryOption(code: 'TR', name: 'Turquia', regionKey: 'europeo'),
    CountryOption(code: 'UA', name: 'Ucrania', regionKey: 'europeo'),

    // Asiatico
    CountryOption(code: 'CN', name: 'China', regionKey: 'asiatico'),
    CountryOption(code: 'HK', name: 'Hong Kong', regionKey: 'asiatico'),
    CountryOption(code: 'ID', name: 'Indonesia', regionKey: 'asiatico'),
    CountryOption(code: 'IN', name: 'India', regionKey: 'asiatico'),
    CountryOption(code: 'JP', name: 'Japon', regionKey: 'asiatico'),
    CountryOption(code: 'KR', name: 'Corea del Sur', regionKey: 'asiatico'),
    CountryOption(code: 'MY', name: 'Malasia', regionKey: 'asiatico'),
    CountryOption(code: 'PH', name: 'Filipinas', regionKey: 'asiatico'),
    CountryOption(code: 'SG', name: 'Singapur', regionKey: 'asiatico'),
    CountryOption(code: 'TH', name: 'Tailandia', regionKey: 'asiatico'),
    CountryOption(code: 'TW', name: 'Taiwan', regionKey: 'asiatico'),
    CountryOption(code: 'VN', name: 'Vietnam', regionKey: 'asiatico'),

    // Africano
    CountryOption(code: 'CM', name: 'Camerun', regionKey: 'africano'),
    CountryOption(code: 'DZ', name: 'Argelia', regionKey: 'africano'),
    CountryOption(code: 'EG', name: 'Egipto', regionKey: 'africano'),
    CountryOption(code: 'ET', name: 'Etiopia', regionKey: 'africano'),
    CountryOption(code: 'GH', name: 'Ghana', regionKey: 'africano'),
    CountryOption(code: 'KE', name: 'Kenia', regionKey: 'africano'),
    CountryOption(code: 'MA', name: 'Marruecos', regionKey: 'africano'),
    CountryOption(code: 'NG', name: 'Nigeria', regionKey: 'africano'),
    CountryOption(code: 'SN', name: 'Senegal', regionKey: 'africano'),
    CountryOption(code: 'TN', name: 'Tunez', regionKey: 'africano'),
    CountryOption(code: 'ZA', name: 'Sudafrica', regionKey: 'africano'),

    // Medio Oriente
    CountryOption(
      code: 'AE',
      name: 'Emiratos Arabes Unidos',
      regionKey: 'medio_oriente',
    ),
    CountryOption(code: 'BH', name: 'Barein', regionKey: 'medio_oriente'),
    CountryOption(code: 'IL', name: 'Israel', regionKey: 'medio_oriente'),
    CountryOption(code: 'IQ', name: 'Irak', regionKey: 'medio_oriente'),
    CountryOption(code: 'IR', name: 'Iran', regionKey: 'medio_oriente'),
    CountryOption(code: 'JO', name: 'Jordania', regionKey: 'medio_oriente'),
    CountryOption(code: 'KW', name: 'Kuwait', regionKey: 'medio_oriente'),
    CountryOption(code: 'LB', name: 'Libano', regionKey: 'medio_oriente'),
    CountryOption(code: 'OM', name: 'Oman', regionKey: 'medio_oriente'),
    CountryOption(code: 'PS', name: 'Palestina', regionKey: 'medio_oriente'),
    CountryOption(code: 'QA', name: 'Qatar', regionKey: 'medio_oriente'),
    CountryOption(
      code: 'SA',
      name: 'Arabia Saudita',
      regionKey: 'medio_oriente',
    ),
    CountryOption(code: 'SY', name: 'Siria', regionKey: 'medio_oriente'),
    CountryOption(code: 'YE', name: 'Yemen', regionKey: 'medio_oriente'),

    // Oceania
    CountryOption(code: 'AU', name: 'Australia', regionKey: 'oceania'),
    CountryOption(code: 'FJ', name: 'Fiyi', regionKey: 'oceania'),
    CountryOption(code: 'NZ', name: 'Nueva Zelanda', regionKey: 'oceania'),
    CountryOption(code: 'PG', name: 'Papua Nueva Guinea', regionKey: 'oceania'),
    CountryOption(code: 'WS', name: 'Samoa', regionKey: 'oceania'),
  ];

  static final Map<String, CountryOption> _byCode = {
    for (final country in all) country.code: country,
  };

  static final Map<String, CountryOption> _byName = {
    for (final country in all) _normalizeText(country.name): country,
  };

  static CountryOption? findByCode(String? code) {
    final key = (code ?? '').trim().toUpperCase();
    if (key.isEmpty) return null;
    return _byCode[key];
  }

  static CountryOption? findByName(String? name) {
    final key = _normalizeText(name ?? '');
    if (key.isEmpty) return null;
    return _byName[key];
  }

  static String? countryNameFromCode(String? code) {
    return findByCode(code)?.name;
  }

  static String? regionKeyFromCode(String? code) {
    return findByCode(code)?.regionKey;
  }

  static List<CountryOption> byRegion(String regionKey) {
    final key = regionKey.trim().toLowerCase();
    final filtered = all.where((entry) => entry.regionKey == key).toList();
    filtered.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return filtered;
  }

  static String flagFromIso(String? countryCode) {
    final code = (countryCode ?? '').trim().toUpperCase();
    if (!RegExp(r'^[A-Z]{2}$').hasMatch(code)) return '';
    return String.fromCharCodes(
      code.codeUnits.map((char) => 0x1F1E6 + (char - 0x41)),
    );
  }

  static String _normalizeText(String value) {
    var text = value.trim().toLowerCase();
    const accents = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u',
      'ñ': 'n',
    };
    accents.forEach((raw, clean) {
      text = text.replaceAll(raw, clean);
    });
    text = text.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text;
  }
}
