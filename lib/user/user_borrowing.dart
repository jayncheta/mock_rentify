import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../browse.dart' show Item;

class UserBorrowingScreen extends StatelessWidget {
  static const String routeName = '/user/user-borrowing';

  final Item item;
  final String borrowDate;
  final String pickUpTime;
  final String returnDate;
  final String returnTime;
  final String reason;

  const UserBorrowingScreen({
    super.key,
    required this.item,
    required this.borrowDate,
    required this.pickUpTime,
    required this.returnDate,
    required this.returnTime,
    required this.reason,
  });

  Future<void> _saveBorrowRequest(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();

    // Retrieve existing history or initialize empty
    final data = prefs.getStringList('user_borrow_history') ?? [];

    // Create a new borrow request record
    final newRequest = {
      'item': {
        'id': item.id,
        'title': item.title,
        'imageUrl': item.imageUrl,
        'statusColor': item.statusColor,
        'category': item.category,
        'description': item.description,
      },
      'borrowerName': 'James', // TODO: make this dynamic later
      'borrowDate': borrowDate,
      'pickUpTime': pickUpTime,
      'returnDate': returnDate,
      'returnTime': returnTime,
      'reason': reason,
      'status': 'Pending', // Track approval status
      'createdAt': DateTime.now().toIso8601String(),
    };

    // Save it locally
    data.add(jsonEncode(newRequest));
    await prefs.setStringList('user_borrow_history', data);

    // Confirmation message
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Borrow request submitted!')));

    // Navigate to history page
    Navigator.pushNamed(context, '/user/request');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 10),
            child: Icon(Icons.favorite_border, color: Colors.black),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Image.asset(item.imageUrl, height: 180)),
            const SizedBox(height: 15),
            const Divider(thickness: 1.5, color: Colors.orangeAccent),
            const SizedBox(height: 20),
            Text(
              item.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text('Lender:', style: TextStyle(fontSize: 20)),
            const SizedBox(height: 1),
            Row(
              children: const [
                Icon(Icons.person, size: 36),
                SizedBox(width: 5),
                Text(
                  'Lender name',
                  style: TextStyle(color: Colors.black54, fontSize: 20),
                ),
                Spacer(),
                IconButton(
                  onPressed: null,
                  icon: Icon(
                    Icons.chat_bubble_outline,
                    size: 36,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Description:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
            const SizedBox(height: 10),
            Text(reason, style: const TextStyle(color: Colors.black87)),
            const Spacer(),
            ElevatedButton(
              onPressed: () => _saveBorrowRequest(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orangeAccent,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Rent now',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
