import 'package:hive_flutter/hive_flutter.dart';
import 'package:optibill/models/frame.dart';
import 'package:optibill/models/lens.dart';
import 'package:optibill/services/product_service.dart';

class CSVDataImporter {
  final ProductService _productService = ProductService();

  /// Validates CSV structure before importing
  void validateCSVStructure(String csvData) {
    print('=== CSV VALIDATION ===');

    List<String> allLines = csvData.split('\n');
    print('Total lines in CSV (including empty): ${allLines.length}');

    List<String> nonEmptyLines = allLines
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    print('Non-empty lines: ${nonEmptyLines.length}');

    if (nonEmptyLines.isEmpty) {
      print('ERROR: No non-empty lines found!');
      return;
    }

    // Show each line with its number
    for (int i = 0; i < nonEmptyLines.length; i++) {
      String line = nonEmptyLines[i];
      if (i == 0) {
        print('Line ${i + 1} (HEADER): "$line"');
      } else {
        print('Line ${i + 1} (DATA): "$line"');
      }
    }

    print('Expected data rows: ${nonEmptyLines.length - 1}');
    print('=== END CSV VALIDATION ===\n');
  }
  Future<void> importProductsFromCSV(String csvData) async {
    try {
      // Split CSV into lines and filter out empty lines
      List<String> lines = csvData.trim().split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();

      if (lines.isEmpty) {
        print('No data found in CSV');
        return;
      }

      // Get headers (first line)
      List<String> headers = _parseCSVLine(lines[0]);
      print('Headers found: $headers');
      print('Total data lines to process: ${lines.length - 1}');

      int frameCount = 0;
      int lensCount = 0;
      int errorCount = 0;
      int skippedCount = 0;
      List<String> failedRows = [];
      List<String> successfulRows = [];

      // Process each data line
      for (int i = 1; i < lines.length; i++) {
        try {
          String currentLine = lines[i].trim();
          if (currentLine.isEmpty) {
            print('Row ${i + 1}: Skipped - Empty line');
            skippedCount++;
            continue;
          }

          print('--- Processing Row ${i + 1} ---');
          print('Raw line: "$currentLine"');

          List<String> values = _parseCSVLine(currentLine);
          print('Parsed into ${values.length} values: $values');

          if (values.length != headers.length) {
            String error = 'Column count mismatch. Expected ${headers.length}, got ${values.length}';
            print('Row ${i + 1}: ERROR - $error');
            print('Headers: $headers');
            print('Values: $values');
            failedRows.add('Row ${i + 1}: $error - Line: "$currentLine"');
            errorCount++;
            continue;
          }

          // Create a map for easier access
          Map<String, String> rowData = {};
          for (int j = 0; j < headers.length; j++) {
            String key = headers[j].trim().toLowerCase();
            String value = values[j].trim();
            rowData[key] = value;
            print('  $key: "$value"');
          }

          // Determine product type and create appropriate object
          String productType = rowData['type']?.toLowerCase() ?? '';
          String productName = rowData['name'] ?? 'Unknown';

          if (productType == 'frame') {
            await _createFrame(rowData);
            frameCount++;
            successfulRows.add('Row ${i + 1}: Frame "$productName" imported successfully');
            print('Row ${i + 1}: SUCCESS - Frame "$productName" created');
          } else if (productType == 'lens') {
            await _createLens(rowData);
            lensCount++;
            successfulRows.add('Row ${i + 1}: Lens "$productName" imported successfully');
            print('Row ${i + 1}: SUCCESS - Lens "$productName" created');
          } else {
            String error = 'Unknown product type: "$productType"';
            print('Row ${i + 1}: ERROR - $error');
            failedRows.add('Row ${i + 1}: $error - Product: "$productName"');
            errorCount++;
          }
        } catch (e, stackTrace) {
          String error = 'Exception during processing: $e';
          print('Row ${i + 1}: ERROR - $error');
          print('Stack trace: $stackTrace');
          failedRows.add('Row ${i + 1}: $error - Line: "${lines[i]}"');
          errorCount++;
        }

        print(''); // Empty line for readability
      }

      print('');
      print('=== IMPORT SUMMARY ===');
      print('Total lines processed: ${lines.length - 1}');
      print('Frames imported: $frameCount');
      print('Lenses imported: $lensCount');
      print('Errors: $errorCount');
      print('Skipped empty lines: $skippedCount');
      print('Total successful: ${frameCount + lensCount}');

      // Final verification - check what's actually in the database
      print('');
      print('=== FINAL DATABASE VERIFICATION ===');
      final allProductsAfterImport = _productService.getAllProducts();
      print('Products actually in database after import: ${allProductsAfterImport.length}');

      if (allProductsAfterImport.length != (frameCount + lensCount)) {
        print('⚠️  WARNING: Imported ${frameCount + lensCount} but database only has ${allProductsAfterImport.length}!');

        // Show all products in database
        print('Products currently in database:');
        for (int i = 0; i < allProductsAfterImport.length; i++) {
          final product = allProductsAfterImport[i];
          if (product is Frame) {
            print('  Frame ${i + 1}: ${product.modelName} (ID: ${product.id})');
          } else if (product is Lens) {
            print('  Lens ${i + 1}: ${product.name} (ID: ${product.id})');
          }
        }

        // Check for duplicate names (which might indicate ID collisions)
        print('');
        print('Checking for duplicate names:');
        Map<String, int> nameCount = {};
        for (var product in allProductsAfterImport) {
          String name = product is Frame ? product.modelName : (product as Lens).name;
          nameCount[name] = (nameCount[name] ?? 0) + 1;
        }

        nameCount.forEach((name, count) {
          if (count > 1) {
            print('  ⚠️  "$name" appears $count times - possible duplicate!');
          }
        });
      } else {
        print('✓ Database verification passed: All products successfully saved');
      }

      if (successfulRows.isNotEmpty) {
        print('');
        print('=== SUCCESSFUL IMPORTS ===');
        for (String success in successfulRows) {
          print(success);
        }
      }

      if (failedRows.isNotEmpty) {
        print('');
        print('=== FAILED IMPORTS ===');
        for (String failure in failedRows) {
          print(failure);
        }
      }

    } catch (e, stackTrace) {
      print('Error importing CSV data: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Creates a Frame object from CSV row data
  Future<void> _createFrame(Map<String, String> data) async {
    // Generate a more unique ID to prevent collisions
    String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    String microseconds = DateTime.now().microsecond.toString().padLeft(6, '0');
    String randomPart = (DateTime.now().microsecond % 1000).toString().padLeft(3, '0');
    String uniqueId = '${timestamp}_${microseconds}_$randomPart';

    Frame frame = Frame(
      id: uniqueId,
      modelName: data['name'] ?? '',
      brand: data['brand'] ?? '',
      sellingPrice: _parseDouble(data['selling price'] ?? data['sellingprice'] ?? '0'),
      costPrice: _parseDouble(data['cost price'] ?? data['costprice'] ?? '0'),
      stock: _parseDouble(data['stock'] ?? '0'),
      // Store code and size information if your Frame model has these fields
      description: 'Code: ${data['code'] ?? ''} | Size: ${data['size'] ?? ''}',
      // size: data['size'] ?? '',
    );

    print('Creating Frame with ID: ${frame.id}, Name: ${frame.modelName}');

    try {
      await _productService.addFrame(frame);
      print('Successfully saved Frame: ${frame.modelName}');

      // Immediately verify it was saved
      await _verifyFrameSaved(frame);

    } catch (e) {
      print('ERROR saving Frame ${frame.modelName}: $e');
      rethrow;
    }
  }

  /// Verify that a frame was actually saved to the database
  Future<void> _verifyFrameSaved(Frame frame) async {
    try {
      final allProducts = _productService.getAllProducts();
      final frames = allProducts.whereType<Frame>();

      bool found = frames.any((f) => f.id == frame.id);
      if (found) {
        print('✓ Verification passed: Frame ${frame.modelName} found in database');
      } else {
        print('✗ Verification FAILED: Frame ${frame.modelName} NOT found in database!');

        // Show what frames ARE in the database
        print('Current frames in database:');
        for (var f in frames) {
          print('  - ${f.modelName} (ID: ${f.id})');
        }
      }
    } catch (e) {
      print('Error during verification: $e');
    }
  }

  /// Creates a Lens object from CSV row data
  Future<void> _createLens(Map<String, String> data) async {
    Lens lens = Lens(
      id: DateTime.now().millisecondsSinceEpoch.toString() +
          (DateTime.now().microsecond % 1000).toString(),
      name: data['name'] ?? data['model'] ?? data['modelname'] ?? '',
      company: data['company'] ?? data['brand'] ?? '',
      sellingPrice: _parseDouble(data['sellingprice'] ?? data['selling price'] ?? '0'),
      costPrice: _parseDouble(data['costprice'] ?? data['cost price'] ?? '0'),
      stock: _parseDouble(data['stock'] ?? '0'),
      description: 'Code: ${data['code'] ?? ''} | Size: ${data['size'] ?? ''}',

    );

    await _productService.addLens(lens);
  }

  /// Parses a single CSV line, handling quoted values with commas
  List<String> _parseCSVLine(String line) {
    List<String> result = [];
    bool inQuotes = false;
    String currentField = '';

    for (int i = 0; i < line.length; i++) {
      String char = line[i];

      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          // Handle escaped quotes ("")
          currentField += '"';
          i++; // Skip the next quote
        } else {
          // Toggle quote state
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        // End of field
        result.add(currentField.trim());
        currentField = '';
      } else {
        currentField += char;
      }
    }

    // Add the last field
    result.add(currentField.trim());

    // Remove any remaining quotes from fields
    for (int i = 0; i < result.length; i++) {
      String field = result[i];
      if (field.startsWith('"') && field.endsWith('"') && field.length > 1) {
        result[i] = field.substring(1, field.length - 1);
      }
    }

    return result;
  }

  /// Safely parses string to double
  double _parseDouble(String value) {
    try {
      // Remove currency symbols and whitespace
      String cleanValue = value.replaceAll(RegExp(r'[₹\$,\s]'), '');
      return double.tryParse(cleanValue) ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  /// Safely parses string to int
  int _parseInt(String value) {
    try {
      String cleanValue = value.replaceAll(RegExp(r'[,\s]'), '');
      return int.tryParse(cleanValue) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Clears all existing products (use with caution!)
  Future<void> clearAllProducts() async {
    Box<Frame> frameBox = Hive.box<Frame>('frames');
    Box<Lens> lensBox = Hive.box<Lens>('lenses');

    await frameBox.clear();
    await lensBox.clear();

    print('All products cleared from database');
  }
}