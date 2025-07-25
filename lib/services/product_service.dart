import 'package:hive_flutter/hive_flutter.dart';
import 'package:optibill/models/frame.dart';
import 'package:optibill/models/lens.dart';
import 'package:collection/collection.dart'; // Import this for firstWhereOrNull

class ProductService {
  final Box<Frame> _framesBox = Hive.box<Frame>('frames');
  final Box<Lens> _lensesBox = Hive.box<Lens>('lenses');

  // --- Frame Operations ---
  List<Frame> getFrames() {
    return _framesBox.values.toList();
  }

  Frame? getFrameById(String id) {
    // Use firstWhereOrNull for nullable return
    return _framesBox.values.firstWhereOrNull((frame) => frame.id == id);
  }

  Future<void> addFrame(Frame frame) async {
    await _framesBox.put(frame.id, frame); // Use ID as key for easy retrieval
  }

  Future<void> updateFrame(Frame frame) async {
    await _framesBox.put(frame.id, frame);
  }

  Future<void> deleteFrame(String id) async {
    await _framesBox.delete(id);
  }

  // --- Lens Operations ---
  List<Lens> getLenses() {
    return _lensesBox.values.toList();
  }

  Lens? getLensById(String id) {
    // Use firstWhereOrNull for nullable return
    return _lensesBox.values.firstWhereOrNull((lens) => lens.id == id);
  }

  Future<void> addLens(Lens lens) async {
    await _lensesBox.put(lens.id, lens); // Use ID as key
  }

  Future<void> updateLens(Lens lens) async {
    await _lensesBox.put(lens.id, lens);
  }

  Future<void> deleteLens(String id) async {
    await _lensesBox.delete(id);
  }

  // --- Combined Product Retrieval ---
  List<dynamic> getAllProducts() {
    return [..._framesBox.values.toList(), ..._lensesBox.values.toList()];
  }

  dynamic getProductById(String id, String type) {
    if (type == 'Frame') {
      return getFrameById(id);
    } else if (type == 'Lens') {
      return getLensById(id);
    }
    return null;
  }

  // --- Stock Management ---
  Future<void> decreaseStock(String productId, String productType, int quantity) async {
    if (productType == 'Frame') {
      final frame = getFrameById(productId);
      if (frame != null) {
        frame.stock = (frame.stock - quantity).clamp(0, double.infinity);
        await updateFrame(frame);
      }
    } else if (productType == 'Lens') {
      final lens = getLensById(productId);
      if (lens != null) {
        lens.stock = (lens.stock - quantity).clamp(0, double.infinity);
        await updateLens(lens);
      }
    }
  }

  Future<void> increaseStock(String productId, String productType, int quantity) async {
    if (productType == 'Frame') {
      final frame = getFrameById(productId);
      if (frame != null) {
        frame.stock += quantity;
        await updateFrame(frame);
      }
    } else if (productType == 'Lens') {
      final lens = getLensById(productId);
      if (lens != null) {
        lens.stock += quantity;
        await updateLens(lens);
      }
    }
  }
}