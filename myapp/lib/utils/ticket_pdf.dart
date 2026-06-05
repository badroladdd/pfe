import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:myapp/utils/currency.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
final _navy   = PdfColor.fromInt(0xFF1a3a5c);
final _blue   = PdfColor.fromInt(0xFF2563a8);
final _cyan   = PdfColor.fromInt(0xFF38b2d8);
final _lBlue  = PdfColor.fromInt(0xFFe8f4fb);
final _border = PdfColor.fromInt(0xFFcce0f5);

// ── Aéroports ─────────────────────────────────────────────────────────────────
const _airportNames = <String, String>{
  'ALG': 'Houari Boumediene, Alger',
  'ORN': 'Ahmed Ben Bella, Oran',
  'CZL': 'Mohamed Boudiaf, Constantine',
  'AAE': 'Rabah Bitat, Annaba',
  'BJA': 'Abane Ramdane, Béjaïa',
  'TLM': 'Zenata, Tlemcen',
  'GJL': 'Taher, Jijel',
  'BSK': 'Mohamed Khider, Biskra',
  'TMR': 'Aguenar, Tamanrasset',
  'GHE': 'Noumerat, Ghardaïa',
  'OGX': 'Ain el Beida, Ouargla',
  'IAM': 'Zarzaitine, In Amenas',
  'ELU': 'Guemar, El Oued',
  'VVZ': 'Takhamalt, Illizi',
};

// ── Helpers ───────────────────────────────────────────────────────────────────
String _p2(int n) => n.toString().padLeft(2, '0');
String _fmtDate(DateTime? dt)    => dt == null ? '' : '${dt.year}-${_p2(dt.month)}-${_p2(dt.day)}';
String _fmtTime(DateTime? dt)    => dt == null ? '--:--' : '${_p2(dt.hour)}:${_p2(dt.minute)}';
String _fmtCreated(DateTime? dt) => dt == null ? '' : '${_p2(dt.day)}/${_p2(dt.month)}/${dt.year}';

String _duration(DateTime? dep, DateTime? arr) {
  if (dep == null || arr == null) return '';
  final diff = arr.difference(dep);
  final h = diff.inHours;
  final m = diff.inMinutes % 60;
  return h > 0 ? '${h}h ${m}m' : '${m}m';
}

String _eTicketNumber(String ref, int idx) {
  var hash = 0;
  for (final c in ref.codeUnits) {
    hash = (hash * 31 + c) % 9000000000000;
  }
  return (1000000000000 + hash + idx).toString();
}

// ── Main entry point ──────────────────────────────────────────────────────────
Future<void> downloadTicketPdf(Map<String, dynamic> reservation) async {
  final pdf = pw.Document();

  final ref       = reservation['booking_reference']?.toString() ?? 'N/A';
  final origin    = reservation['origin_iata']?.toString() ?? '---';
  final dest      = reservation['destination_iata']?.toString() ?? '---';
  final amountRaw = double.tryParse(reservation['total_amount']?.toString() ?? '0') ?? 0.0;
  final amountDzd = formatDzd(amountRaw);
  final carrier   = reservation['carrier_name']?.toString() ?? '';
  final flightNum = reservation['flight_number']?.toString() ?? '';
  final userName  = reservation['user_full_name']?.toString() ?? '';
  final userPhone = reservation['user_phone']?.toString() ?? '';

  DateTime? depDt, arrDt, createdDt;
  try { depDt     = DateTime.parse(reservation['departure_at'] ?? ''); } catch (_) {}
  try { arrDt     = DateTime.parse(reservation['arrival_at'] ?? ''); } catch (_) {}
  try { createdDt = DateTime.parse(reservation['created_at'] ?? ''); } catch (_) {}

  final depDate = _fmtDate(depDt);
  final depTime = _fmtTime(depDt);
  final arrDate = _fmtDate(arrDt);
  final arrTime = _fmtTime(arrDt);
  final dur     = _duration(depDt, arrDt);
  final created = _fmtCreated(createdDt);

  final passengers =
      (reservation['passengers'] as List?)?.cast<Map<String, dynamic>>() ?? [];

  // ── Page 1 ──────────────────────────────────────────────────────────────────
  pdf.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 32),
    build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _header(ref, created),
        pw.SizedBox(height: 18),
        _clientCard(userName, userPhone),
        pw.SizedBox(height: 18),
        pw.Text('Détails de l\'itinéraire',
            style: pw.TextStyle(
                fontSize: 15, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        _itineraryCard(origin, dest, depDate, depTime, arrDate, arrTime,
            carrier, flightNum, dur),
        pw.SizedBox(height: 18),
        _passengersSection(passengers, ref),
        pw.SizedBox(height: 14),
        _priceRow(amountDzd),
        pw.SizedBox(height: 18),
        pw.Text('Liste de contrôle de voyage',
            style: pw.TextStyle(
                fontSize: 15, fontWeight: pw.FontWeight.bold)),
        pw.Spacer(),
        pw.Divider(color: PdfColors.grey300),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Ce billet est valable uniquement pour le vol indiqué.',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
            pw.Text('Généré le $created',
                style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
          ],
        ),
      ],
    ),
  ));

  // ── Page 2 ──────────────────────────────────────────────────────────────────
  pdf.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 32),
    build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _travelDocs()),
            pw.SizedBox(width: 24),
            pw.Expanded(child: _flightTips()),
          ],
        ),
        pw.Spacer(),
        _contactRow(),
      ],
    ),
  ));

  await Printing.layoutPdf(
    onLayout: (format) async => pdf.save(),
    name: 'billet_$ref.pdf',
  );
}

