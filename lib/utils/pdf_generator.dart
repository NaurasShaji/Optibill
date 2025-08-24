import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:optibill/models/invoice.dart';
import 'package:optibill/models/invoice_item.dart';

final thermal58mm = PdfPageFormat(164, double.infinity); // 58mm width in points

class PdfGenerator {
  static Future<Uint8List> generateInvoicePdf(Invoice invoice) async {
    final pdf = pw.Document();
    final formatCurrency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 0);
    final formatDate = DateFormat('dd-MM-yyyy HH:mm');

    pdf.addPage(
      pw.Page(
        pageFormat: thermal58mm,
        margin: const pw.EdgeInsets.all(8),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header Section
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 2, color: PdfColors.black),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'LENS4EYES',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'Optical Store',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 10),
              
              // Invoice Details Section
              pw.Container(
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 1, color: PdfColors.black),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Invoice #:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        pw.Text(invoice.invoiceId.substring(0, 8).toUpperCase(),
                            style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                    pw.SizedBox(height: 2),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Date:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        pw.Text(formatDate.format(invoice.saleDate),
                            style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                    pw.SizedBox(height: 2),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Payment:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(width: 1, color: PdfColors.black),
                          ),
                          child: pw.Text(invoice.paymentMethod.toUpperCase(),
                              style: const pw.TextStyle(fontSize: 8)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 8),

