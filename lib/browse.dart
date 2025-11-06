import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/items_service.dart' show ItemsService;
import 'services/user_service.dart' show UserBorrowService;
import 'package:shared_preferences/shared_preferences.dart';
import 'user/borrow_request.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class FavoritesRepo {
  FavoritesRepo._();
  static final FavoritesRepo instance = FavoritesRepo._();

  final ValueNotifier<Set<String>> favorites = ValueNotifier(<String>{});
  static const String _baseUrl = 'http://10.2.8.30:3000';

  // Fallback to local storage if backend fails
  static const String _favoritesKey = 'user_favorites';

  /// Load favorites from backend
  Future<void> loadFavorites() async {
    try {
      // Get current logged-in user
      final user = await UserBorrowService().getCurrentUser();
      if (user == null) {
        debugPrint(
          '⚠️ No user logged in, loading favorites from local storage',
        );
        await _loadFavoritesLocal();
        return;
      }

      final userId = user['user_id']?.toString() ?? '';
      if (userId.isEmpty) {
        debugPrint('⚠️ Invalid user ID, loading favorites from local storage');
        await _loadFavoritesLocal();
        return;
      }

      debugPrint('🔄 Loading favorites for user $userId from backend...');
      final response = await http.get(
        Uri.parse('$_baseUrl/users/$userId/favorites'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic> favList = data['favorites'] ?? [];
        favorites.value = favList.map((e) => e.toString()).toSet();
        debugPrint('✅ Loaded ${favorites.value.length} favorites from backend');
      } else {
        debugPrint('❌ Error loading favorites: ${response.statusCode}');
        await _loadFavoritesLocal(); // Fallback to local
      }
    } catch (e) {
      debugPrint('❌ Error loading favorites from backend: $e');
      await _loadFavoritesLocal(); // Fallback to local
    }
  }

  /// Load favorites from local storage (fallback)
  Future<void> _loadFavoritesLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? savedFavorites = prefs.getStringList(_favoritesKey);
    if (savedFavorites != null) {
      favorites.value = savedFavorites.toSet();
      debugPrint(
        '✅ Loaded ${favorites.value.length} favorites from local storage',
      );
    }
  }

  /// Save favorites to backend
  Future<void> _saveFavorite(String itemId, bool isAdding) async {
    try {
      // Get current logged-in user
      final user = await UserBorrowService().getCurrentUser();
      if (user == null) {
        debugPrint('⚠️ No user logged in, saving to local storage');
        await _saveFavoritesLocal();
        return;
      }

      final userId = user['user_id']?.toString() ?? '';
      if (userId.isEmpty) {
        await _saveFavoritesLocal();
        return;
      }

      if (isAdding) {
        // Add to favorites
        debugPrint('➕ Adding item $itemId to favorites for user $userId');
        final response = await http.post(
          Uri.parse('$_baseUrl/users/$userId/favorites'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'item_id': itemId}),
        );

        if (response.statusCode == 200) {
          debugPrint('✅ Item added to favorites in backend');
        } else {
          debugPrint('❌ Error adding favorite: ${response.statusCode}');
        }
      } else {
        // Remove from favorites
        debugPrint('➖ Removing item $itemId from favorites for user $userId');
        final response = await http.delete(
          Uri.parse('$_baseUrl/users/$userId/favorites/$itemId'),
          headers: {'Content-Type': 'application/json'},
        );

        if (response.statusCode == 200) {
          debugPrint('✅ Item removed from favorites in backend');
        } else {
          debugPrint('❌ Error removing favorite: ${response.statusCode}');
        }
      }

      // Also save to local storage as backup
      await _saveFavoritesLocal();
    } catch (e) {
      debugPrint('❌ Error saving favorite to backend: $e');
      await _saveFavoritesLocal();
    }
  }

  /// Save to local storage (fallback)
  Future<void> _saveFavoritesLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, favorites.value.toList());
  }

  bool isFavorite(String id) => favorites.value.contains(id);

  void toggle(String id, String itemName, BuildContext context) {
    final current = Set<String>.from(favorites.value);
    final isFav = current.contains(id);

    if (isFav) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Remove from Favorites',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: Text(
            'Would you like to remove "$itemName" from your favorites?',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: GoogleFonts.poppins()),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                current.remove(id);
                favorites.value = current;
                _saveFavorite(id, false); // Remove from backend
              },
              child: Text('Yes', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      );
    } else {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Add to Favorites',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: Text(
            'Would you like to add "$itemName" to your favorites?',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: GoogleFonts.poppins()),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                current.add(id);
                favorites.value = current;
                _saveFavorite(id, true); // Add to backend
              },
              child: Text('Yes', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      );
    }
  }
}

