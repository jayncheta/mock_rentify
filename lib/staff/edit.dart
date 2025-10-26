import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../browse.dart' show primaryColor, Item;
import 'add.dart' show AddItemsScreen;
import 'disable.dart' show DisableItemsScreen;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/items_service.dart' show ItemsService;

// --- Colors ---
final Color tabInactiveColor = Colors.grey[700]!;
const Color searchBarColor = Color(0xFFF0F0F0);
const Color textInputBgColor = Color(0xFFFBE7D7);
const Color buttonSaveColor = Color(0xFF4CAF50);
const Color buttonCancelColor = Color(0xFFD9D9D9);
const Color changePhotoButtonColor = Color(0xFFFBE7D7);
final Color changePhotoTextColor = Colors.deepOrange.shade700;

class EditItemsScreen extends StatefulWidget {
  const EditItemsScreen({super.key});
  static const String routeName = '/staff/edit';

  @override
  State<EditItemsScreen> createState() => _EditItemsScreenState();
}

class _EditItemsScreenState extends State<EditItemsScreen> {
  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String? _selectedCategory;
  final List<String> _categories = [
    "Electronics",
    "Furniture",
    "Tools",
    "Other",
  ];

  Item? _editingItem;
  List<Item> _filteredItems = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _filteredItems = ItemsService.instance.getItems();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredItems = ItemsService.instance.getItems().where((item) {
        return item.title.toLowerCase().contains(query) ||
            item.id.toLowerCase().contains(query);
      }).toList();
    });
  }

  void _startEditing(Item item) {
    setState(() {
      _editingItem = item;
      _nameController.text = item.title;
      _idController.text = item.id;
      _descriptionController.text = item.description;
      _selectedCategory = item.category;
      _imageFile = null;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _imageFile = pickedFile;
        });
      }
    } catch (e) {
      debugPrint("Image picking failed: $e");
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    _descriptionController.dispose();
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
              leading: Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: Colors.grey[200],
                  child: IconButton(
                    icon: const Icon(Icons.person),
                    onPressed: () {},
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('History tapped')),
                    );
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
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.black),
            ),
            // 👇 New Tab Navigation Bar (Add | Edit | Disable)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8),
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
                  buildTab("Edit", true, () {}),
                  buildTab("Disable", false, () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      DisableItemsScreen.routeName,
                      (route) => false,
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Search bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search by Item ID or Name",
                hintStyle: GoogleFonts.poppins(
                  color: Colors.black.withOpacity(0.5),
                ),
                prefixIcon: const Icon(Icons.search, color: Colors.black54),
                filled: true,
                fillColor: searchBarColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // List of items
            Expanded(
              child: _editingItem == null
                  ? ValueListenableBuilder<List<Item>>(
                      valueListenable: ItemsService.instance.items,
                      builder: (context, items, _) {
                        final displayItems = _searchController.text.isEmpty
                            ? items
                            : _filteredItems;
                        if (displayItems.isEmpty) {
                          return Center(
                            child: Text(
                              'No items found',
                              style: GoogleFonts.poppins(),
                            ),
                          );
                        }
                        return ListView.builder(
                          itemCount: displayItems.length,
                          itemBuilder: (context, index) {
                            final item = displayItems[index];
                            return ListTile(
                              leading: item.imageUrl.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.asset(
                                        item.imageUrl,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) =>
                                            const Icon(
                                              Icons.broken_image,
                                              size: 48,
                                            ),
                                      ),
                                    )
                                  : const Icon(Icons.image, size: 48),
                              title: Text(
                                item.title,
                                style: GoogleFonts.poppins(),
                              ),
                              subtitle: Text(
                                'ID: ${item.id}',
                                style: GoogleFonts.poppins(fontSize: 12),
                              ),
                              trailing: item.isDisabled
                                  ? Chip(
                                      label: Text(
                                        'Disabled',
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      backgroundColor: Colors.red,
                                      materialTapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 0,
                                      ),
                                    )
                                  : null,
                              onTap: () => _startEditing(item),
                            );
                          },
                        );
                      },
                    )
                  : SingleChildScrollView(child: buildEditItemForm()),
            ),
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

  // --- Form and button widgets remain unchanged ---
  Widget buildEditItemForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildLabel("Item name:"),
        buildTextField(_nameController),
        const SizedBox(height: 16),
        buildLabel("Item ID):"),
        buildTextField(_idController, enabled: false),
        const SizedBox(height: 16),
        buildLabel("Item Description:"),
        buildTextField(_descriptionController, maxLines: 5),
        const SizedBox(height: 16),
        buildLabel("Category:"),
        buildCategoryDropdown(),
        const SizedBox(height: 16),
        buildLabel("Upload Image"),
        buildImageUploadSection(),
        const SizedBox(height: 32),
        buildActionButtons(),
      ],
    );
  }

  Widget buildLabel(String label) {
    return Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w500));
  }

  Widget buildTextField(
    TextEditingController controller, {
    bool enabled = true,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      decoration: InputDecoration(
        filled: true,
        fillColor: textInputBgColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
    );
  }

  Widget buildCategoryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: textInputBgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCategory,
          isExpanded: true,
          hint: Text(
            "Select Category",
            style: GoogleFonts.poppins(color: Colors.black54),
          ),
          items: _categories.map((e) {
            return DropdownMenuItem<String>(
              value: e,
              child: Text(e, style: GoogleFonts.poppins()),
            );
          }).toList(),
          onChanged: (value) => setState(() => _selectedCategory = value),
        ),
      ),
    );
  }

  Widget buildImageUploadSection() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: textInputBgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _imageFile != null
                ? (kIsWeb
                      ? Image.network(_imageFile!.path, fit: BoxFit.cover)
                      : Image.file(File(_imageFile!.path), fit: BoxFit.cover))
                : (_editingItem != null && _editingItem!.imageUrl.isNotEmpty
                      ? Image.asset(
                          _editingItem!.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.broken_image, size: 48),
                        )
                      : Image.network(
                          "https://placehold.co/400x400/333333/FFFFFF?text=Laptop",
                          fit: BoxFit.cover,
                        )),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: () => _showImagePickerOptions(),
          icon: Icon(Icons.upload, size: 20, color: changePhotoTextColor),
          label: Text(
            "Change photo",
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: changePhotoTextColor,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: changePhotoButtonColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text('Photo Library', style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text('Camera', style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              // Return to the in-screen edit list instead of navigating away
              setState(() {
                _editingItem = null;
                _imageFile = null;
                _nameController.clear();
                _idController.clear();
                _descriptionController.clear();
                _selectedCategory = null;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.grey, width: 1.5),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              "Cancel",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(
                    'Confirm changes',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                  ),
                  content: Text(
                    'Are you sure you want to save these changes?',
                    style: GoogleFonts.poppins(),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Cancel', style: GoogleFonts.poppins()),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        await _saveChanges();
                      },
                      child: Text('Confirm', style: GoogleFonts.poppins()),
                    ),
                  ],
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: buttonSaveColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              "Save",
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _saveChanges() async {
    try {
      if (_editingItem == null) return;
      final updatedItem = _editingItem!.copyWith(
        title: _nameController.text.trim(),
        category: _selectedCategory!,
        description: _descriptionController.text.trim(),
      );
      await ItemsService.instance.updateItem(updatedItem);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item updated successfully')),
        );
        // Return to the edit list view instead of navigating away
        setState(() {
          _editingItem = null;
          _imageFile = null;
          _nameController.clear();
          _idController.clear();
          _descriptionController.clear();
          _selectedCategory = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating item: $e')));
      }
    }
  }
}