// ── Widget builders ───────────────────────────────────────────────────────────

pw.Widget _header(String ref, String date) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      pw.Text('e-Billet $ref',
          style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromInt(0xFF111827))),
      // Logo cercle bleu avec "V"
      pw.Container(
        width: 38,
        height: 38,
        decoration: pw.BoxDecoration(
          color: _blue,
          shape: pw.BoxShape.circle,
        ),
        child: pw.Center(
          child: pw.Text('V',
              style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold)),
        ),
      ),
    ],
  );
}

pw.Widget _clientCard(String name, String phone) {
  final items = <_LabelValue>[];
  if (name.isNotEmpty)  items.add(_LabelValue('Nom du client', name));
  if (phone.isNotEmpty) items.add(_LabelValue('Numéro de téléphone', phone));
  if (items.isEmpty) return pw.SizedBox();

  return pw.Container(
    padding: const pw.EdgeInsets.all(14),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey300),
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: items
          .expand((lv) => [
                pw.Text(lv.label,
                    style: pw.TextStyle(
                        fontSize: 9, color: PdfColors.grey500)),
                pw.SizedBox(height: 2),
                pw.Text(lv.value,
                    style: pw.TextStyle(
                        fontSize: 12, fontWeight: pw.FontWeight.bold)),
                if (lv != items.last) pw.SizedBox(height: 10),
              ])
          .toList(),
    ),
  );
}

pw.Widget _itineraryCard(
    String origin, String dest,
    String depDate, String depTime,
    String arrDate, String arrTime,
    String carrier, String flightNum, String dur) {
  final originName = _airportNames[origin] ?? origin;
  final destName   = _airportNames[dest] ?? dest;
  final flightLabel = [carrier, flightNum].where((s) => s.isNotEmpty).join(' ');

  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _border),
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // ── En-tête route (fond bleu marine) ──────────────────────────────
        pw.Container(
          width: double.infinity,
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: pw.BoxDecoration(
            color: _navy,
            borderRadius: const pw.BorderRadius.only(
              topLeft:  pw.Radius.circular(7),
              topRight: pw.Radius.circular(7),
            ),
          ),
          child: pw.Text(
            'Vol de $origin à $dest',
            style: pw.TextStyle(
                color: PdfColors.white,
                fontSize: 13,
                fontWeight: pw.FontWeight.bold),
          ),
        ),

        // ── Détail du vol ─────────────────────────────────────────────────
        pw.Padding(
          padding: const pw.EdgeInsets.all(16),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              // Départ
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (depDate.isNotEmpty)
                      pw.Text(depDate,
                          style: pw.TextStyle(
                              fontSize: 9, color: PdfColors.grey500)),
                    pw.Text(depTime,
                        style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: _navy)),
                    pw.Text('( $origin )',
                        style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: _blue)),
                    pw.SizedBox(height: 4),
                    pw.Text(originName,
                        style: pw.TextStyle(
                            fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
              ),

              // Centre : numéro de vol + durée + classe
              pw.Column(
                children: [
                  if (flightLabel.isNotEmpty)
                    pw.Text(flightLabel,
                        style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: _navy)),
                  pw.SizedBox(height: 6),
                  pw.Text('- - - - -',
                      style: pw.TextStyle(
                          fontSize: 10, color: PdfColors.grey400)),
                  pw.SizedBox(height: 6),
                  if (dur.isNotEmpty)
                    pw.Text(dur,
                        style: pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey500)),
                  pw.SizedBox(height: 4),
                  pw.Text('Economy',
                      style: pw.TextStyle(
                          fontSize: 9,
                          color: _cyan,
                          fontWeight: pw.FontWeight.bold)),
                ],
              ),

              // Arrivée
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    if (arrDate.isNotEmpty)
                      pw.Text(arrDate,
                          style: pw.TextStyle(
                              fontSize: 9, color: PdfColors.grey500)),
                    pw.Text(arrTime,
                        style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: _navy)),
                    pw.Text('( $dest )',
                        style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: _blue)),
                    pw.SizedBox(height: 4),
                    pw.Text(destName,
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ── Badge bagage ──────────────────────────────────────────────────
        pw.Container(
          padding:
              const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: _border)),
          ),
          child: pw.Row(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: pw.BoxDecoration(
                  color: _blue,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text('1 PCS',
                    style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(width: 8),
              pw.Text('Bagage enregistré',
                  style: pw.TextStyle(
                      fontSize: 10, color: PdfColors.grey600)),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _passengersSection(
    List<Map<String, dynamic>> passengers, String ref) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text('Détails des voyageurs',
          style: pw.TextStyle(
              fontSize: 15, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      pw.Table(
        border: pw.TableBorder.all(color: _border),
        columnWidths: {
          0: const pw.FlexColumnWidth(2),
          1: const pw.FlexColumnWidth(2),
        },
        children: [
          // En-tête
          pw.TableRow(
            decoration: pw.BoxDecoration(color: _navy),
            children: [
              _cell('Voyageur', header: true),
              _cell('Numéro de billet électronique', header: true),
            ],
          ),
          // Lignes voyageurs
          ...passengers.asMap().entries.map((e) {
            final p    = e.value;
            final name = '${p['title'] ?? ''} ${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim();
            return pw.TableRow(
              decoration: pw.BoxDecoration(
                color: e.key.isOdd ? PdfColors.grey50 : PdfColors.white,
              ),
              children: [
                _cell(name),
                _cell(_eTicketNumber(ref, e.key)),
              ],
            );
          }),
        ],
      ),
    ],
  );
}

pw.Widget _cell(String text, {bool header = false}) {
  return pw.Padding(
    padding:
        const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    child: pw.Text(
      text,
      style: header
          ? pw.TextStyle(
              color: PdfColors.white,
              fontSize: 10,
              fontWeight: pw.FontWeight.bold)
          : pw.TextStyle(fontSize: 10),
    ),
  );
}

pw.Widget _priceRow(String amountDzd) {
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.end,
    children: [
      pw.Text('Prix total : ',
          style: pw.TextStyle(
              fontSize: 13, fontWeight: pw.FontWeight.bold)),
      pw.Text(amountDzd,
          style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: _cyan)),
    ],
  );
}

