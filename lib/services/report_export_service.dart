// lib/services/report_export_service.dart
// UC-17: Export Reports as PDF and CSV

import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import '../models/medication_model.dart';
import '../models/adherence_event_model.dart';

class ReportExportService {
  Future<void> exportToPDF({
    required List<Medication> medications,
    required List<AdherenceEvent> events,
    required Map<String, dynamic> stats,
    required String dateRange,
  }) async {
    final pdf = pw.Document();
    final now = DateTime.now();
    final formatter = DateFormat('dd/MM/yyyy');

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (pw.Context context) => [
        // Header
        pw.Container(
          padding: const pw.EdgeInsets.all(20),
          decoration: pw.BoxDecoration(color: PdfColors.blue700, borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('MediSmart', style: pw.TextStyle(color: PdfColors.white, fontSize: 28, fontWeight: pw.FontWeight.bold)),
            pw.Text('Medication Adherence Report', style: const pw.TextStyle(color: PdfColor(1, 1, 1, 0.7), fontSize: 16)),
            pw.SizedBox(height: 8),
            pw.Text('Period: $dateRange   |   Generated: ${formatter.format(now)}',
              style: const pw.TextStyle(color: PdfColor(1, 1, 1, 0.7), fontSize: 12)),
          ]),
        ),
        pw.SizedBox(height: 20),

        // Stats
        pw.Text('Summary', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Row(children: [
          _pdfStatBox('Adherence', '${((stats['percentage'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)}%', PdfColors.blue),
          pw.SizedBox(width: 10),
          _pdfStatBox('Taken', '${stats['taken'] ?? 0}', PdfColors.green),
          pw.SizedBox(width: 10),
          _pdfStatBox('Missed', '${stats['missed'] ?? 0}', PdfColors.red),
          pw.SizedBox(width: 10),
          _pdfStatBox('Total', '${stats['total'] ?? 0}', PdfColors.orange),
        ]),
        pw.SizedBox(height: 20),

        // Per medication
        pw.Text('Per Medication', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Table(border: pw.TableBorder.all(color: PdfColors.grey300), children: [
          pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.blue100), children: [
            _pdfCell('Medication', isHeader: true), _pdfCell('Dosage', isHeader: true),
            _pdfCell('Frequency', isHeader: true), _pdfCell('Status', isHeader: true),
          ]),
          ...medications.map((med) => pw.TableRow(children: [
            _pdfCell(med.name), _pdfCell('${med.dosageAmount}${med.dosageUnit}'),
            _pdfCell(med.frequency), _pdfCell(med.isActive ? 'Active' : 'Inactive'),
          ])),
        ]),
        pw.SizedBox(height: 20),

        // Recent events
        if (events.isNotEmpty) ...[
          pw.Text('Recent Adherence Events (Last 20)', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Table(border: pw.TableBorder.all(color: PdfColors.grey300), children: [
            pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.blue100), children: [
              _pdfCell('Medication', isHeader: true), _pdfCell('Date & Time', isHeader: true),
              _pdfCell('Status', isHeader: true), _pdfCell('Source', isHeader: true),
            ]),
            ...events.take(20).map((e) => pw.TableRow(children: [
              _pdfCell(e.medicationName),
              _pdfCell(DateFormat('dd/MM/yyyy HH:mm').format(e.scheduledAt)),
              _pdfCell(e.status), _pdfCell(e.source),
            ])),
          ]),
        ],

        // Footer
        pw.SizedBox(height: 30),
        pw.Divider(),
        pw.Text('MediSmart - Your Health Companion  |  IT Capstone Project 2026',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
        pw.Text('This report is for personal medication tracking purposes only. Consult your healthcare provider for medical advice.',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500)),
      ],
    ));

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/MediSmart_Report_${DateFormat('yyyyMMdd').format(now)}.pdf');
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles([XFile(file.path)], text: 'MediSmart Adherence Report');
  }

  pw.Widget _pdfStatBox(String label, String value, PdfColor color) {
    return pw.Expanded(child: pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(8)),
      child: pw.Column(children: [
        pw.Text(value, style: pw.TextStyle(color: PdfColors.white, fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.Text(label, style: const pw.TextStyle(color: PdfColor(1, 1, 1, 0.7), fontSize: 11)),
      ]),
    ));
  }

  pw.Widget _pdfCell(String text, {bool isHeader = false}) {
    return pw.Padding(padding: const pw.EdgeInsets.all(8),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 11, fontWeight: isHeader ? pw.FontWeight.bold : null)));
  }

  Future<void> exportToCSV({
    required List<AdherenceEvent> events,
    required String dateRange,
  }) async {
    List<List<dynamic>> rows = [
      ['MediSmart Adherence Report - $dateRange'],
      ['Generated: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'],
      [],
      ['Medication Name', 'Date', 'Time', 'Status', 'Source', 'Notes'],
      ...events.map((e) => [
        e.medicationName,
        DateFormat('dd/MM/yyyy').format(e.scheduledAt),
        DateFormat('HH:mm').format(e.scheduledAt),
        e.status,
        e.source,
        e.note ?? '',
      ]),
    ];

    final csvData = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/MediSmart_Report_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv');
    await file.writeAsString(csvData);
    await Share.shareXFiles([XFile(file.path)], text: 'MediSmart Adherence Data');
  }
}
