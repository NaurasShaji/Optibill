import 'package:optibill/utils/csv_data_importer.dart';
import 'package:optibill/services/product_service.dart';
// Your CSV data
const String initialProductsCsv = """
CODE,NAME,SIZE,STOCK,SELLING PRICE,COST PRICE,TYPE,BRAND
"121203,121205",KERZER,"48,52",2,2500,1250.0,FRAME,Expensive
62005,FOX EYE,54,9,1900,950.0,FRAME,Expensive
FA5518,FARENHEIT,51,1,1800,900.0,FRAME,Expensive
921808,LADYOVE,51,1,1200,600.0,FRAME,Expensive
223815,ORIONIS,54,2,1900,950.0,FRAME,Expensive
TH6105,TOM HANS,52,8,2900,1450.0,FRAME,Expensive
TH1108,TOM HARDY,51,10,1800,900.0,FRAME,Expensive
9315404,DOIK DOIKI,50,2,1900,950.0,FRAME,Expensive
0X318,OXION,50,11,1956,978.0,FRAME,Expensive
31002,SUNOXII,49,7,1499,749.5,FRAME,Expensive
KING,STEEPPERS,48,1,1100,550.0,FRAME,Expensive
22057,DANIEL HUNTER,52,2,2200,1100.0,FRAME,Expensive
23011,TOM HARRY,54,3,1750,875.0,FRAME,Expensive
W56133,BLUE OCEAN,54,2,2500,1250.0,FRAME,Expensive
98305,ENSTAR,55,2,1800,900.0,FRAME,Expensive
68005,PORSCHE DESIGN,53,1,1499,749.5,FRAME,Expensive
2237,MICHAELKORS,52,1,2400,1200.0,FRAME,Expensive
26002,LETS ROCK,54,2,2500,1250.0,FRAME,Expensive
9068,RAY BAROO,54,4,2400,1200.0,FRAME,Expensive
B 52602,MIRAGE,53,1,1800,900.0,FRAME,Expensive
16005,SIXTEEN,54,1,2300,1150.0,FRAME,Expensive
-,TOMMY HILFIGER,54,2,1599,799.5,FRAME,Expensive
T34005,MARIA BOSS,54,1,14600,7300.0,FRAME,Expensive
EP1811,EYE PLAYER,52,9,2200,1100.0,FRAME,Expensive
4627,SYNERGY,50,7,1500,750.0,FRAME,Expensive
81803,STYLE,51,8,1300,650.0,FRAME,Expensive
6420,EYEE,51,3,1400,700.0,FRAME,Expensive
90115,RED WOLF,54,1,2600,1300.0,FRAME,Expensive
66662,LIVERPOOL,55,8,1400,700.0,FRAME,Expensive
11111,LENS,54,1,2500,1250.0,LENS,Expensive
""";

class InitialDataLoader {
  static Future<void> loadInitialProducts() async {
    try {
      print('Starting to load initial products...');

      // Check if products already exist
      final productService = ProductService();
      final existingProducts = productService.getAllProducts();

      if (existingProducts.isNotEmpty) {
        print('Products already exist (${existingProducts
            .length} found). Skipping import.');
        return;
      }

      CSVDataImporter importer = CSVDataImporter();
      await importer.importProductsFromCSV(initialProductsCsv);

      print('Initial products loaded successfully!');
    } catch (e) {
      print('Error loading initial products: $e');
      rethrow;
    }
  }

  // Call this if you want to clear existing data first
  static Future<void> clearAndLoadInitialProducts() async {
    try {
      print('Clearing existing products and loading initial data...');

      CSVDataImporter importer = CSVDataImporter();
      await importer.clearAllProducts();
      await importer.importProductsFromCSV(initialProductsCsv);

      print('Products cleared and initial data loaded successfully!');
    }
    catch (e) {
      print('Error during clear and load: $e');
      rethrow;
    }
  }
}