import 'package:flutter/material.dart';
import '../browse.dart' show Item, primaryColor;
import '../services/user_service.dart';

class UserBorrowingScreen extends StatefulWidget {
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

  @override
  State<UserBorrowingScreen> createState() => _UserBorrowingScreenState();
}

class _UserBorrowingScreenState extends State<UserBorrowingScreen> {
  final UserBorrowService _borrowService = UserBorrowService();
  bool _isSubmitting = false;

  Future<void> _saveBorrowRequest() async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    final success = await _borrowService.createBorrowRequest(
      userId: 'current_user_id', // TODO: Get from auth service
      item: {
        'id': widget.item.id,
        'title': widget.item.title,
        'imageUrl': widget.item.imageUrl,
        'statusColor': widget.item.statusColor,
        'description': widget.item.description,
      },
      borrowerName: 'James', // TODO: Get from auth service
      borrowDate: widget.borrowDate,
      pickUpTime: widget.pickUpTime,
      returnDate: widget.returnDate,
      returnTime: widget.returnTime,
      reason: widget.reason,
    );

    setState(() => _isSubmitting = false);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Borrow request submitted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pushNamed(context, '/user/request');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to submit request. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Image.asset(widget.item.imageUrl, height: 180)),
                const SizedBox(height: 15),
                const Divider(thickness: 1.5, color: primaryColor),
                const SizedBox(height: 20),
                Text(
                  widget.item.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
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
                Text(
                  widget.reason,
                  style: const TextStyle(color: Colors.black87),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _saveBorrowRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          'Rent now',
                          style: TextStyle(color: Colors.white, fontSize: 18),
                        ),
                ),
              ],
            ),
          ),
          if (_isSubmitting)
            Container(
              color: Colors.black.withOpacity(0.1),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
