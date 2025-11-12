import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../browse.dart' show primaryColor;
import '../services/items_service.dart' show ItemsService;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'disable.dart' show DisableItemsScreen;
import 'package:http/http.dart' as http;
import 'dart:convert';

// Additional colors from the image
const Color formFieldBackgroundColor = Color(0xFFFBE7D7);
const Color addButtonColor = Color(0xFF4CAF50);
final Color tabInactiveColor = Colors.grey[700]!;

class AddItemsScreen extends StatefulWidget {
  const AddItemsScreen({super.key});
  static const String routeName = '/staff/add';

  @override
  State<AddItemsScreen> createState() => _AddItemsScreenState();
}

class _AddItemsScreenState extends State<AddItemsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  XFile? _imageFile;
  final ImagePicker _picker = ImagePicker();
  int _nextItemId = 0;

  @override
  void initState() {
    super.initState();
    _fetchNextItemId();
  }

  Future<void> _fetchNextItemId() async {
    try {
      final response = await http.get(
        Uri.parse('http://10.2.8.21:3000/items?includeDisabled=true'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> items = jsonDecode(response.body);
        if (items.isNotEmpty) {
          final maxId = items
              .map((item) => item['item_id'] as int)
              .reduce((a, b) => a > b ? a : b);
          setState(() {
            _nextItemId = maxId + 1;
          });
        } else {
          setState(() {
            _nextItemId = 1;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching next item ID: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        setState(() {
          _imageFile = pickedFile;
        });
      }
    } catch (e) {
      debugPrint("Failed to pick image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to pick image. Error: $e")),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveItem() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an item name')),
      );
      return;
    }

    try {
      File? imageFile;
      String? assetImagePath;
      // Try to match asset image by name
      final normalized = name.toLowerCase().replaceAll(
        RegExp(r'[^a-z0-9]'),
        '',
      );
      final assetCandidates = [
        'assets/images/$normalized.png',
        'assets/images/$normalized.jpg',
        'assets/images/$normalized.jpeg',
      ];
      for (final path in assetCandidates) {
        // This check is not perfect in Flutter, but we can try to use AssetImage and catch errors in browse
        assetImagePath = path;
        break;
      }
      if (_imageFile != null) imageFile = File(_imageFile!.path);

      final description = _descriptionController.text.trim();

      await ItemsService.instance.addItem(
        title: name,
        description: description,
        imageFile: imageFile,
        assetImagePath: assetImagePath,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Item added successfully')),
        );

        // Clear form but stay on page
        _nameController.clear();
        _descriptionController.clear();
        setState(() {
          _imageFile = null;
          _nextItemId = _nextItemId + 1; // Increment for next item
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error adding item: $e')));
      }
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Select from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take with Camera'),
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

  Widget buildImagePreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: kIsWeb
          ? Image.network(
              _imageFile!.path,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            )
          : Image.file(
              File(_imageFile!.path),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
    );
  }

  Widget buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Item name:",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            hintText: "Items Name",
            hintStyle: GoogleFonts.poppins(
              color: Colors.black.withOpacity(0.5),
            ),
            filled: true,
            fillColor: formFieldBackgroundColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "Item ID:",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextField(
          enabled: false,
          controller: TextEditingController(
            text: _nextItemId > 0 ? _nextItemId.toString() : 'Loading...',
          ),
          decoration: InputDecoration(
            hintStyle: GoogleFonts.poppins(
              color: Colors.black.withOpacity(0.5),
            ),
            filled: true,
            fillColor: formFieldBackgroundColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "Description:",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionController,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: "Item Description",
            hintStyle: GoogleFonts.poppins(
              color: Colors.black.withOpacity(0.5),
            ),
            filled: true,
            fillColor: formFieldBackgroundColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "Upload Image",
          style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _showImagePickerOptions,
          child: Container(
            height: 150,
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: formFieldBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: primaryColor.withOpacity(0.7),
                width: 1.5,
              ),
            ),
            child: _imageFile == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.upload_file_outlined,
                        color: Colors.black54,
                        size: 36,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Upload Image",
                        style: GoogleFonts.poppins(
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  )
                : buildImagePreview(),
          ),
        ),
      ],
    );
  }

  Widget buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              if (Navigator.canPop(context)) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              side: const BorderSide(color: Colors.grey, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              "Cancel",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: _saveItem,
            style: ElevatedButton.styleFrom(
              backgroundColor: addButtonColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              "Add",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ],
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
          if (isSelected) Container(height: 3, width: 60, color: primaryColor),
        ],
      ),
    );
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
              backgroundColor: Colors.white,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.black),
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
                PopupMenuButton<String>(
                  icon: const Icon(Icons.menu, color: Colors.black),
                  onSelected: (value) {
                    switch (value) {
                      case 'staff':
                        // Already on staff screen
                        break;
                      case 'return':
                        Navigator.pushNamed(context, '/staff/return');
                        break;
                      case 'history':
                        Navigator.pushNamed(context, '/staff/history');
                        break;
                      case 'browse':
                        Navigator.pushNamed(context, '/staff/browse');
                        break;
                      case 'logout':
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
                                child: Text(
                                  'Cancel',
                                  style: GoogleFonts.poppins(),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Logged out')),
                                  );
                                  Navigator.pushNamedAndRemoveUntil(
                                    context,
                                    '/login',
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
              ],
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  buildTab("Add", true, () {}),
                  buildTab(
                    "Edit",
                    false,
                    () => Navigator.pushNamed(context, '/staff/edit'),
                  ),
                  buildTab(
                    "Disable",
                    false,
                    () => Navigator.pushNamed(
                      context,
                      DisableItemsScreen.routeName,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildForm(),
            const SizedBox(height: 24),
            buildActionButtons(),
          ],
        ),
      ),
    );
  }
}
