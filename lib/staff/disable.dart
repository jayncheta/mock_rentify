import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../browse.dart' show primaryColor, Item;
import 'add.dart' show AddItemsScreen;
import 'edit.dart' show EditItemsScreen;
import '../services/items_service.dart' show ItemsService;

// --- Colors ---
final Color tabInactiveColor = Colors.grey[700]!;
const Color searchBarColor = Color(0xFFF0F0F0);
const Color itemCardColor = Color(0xFFFBE7D7);
const Color buttonDisableColor = Color(0xFFE53935);
const Color buttonEnableColor = Color(0xFF4CAF50);
final Color buttonDisabledGrey = Colors.grey.shade400;
const Color statusAvailableColor = Color(0xFF4CAF50);
// Yellow for borrowed status
const Color statusBorrowedColor = Color(0xFFFFC107);

class DisableItemsScreen extends StatefulWidget {
  const DisableItemsScreen({super.key});
  static const String routeName = '/disable';

  @override
  State<DisableItemsScreen> createState() => _DisableItemsScreenState();
}

class _DisableItemsScreenState extends State<DisableItemsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Ensure flags are applied so status reflects real state
    ItemsService.instance.loadDisabledFlags();
    ItemsService.instance.loadBorrowedFlags();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(120),
        child: Column(
          children: [
            AppBar(
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
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
                ],
              ),
              title: const SizedBox.shrink(),
              centerTitle: false,
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/staff/return');
                  },
                  child: Text(
                    'Return',
                    style: GoogleFonts.poppins(color: Colors.black),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/staff/history');
                  },
                  child: Text(
                    'History',
                    style: GoogleFonts.poppins(color: Colors.black),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/staff/browse');
                  },
                  child: Text(
                    'Browse',
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
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
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
                  },
                  child: Text(
                    'Logout',
                    style: GoogleFonts.poppins(color: Colors.red),
                  ),
                ),
              ],
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.black),
            ),

            // 👇 Top navigation bar: Add | Edit | Disable
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  buildTab("Add", false, () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      AddItemsScreen.routeName,
                      (route) => false,
                    );
                  }),
                  buildTab("Edit", false, () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      EditItemsScreen.routeName,
                      (route) => false,
                    );
                  }),
                  buildTab("Disable", true, () {}),
                ],
              ),
            ),
          ],
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          children: [
            buildSearchBar(),
            const SizedBox(height: 24),
            buildItemsList(),
          ],
        ),
      ),
    );
  }

  Widget buildTab(String title, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? primaryColor : tabInactiveColor,
            ),
          ),
          const SizedBox(height: 4),
          if (isSelected) Container(height: 3, width: 60, color: primaryColor),
        ],
      ),
    );
  }

  Widget buildSearchBar() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: "Search by Item ID or Items Name",
        hintStyle: GoogleFonts.poppins(color: Colors.black.withOpacity(0.5)),
        prefixIcon: const Icon(Icons.search, color: Colors.black54),
        filled: true,
        fillColor: searchBarColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget buildItemsList() {
    return ValueListenableBuilder<List<Item>>(
      valueListenable: ItemsService.instance.items,
      builder: (context, items, _) {
        if (items.isEmpty) {
          return Center(
            child: Text(
              'No items found',
              style: GoogleFonts.poppins(fontSize: 16, color: Colors.black54),
            ),
          );
        }
        return Column(children: items.map(buildItemCard).toList());
      },
    );
  }

  Widget buildItemCard(Item item) {
    // Derive status from flags, not the legacy statusColor string
    final bool isAvailable = !item.isDisabled && !item.isBorrowed;
    final String statusText = item.isDisabled
        ? "Disabled"
        : (item.isBorrowed ? "Borrowed" : "Available");
    final Color statusColor = item.isDisabled
        ? Colors.red
        : (item.isBorrowed ? statusBorrowedColor : statusAvailableColor);
    final bool canDisable =
        isAvailable; // can disable only when fully available
    final bool canEnable = item.isDisabled;
    final String buttonText = item.isDisabled ? "Enable" : "Disable";
    final Color buttonColor = item.isDisabled
        ? buttonEnableColor
        : buttonDisableColor;
    final bool isButtonDisabled = !canDisable && !canEnable;
    final VoidCallback? onPressed = isButtonDisabled
        ? null
        : (canEnable
              ? () => _showEnableConfirmDialog(item)
              : () => _showDisableConfirmDialog(item));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: itemCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            item.title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Text(
                    "Status: ",
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                  Text(
                    statusText,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isButtonDisabled
                      ? buttonDisabledGrey
                      : buttonColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                ),
                child: Text(
                  buttonText,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDisableConfirmDialog(Item item) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Confirm Disabling Asset",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: RichText(
          text: TextSpan(
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
            children: [
              const TextSpan(text: "Are you sure you want to \ndisable \""),
              TextSpan(
                text: item.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: "\"?"),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.all(16),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              side: const BorderSide(color: Colors.grey),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text("Cancel", style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () async {
              await ItemsService.instance.toggleItemStatus(item.id);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonDisableColor,
              foregroundColor: Colors.white,
            ),
            child: Text("Confirm Disable", style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  void _showEnableConfirmDialog(Item item) {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Confirm Enabling Asset",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: RichText(
          text: TextSpan(
            style: GoogleFonts.poppins(fontSize: 16, color: Colors.black87),
            children: [
              const TextSpan(text: "Are you sure you want to \nenable \""),
              TextSpan(
                text: item.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: "\"?"),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.all(16),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              side: const BorderSide(color: Colors.grey),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text("Cancel", style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () async {
              await ItemsService.instance.toggleItemStatus(item.id);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonEnableColor,
              foregroundColor: Colors.white,
            ),
            child: Text("Confirm Enable", style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }
}
