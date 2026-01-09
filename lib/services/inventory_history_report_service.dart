import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/inventory_history_model.dart';

class InventoryHistoryReportService {
  Future<pw.ImageProvider?> _loadLogo() async {
    try {
      final imageBytes = await rootBundle.load(
        'assets/images/logo_sulteng.png',
      );
      return pw.MemoryImage(imageBytes.buffer.asUint8List());
    } catch (e) {
      return null;
    }
  }

  Future<void> generateMonthlyReport({
    required List<InventoryHistory> history,
    required int month,
    required int year,
  }) async {
    final font = pw.Font.times();
    final boldFont = pw.Font.timesBold();
    final logo = await _loadLogo();

    final pdf = pw.Document();
    final dateFormatter = DateFormat(
      'd MMMM yyyy HH:mm',
      'id_ID',
    ); // Detailed date
    final monthFormatter = DateFormat('MMMM yyyy', 'id_ID');

    // Filter out rows? No, assume filtered list passed.

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.legal.landscape,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return [
            // Header
            _buildHeader(logo, font, boldFont),
            pw.SizedBox(height: 20),

            // Title
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    'LAPORAN RIWAYAT ATK (BARANG PAKAI HABIS)',
                    style: pw.TextStyle(font: boldFont, fontSize: 14),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.Text(
                    'PERIODE: ${monthFormatter.format(DateTime(year, month)).toUpperCase()}',
                    style: pw.TextStyle(font: boldFont, fontSize: 12),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),

            // Table
            pw.TableHelper.fromTextArray(
              headers: [
                'No',
                'Tanggal',
                'Nama Barang',
                'Tipe',
                'Jml',
                'Keterangan',
              ],
              data: List<List<dynamic>>.generate(history.length, (index) {
                final item = history[index];
                final isIn = item.actionType == 'in';
                return [
                  (index + 1).toString(),
                  dateFormatter.format(item.createdAt),
                  item.itemName ?? '-',
                  isIn ? 'Masuk' : 'Keluar',
                  item.quantityChange.abs().toString(),
                  item.notes ?? '-',
                ];
              }),
              headerStyle: pw.TextStyle(
                font: boldFont,
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: pw.TextStyle(font: font, fontSize: 9),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.center,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerLeft,
              },
              border: pw.TableBorder.all(width: 0.5),
              columnWidths: {
                0: const pw.FixedColumnWidth(30), // No
                1: const pw.FixedColumnWidth(90), // Date
                2: const pw.FlexColumnWidth(3), // Name
                3: const pw.FixedColumnWidth(50), // Type
                4: const pw.FixedColumnWidth(40), // Qty
                5: const pw.FlexColumnWidth(4), // Notes
              },
            ),
            pw.SizedBox(height: 20),

            // Footer / Signature (Optional - Generic)
            _buildFooter(font),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Laporan_Riwayat_ATK_${month}_$year',
    );
  }

  pw.Widget _buildHeader(
    pw.ImageProvider? logo,
    pw.Font font,
    pw.Font boldFont,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        if (logo != null) ...[
          pw.Container(width: 60, height: 60, child: pw.Image(logo)),
          pw.SizedBox(width: 15),
        ],
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                'PEMERINTAH PROVINSI SULAWESI TENGAH',
                style: pw.TextStyle(font: font, fontSize: 14),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'BADAN PENDAPATAN DAERAH',
                style: pw.TextStyle(font: boldFont, fontSize: 16),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'UPTB WILAYAH I PALU',
                style: pw.TextStyle(font: boldFont, fontSize: 14),
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                'Jl. Cik Ditiro No. 22 Palu',
                style: pw.TextStyle(font: font, fontSize: 10),
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildFooter(pw.Font font) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        pw.Text(
          'Palu, ${DateFormat('d MMMM yyyy', 'id_ID').format(DateTime.now())}',
          style: pw.TextStyle(font: font, fontSize: 10),
        ),
        pw.SizedBox(height: 50),
        pw.Text(
          '( Pengurus Barang )',
          style: pw.TextStyle(font: font, fontSize: 10),
        ),
      ],
    );
  }
}
