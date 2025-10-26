import 'package:flutter/foundation.dart';
import '../browse.dart' show Item;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class ItemsService {
  ItemsService._();
  static final ItemsService instance = ItemsService._();

  // Observable list of items
  final ValueNotifier<List<Item>> items = ValueNotifier<List<Item>>([]);

  // Add a new item
  Future<void> addItem({
    required String title,
    required File? imageFile,
    required String category,
  }) async {
    try {
      // Generate a unique ID
      final id = DateTime.now().millisecondsSinceEpoch.toString();

      // Save image to app directory and get its path
      String imageUrl = '';
      if (imageFile != null) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = '${id}${path.extension(imageFile.path)}';
        final savedImage = await imageFile.copy('${appDir.path}/$fileName');
        imageUrl = savedImage.path;
      }

      // Create new item
      final newItem = Item(
        id: id,
        title: title,
        imageUrl: imageUrl,
        category: category,
        statusColor: 'Available', // Default status
      );

      // Add to list
      final currentItems = List<Item>.from(items.value);
      currentItems.add(newItem);
      items.value = currentItems;
    } catch (e) {
      debugPrint('Error adding item: ${e}');
      rethrow;
    }
  }

  // Update an existing item
  Future<void> updateItem(Item updatedItem) async {
    try {
      final currentItems = List<Item>.from(items.value);
      final index = currentItems.indexWhere(
        (item) => item.id == updatedItem.id,
      );

      if (index == -1) throw Exception('Item not found');

      currentItems[index] = updatedItem;
      items.value = currentItems;
    } catch (e) {
      debugPrint('Error updating item: ${e}');
      rethrow;
    }
  }

  // Toggle item disabled status
  Future<void> toggleItemStatus(String itemId) async {
    try {
      final currentItems = List<Item>.from(items.value);
      final index = currentItems.indexWhere((item) => item.id == itemId);

      if (index == -1) throw Exception('Item not found');

      currentItems[index] = currentItems[index].copyWith(
        isDisabled: !currentItems[index].isDisabled,
      );
      items.value = currentItems;
    } catch (e) {
      debugPrint('Error toggling item status: ${e}');
      rethrow;
    }
  }

  // Get items
  List<Item> getItems() => items.value;

  // Get item by ID
  Item? getItemById(String id) {
    try {
      return items.value.firstWhere((item) => item.id == id);
    } catch (e) {
      return null;
    }
  }
}