class Item {
  final String id;
  final String title;
  final String imageUrl;
  final String statusColor;
  final String description;
  final bool isDisabled;
  final bool isBorrowed;

  const Item({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.statusColor,
    this.description = '',
    this.isDisabled = false,
    this.isBorrowed = false,
  });

  Item copyWith({
    String? id,
    String? title,
    String? imageUrl,
    String? statusColor,
    String? description,
    bool? isDisabled,
    bool? isBorrowed,
  }) {
    return Item(
      id: id ?? this.id,
      title: title ?? this.title,
      imageUrl: imageUrl ?? this.imageUrl,
      statusColor: statusColor ?? this.statusColor,
      description: description ?? this.description,
      isDisabled: isDisabled ?? this.isDisabled,
      isBorrowed: isBorrowed ?? this.isBorrowed,
    );
  }
}

const primaryColor = Color(0xFFF96A38);
const secondaryColor = Color(0xFF1F1F1F);

class SearchBarWidget extends StatelessWidget {
  const SearchBarWidget({super.key});
  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search items',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class FavoriteItemCard extends StatelessWidget {
  final Item item;
  const FavoriteItemCard({super.key, required this.item});
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                item.imageUrl,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    item.title,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Favorite',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  BorrowRequestScreen.routeName,
                  arguments: item,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              child: Text(
                'Rent Again',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.white),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<Set<String>>(
              valueListenable: FavoritesRepo.instance.favorites,
              builder: (context, favs, _) {
                final isFav = favs.contains(item.id);
                return IconButton(
                  onPressed: () => FavoritesRepo.instance.toggle(
                    item.id,
                    item.title,
                    context,
                  ),
                  icon: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    color: isFav ? primaryColor : Colors.grey,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ItemCard extends StatelessWidget {
  final Item item;
  const ItemCard({super.key, required this.item});

  Future<bool> _hasActiveBorrow() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('user_borrow_history') ?? [];

    for (final s in list) {
      try {
        final r = jsonDecode(s) as Map<String, dynamic>;
        final status = (r['status'] ?? '').toString();
        final returnedAt = r['returnedAt'];

        // Check if there's an approved item that hasn't been returned
        if (status == 'Approved' && returnedAt == null) {
          return true;
        }
      } catch (_) {
        continue;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.asset(
                      item.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Center(child: Icon(Icons.broken_image)),
                    ),
                  ),
                  // 🔴 Green = available, Red = unavailable
                  // 🟡 Yellow = borrowed
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      width: 12,
                      height: 20,
                      decoration: BoxDecoration(
                        color: item.isDisabled
                            ? Colors.red
                            : (item.isBorrowed ? Colors.amber : Colors.green),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),

                  // Favorite icon
                  Positioned(
                    top: 6,
                    right: 6,
                    child: ValueListenableBuilder<Set<String>>(
                      valueListenable: FavoritesRepo.instance.favorites,
                      builder: (context, favs, _) {
                        final isFav = favs.contains(item.id);
                        return CircleAvatar(
                          backgroundColor: Colors.white70,
                          child: IconButton(
                            icon: Icon(
                              isFav ? Icons.favorite : Icons.favorite_border,
                              color: isFav ? primaryColor : Colors.grey,
                            ),
                            onPressed: () => FavoritesRepo.instance.toggle(
                              item.id,
                              item.title,
                              context,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(item.title, style: GoogleFonts.poppins(fontSize: 14)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  if (item.isDisabled) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('This item is unavailable'),
                        backgroundColor: Colors.redAccent,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  } else if (item.isBorrowed) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('This item is currently borrowed'),
                        backgroundColor: Colors.amber,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  } else {
                    // Check if user has already borrowed an item
                    final hasActive = await _hasActiveBorrow();
                    if (hasActive) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'You have reached your limit of borrowing items for today (1/1)',
                          ),
                          backgroundColor: Colors.redAccent,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    } else {
                      Navigator.pushNamed(
                        context,
                        BorrowRequestScreen.routeName,
                        arguments: item,
                      );
                    }
                  }
                },
                child: Text('Rent', style: GoogleFonts.poppins()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BrowseScreen extends StatefulWidget {
  static const String routeName = '/browse';
  const BrowseScreen({super.key});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    FavoritesRepo.instance.loadFavorites();
    ItemsService.instance.loadDisabledFlags();
    ItemsService.instance.loadBorrowedFlags();

    // Fetch items from backend instead of using hardcoded data
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final success = await ItemsService.instance.fetchItemsFromBackend();

    setState(() {
      _isLoading = false;
      if (!success) {
        _errorMessage =
            'Could not load items from server. Please check your connection.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.grey[200],
            child: IconButton(
              icon: const Icon(Icons.person),
              onPressed: () {
                Navigator.pushNamed(context, '/user/profile');
              },
            ),
          ),
        ),
        title: Text(
          'Browse',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pushNamed(context, '/user/request');
            },
            child: Text(
              'Request',
              style: GoogleFonts.poppins(color: Colors.black),
            ),
          ),
          TextButton(
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(
                    'Logout',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  content: Text(
                    'Are you sure you want to logout from this device?',
                    style: GoogleFonts.poppins(),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Cancel', style: GoogleFonts.poppins()),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Logged out')),
                        );
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/',
                          (route) => false,
                        );
                      },
                      child: Text(
                        'Logout',
                        style: GoogleFonts.poppins(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },
            child: Text(
              'Logout',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox.shrink(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SizedBox(height: 20),

                    // Search field with refresh button
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              hintText: 'Search items',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onChanged: (query) {
                              setState(() {
                                _searchQuery = query.trim().toLowerCase();
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: primaryColor),
                          onPressed: _isLoading ? null : _loadItems,
                          tooltip: 'Refresh items',
                        ),
                      ],
                    ),

                    // Loading indicator
                    if (_isLoading)
                      const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Center(
                          child: CircularProgressIndicator(color: primaryColor),
                        ),
                      ),

                    // Error message
                    if (_errorMessage != null && !_isLoading)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Card(
                          color: Colors.red[50],
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: GoogleFonts.poppins(
                                      color: Colors.red[900],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Favorites Section
                    Text(
                      'Favorites:',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ValueListenableBuilder<Set<String>>(
                      valueListenable: FavoritesRepo.instance.favorites,
                      builder: (context, favs, _) {
                        final favItems = ItemsService.instance.items.value
                            .where((i) => favs.contains(i.id))
                            .toList();
                        if (favItems.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              'No favorites yet',
                              style: GoogleFonts.poppins(color: Colors.grey),
                            ),
                          );
                        }
                        return Column(
                          children: favItems
                              .map(
                                (it) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8.0),
                                  child: FavoriteItemCard(item: it),
                                ),
                              )
                              .toList(),
                        );
                      },
                    ),
                    const SizedBox(height: 30),

                    // Rent Section
                    Text(
                      'Rent:',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),

                    ValueListenableBuilder<List<Item>>(
                      valueListenable: ItemsService.instance.items,
                      builder: (context, items, _) {
                        final filtered = _searchQuery.isEmpty
                            ? items
                            : items
                                  .where(
                                    (item) => item.title.toLowerCase().contains(
                                      _searchQuery,
                                    ),
                                  )
                                  .toList();
                        if (filtered.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Text(
                                'No items available for rent',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16.0,
                                mainAxisSpacing: 16.0,
                                childAspectRatio: 0.75,
                              ),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            return ItemCard(item: filtered[index]);
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