              // Customer Details (if available)
              if (invoice.customerName != null && invoice.customerName!.isNotEmpty ||
                  invoice.customerContact != null && invoice.customerContact!.isNotEmpty) ...[
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 1, color: PdfColors.black),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('CUSTOMER DETAILS', 
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 3),
                      if (invoice.customerName != null && invoice.customerName!.isNotEmpty)
                        pw.Text('Name: ${invoice.customerName}', style: const pw.TextStyle(fontSize: 8)),
                      if (invoice.customerContact != null && invoice.customerContact!.isNotEmpty)
                        pw.Text('Contact: ${invoice.customerContact}', style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 8),
              ],

              // Items Header
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.black,
                ),
                child: pw.Text('ITEMS PURCHASED',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, 
                      fontSize: 10,
                      color: PdfColors.white,
                    )),
              ),

              pw.SizedBox(height: 4),

              // Items List
              ...invoice.items.asMap().entries.map((entry) {
                int index = entry.key;
                var item = entry.value;
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 1, color: PdfColors.black),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        children: [
                          pw.Container(
                            width: 16,
                            height: 16,
                            decoration: pw.BoxDecoration(
                              color: PdfColors.black,
                              shape: pw.BoxShape.circle,
                            ),
                            child: pw.Center(
                              child: pw.Text('${index + 1}',
                                  style: pw.TextStyle(
                                    fontSize: 8, 
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.white,
                                  )),
                            ),
                          ),
                          pw.SizedBox(width: 6),
                          pw.Expanded(
                            child: pw.Text('${item.productName}',
                                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 3),
                      pw.Text('Type: ${item.productType}',
                          style: const pw.TextStyle(fontSize: 8)),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Qty: ${item.quantity}',
                              style: const pw.TextStyle(fontSize: 9)),
                          pw.Text('@ ${formatCurrency.format(item.unitSellingPrice)}',
                              style: const pw.TextStyle(fontSize: 9)),
                        ],
                      ),
                      if (item.discountAmount != null && item.discountAmount! > 0) ...[
                        pw.SizedBox(height: 2),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Discount:',
                                style: const pw.TextStyle(fontSize: 8)),
                            pw.Text('-${formatCurrency.format(item.discountAmount!)}',
                                style: const pw.TextStyle(fontSize: 8)),
                          ],
                        ),
                      ],
                      pw.SizedBox(height: 3),
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(width: 1, color: PdfColors.black),
                        ),
                        child: pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Item Total:',
                                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                            pw.Text(formatCurrency.format(item.totalSellingPrice),
                                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),

              // Bill Summary
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 2, color: PdfColors.black),
                ),
                child: pw.Column(
                  children: [
                    pw.Text('BILL SUMMARY',
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Subtotal:', style: const pw.TextStyle(fontSize: 10)),
                        pw.Text(formatCurrency.format(invoice.subtotal),
                            style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    if (invoice.totalDiscountOnBill != null && invoice.totalDiscountOnBill! > 0) ...[
                      pw.SizedBox(height: 3),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Bill Discount:', 
                              style: const pw.TextStyle(fontSize: 10)),
                          pw.Text('-${formatCurrency.format(invoice.totalDiscountOnBill!)}',
                              style: const pw.TextStyle(fontSize: 10)),
                        ],
                      ),
                    ],
                    pw.SizedBox(height: 6),
                    pw.Container(
                      width: double.infinity,
                      height: 2,
                      color: PdfColors.black,
                    ),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('TOTAL AMOUNT:',
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.Text(formatCurrency.format(invoice.totalAmount),
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 15),

              // Footer
              pw.Column(
                children: [
                  pw.Container(
                    width: double.infinity,
                    height: 2,
                    color: PdfColors.black,
                  ),
                  pw.SizedBox(height: 8),
                  pw.Center(
                    child: pw.Text(
                      'Thank you for choosing Lens4Eyes!',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        fontStyle: pw.FontStyle.italic,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Center(
                    child: pw.Text(
                      'Visit us again for all your optical needs',
                      style: const pw.TextStyle(fontSize: 8),
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    width: double.infinity,
                    height: 2,
                    color: PdfColors.black,
                  ),
                ],
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

//For A4
// import 'dart:typed_data'; // This import is crucial for Uint8List
// import 'package:pdf/pdf.dart';
// import 'package:pdf/widgets.dart' as pw;
// import 'package:printing/printing.dart';
// import 'package:intl/intl.dart';
// import 'package:optibill/models/invoice.dart';
// import 'package:optibill/models/invoice_item.dart';
//
// final thermal58mm = PdfPageFormat(164, double.infinity);
//
// class PdfGenerator {
//   static Future<Uint8List> generateInvoicePdf(Invoice invoice) async {
//     final pdf = pw.Document();
//
//     final formatCurrency = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. '); // Indian Rupee
//     final formatDate = DateFormat('dd-MM-yyyy HH:mm');
//
//     pdf.addPage(
//       pw.Page(
//         pageFormat: thermal58mm,
//         build: (pw.Context context) {
//           return pw.Column(
//             crossAxisAlignment: pw.CrossAxisAlignment.start,
//             children: [
//               pw.Center(
//                 child: pw.Text(
//                   'Lens4Eyes',
//                   style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
//                 ),
//               ),
//               pw.SizedBox(height: 20),
//               pw.Row(
//                 mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
//                 children: [
//                   pw.Column(
//                     crossAxisAlignment: pw.CrossAxisAlignment.start,
//                     children: [
//                       pw.Text('Invoice ID: ${invoice.invoiceId.substring(0, 8).toUpperCase()}'),
//                       pw.Text('Date: ${formatDate.format(invoice.saleDate)}'),
//                       pw.Text('Payment Method: ${invoice.paymentMethod}'),
//                     ],
//                   ),
//                   pw.Column(
//                     crossAxisAlignment: pw.CrossAxisAlignment.end,
//                     children: [
//                       if (invoice.customerName != null && invoice.customerName!.isNotEmpty)
//                         pw.Text('Customer: ${invoice.customerName}'),
//                       if (invoice.customerContact != null && invoice.customerContact!.isNotEmpty)
//                         pw.Text('Contact: ${invoice.customerContact}'),
//                     ],
//                   ),
//                 ],
//               ),
//               pw.Divider(),
//               pw.SizedBox(height: 10),
//               pw.Text(
//                 'Items:',
//                 style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
//               ),
//               pw.Table.fromTextArray(
//                 headers: ['Product', 'Type', 'Qty', 'Unit Price', 'Discount', 'Total'],
//                 data: invoice.items.map((item) {
//                   return [
//                     item.productName,
//                     item.productType,
//                     item.quantity.toString(),
//                     formatCurrency.format(item.unitSellingPrice),
//                     item.discountAmount != null && item.discountAmount! > 0
//                         ? formatCurrency.format(item.discountAmount!)
//                         : '-',
//                     formatCurrency.format(item.totalSellingPrice),
//                   ];
//                 }).toList(),
//                 border: null,
//                 headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
//                 headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
//                 cellAlignment: pw.Alignment.centerLeft,
//                 cellPadding: const pw.EdgeInsets.all(5),
//               ),
//               pw.SizedBox(height: 20),
//               pw.Divider(),
//               pw.Align(
//                 alignment: pw.Alignment.centerRight,
//                 child: pw.Column(
//                   crossAxisAlignment: pw.CrossAxisAlignment.end,
//                   children: [
//                     pw.Text('Subtotal: ${formatCurrency.format(invoice.subtotal)}'),
//                     if (invoice.totalDiscountOnBill != null && invoice.totalDiscountOnBill! > 0)
//                       pw.Text('Bill Discount: -${formatCurrency.format(invoice.totalDiscountOnBill!)}'),
//                     pw.Text(
//                       'Total Amount: ${formatCurrency.format(invoice.totalAmount)}',
//                       style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
//                     ),
//                     pw.SizedBox(height: 10),
//
//                   ],
//                 ),
//               ),
//               pw.Spacer(),
//               pw.Center(
//                 child: pw.Text('Thank you for your business!', style: const pw.TextStyle(fontSize: 12)),
//               ),
//             ],
//           );
//         },
//       ),
//     );
//
//     return pdf.save();
//   }
//
//   static Future<void> printAndSharePdf(Uint8List pdfBytes, String filename) async {
//     await Printing.sharePdf(bytes: pdfBytes, filename: filename);
//   }
// }