pw.Widget _travelDocs() {
  const docs = [
    'Un passeport avec une validité minimale de 6 mois est requis, avec suffisamment de pages vierges.',
    'Un visa valide pour le pays que vous visitez. Vérifiez également si un visa de transit est requis.',
    'Les autorités d\'immigration exigent que les compagnies aériennes fournissent les informations sur les passagers à l\'avance avant le départ.',
  ];
  return _infoSection('Documents de voyage', docs);
}

pw.Widget _flightTips() {
  const tips = [
    'Veuillez vous assurer d\'être à l\'aéroport bien avant l\'heure de départ de votre vol.',
    'Pour les vols internationaux, il est conseillé d\'arriver au moins 4 heures avant le départ.',
    'Pour les vols intérieurs, il est conseillé d\'arriver au moins 2 heures avant le départ.',
  ];
  return _infoSection('Ne manquez pas votre vol', tips);
}

pw.Widget _infoSection(String title, List<String> items) {
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Container(
        width: double.infinity,
        padding:
            const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: pw.BoxDecoration(
          color: _lBlue,
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Text(title,
            style: pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
                color: _navy)),
      ),
      pw.SizedBox(height: 10),
      ...items.map((item) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('• ',
                    style: pw.TextStyle(
                        color: _blue,
                        fontWeight: pw.FontWeight.bold)),
                pw.Expanded(
                    child: pw.Text(item,
                        style: pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700))),
              ],
            ),
          )),
    ],
  );
}

pw.Widget _contactRow() {
  return pw.Container(
    padding: const pw.EdgeInsets.all(16),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _border),
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Row(
      children: [
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                  'Pour modifier ou rembourser votre billet, visitez',
                  style: pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey600)),
              pw.SizedBox(height: 2),
              pw.Text('support.volz.app',
                  style: pw.TextStyle(
                      fontSize: 10,
                      color: _cyan,
                      fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
        pw.SizedBox(width: 20),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                  'Pour toute autre information, appelez-nous au :',
                  style: pw.TextStyle(
                      fontSize: 9, color: PdfColors.grey600)),
              pw.SizedBox(height: 2),
              pw.Text('05 60 99 90 09',
                  style: pw.TextStyle(
                      fontSize: 10,
                      color: _cyan,
                      fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
      ],
    ),
  );
}

// ── Data class simple ─────────────────────────────────────────────────────────
class _LabelValue {
  const _LabelValue(this.label, this.value);
  final String label;
  final String value;
}
