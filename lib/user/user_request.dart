import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/user_service.dart';

class UserRequestPage extends StatefulWidget {
  static const String routeName = '/user/request';
  const UserRequestPage({super.key});

  @override
  State<UserRequestPage> createState() => _UserRequestPageState();
}

class _UserRequestPageState extends State<UserRequestPage> {
  final UserBorrowService _borrowService = UserBorrowService();
  List<Map<String, dynamic>> _borrowHistory = [];
  String _selectedTab = 'All';
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBorrowHistory();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadBorrowHistory();
  }

  Future<void> _loadBorrowHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Get current user's borrow requests
      final requests = await _borrowService.getUserBorrowRequests(
        includeReturned: false, // Only show active requests
      );

      if (mounted) {
        setState(() {
          _borrowHistory = requests;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load requests: $e';
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredHistory {
    // Apply tab filter first
    final List<Map<String, dynamic>> base = _selectedTab == 'All'
        ? _borrowHistory
        : _borrowHistory
              .where(
                (item) => (item['status'] ?? '').toString() == _selectedTab,
              )
              .toList();

    // Exclude items that are already returned (returnedAt set)
    // and include ALL item types (no Windows-only filter), so active MacBook shows.
    return base.where((entry) {
      final returnedAt = entry['returnedAt'];
      final isReturned = returnedAt != null && returnedAt.toString().isNotEmpty;
      return !isReturned;
    }).toList();
  }

  bool get _hasActiveLate {
    for (final entry in _borrowHistory) {
      try {
        final status = (entry['status'] ?? '').toString();
        final late = (entry['lateReturn'] ?? false) == true;
        final returnedAt = entry['returnedAt'];
        final isActive =
            status == 'Approved' &&
            (returnedAt == null || returnedAt.toString().isEmpty);
        if (isActive && late) return true;
      } catch (_) {
        // ignore malformed
      }
    }
    return false;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green;
      case 'Pending':
        return Colors.orange;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildTabButton(String title) {
    final isSelected = _selectedTab == title;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = title),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.orangeAccent : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        automaticallyImplyLeading: false,
        elevation: 0,
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
          'Requests',
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pushNamed(context, '/browse');
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

      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _borrowHistory.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: GoogleFonts.poppins(color: Colors.red[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadBorrowHistory,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tabs Row
        Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTabButton('All'),
              _buildTabButton('Pending'),
              _buildTabButton('Approved'),
              _buildTabButton('Rejected'),
            ],
          ),
        ),

        // Late Return banner
        if (_hasActiveLate)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE), // light red
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.redAccent.withOpacity(0.6)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You have a late item to return',
                      style: GoogleFonts.poppins(
                        color: Colors.red[900],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

        // Borrow List
        Expanded(
          child: _filteredHistory.isEmpty
              ? Center(
                  child: Text(
                    'No requests found',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: _filteredHistory.length,
                  itemBuilder: (context, index) {
                    final itemData = _filteredHistory[index];

                    // Handle both old format (with nested 'item') and new format (flat structure)
                    final String itemName =
                        itemData['item_name']?.toString() ??
                        itemData['item']?['title']?.toString() ??
                        'Unknown Item';
                    final String itemImage =
                        itemData['item_image']?.toString() ??
                        itemData['item']?['imageUrl']?.toString() ??
                        'assets/images/macbook.png';

                    final status = (itemData['status'] ?? 'Pending').toString();
                    final reason =
                        itemData['borrower_reason']?.toString() ??
                        itemData['reason']?.toString() ??
                        '';
                    final color = _statusColor(status);
                    final returnedAt = itemData['returnedAt'];
                    final late = (itemData['lateReturn'] ?? false) == true;
                    final isActive =
                        status == 'Approved' &&
                        (returnedAt == null || returnedAt.toString().isEmpty);
                    final String displayStatus = (isActive && late)
                        ? 'Late Return'
                        : status;
                    final Color displayColor = (isActive && late)
                        ? Colors.red
                        : color;

                    return Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                margin: const EdgeInsets.all(10),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.asset(
                                    itemImage,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.asset(
                                          'assets/images/macbook.png',
                                          width: 80,
                                          height: 80,
                                          fit: BoxFit.cover,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      itemName,
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Status: $status',
                                      style: GoogleFonts.poppins(fontSize: 13),
                                    ),
                                    if (reason.isNotEmpty)
                                      Text(
                                        'Reason: $reason',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.1),
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(16),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: displayColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      displayStatus,
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        color: displayColor,
                                      ),
                                    ),
                                  ],
                                ),
                                if (status == 'Approved')
                                  ElevatedButton(
                                    onPressed: () {
                                      final pickUpTime =
                                          (itemData['pickUpTime'] ?? '')
                                              .toString();
                                      showDialog<void>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text(
                                            'Pick-up Info',
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          content: Text(
                                            pickUpTime.isNotEmpty
                                                ? 'Pick-up time: $pickUpTime'
                                                : 'Pick-up time not set.',
                                            style: GoogleFonts.poppins(),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(context).pop(),
                                              child: Text(
                                                'Close',
                                                style: GoogleFonts.poppins(),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text('View Pick-up Info'),
                                  )
                                else if (status == 'Pending')
                                  ElevatedButton(
                                    onPressed: () async {
                                      // Show confirmation dialog
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: Text(
                                            'Cancel Request',
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          content: Text(
                                            'Are you sure you want to cancel this pending request?',
                                            style: GoogleFonts.poppins(),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(
                                                context,
                                              ).pop(false),
                                              child: Text(
                                                'No',
                                                style: GoogleFonts.poppins(),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () => Navigator.of(
                                                context,
                                              ).pop(true),
                                              child: Text(
                                                'Yes, Cancel',
                                                style: GoogleFonts.poppins(
                                                  color: Colors.red,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirmed == true) {
                                        // Get request ID
                                        final requestId = itemData['request_id']
                                            ?.toString();

                                        if (requestId == null) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Error: Request ID not found',
                                                  style: GoogleFonts.poppins(),
                                                ),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                          return;
                                        }

                                        // Call cancel method
                                        final success = await _borrowService
                                            .cancelBorrowRequest(
                                              requestId: requestId,
                                            );

                                        if (mounted) {
                                          if (success) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Request canceled successfully',
                                                  style: GoogleFonts.poppins(),
                                                ),
                                                backgroundColor: Colors.green,
                                              ),
                                            );
                                            // Reload the list
                                            _loadBorrowHistory();
                                          } else {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Failed to cancel request',
                                                  style: GoogleFonts.poppins(),
                                                ),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      'Cancel Request',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (status == 'Rejected')
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              child: Text(
                                'Rejected reason: $reason',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
