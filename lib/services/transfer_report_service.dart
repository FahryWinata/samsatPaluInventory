import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

/// Data class for person info in handover report
class PersonInfo {
  final String name;
  final String nip;
  final String position;

  PersonInfo({required this.name, required this.nip, required this.position});
}

/// Data class for asset info in handover report
class HandoverAssetInfo {
  final String name;
  final String? serialNumber;
  final String? brand;
  final String? year;

  HandoverAssetInfo({
    required this.name,
    this.serialNumber,
    this.brand,
    this.year,
  });
}

class TransferReportService {
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

  /// Generate and preview the handover report PDF
  Future<void> generateHandoverReport({
    required DateTime transferDate,
    required PersonInfo fromPerson, // Pihak Pertama
    required PersonInfo toPerson, // Pihak Kedua
    PersonInfo? approver, // Mengetahui (Optional)
    required HandoverAssetInfo asset,
    String? notes,
  }) async {
    // Use standard Times New Roman font
    final font = pw.Font.times();
    final boldFont = pw.Font.timesBold();
    final logo = await _loadLogo();

    final pdf = pw.Document();
    final dateFormatter = DateFormat('d MMMM yyyy', 'id_ID');
    final dayFormatter = DateFormat('EEEE', 'id_ID');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 50, vertical: 40),
        build: (context) {
          return [
            // Header
            _buildHeader(logo, font, boldFont),
            pw.SizedBox(height: 10), // Reduced from 20
            // Title
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text(
                    'BERITA ACARA SERAH TERIMA BARANG MILIK DAERAH',
                    style: pw.TextStyle(font: boldFont, fontSize: 12),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.Text(
                    'BERUPA ${asset.name.toUpperCase()}',
                    style: pw.TextStyle(font: boldFont, fontSize: 12),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 2), // Reduced from 4
                  pw.Text(
                    'Nomor : ______ / ______ / UPTB Wil. I Palu',
                    style: pw.TextStyle(font: font, fontSize: 10),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10), // Reduced from 16
            // Opening paragraph
            pw.RichText(
              text: pw.TextSpan(
                style: pw.TextStyle(font: font, fontSize: 10),
                children: [
                  const pw.TextSpan(text: 'Pada hari ini '),
                  pw.TextSpan(
                    text: dayFormatter.format(transferDate),
                    style: pw.TextStyle(font: boldFont),
                  ),
                  const pw.TextSpan(text: ' Tanggal '),
                  pw.TextSpan(
                    text: dateFormatter.format(transferDate),
                    style: pw.TextStyle(font: boldFont),
                  ),
                  const pw.TextSpan(
                    text:
                        ', yang bertanda tangan di bawah ini masing - masing :',
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8), // Reduced from 12
            // Party 1 (From)
            _buildPersonSection(
              '1.',
              fromPerson,
              'Pihak Pertama (I)',
              font,
              boldFont,
            ),
            pw.SizedBox(height: 4), // Reduced from 8
            // Party 2 (To)
            _buildPersonSection(
              '2.',
              toPerson,
              'Pihak Kedua (II)',
              font,
              boldFont,
            ),
            pw.SizedBox(height: 8), // Reduced from 12
            // Asset handover statement
            pw.RichText(
              text: pw.TextSpan(
                style: pw.TextStyle(font: font, fontSize: 10),
                children: [
                  const pw.TextSpan(
                    text: 'Telah melakukan serah terima berupa ',
                  ),
                  pw.TextSpan(
                    text: '1 (SATU) UNIT ${asset.name.toUpperCase()}',
                    style: pw.TextStyle(font: boldFont),
                  ),
                  const pw.TextSpan(
                    text: ' dengan spesifikasi dan ketentuan sebagai berikut :',
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 8), // Reduced from 12
            // Specifications
            pw.Text(
              '1. Spesifikasi :',
              style: pw.TextStyle(font: boldFont, fontSize: 10),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildSpecRow(
                    'a.',
                    'Nomor Seri',
                    asset.serialNumber ?? '-',
                    font,
                  ),
                  _buildSpecRow('b.', 'Merk/Type', asset.brand ?? '-', font),
                  _buildSpecRow(
                    'c.',
                    'Tahun Perolehan',
                    asset.year ?? '-',
                    font,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 4), // Reduced from 8
            // Terms
            pw.Text(
              '2. Ketentuan :',
              style: pw.TextStyle(font: boldFont, fontSize: 10),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 20),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildTermRow(
                    'a.',
                    'Bahwa Pihak Kedua telah menerima ${asset.name.toLowerCase()} tersebut di atas dalam keadaan baik dan benar.',
                    font,
                  ),
                  _buildTermRow(
                    'b.',
                    'Apabila pihak kedua telah pindah tugas/meninggal/pensiun, kendaraan tersebut harus dikembalikan kepada Bagian yang menangani Aset melalui Sub Bagian Tata Usaha UPTB Pendapatan Wilayah I Palu.',
                    font,
                  ),
                  _buildTermRow(
                    'c.',
                    '${asset.name} tersebut dipergunakan untuk kepentingan dinas.',
                    font,
                  ),
                  _buildTermRow(
                    'd.',
                    'Pihak kedua bertanggungjawab atas kehilangan ${asset.name.toLowerCase()} tersebut sesuai ketentuan Perundang-undangan yang berlaku.',
                    font,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10), // Reduced from 16
            // Closing
            pw.Text(
              'Demikian Berita Acara Serah Terima ini dibuat serta ditanda tangani oleh kedua pihak untuk dipergunakan sebagaimana mestinya.',
              style: pw.TextStyle(font: font, fontSize: 10),
            ),
            pw.SizedBox(height: 16), // Reduced from 24
            // Signatures
            _buildSignatures(fromPerson, toPerson, approver, font, boldFont),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Berita_Acara_Serah_Terima_${asset.name.replaceAll(' ', '_')}',
    );
  }

  pw.Widget _buildHeader(
    pw.ImageProvider? logo,
    pw.Font font,
    pw.Font boldFont,
  ) {
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            if (logo != null)
              pw.Container(
                width: 55,
                height: 70,
                child: pw.Image(logo, fit: pw.BoxFit.contain),
              )
            else
              pw.SizedBox(width: 55, height: 70),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'PEMERINTAH PROVINSI SULAWESI TENGAH',
                    style: pw.TextStyle(font: boldFont, fontSize: 13),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.Text(
                    'UNIT PELAKSANA TEKNIS BADAN (UPT)',
                    style: pw.TextStyle(font: boldFont, fontSize: 14),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.Text(
                    'PENDAPATAN DAERAH WILAYAH I PALU',
                    style: pw.TextStyle(font: boldFont, fontSize: 14),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Jl. Ra. Kartini No. 106 Telp. (0451) 456883 - 456884',
                    style: pw.TextStyle(font: font, fontSize: 8),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Container(height: 2, color: PdfColors.black),
        pw.SizedBox(height: 1),
        pw.Container(height: 1, color: PdfColors.black),
      ],
    );
  }

  pw.Widget _buildPersonSection(
    String number,
    PersonInfo person,
    String role,
    pw.Font font,
    pw.Font boldFont,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 20,
          child: pw.Text(number, style: pw.TextStyle(font: font, fontSize: 10)),
        ),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildInfoRow('N a m a', person.name, font, boldFont),
              _buildInfoRow('NIP', person.nip, font, font),
              _buildInfoRow('Jabatan', person.position, font, font),
              pw.Row(
                children: [
                  pw.SizedBox(
                    width: 80,
                    child: pw.Text(
                      '',
                      style: pw.TextStyle(font: font, fontSize: 10),
                    ),
                  ),
                  pw.Text(
                    'Selanjutnya disebut $role',
                    style: pw.TextStyle(font: boldFont, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildInfoRow(
    String label,
    String value,
    pw.Font font,
    pw.Font valueFont,
  ) {
    return pw.Row(
      children: [
        pw.SizedBox(
          width: 80,
          child: pw.Text(label, style: pw.TextStyle(font: font, fontSize: 10)),
        ),
        pw.Text(': ', style: pw.TextStyle(font: font, fontSize: 10)),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(font: valueFont, fontSize: 10),
          ),
        ),
      ],
    );
  }

  pw.Widget _buildSpecRow(
    String letter,
    String label,
    String value,
    pw.Font font,
  ) {
    return pw.Row(
      children: [
        pw.SizedBox(
          width: 20,
          child: pw.Text(letter, style: pw.TextStyle(font: font, fontSize: 10)),
        ),
        pw.SizedBox(
          width: 100,
          child: pw.Text(label, style: pw.TextStyle(font: font, fontSize: 10)),
        ),
        pw.Text(': $value', style: pw.TextStyle(font: font, fontSize: 10)),
      ],
    );
  }

  pw.Widget _buildTermRow(String letter, String text, pw.Font font) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 20,
            child: pw.Text(
              letter,
              style: pw.TextStyle(font: font, fontSize: 10),
            ),
          ),
          pw.Expanded(
            child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 10)),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildSignatures(
    PersonInfo fromPerson,
    PersonInfo toPerson,
    PersonInfo? approver,
    pw.Font font,
    pw.Font boldFont,
  ) {
    return pw.Column(
      children: [
        // Top row: Party 2 (left) and Party 1 (right)
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            _buildSignatureBlock('PIHAK KEDUA (II)', toPerson, font, boldFont),
            _buildSignatureBlock(
              'PIHAK PERTAMA (I)',
              fromPerson,
              font,
              boldFont,
            ),
          ],
        ),

        if (approver != null) ...[
          pw.SizedBox(height: 30),

          // Bottom: Approver (center)
          pw.Center(
            child: pw.Column(
              children: [
                pw.Text(
                  'MENGETAHUI / MENGESAHKAN :',
                  style: pw.TextStyle(font: boldFont, fontSize: 10),
                ),
                pw.Text(
                  'KEPALA UPTB PENDAPATAN WILAYAH 1 PALU',
                  style: pw.TextStyle(font: boldFont, fontSize: 10),
                ),
                pw.Text(
                  'PROVINSI SULAWESI TENGAH',
                  style: pw.TextStyle(font: boldFont, fontSize: 10),
                ),
                pw.SizedBox(height: 50),
                pw.Text(
                  approver.name,
                  style: pw.TextStyle(
                    font: boldFont,
                    fontSize: 10,
                    decoration: pw.TextDecoration.underline,
                    color: PdfColors.black,
                  ),
                ),
                pw.Text(
                  approver.position,
                  style: pw.TextStyle(font: font, fontSize: 9),
                ),
                pw.Text(
                  'NIP. ${approver.nip}',
                  style: pw.TextStyle(font: font, fontSize: 9),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  pw.Widget _buildSignatureBlock(
    String title,
    PersonInfo person,
    pw.Font font,
    pw.Font boldFont,
  ) {
    return pw.Column(
      children: [
        pw.Text(title, style: pw.TextStyle(font: boldFont, fontSize: 10)),
        pw.SizedBox(height: 50),
        pw.Text(
          person.name,
          style: pw.TextStyle(
            font: boldFont,
            fontSize: 10,
            decoration: pw.TextDecoration.underline,
            color: PdfColors.black,
          ),
        ),
        pw.Text(
          'NIP. ${person.nip}',
          style: pw.TextStyle(font: font, fontSize: 9),
        ),
      ],
    );
  }
}
