import 'dart:typed_data'; // This import is crucial for Uint8List
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:optibill/models/invoice.dart';
import 'package:optibill/models/invoice_item.dart';

class PdfGenerator {
  static Future<Uint8List> generateInvoicePdf(Invoice invoice) async {
    final pdf = pw.Document();

    final formatCurrency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. '); // Indian Rupee
    final formatDate = DateFormat('dd-MM-yyyy HH:mm');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'Lens4Eyes',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Invoice ID: ${invoice.invoiceId.substring(0, 8).toUpperCase()}'),
                      pw.Text('Date: ${formatDate.format(invoice.saleDate)}'),
                      pw.Text('Payment Method: ${invoice.paymentMethod}'),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      if (invoice.customerName != null && invoice.customerName!.isNotEmpty)
                        pw.Text('Customer: ${invoice.customerName}'),
                      if (invoice.customerContact != null && invoice.customerContact!.isNotEmpty)
                        pw.Text('Contact: ${invoice.customerContact}'),
                    ],
                  ),
                ],
              ),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text(
                'Items:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Table.fromTextArray(
                headers: ['Product', 'Type', 'Qty', 'Unit Price', 'Discount', 'Total'],
                data: invoice.items.map((item) {
                  return [
                    item.productName,
                    item.productType,
                    item.quantity.toString(),
                    formatCurrency.format(item.unitSellingPrice),
                    item.discountAmount != null && item.discountAmount! > 0
                        ? formatCurrency.format(item.discountAmount!)
                        : '-',
                    formatCurrency.format(item.totalSellingPrice),
                  ];
                }).toList(),
                border: null,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.all(5),
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Subtotal: ${formatCurrency.format(invoice.subtotal)}'),
                    if (invoice.totalDiscountOnBill != null && invoice.totalDiscountOnBill! > 0)
                      pw.Text('Bill Discount: -${formatCurrency.format(invoice.totalDiscountOnBill!)}'),
                    pw.Text(
                      'Total Amount: ${formatCurrency.format(invoice.totalAmount)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
                    ),
                    pw.SizedBox(height: 10),

                  ],
                ),
              ),
              pw.Spacer(),
              pw.Center(
                child: pw.Text('Thank you for your business!', style: const pw.TextStyle(fontSize: 12)),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static Future<void> printAndSharePdf(Uint8List pdfBytes, String filename) async {
    await Printing.sharePdf(bytes: pdfBytes, filename: filename);
  }
}
