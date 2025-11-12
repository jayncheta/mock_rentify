import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../browse.dart' show Item;
import '../services/items_service.dart' show ItemsService;
import 'add.dart' show AddItemsScreen;

class StaffBrowseScreen extends StatefulWidget {
  static const String routeName = '/staff/browse';
  const StaffBrowseScreen({super.key});

  @override
  State<StaffBrowseScreen> createState() => _StaffBrowseScreenState();
}

class _StaffBrowseScreenState extends State<StaffBrowseScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Fetch items from backend database
    _loadItems();
  }

  Future<void> _loadItems() async {
    // Fetch items from backend
    await ItemsService.instance.fetchItemsFromBackend();
    // Load disabled and borrowed flags
    await ItemsService.instance.loadDisabledFlags();
    await ItemsService.instance.loadBorrowedFlags();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
                Navigator.pushNamed(context, '/staff/dashboard');
              },
            ),
          ),
        ),
        title: Text(
          'Browse Items (Staff View)',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.menu, color: Colors.black),
            onSelected: (value) {
              switch (value) {
                case 'staff':
                  Navigator.pushNamed(context, AddItemsScreen.routeName);
                  break;
                case 'return':
                  Navigator.pushNamed(context, '/staff/return');
                  break;
                case 'history':
                  Navigator.pushNamed(context, '/staff/history');
                  break;
                case 'browse':
                  // Already on browse screen
                  break;
                case 'logout':
                  showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(
                        'Logout',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      content: Text(
                        'Are you sure you want to logout?',
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
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'staff',
                child: Text('Staff', style: GoogleFonts.poppins()),
              ),
              PopupMenuItem<String>(
                value: 'return',
                child: Text('Return', style: GoogleFonts.poppins()),
              ),
              PopupMenuItem<String>(
                value: 'history',
                child: Text('History', style: GoogleFonts.poppins()),
              ),
              PopupMenuItem<String>(
                value: 'browse',
                child: Text('Browse', style: GoogleFonts.poppins()),
              ),
              PopupMenuItem<String>(
                value: 'logout',
                child: Text(
                  'Logout',
                  style: GoogleFonts.poppins(color: Colors.red),
                ),
              ),
            ],
          ),
          const SizedBox(width: 5),
        ],
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SizedBox(height: 20),
                    // Search Bar
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search items by name or ID',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      onChanged: (query) {
                        setState(() {
                          _searchQuery = query.trim().toLowerCase();
                        });
                      },
                    ),
                    const SizedBox(height: 24),

                    // Items Section
                    Text(
                      'All Items:',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
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
                                    (item) =>
                                        item.title.toLowerCase().contains(
                                          _searchQuery,
                                        ) ||
                                        item.id.toLowerCase().contains(
                                          _searchQuery,
                                        ),
                                  )
                                  .toList();

                        if (filtered.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Text(
                                _searchQuery.isEmpty
                                    ? 'No items available'
                                    : 'No items found matching "$_searchQuery"',
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
                            return StaffItemCard(item: filtered[index]);
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

class StaffItemCard extends StatelessWidget {
  final Item item;
  const StaffItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
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
                    child: Image.network(
                      item.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Center(child: Icon(Icons.broken_image)),
                    ),
                  ),
                  // Status label
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: item.isDisabled
                            ? Colors.red.withOpacity(0.9)
                            : (item.isBorrowed
                                  ? Colors.amber.withOpacity(0.9)
                                  : Colors.green.withOpacity(0.9)),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        item.isDisabled
                            ? 'Disabled'
                            : (item.isBorrowed ? 'Borrowed' : 'Available'),
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              item.title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              'ID: ${item.id}',
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }
}
