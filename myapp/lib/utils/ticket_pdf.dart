import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:myapp/utils/currency.dart';

Future<void> downloadTicketPdf(Map<String, dynamic> reservation) async {
  final pdf = pw.Document();

  final ref       = reservation['booking_reference']?.toString() ?? reservation['id']?.toString() ?? 'N/A';
  final origin    = reservation['origin_iata']?.toString()      ?? '---';
  final dest      = reservation['destination_iata']?.toString() ?? '---';
  final amountEur = double.tryParse(reservation['total_amount']?.toString() ?? '0') ?? 0.0;
  final amountDzd = formatDzd(amountEur);
  final createdAt = reservation['created_at']?.toString()        ?? '';
  final userEmail = reservation['user_email']?.toString()        ?? '';
  final userName  = reservation['user_full_name']?.toString()    ?? '';

  DateTime? date;
  try { date = DateTime.parse(createdAt); } catch (_) {}
  final dateStr = date != null
      ? '${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}'
      : '';

  // passengers
  final passengers = (reservation['passengers'] as List?)
      ?.cast<Map<String, dynamic>>() ?? [];

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (pw.Context ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [

          // ── en-tête ──────────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              color: PdfColors.blue800,
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('BILLET ELECTRONIQUE',
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text('Systeme de Reservation de Vols',
                        style: const pw.TextStyle(color: PdfColors.grey200, fontSize: 11)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('CONFIRME',
                        style: pw.TextStyle(
                            color: PdfColors.green200,
                            fontSize: 13,
                            fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text(dateStr,
                        style: const pw.TextStyle(color: PdfColors.grey200, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 24),

          // ── référence PNR ─────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Text('Référence de réservation : ',
                    style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                pw.Text(ref,
                    style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                        letterSpacing: 4)),
              ],
            ),
          ),

          pw.SizedBox(height: 24),

          // ── trajet ────────────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.blue200),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(
                  children: [
                    pw.Text(origin,
                        style: pw.TextStyle(
                            fontSize: 32,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900)),
                    pw.Text('Départ', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text('---->', style: pw.TextStyle(fontSize: 20, color: PdfColors.blue400, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Vol direct', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text(dest,
                        style: pw.TextStyle(
                            fontSize: 32,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900)),
                    pw.Text('Arrivée', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                  ],
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 24),

          // ── passager(s) ───────────────────────────────────────────────
          pw.Text('Passager(s)',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
          pw.SizedBox(height: 8),
          if (passengers.isNotEmpty)
            ...passengers.map((p) {
              final name = '${p['title'] ?? ''} ${p['first_name'] ?? ''} ${p['last_name'] ?? ''}'.trim();
              final type = p['type']?.toString() ?? 'adult';
              return pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 6),
                padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  children: [
                    pw.Text('● ', style: const pw.TextStyle(color: PdfColors.blue700)),
                    pw.Text(name, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                    pw.Spacer(),
                    pw.Text(type, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
                  ],
                ),
              );
            })
          else
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              child: pw.Text(userName.isNotEmpty ? userName : userEmail,
                  style: const pw.TextStyle(fontSize: 11)),
            ),

          pw.SizedBox(height: 24),

          // ── montant ───────────────────────────────────────────────────
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              color: PdfColors.green50,
              border: pw.Border.all(color: PdfColors.green200),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Montant total payé',
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                pw.Text(amountDzd,
                    style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.green800)),
              ],
            ),
          ),

          pw.Spacer(),

          // ── pied de page ──────────────────────────────────────────────
          pw.Divider(color: PdfColors.grey300),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Ce billet est valable uniquement pour le vol indiqué.',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
              pw.Text('Généré le $dateStr',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
            ],
          ),
        ],
      ),
    ),
  );

  await Printing.layoutPdf(
    onLayout: (format) async => pdf.save(),
    name: 'billet_$ref.pdf',
  );
}
