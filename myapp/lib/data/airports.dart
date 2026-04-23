class Airport {
  final String iata;
  final String name;
  final String city;
  final String country;

  const Airport({required this.iata, required this.name, required this.city, required this.country});

  String get display => '$iata — $city, $country';
  String get subtitle => name;

  bool matches(String query) {
    final q = query.toLowerCase();
    return iata.toLowerCase().contains(q) ||
        city.toLowerCase().contains(q) ||
        name.toLowerCase().contains(q) ||
        country.toLowerCase().contains(q);
  }
}

const List<Airport> kAirports = [
  // ── Algérie ──────────────────────────────────────────────────────────────
  Airport(iata: 'ALG', name: 'Aéroport Houari Boumediene',       city: 'Alger',        country: 'Algérie'),
  Airport(iata: 'ORN', name: 'Aéroport Es-Sénia',                city: 'Oran',         country: 'Algérie'),
  Airport(iata: 'CZL', name: 'Aéroport Mohamed Boudiaf',         city: 'Constantine',  country: 'Algérie'),
  Airport(iata: 'AAE', name: 'Aéroport Rabah Bitat',             city: 'Annaba',       country: 'Algérie'),
  Airport(iata: 'TLM', name: 'Aéroport Zenata',                  city: 'Tlemcen',      country: 'Algérie'),
  Airport(iata: 'BJA', name: 'Aéroport Abane Ramdane',           city: 'Béjaïa',       country: 'Algérie'),
  Airport(iata: 'SKI', name: 'Aéroport Aissa Djebara',           city: 'Skikda',       country: 'Algérie'),
  Airport(iata: 'GJL', name: 'Aéroport Taher',                   city: 'Jijel',        country: 'Algérie'),
  Airport(iata: 'TMR', name: 'Aéroport Aguenar',                 city: 'Tamanrasset',  country: 'Algérie'),
  Airport(iata: 'OGX', name: 'Aéroport Ain Beida',               city: 'Ouargla',      country: 'Algérie'),
  Airport(iata: 'GHA', name: 'Aéroport Noumerate',               city: 'Ghardaïa',     country: 'Algérie'),
  Airport(iata: 'ELU', name: 'Aéroport Guemar',                  city: 'El Oued',      country: 'Algérie'),
  Airport(iata: 'BSK', name: 'Aéroport Mohamed Khider',          city: 'Biskra',       country: 'Algérie'),
  Airport(iata: 'BMW', name: 'Aéroport Bordj Badji Mokhtar',     city: 'Bordj Mokhtar',country: 'Algérie'),
  Airport(iata: 'INZ', name: 'Aéroport In Salah',                city: 'In Salah',     country: 'Algérie'),

  // ── France ───────────────────────────────────────────────────────────────
  Airport(iata: 'CDG', name: 'Aéroport Charles de Gaulle',       city: 'Paris',        country: 'France'),
  Airport(iata: 'ORY', name: 'Aéroport d\'Orly',                 city: 'Paris',        country: 'France'),
  Airport(iata: 'BVA', name: 'Aéroport Beauvais-Tillé',          city: 'Paris',        country: 'France'),
  Airport(iata: 'LYS', name: 'Aéroport Lyon-Saint-Exupéry',      city: 'Lyon',         country: 'France'),
  Airport(iata: 'MRS', name: 'Aéroport Marseille-Provence',      city: 'Marseille',    country: 'France'),
  Airport(iata: 'NCE', name: 'Aéroport Nice-Côte d\'Azur',       city: 'Nice',         country: 'France'),
  Airport(iata: 'TLS', name: 'Aéroport Toulouse-Blagnac',        city: 'Toulouse',     country: 'France'),
  Airport(iata: 'BOD', name: 'Aéroport Bordeaux-Mérignac',       city: 'Bordeaux',     country: 'France'),
  Airport(iata: 'NTE', name: 'Aéroport Nantes-Atlantique',       city: 'Nantes',       country: 'France'),
  Airport(iata: 'LIL', name: 'Aéroport Lille-Lesquin',           city: 'Lille',        country: 'France'),
  Airport(iata: 'SXB', name: 'Aéroport Strasbourg',              city: 'Strasbourg',   country: 'France'),

  // ── Espagne ──────────────────────────────────────────────────────────────
  Airport(iata: 'MAD', name: 'Aéroport Adolfo Suárez Madrid-Barajas', city: 'Madrid',  country: 'Espagne'),
  Airport(iata: 'BCN', name: 'Aéroport El Prat',                 city: 'Barcelone',    country: 'Espagne'),
  Airport(iata: 'AGP', name: 'Aéroport de Málaga',               city: 'Malaga',       country: 'Espagne'),
  Airport(iata: 'VLC', name: 'Aéroport de Valence',              city: 'Valence',      country: 'Espagne'),
  Airport(iata: 'PMI', name: 'Aéroport de Palma',                city: 'Palma de Majorque', country: 'Espagne'),

  // ── Italie ───────────────────────────────────────────────────────────────
  Airport(iata: 'FCO', name: 'Aéroport Leonardo da Vinci',       city: 'Rome',         country: 'Italie'),
  Airport(iata: 'MXP', name: 'Aéroport Malpensa',                city: 'Milan',        country: 'Italie'),
  Airport(iata: 'LIN', name: 'Aéroport Linate',                  city: 'Milan',        country: 'Italie'),
  Airport(iata: 'VCE', name: 'Aéroport Marco Polo',              city: 'Venise',       country: 'Italie'),
  Airport(iata: 'NAP', name: 'Aéroport de Naples',               city: 'Naples',       country: 'Italie'),

  // ── Royaume-Uni ──────────────────────────────────────────────────────────
  Airport(iata: 'LHR', name: 'Aéroport Heathrow',                city: 'Londres',      country: 'Royaume-Uni'),
  Airport(iata: 'LGW', name: 'Aéroport Gatwick',                 city: 'Londres',      country: 'Royaume-Uni'),
  Airport(iata: 'STN', name: 'Aéroport Stansted',                city: 'Londres',      country: 'Royaume-Uni'),
  Airport(iata: 'MAN', name: 'Aéroport de Manchester',           city: 'Manchester',   country: 'Royaume-Uni'),
  Airport(iata: 'EDI', name: 'Aéroport d\'Édimbourg',            city: 'Édimbourg',    country: 'Royaume-Uni'),

  // ── Allemagne ────────────────────────────────────────────────────────────
  Airport(iata: 'FRA', name: 'Aéroport de Francfort',            city: 'Francfort',    country: 'Allemagne'),
  Airport(iata: 'MUC', name: 'Aéroport de Munich',               city: 'Munich',       country: 'Allemagne'),
  Airport(iata: 'BER', name: 'Aéroport de Berlin-Brandebourg',   city: 'Berlin',       country: 'Allemagne'),
  Airport(iata: 'DUS', name: 'Aéroport de Düsseldorf',           city: 'Düsseldorf',   country: 'Allemagne'),
  Airport(iata: 'HAM', name: 'Aéroport de Hambourg',             city: 'Hambourg',     country: 'Allemagne'),

  // ── Pays-Bas / Belgique / Suisse ─────────────────────────────────────────
  Airport(iata: 'AMS', name: 'Aéroport Amsterdam-Schiphol',      city: 'Amsterdam',    country: 'Pays-Bas'),
  Airport(iata: 'BRU', name: 'Aéroport de Bruxelles',            city: 'Bruxelles',    country: 'Belgique'),
  Airport(iata: 'ZRH', name: 'Aéroport de Zurich',               city: 'Zurich',       country: 'Suisse'),
  Airport(iata: 'GVA', name: 'Aéroport de Genève',               city: 'Genève',       country: 'Suisse'),

  // ── Turquie ──────────────────────────────────────────────────────────────
  Airport(iata: 'IST', name: 'Aéroport Istanbul',                city: 'Istanbul',     country: 'Turquie'),
  Airport(iata: 'SAW', name: 'Aéroport Sabiha Gökçen',           city: 'Istanbul',     country: 'Turquie'),
  Airport(iata: 'AYT', name: 'Aéroport d\'Antalya',              city: 'Antalya',      country: 'Turquie'),
  Airport(iata: 'ESB', name: 'Aéroport d\'Ankara',               city: 'Ankara',       country: 'Turquie'),

  // ── Émirats / Qatar / Arabie Saoudite ────────────────────────────────────
  Airport(iata: 'DXB', name: 'Aéroport International de Dubaï',  city: 'Dubaï',        country: 'Émirats arabes unis'),
  Airport(iata: 'AUH', name: 'Aéroport d\'Abu Dhabi',            city: 'Abu Dhabi',    country: 'Émirats arabes unis'),
  Airport(iata: 'DOH', name: 'Aéroport Hamad',                   city: 'Doha',         country: 'Qatar'),
  Airport(iata: 'RUH', name: 'Aéroport King Khalid',             city: 'Riyad',        country: 'Arabie Saoudite'),
  Airport(iata: 'JED', name: 'Aéroport King Abdulaziz',          city: 'Djeddah',      country: 'Arabie Saoudite'),
  Airport(iata: 'MED', name: 'Aéroport Prince Mohammad bin Abdulaziz', city: 'Médine', country: 'Arabie Saoudite'),

  // ── Maroc / Tunisie / Egypte / Libye ─────────────────────────────────────
  Airport(iata: 'CMN', name: 'Aéroport Mohammed V',              city: 'Casablanca',   country: 'Maroc'),
  Airport(iata: 'RAK', name: 'Aéroport Menara',                  city: 'Marrakech',    country: 'Maroc'),
  Airport(iata: 'TNG', name: 'Aéroport Ibn Battouta',            city: 'Tanger',       country: 'Maroc'),
  Airport(iata: 'FEZ', name: 'Aéroport Saïss',                   city: 'Fès',          country: 'Maroc'),
  Airport(iata: 'TUN', name: 'Aéroport Tunis-Carthage',          city: 'Tunis',        country: 'Tunisie'),
  Airport(iata: 'SFA', name: 'Aéroport de Sfax',                 city: 'Sfax',         country: 'Tunisie'),
  Airport(iata: 'MIR', name: 'Aéroport de Monastir',             city: 'Monastir',     country: 'Tunisie'),
  Airport(iata: 'CAI', name: 'Aéroport International du Caire',  city: 'Le Caire',     country: 'Égypte'),
  Airport(iata: 'HRG', name: 'Aéroport de Hurghada',             city: 'Hurghada',     country: 'Égypte'),
  Airport(iata: 'SSH', name: 'Aéroport de Charm el-Cheikh',      city: 'Charm el-Cheikh', country: 'Égypte'),
  Airport(iata: 'TIP', name: 'Aéroport de Tripoli',              city: 'Tripoli',      country: 'Libye'),

  // ── Canada / USA ─────────────────────────────────────────────────────────
  Airport(iata: 'YUL', name: 'Aéroport Pierre-Elliott-Trudeau',  city: 'Montréal',     country: 'Canada'),
  Airport(iata: 'YYZ', name: 'Aéroport Pearson',                 city: 'Toronto',      country: 'Canada'),
  Airport(iata: 'JFK', name: 'Aéroport John F. Kennedy',         city: 'New York',     country: 'États-Unis'),
  Airport(iata: 'LAX', name: 'Aéroport Los Angeles',             city: 'Los Angeles',  country: 'États-Unis'),
  Airport(iata: 'ORD', name: 'Aéroport O\'Hare',                 city: 'Chicago',      country: 'États-Unis'),

  // ── Asie ─────────────────────────────────────────────────────────────────
  Airport(iata: 'PEK', name: 'Aéroport de Pékin-Capital',        city: 'Pékin',        country: 'Chine'),
  Airport(iata: 'PVG', name: 'Aéroport de Shanghai-Pudong',      city: 'Shanghai',     country: 'Chine'),
  Airport(iata: 'HND', name: 'Aéroport de Tokyo-Haneda',         city: 'Tokyo',        country: 'Japon'),
  Airport(iata: 'SIN', name: 'Aéroport Changi',                  city: 'Singapour',    country: 'Singapour'),
  Airport(iata: 'BOM', name: 'Aéroport Chhatrapati Shivaji',     city: 'Mumbai',       country: 'Inde'),
  Airport(iata: 'DEL', name: 'Aéroport Indira Gandhi',           city: 'New Delhi',    country: 'Inde'),
];
