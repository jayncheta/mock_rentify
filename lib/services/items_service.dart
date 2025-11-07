import 'package:flutter/foundation.dart';
import '../browse.dart' show Item;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ItemsService {
  ItemsService._();
  static final ItemsService instance = ItemsService._();

  // Observable list of items
  final ValueNotifier<List<Item>> items = ValueNotifier<List<Item>>([]);

  // Backend API base URL
  static const String _baseUrl = 'http://172.27.9.184:3000';

  // --- Persistence keys ---
  static const String _disabledIdsKey = 'disabled_item_ids';
  static const String _borrowedIdsKey = 'borrowed_item_ids';

  /// Fetch items from backend database
  Future<bool> fetchItemsFromBackend() async {
    try {
      debugPrint('🔄 Fetching items from backend...');
      final response = await http.get(
        Uri.parse('$_baseUrl/items?includeDisabled=true'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        debugPrint('✅ Fetched ${data.length} items from database');

        final List<Item> fetchedItems = data.map((item) {
          return Item(
            id: item['item_id']?.toString() ?? item['id']?.toString() ?? '',
            title:
                item['item_name']?.toString() ??
                item['title']?.toString() ??
                'Unknown',
            imageUrl: _mapItemToImage(item['item_name']?.toString() ?? ''),
            statusColor: item['availability_status']?.toString() ?? 'Available',
            description: item['description']?.toString() ?? '',
            isDisabled:
                item['availability_status']?.toString().toLowerCase() ==
                'unavailable',
            isBorrowed: false, // Will be updated from local flags
          );
        }).toList();

        items.value = fetchedItems;

        // Apply saved disabled and borrowed flags
        await loadDisabledFlags();
        await loadBorrowedFlags();

        return true;
      } else {
        debugPrint('❌ Error fetching items: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error fetching items from backend: $e');
      return false;
    }
  }

  /// Map item name to local asset image
  String _mapItemToImage(String itemName) {
    final name = itemName.toLowerCase();

    if (name.contains('ipad air')) {
      return 'http://172.27.9.184:3000/images/ipad_air.png';
    } else if (name.contains('ipad pro')) {
      return 'http://172.27.9.184:3000/images/ipad_pro.png';
    } else if (name.contains('ipad') || name.contains('tablet')) {
      return 'http://172.27.9.184:3000/images/ipad_air.png';
    } else if (name.contains('macbook air')) {
      return 'http://172.27.9.184:3000/images/macbook_air.png';
    } else if (name.contains('macbook pro')) {
      return 'http://172.27.9.184:3000/images/macbook_pro.png';
    } else if (name.contains('macbook') || name.contains('mac')) {
      return 'http://172.27.9.184:3000/images/macbook_pro.png';
    } else if (name.contains('dell') || name.contains('xps')) {
      return 'http://172.27.9.184:3000/images/dell_xps.png';
    } else if (name.contains('hp') || name.contains('spectre')) {
      return 'http://172.27.9.184:3000/images/hp_spectre.png';
    } else if (name.contains('windows') ||
        name.contains('laptop') ||
        name.contains('pc')) {
      return 'http://172.27.9.184:3000/images/dell_xps.png';
    } else if (name.contains('blue yeti') || name.contains('yeti')) {
      return 'http://172.27.9.184:3000/images/blue_yeti.png';
    } else if (name.contains('rode') || name.contains('nt')) {
      return 'http://172.27.9.184:3000/images/rode_nt.png';
    } else if (name.contains('mic') || name.contains('microphone')) {
      return 'http://172.27.9.184:3000/images/blue_yeti.png';
    }

    // Default fallback
    return 'http://172.27.9.184:3000/images/default.png';
  }

  // Load disabled flags from persistent storage and apply to current items
  Future<void> loadDisabledFlags() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final disabledList = prefs.getStringList(_disabledIdsKey) ?? <String>[];
      if (disabledList.isEmpty) return;

      final current = List<Item>.from(items.value);
      bool changed = false;
      for (int i = 0; i < current.length; i++) {
        final it = current[i];
        final shouldBeDisabled = disabledList.contains(it.id);
        if (it.isDisabled != shouldBeDisabled) {
          current[i] = it.copyWith(isDisabled: shouldBeDisabled);
          changed = true;
        }
      }
      if (changed) items.value = current;
    } catch (e) {
      debugPrint('Error loading disabled flags: $e');
    }
  }

  // Load borrowed flags from persistent storage and apply to current items
  Future<void> loadBorrowedFlags() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final borrowedList = prefs.getStringList(_borrowedIdsKey) ?? <String>[];
      if (borrowedList.isEmpty) return;

      final current = List<Item>.from(items.value);
      bool changed = false;
      for (int i = 0; i < current.length; i++) {
        final it = current[i];
        final shouldBeBorrowed = borrowedList.contains(it.id);
        if (it.isBorrowed != shouldBeBorrowed) {
          current[i] = it.copyWith(isBorrowed: shouldBeBorrowed);
          changed = true;
        }
      }
      if (changed) items.value = current;
    } catch (e) {
      debugPrint('Error loading borrowed flags: $e');
    }
  }

  // Save current disabled item IDs to persistent storage
  Future<void> _saveDisabledFlags() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final disabledIds = items.value
          .where((e) => e.isDisabled)
          .map((e) => e.id)
          .toList(growable: false);
      await prefs.setStringList(_disabledIdsKey, disabledIds);
    } catch (e) {
      debugPrint('Error saving disabled flags: $e');
    }
  }

  // Save current borrowed item IDs to persistent storage
  Future<void> _saveBorrowedFlags() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final borrowedIds = items.value
          .where((e) => e.isBorrowed)
          .map((e) => e.id)
          .toList(growable: false);
      await prefs.setStringList(_borrowedIdsKey, borrowedIds);
    } catch (e) {
      debugPrint('Error saving borrowed flags: $e');
    }
  }

  // Add a new item
  Future<void> addItem({
    required String title,
    required File? imageFile,
    String? assetImagePath,
  }) async {
    try {
      // Generate a unique ID
      final id = DateTime.now().millisecondsSinceEpoch.toString();

      // Save image to app directory and get its path
      String imageUrl = '';
      if (assetImagePath != null && assetImagePath.isNotEmpty) {
        imageUrl = assetImagePath;
      } else if (imageFile != null) {
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

      // Preserve persisted disabled flags if not explicitly changed upstream
      // Write the updated item back; disabled flag will be persisted via _saveDisabledFlags()
      currentItems[index] = updatedItem;
      items.value = currentItems;
      await _saveDisabledFlags();
      await _saveBorrowedFlags();
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
      await _saveDisabledFlags();
    } catch (e) {
      debugPrint('Error toggling item status: ${e}');
      rethrow;
    }
  }

  // Set item borrowed status
  Future<void> setBorrowed(String itemId, bool borrowed) async {
    try {
      final currentItems = List<Item>.from(items.value);
      final index = currentItems.indexWhere((item) => item.id == itemId);
      if (index != -1) {
        // Update in-memory list if present
        currentItems[index] = currentItems[index].copyWith(
          isBorrowed: borrowed,
        );
        items.value = currentItems;
        await _saveBorrowedFlags();
      } else {
        // Item list not initialized or missing; persist directly so it will
        // be applied when items are loaded later via loadBorrowedFlags().
        final prefs = await SharedPreferences.getInstance();
        final list = prefs.getStringList(_borrowedIdsKey) ?? <String>[];
        if (borrowed) {
          if (!list.contains(itemId)) list.add(itemId);
        } else {
          list.remove(itemId);
        }
        await prefs.setStringList(_borrowedIdsKey, list);
      }
    } catch (e) {
      debugPrint('Error setting borrowed flag: $e');
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
