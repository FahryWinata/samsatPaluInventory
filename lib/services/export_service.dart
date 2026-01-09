import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/inventory_model.dart';
import '../models/asset_model.dart';

class ExportService {
  // Generate Inventory Report
  Future<void> generateInventoryReport(
    List<InventoryItem> items, {
    String? customTitle,
    String? approverName,
    String? approverRank,
    String? approverNip,
    String? approverTitle,
    // Second signer parameters
    String? creatorName,
    String? creatorRank,
    String? creatorNip,
    String? creatorTitle,
    // Third signer parameters
    String? thirdSignerName,
    String? thirdSignerRank,
    String? thirdSignerNip,
    String? thirdSignerTitle,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();
    final logoImage = await _loadLogo();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.legal.landscape,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          _buildCustomHeader(logoImage, font, boldFont),
          pw.SizedBox(height: 20),
          pw.Center(
            child: pw.Text(
              customTitle ?? 'LAPORAN INVENTARIS',
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 14,
                decoration: pw.TextDecoration.underline,
              ),
            ),
          ),
          pw.SizedBox(height: 20),
          _buildInventoryTable(items, font, boldFont),
          pw.SizedBox(height: 40),
          _buildTripleSignature(
            font,
            boldFont,
            approverName: approverName,
            approverRank: approverRank,
            approverNip: approverNip,
            approverTitle: approverTitle,
            creatorName: creatorName,
            creatorRank: creatorRank,
            creatorNip: creatorNip,
            creatorTitle: creatorTitle,
            thirdSignerName: thirdSignerName,
            thirdSignerRank: thirdSignerRank,
            thirdSignerNip: thirdSignerNip,
            thirdSignerTitle: thirdSignerTitle,
          ),
        ],
      ),
    );

    final fileName = customTitle != null
        ? '${customTitle.replaceAll(' ', '_')}.pdf'
        : 'Inventory_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: fileName,
    );
  }

  // Generate Asset Report
  Future<void> generateAssetReport(
    List<Asset> assets,
    Map<int, String> holderNames,
    Map<int, String> categoryNames,
    Map<int, String> roomNames, {
    String? customTitle,
    String? approverName,
    String? approverRank,
    String? approverNip,
    String? approverTitle,
    // Second signer parameters
    String? creatorName,
    String? creatorRank,
    String? creatorNip,
    String? creatorTitle,
    // Third signer parameters
    String? thirdSignerName,
    String? thirdSignerRank,
    String? thirdSignerNip,
    String? thirdSignerTitle,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.openSansRegular();
    final boldFont = await PdfGoogleFonts.openSansBold();
    final logoImage = await _loadLogo();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.legal.landscape,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          _buildCustomHeader(logoImage, font, boldFont),
          pw.SizedBox(height: 20),
          pw.Center(
            child: pw.Text(
              customTitle ?? 'LAPORAN STATUS ASET',
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 14,
                decoration: pw.TextDecoration.underline,
              ),
            ),
          ),
          pw.SizedBox(height: 20),
          _buildAssetTable(
            assets,
            holderNames,
            categoryNames,
            roomNames,
            font,
            boldFont,
          ),
          pw.SizedBox(height: 40),
          _buildTripleSignature(
            font,
            boldFont,
            approverName: approverName,
            approverRank: approverRank,
            approverNip: approverNip,
            approverTitle: approverTitle,
            creatorName: creatorName,
            creatorRank: creatorRank,
            creatorNip: creatorNip,
            creatorTitle: creatorTitle,
            thirdSignerName: thirdSignerName,
            thirdSignerRank: thirdSignerRank,
            thirdSignerNip: thirdSignerNip,
            thirdSignerTitle: thirdSignerTitle,
          ),
        ],
      ),
    );

    final fileName = customTitle != null
        ? '${customTitle.replaceAll(' ', '_')}.pdf'
        : 'Asset_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: fileName,
    );
  }

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

  // --- Helper Widgets for PDF ---

  pw.Widget _buildCustomHeader(
    pw.ImageProvider? logo,
    pw.Font font,
    pw.Font boldFont,
  ) {
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            // Logo
            if (logo != null)
              pw.Container(
                width: 60,
                height: 75,
                child: pw.Image(logo, fit: pw.BoxFit.contain),
              )
            else
              pw.SizedBox(width: 60, height: 75),
            pw.SizedBox(width: 10),
            // Text Content
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'PEMERINTAH PROVINSI SULAWESI TENGAH',
                    style: pw.TextStyle(font: boldFont, fontSize: 14),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.Text(
                    'UNIT PELAKSANA TEKNIS',
                    style: pw.TextStyle(font: boldFont, fontSize: 16),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.Text(
                    'PENDAPATAN DAERAH WILAYAH I PALU',
                    style: pw.TextStyle(font: boldFont, fontSize: 16),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Jl. R.A Kartini No. 26, Palu - Kode Pos 94235 Telp. (0821) 2854-4041 Faks. (0851) 6627-7348',
                    style: pw.TextStyle(font: font, fontSize: 8),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.Text(
                    'Email : uptb.wilayah1palu@gmail.com',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 8,
                      color: PdfColors.blue,
                      decoration: pw.TextDecoration.underline,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 2),
        pw.SizedBox(height: 2),
        pw.Container(height: 2, color: PdfColors.black),
        pw.SizedBox(height: 1),
        pw.Container(height: 1, color: PdfColors.black),
      ],
    );
  }

  // Build triple signature layout with proper alignment
  pw.Widget _buildTripleSignature(
    pw.Font font,
    pw.Font boldFont, {
    // Left signature (Approver/Mengetahui)
    String? approverName,
    String? approverRank,
    String? approverNip,
    String? approverTitle,
    // Right signature (Creator/Pembuat Laporan)
    String? creatorName,
    String? creatorRank,
    String? creatorNip,
    String? creatorTitle,
    // Third signature (bottom center)
    String? thirdSignerName,
    String? thirdSignerRank,
    String? thirdSignerNip,
    String? thirdSignerTitle,
  }) {
    return pw.Column(
      children: [
        // Top row - Two signatures side by side
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // Left signature - Mengetahui/Approver
            pw.Container(
              width: 200,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  // Fixed height container for title to align both signatures
                  pw.Container(
                    height: 40,
                    child: pw.Text(
                      approverTitle ?? 'Pengurus Barang,',
                      style: pw.TextStyle(font: boldFont, fontSize: 9),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.SizedBox(height: 50),
                  pw.Text(
                    approverName ?? '',
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 9,
                      decoration: pw.TextDecoration.underline,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  if (approverRank != null && approverRank.isNotEmpty)
                    pw.Text(
                      approverRank,
                      style: pw.TextStyle(font: font, fontSize: 9),
                      textAlign: pw.TextAlign.center,
                    ),
                  if (approverNip != null && approverNip.isNotEmpty)
                    pw.Text(
                      'NIP. $approverNip',
                      style: pw.TextStyle(font: font, fontSize: 9),
                      textAlign: pw.TextAlign.center,
                    ),
                ],
              ),
            ),
            // Right signature - Pembuat Laporan/Creator
            pw.Container(
              width: 200,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  // Fixed height container for title to align both signatures
                  pw.Container(
                    height: 40,
                    child: pw.Text(
                      creatorTitle ?? 'Kepala Seksi Tata Usaha,',
                      style: pw.TextStyle(font: boldFont, fontSize: 9),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  pw.SizedBox(height: 50),
                  pw.Text(
                    creatorName ?? '',
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 9,
                      decoration: pw.TextDecoration.underline,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  if (creatorRank != null && creatorRank.isNotEmpty)
                    pw.Text(
                      creatorRank,
                      style: pw.TextStyle(font: font, fontSize: 9),
                      textAlign: pw.TextAlign.center,
                    ),
                  if (creatorNip != null && creatorNip.isNotEmpty)
                    pw.Text(
                      'NIP. $creatorNip',
                      style: pw.TextStyle(font: font, fontSize: 9),
                      textAlign: pw.TextAlign.center,
                    ),
                ],
              ),
            ),
          ],
        ),
        if (thirdSignerName != null && thirdSignerName.isNotEmpty) ...[
          // Spacing between top row and third signature
          pw.SizedBox(height: 30),
          // Third signature - Centered below
          pw.Center(
            child: pw.Container(
              width: 200,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    height: 50,
                    child: pw.Column(
                      children: [
                        pw.Text(
                          'Mengetahui,',
                          style: pw.TextStyle(font: boldFont, fontSize: 9),
                          textAlign: pw.TextAlign.center,
                        ),
                        pw.Text(
                          thirdSignerTitle ??
                              'KEPALA UNIT PELAKSANA TEKNIS\nPENDAPATAN DAERAH WILAYAH I PALU',
                          style: pw.TextStyle(font: boldFont, fontSize: 9),
                          textAlign: pw.TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  pw.Text(
                    thirdSignerName,
                    style: pw.TextStyle(
                      font: boldFont,
                      fontSize: 9,
                      decoration: pw.TextDecoration.underline,
                    ),
                    textAlign: pw.TextAlign.center,
                  ),
                  if (thirdSignerRank != null && thirdSignerRank.isNotEmpty)
                    pw.Text(
                      thirdSignerRank,
                      style: pw.TextStyle(font: font, fontSize: 9),
                      textAlign: pw.TextAlign.center,
                    ),
                  if (thirdSignerNip != null && thirdSignerNip.isNotEmpty)
                    pw.Text(
                      'NIP. $thirdSignerNip',
                      style: pw.TextStyle(font: font, fontSize: 9),
                      textAlign: pw.TextAlign.center,
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  pw.Widget _buildInventoryTable(
    List<InventoryItem> items,
    pw.Font font,
    pw.Font boldFont,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableCell(
              'No',
              boldFont,
              align: pw.TextAlign.center,
              isHeader: true,
            ),
            _buildTableCell(
              'Nama Barang',
              boldFont,
              align: pw.TextAlign.center,
              isHeader: true,
            ),
            _buildTableCell(
              'Jumlah',
              boldFont,
              align: pw.TextAlign.center,
              isHeader: true,
            ),
            _buildTableCell(
              'Satuan',
              boldFont,
              align: pw.TextAlign.center,
              isHeader: true,
            ),
            _buildTableCell(
              'Kondisi',
              boldFont,
              align: pw.TextAlign.center,
              isHeader: true,
            ),
          ],
        ),
        // Data
        ...items.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final item = entry.value;
          final isOut = item.quantity <= 0;
          final isLow = item.isLowStock;

          // Determine row color
          PdfColor? rowColor;
          if (isOut) {
            rowColor = PdfColors.red100;
          } else if (isLow) {
            rowColor = PdfColors.yellow100;
          }

          return pw.TableRow(
            decoration: rowColor != null
                ? pw.BoxDecoration(color: rowColor)
                : null,
            children: [
              _buildTableCell(
                index.toString(),
                font,
                align: pw.TextAlign.center,
              ),
              _buildTableCell(item.name, font),
              _buildTableCell(
                item.quantity.toString(),
                font,
                align: pw.TextAlign.center,
              ),
              _buildTableCell(
                item.unit ?? '-',
                font,
                align: pw.TextAlign.center,
              ),
              _buildTableCell(
                isOut ? 'Habis' : (isLow ? 'Kurang' : 'Baik'),
                font,
                align: pw.TextAlign.center,
              ),
            ],
          );
        }),
      ],
    );
  }

  pw.Widget _buildAssetTable(
    List<Asset> assets,
    Map<int, String> holderNames,
    Map<int, String> categoryNames,
    Map<int, String> roomNames,
    pw.Font font,
    pw.Font boldFont,
  ) {
    return pw.Table(
      columnWidths: {
        0: const pw.FixedColumnWidth(25), // No
        1: const pw.FlexColumnWidth(2), // Name
        2: const pw.FixedColumnWidth(35), // Qty (New)
        3: const pw.FlexColumnWidth(1.2), // Category
        4: const pw.FlexColumnWidth(1.2), // Room
        5: const pw.FixedColumnWidth(40), // Tahun
        6: const pw.FlexColumnWidth(1.5), // Serial
        7: const pw.FixedColumnWidth(50), // Status
        8: const pw.FlexColumnWidth(1.5), // User
        9: const pw.FlexColumnWidth(2.5), // Deskripsi
      },
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
      children: [
        // Header
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            _buildTableCell(
              'No',
              boldFont,
              align: pw.TextAlign.center,
              isHeader: true,
            ),
            _buildTableCell(
              'Nama Aset',
              boldFont,
              align: pw.TextAlign.center,
              isHeader: true,
            ),
            _buildTableCell(
              'Jml', // Short for Jumlah
              boldFont,
              align: pw.TextAlign.center,
              isHeader: true,
            ),
            _buildTableCell(
              'Kategori',
              boldFont,
              align: pw.TextAlign.center,
              isHeader: true,
            ),
            _buildTableCell(
              'Ruangan',
              boldFont,
              align: pw.TextAlign.center,
              isHeader: true,
            ),
            _buildTableCell(
              'Thn',
              boldFont,
              align: pw.TextAlign.center,
              isHeader: true,
            ),
            _buildTableCell(
              'Nomor Seri',
              boldFont,
              align: pw.TextAlign.center,
              isHeader: true,
            ),
            _buildTableCell(
              'Status',
              boldFont,
              align: pw.TextAlign.center,
              isHeader: true,
            ),
            _buildTableCell(
              'Pengguna',
              boldFont,
              align: pw.TextAlign.center,
              isHeader: true,
            ),
            _buildTableCell(
              'Deskripsi',
              boldFont,
              align: pw.TextAlign.center,
              isHeader: true,
            ),
          ],
        ),
        // Data
        ...assets.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final asset = entry.value;
          final holder = asset.status == 'maintenance'
              ? (asset.maintenanceLocation ?? 'Maintenance')
              : (asset.currentHolderId != null
                    ? holderNames[asset.currentHolderId] ?? 'Unknown'
                    : '-');

          return pw.TableRow(
            children: [
              _buildTableCell(
                index.toString(),
                font,
                align: pw.TextAlign.center,
              ),
              _buildTableCell(asset.name, font),
              _buildTableCell(
                asset.quantity.toString(),
                font,
                align: pw.TextAlign.center,
              ),

              _buildTableCell(
                asset.categoryId != null
                    ? categoryNames[asset.categoryId] ?? '-'
                    : '-',
                font,
              ),
              _buildTableCell(
                asset.assignedToRoomId != null
                    ? roomNames[asset.assignedToRoomId] ?? '-'
                    : '-',
                font,
              ),
              _buildTableCell(
                asset.purchaseDate != null
                    ? DateFormat('yyyy').format(asset.purchaseDate!)
                    : '-',
                font,
                align: pw.TextAlign.center,
              ),
              _buildTableCell(asset.identifierValue ?? '-', font),
              // Status color indicator
              _buildStatusColorCell(asset.status),
              _buildTableCell(holder, font),
              _buildTableCell(asset.description ?? '-', font),
            ],
          );
        }),
      ],
    );
  }

  // Build status color cell with colored circle indicator
  pw.Widget _buildStatusColorCell(String status) {
    PdfColor statusColor;
    switch (status.toLowerCase()) {
      case 'available':
        statusColor = PdfColors.green;
        break;
      case 'assigned':
        statusColor = PdfColors.blue;
        break;
      case 'maintenance':
        statusColor = PdfColors.red;
        break;
      default:
        statusColor = PdfColors.grey;
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Center(
        child: pw.Container(
          width: 12,
          height: 12,
          decoration: pw.BoxDecoration(
            color: statusColor,
            shape: pw.BoxShape.circle,
          ),
        ),
      ),
    );
  }

  pw.Widget _buildTableCell(
    String text,
    pw.Font font, {
    pw.TextAlign align = pw.TextAlign.left,
    bool isHeader = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          font: font,
          fontSize: 10,
          fontWeight: isHeader ? pw.FontWeight.bold : null,
        ),
      ),
    );
  }
}
