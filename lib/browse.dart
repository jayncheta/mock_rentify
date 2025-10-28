import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/items_service.dart' show ItemsService;
import 'package:shared_preferences/shared_preferences.dart';
import 'user/borrow_request.dart';

class FavoritesRepo {
  FavoritesRepo._();
  static final FavoritesRepo instance = FavoritesRepo._();

  final ValueNotifier<Set<String>> favorites = ValueNotifier(<String>{});
  static const String _favoritesKey = 'user_favorites';

  Future<void> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? savedFavorites = prefs.getStringList(_favoritesKey);
    if (savedFavorites != null) {
      favorites.value = savedFavorites.toSet();
    }
  }

  Future<void> _saveFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_favoritesKey, favorites.value.toList());
  }

  bool isFavorite(String id) => favorites.value.contains(id);

  void toggle(String id) {
    final current = Set<String>.from(favorites.value);
    if (!current.add(id)) current.remove(id);
    favorites.value = current;
    _saveFavorites();
  }
}

class Item {
  final String id;
  final String title;
  final String imageUrl;
  final String statusColor;
  final String category;
  final String description;
  final bool isDisabled;
  final bool isBorrowed;

  const Item({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.statusColor,
    required this.category,
    this.description = '',
    this.isDisabled = false,
    this.isBorrowed = false,
  });

  Item copyWith({
    String? id,
    String? title,
    String? imageUrl,
    String? statusColor,
    String? category,
    String? description,
    bool? isDisabled,
    bool? isBorrowed,
  }) {
    return Item(
      id: id ?? this.id,
      title: title ?? this.title,
      imageUrl: imageUrl ?? this.imageUrl,
      statusColor: statusColor ?? this.statusColor,
      category: category ?? this.category,
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
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            item.imageUrl,
            width: 56,
            height: 56,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image),
          ),
        ),
        title: Text(item.title, style: GoogleFonts.poppins()),
        subtitle: Text('Favorite', style: GoogleFonts.poppins(fontSize: 12)),
        trailing: ValueListenableBuilder<Set<String>>(
          valueListenable: FavoritesRepo.instance.favorites,
          builder: (context, favs, _) {
            final isFav = favs.contains(item.id);
            return IconButton(
              onPressed: () => FavoritesRepo.instance.toggle(item.id),
              icon: Icon(
                isFav ? Icons.favorite : Icons.favorite_border,
                color: isFav ? primaryColor : Colors.grey,
              ),
            );
          },
        ),
      ),
    );
  }
}

class ItemCard extends StatelessWidget {
  final Item item;
  const ItemCard({super.key, required this.item});

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
                            onPressed: () =>
                                FavoritesRepo.instance.toggle(item.id),
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
                onPressed: () {
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
                    Navigator.pushNamed(
                      context,
                      BorrowRequestScreen.routeName,
                      arguments: item,
                    );
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
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    FavoritesRepo.instance.loadFavorites();
    ItemsService.instance.loadDisabledFlags();
    ItemsService.instance.loadBorrowedFlags();

    if (!_initialized && ItemsService.instance.items.value.isEmpty) {
      _initialized = true;
      final List<Item> initialItems = [
        Item(
          id: 'ipad1',
          title: 'ipad',
          imageUrl: 'assets/images/ipad.png',
          statusColor: 'Unvailable',
          category: 'Electronics',
          isDisabled: true,
        ),
        Item(
          id: 'ipad2',
          title: 'ipad',
          imageUrl: 'assets/images/ipad.png',
          statusColor: 'Available',
          category: 'Electronics',
        ),
        Item(
          id: 'macbook1',
          title: 'macbook',
          imageUrl: 'assets/images/macbook.png',
          statusColor: 'Available',
          category: 'Electronics',
        ),
        Item(
          id: 'macbook2',
          title: 'macbook',
          imageUrl: 'assets/images/macbook.png',
          statusColor: 'Available',
          category: 'Electronics',
        ),
        Item(
          id: 'windowslaptop1',
          title: 'windows laptop',
          imageUrl: 'assets/images/windows_laptop.png',
          statusColor: 'Available',
          category: 'Electronics',
        ),
        Item(
          id: 'windowslaptop2',
          title: 'windows laptop',
          imageUrl: 'assets/images/windows_laptop.png',
          statusColor: 'Available',
          category: 'Electronics',
        ),
        Item(
          id: 'windowslaptop3',
          title: 'windows laptop',
          imageUrl: 'assets/images/windows_laptop.png',
          statusColor: 'Available',
          category: 'Electronics',
        ),
        Item(
          id: 'microphone1',
          title: 'Microphone',
          imageUrl: 'assets/images/microphone.png',
          statusColor: 'Available',
          category: 'Electronics',
        ),
        Item(
          id: 'microphone2',
          title: 'Microphone',
          imageUrl: 'assets/images/microphone.png',
          statusColor: 'Available',
          category: 'Electronics',
        ),
        Item(
          id: 'microphone3',
          title: 'Microphone',
          imageUrl: 'assets/images/microphone.png',
          statusColor: 'Available',
          category: 'Electronics',
        ),
        Item(
          id: 'microphone4',
          title: 'Microphone',
          imageUrl: 'assets/images/microphone.png',
          statusColor: 'Available',
          category: 'Electronics',
        ),
        Item(
          id: 'microphone5',
          title: 'Microphone',
          imageUrl: 'assets/images/microphone.png',
          statusColor: 'Available',
          category: 'Electronics',
        ),
      ];
      ItemsService.instance.items.value = initialItems;
      // Apply any saved disabled flags to the seeded items
      ItemsService.instance.loadDisabledFlags();
      // Apply any saved borrowed flags to the seeded items
      ItemsService.instance.loadBorrowedFlags();
    }
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
              Navigator.pushNamed(context, '/user/history');
            },
            child: Text(
              'Request History',
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
                    TextField(
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
