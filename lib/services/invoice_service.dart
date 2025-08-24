import 'package:hive_flutter/hive_flutter.dart';
import 'package:optibill/models/invoice.dart';
import 'package:optibill/models/invoice_item.dart'; // Ensure InvoiceItem is imported
import 'package:collection/collection.dart'; // Import this for firstWhereOrNull

class InvoiceService {
  final Box<Invoice> _invoicesBox = Hive.box<Invoice>('invoices');

  List<Invoice> getInvoices() {
    return _invoicesBox.values.toList();
  }

  Invoice? getInvoiceById(String id) { // Changed return type to nullable
    return _invoicesBox.values.firstWhereOrNull((invoice) => invoice.invoiceId == id);
  }

  Future<void> addInvoice(Invoice invoice) async {
    await _invoicesBox.put(invoice.invoiceId, invoice); // Use invoiceId as key
  }

  Future<void> updateInvoice(Invoice invoice) async {
    await _invoicesBox.put(invoice.invoiceId, invoice);
  }

  Future<void> deleteInvoice(String id) async {
    await _invoicesBox.delete(id);
  }

  // Get invoices for a specific day
  List<Invoice> getDailyInvoices(DateTime date) {
    return _invoicesBox.values.where((invoice) {
      return invoice.saleDate.year == date.year &&
          invoice.saleDate.month == date.month &&
          invoice.saleDate.day == date.day;
    }).toList();
  }

  // Get invoices for a specific month and year
  List<Invoice> getMonthlyInvoices(int month, int year) {
    return _invoicesBox.values.where((invoice) {
      return invoice.saleDate.year == year &&
          invoice.saleDate.month == month;
    }).toList();
  }

  // Get invoices for a specific year
  List<Invoice> getYearlyInvoices(int year) {
    return _invoicesBox.values.where((invoice) {
      return invoice.saleDate.year == year;
    }).toList();
  }
}
