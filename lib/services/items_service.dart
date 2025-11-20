import 'package:flutter/foundation.dart';
import '../browse.dart' show Item;
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ItemsService {
  ItemsService._();
  static final ItemsService instance = ItemsService._();

  // Observable list of items
  final ValueNotifier<List<Item>> items = ValueNotifier<List<Item>>([]);

  // Backend API base URL
  static const String _baseUrl = 'http://10.2.8.26:3000';

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
          final raw = item['lender_name'] ?? item['lenderName'];
          final normalized = (raw is String && raw.trim().isNotEmpty)
              ? raw.trim()
              : 'Yaya'; // fallback so UI never shows Unknown
          return Item(
            id: item['item_id']?.toString() ?? item['id']?.toString() ?? '',
            title:
                item['item_name']?.toString() ??
                item['title']?.toString() ??
                'Unknown',
            imageUrl: _mapItemToImage(item['item_name']?.toString() ?? ''),
            statusColor: item['availability_status']?.toString() ?? 'Available',
            description: item['description']?.toString() ?? '',
            isDisabled: (() {
              final status = item['availability_status']
                  ?.toString()
                  .toLowerCase();
              return status == 'unavailable' || status == 'disabled';
            })(),
            isBorrowed: false, // Will be updated from local flags
            lenderName: normalized,
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

    // Try exact filename match first (convert spaces to underscores, remove special chars)
    final fileName = name
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r'[^a-z0-9_]'), '');
    final exactMatch = 'http://10.2.8.26:3000/images/$fileName.png';

    // Available images: blue_yeti, dell_xps, hp_spectre, hyperx_cloud_2, ipad_air,
    // ipad_pro, iphone17_pro_max, macbook_air, macbook_pro, rode_nt

    // Check for exact matches
    if (name.contains('hyperx') || name.contains('cloud')) {
      return 'http://10.2.8.26:3000/images/hyperX_cloud_2.png';
    } else if (name.contains('ipad air')) {
      return 'http://10.2.8.26:3000/images/ipad_air.png';
    } else if (name.contains('ipad pro')) {
      return 'http://10.2.8.26:3000/images/ipad_pro.png';
    } else if (name.contains('ipad') || name.contains('tablet')) {
      return 'http://10.2.8.26:3000/images/ipad_air.png';
    } else if (name.contains('macbook air')) {
      return 'http://10.2.8.26:3000/images/macbook_air.png';
    } else if (name.contains('macbook pro')) {
      return 'http://10.2.8.26:3000/images/macbook_pro.png';
    } else if (name.contains('macbook') || name.contains('mac')) {
      return 'http://10.2.8.26:3000/images/macbook_pro.png';
    } else if (name.contains('dell') || name.contains('xps')) {
      return 'http://10.2.8.26:3000/images/dell_xps.png';
    } else if (name.contains('hp') || name.contains('spectre')) {
      return 'http://10.2.8.26:3000/images/hp_spectre.png';
    } else if (name.contains('windows') ||
        name.contains('laptop') ||
        name.contains('pc')) {
      return 'http://10.2.8.26:3000/images/dell_xps.png';
    } else if (name.contains('blue yeti') || name.contains('yeti')) {
      return 'http://10.2.8.26:3000/images/blue_yeti.png';
    } else if (name.contains('rode') || name.contains('nt')) {
      return 'http://10.2.8.26:3000/images/rode_nt.png';
    } else if (name.contains('mic') || name.contains('microphone')) {
      return 'http://10.2.8.26:3000/images/blue_yeti.png';
    } else if (name.contains('iphone') || name.contains('phone')) {
      return 'http://10.2.8.26:3000/images/iphone17_pro_max.png';
    }

    // Default fallback - try exact filename match
    return exactMatch;
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
    String description = '',
    required File? imageFile,
    String? assetImagePath,
  }) async {
    try {
      debugPrint('🔄 Adding item "$title" to backend...');

      // Map item name to image URL from backend/images
      final imageUrl = _mapItemToImage(title);

      // Add to backend database - using lender_id = 1 as default
      final response = await http.post(
        Uri.parse('$_baseUrl/items'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'item_name': title,
          'item_description': description,
          'availability_status': 'Available',
          'lender_id': 1, // Default lender
        }),
      );

      debugPrint('Response status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception('Failed to add item to database: ${response.body}');
      }

      final responseData = jsonDecode(response.body);
      final itemId = responseData['item_id'].toString();

      debugPrint('✅ Item added to backend with ID: $itemId');

      // Create new item for local list
      final newItem = Item(
        id: itemId,
        title: title,
        imageUrl: imageUrl,
        statusColor: 'Available',
        lenderName: 'Yaya', // default lender name fallback
      );

      // Add to local list
      final currentItems = List<Item>.from(items.value);
      currentItems.add(newItem);
      items.value = currentItems;
    } catch (e) {
      debugPrint('❌ Error adding item: $e');
      rethrow;
    }
  }

  // Update an existing item
  Future<void> updateItem(Item updatedItem) async {
    try {
      debugPrint('🔄 Updating item ${updatedItem.id} in backend...');

      // Update in backend database
      final response = await http.patch(
        Uri.parse('$_baseUrl/items/${updatedItem.id}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'item_name': updatedItem.title,
          'item_description': updatedItem.description,
          'availability_status': updatedItem.isDisabled
              ? 'Disabled'
              : 'Available',
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update item in database');
      }

      debugPrint('✅ Item updated in backend');

      // Update local list
      final currentItems = List<Item>.from(items.value);
      final index = currentItems.indexWhere(
        (item) => item.id == updatedItem.id,
      );

      if (index == -1) throw Exception('Item not found');

      currentItems[index] = updatedItem;
      items.value = currentItems;
      await _saveDisabledFlags();
      await _saveBorrowedFlags();
    } catch (e) {
      debugPrint('❌ Error updating item: $e');
      rethrow;
    }
  }

  // Toggle item disabled status
  Future<void> toggleItemStatus(String itemId) async {
    try {
      final currentItems = List<Item>.from(items.value);
      final index = currentItems.indexWhere((item) => item.id == itemId);

      if (index == -1) throw Exception('Item not found');

      final newDisabledStatus = !currentItems[index].isDisabled;

      debugPrint(
        '🔄 Toggling item $itemId status to ${newDisabledStatus ? "Disabled" : "Available"}',
      );

      // Update in backend database
      final response = await http.patch(
        Uri.parse('$_baseUrl/items/$itemId/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'availability_status': newDisabledStatus ? 'Disabled' : 'Available',
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update item status in database');
      }

      debugPrint('✅ Item status updated in backend');

      // Update local list
      currentItems[index] = currentItems[index].copyWith(
        isDisabled: newDisabledStatus,
      );
      items.value = currentItems;
      await _saveDisabledFlags();
    } catch (e) {
      debugPrint('❌ Error toggling item status: $e');
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
