import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:optibill/models/invoice.dart';

class ExcelGenerator {
  static Future<void> generateAndSaveDailyReportExcel(List<Invoice> invoices, DateTime date) async {
    final excel = Excel.createExcel();
    final sheet = excel['Daily Report'];

    // Add header
    sheet.appendRow(['Invoice ID', 'Customer', 'Time', 'Amount', 'Profit']);

    // Add data
    for (var invoice in invoices) {
      sheet.appendRow([
        invoice.invoiceId,
        invoice.customerName ?? '',
        DateFormat('HH:mm').format(invoice.saleDate),
        invoice.totalAmount,
        invoice.totalProfit,
      ]);
    }

    // Save file
    final dir = await getExternalStorageDirectory();
    final fileName = 'Daily_Report_${DateFormat('yyyyMMdd').format(date)}.xlsx';
    final file = File('${dir!.path}/$fileName');
    await file.writeAsBytes(excel.encode()!);
  }

  static Future<void> generateAndSaveMonthlyReportExcel(
      Map<String, double> categoryBreakdown,
      Map<String, double> frameBreakdown,
      Map<String, double> lensBreakdown,
      int month,
      int year,
      ) async {
    final excel = Excel.createExcel();
    final sheet = excel['Monthly Report'];

    // Category breakdown
    sheet.appendRow(['Category', 'Revenue']);
    categoryBreakdown.forEach((k, v) => sheet.appendRow([k, v]));

    // Frame breakdown
    sheet.appendRow([]);
    sheet.appendRow(['Frame Brand', 'Revenue']);
    frameBreakdown.forEach((k, v) => sheet.appendRow([k, v]));

    // Lens breakdown
    sheet.appendRow([]);
    sheet.appendRow(['Lens Company', 'Revenue']);
    lensBreakdown.forEach((k, v) => sheet.appendRow([k, v]));

    // Save file
    final dir = await getExternalStorageDirectory();
    final fileName = 'Monthly_Report_${year}_${month.toString().padLeft(2, '0')}.xlsx';
    final file = File('${dir!.path}/$fileName');
    await file.writeAsBytes(excel.encode()!);
  }

  static Future<void> generateAndSaveYearlyReportExcel(
      Map<String, double> categoryBreakdown,
      Map<String, double> frameBreakdown,
      Map<String, double> lensBreakdown,
      int year,
      ) async {
    final excel = Excel.createExcel();
    final sheet = excel['Yearly Report'];

    // Category breakdown
    sheet.appendRow(['Category', 'Revenue']);
    categoryBreakdown.forEach((k, v) => sheet.appendRow([k, v]));

    // Frame breakdown
    sheet.appendRow([]);
    sheet.appendRow(['Frame Brand', 'Revenue']);
    frameBreakdown.forEach((k, v) => sheet.appendRow([k, v]));

    // Lens breakdown
    sheet.appendRow([]);
    sheet.appendRow(['Lens Company', 'Revenue']);
    lensBreakdown.forEach((k, v) => sheet.appendRow([k, v]));

    // Save file
    final dir = await getExternalStorageDirectory();
    final fileName = 'Yearly_Report_$year.xlsx';
    final file = File('${dir!.path}/$fileName');
    await file.writeAsBytes(excel.encode()!);
  }
}