import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

/// Service for all user borrow operations - Connected to backend
class UserBorrowService {
  static final UserBorrowService _instance = UserBorrowService._internal();
  factory UserBorrowService() => _instance;
  UserBorrowService._internal();

  // Backend API base URL - Your server IP address
  static const String _baseUrl = 'http://172.25.4.100:3000';

  /// Create a new borrow request
  /// Connects to: POST /borrow-request
  Future<bool> createBorrowRequest({
    required String userId,
    required Map<String, dynamic> item,
    required String borrowerName,
    required String borrowDate,
    required String pickUpTime,
    required String returnDate,
    required String returnTime,
    required String reason,
  }) async {
    try {
      final itemId = item['id']?.toString() ?? '';
      final lenderId = item['lenderId']?.toString() ?? '1'; // Default lender ID

      final response = await http.post(
        Uri.parse('$_baseUrl/borrow-request'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'item_id': itemId,
          'borrower_id': userId,
          'lender_id': lenderId,
          'borrower_reason': reason,
          'borrow_date': borrowDate,
          'pickup_time': pickUpTime,
          'return_date': returnDate,
          'return_time': returnTime,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('✅ Borrow request created: ${data['request_id']}');
        return true;
      } else {
        debugPrint('❌ Error creating borrow request: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error creating borrow request: $e');
      return false;
    }
  }

  /// Login user
  /// Connects to: POST /login
  Future<Map<String, dynamic>?> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body) as Map<String, dynamic>;

        // Store user info locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_user', jsonEncode(userData));

        debugPrint('✅ Login successful: ${userData['username']}');
        return userData;
      } else if (response.statusCode == 403) {
        debugPrint('❌ Invalid login credentials');
        return null;
      } else {
        debugPrint('❌ Login error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error during login: $e');
      return null;
    }
  }

  /// Get current logged-in user from local storage
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userStr = prefs.getString('current_user');
      if (userStr != null) {
        return jsonDecode(userStr) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting current user: $e');
      return null;
    }
  }

  /// Get user info by ID
  /// Connects to: GET /users/:id
  Future<Map<String, dynamic>?> getUserInfo(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/users/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body) as Map<String, dynamic>;
        debugPrint('✅ User info retrieved: ${userData['username']}');
        return userData;
      } else if (response.statusCode == 404) {
        debugPrint('❌ User not found');
        return null;
      } else {
        debugPrint('❌ Error getting user info: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error getting user info: $e');
      return null;
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_user');
      debugPrint('✅ User logged out');
    } catch (e) {
      debugPrint('❌ Error during logout: $e');
    }
  }

  /// Sign up new user
  /// Connects to: POST /signup
  Future<Map<String, dynamic>?> signup({
    required String username,
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/signup'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'email': email,
          'password': password,
          'full_name': fullName ?? username,
        }),
      );

      if (response.statusCode == 200) {
        final userData = jsonDecode(response.body) as Map<String, dynamic>;

        // Store user info locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('current_user', jsonEncode(userData));

        debugPrint('✅ Signup successful: ${userData['username']}');
        return userData;
      } else if (response.statusCode == 409) {
        debugPrint('❌ Username or email already exists');
        return null;
      } else if (response.statusCode == 400) {
        debugPrint('❌ Missing required fields');
        return null;
      } else {
        debugPrint('❌ Signup error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error during signup: $e');
      return null;
    }
  }

  /// Get all borrow requests for a user
  /// Query params: ?status=Pending|Approved|Rejected&includeReturned=true
  Future<List<Map<String, dynamic>>> getUserBorrowRequests({
    String? userId,
    String? status,
    bool includeReturned = true,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getStringList('user_borrow_history') ?? [];

      List<Map<String, dynamic>> requests = data
          .map((e) => jsonDecode(e) as Map<String, dynamic>)
          .toList();

      // Filter by status if provided
      if (status != null) {
        requests = requests
            .where((req) => req['status']?.toString() == status)
            .toList();
      }

      // Filter out returned items if specified
      if (!includeReturned) {
        requests = requests.where((req) {
          final returnedAt = req['returnedAt'];
          return returnedAt == null || returnedAt.toString().isEmpty;
        }).toList();
      }

      return requests;
    } catch (e) {
      debugPrint('❌ Error loading user borrow requests: $e');
      return [];
    }
  }

  /// Get user statistics
  /// Response: {
  ///   "currentlyRenting": 2,
  ///   "lateReturns": 1,
  ///   "onTimeReturns": 5,
  ///   "totalRentHistory": 6,
  ///   "hasActiveLate": false
  /// }
  Future<Map<String, int>> getUserStats({String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('user_borrow_history') ?? [];

      int currentlyRenting = 0;
      int lateReturns = 0;
      int onTimeReturns = 0;
      int rentHistory = 0;

      final df = DateFormat('dd/MM/yy');

      for (final s in list) {
        Map<String, dynamic> r;
        try {
          r = jsonDecode(s) as Map<String, dynamic>;
        } catch (_) {
          continue;
        }

        final itm = r['item'];
        if (itm is! Map<String, dynamic>) continue;

        final status = (r['status'] ?? '').toString();

        DateTime? plannedReturn;
        final plannedReturnStr = (r['returnDate'] ?? '').toString();
        if (plannedReturnStr.isNotEmpty) {
          try {
            plannedReturn = df.parse(plannedReturnStr);
          } catch (_) {}
        }

        DateTime? returnedAt;
        final returnedAtStr = (r['returnedAt'] ?? '').toString();
        if (returnedAtStr.isNotEmpty) {
          try {
            returnedAt = DateTime.parse(returnedAtStr);
          } catch (_) {}
        }

        final isFlaggedLate = (r['lateReturn'] ?? false) == true;

        if (returnedAt != null) {
          rentHistory += 1;

          final bool isLateByDate =
              plannedReturn != null && returnedAt.isAfter(plannedReturn);
          final bool explicitLate =
              (r['status']?.toString() == 'Late Return') || isFlaggedLate;

          if (isLateByDate || (plannedReturn == null && explicitLate)) {
            lateReturns += 1;
          } else {
            onTimeReturns += 1;
          }
        } else {
          if (status == 'Approved') {
            currentlyRenting += 1;
          }
        }
      }

      return {
        'currently': currentlyRenting,
        'late': lateReturns,
        'history': rentHistory,
        'ontime': onTimeReturns,
      };
    } catch (e) {
      debugPrint('❌ Error getting user stats: $e');
      return {'currently': 0, 'late': 0, 'history': 0, 'ontime': 0};
    }
  }

  /// Check if user has any active late returns
  Future<bool> hasActiveLateReturn({String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('user_borrow_history') ?? [];

      for (final s in list) {
        try {
          final r = jsonDecode(s) as Map<String, dynamic>;
          final status = (r['status'] ?? '').toString();
          final returnedAt = r['returnedAt'];
          final late = (r['lateReturn'] ?? false) == true;

          if (status == 'Approved' &&
              (returnedAt == null || returnedAt.toString().isEmpty) &&
              late) {
            return true;
          }
        } catch (_) {
          continue;
        }
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error checking active late returns: $e');
      return false;
    }
  }

  /// Cancel a pending borrow request
  /// or PATCH /api/borrow-requests/{requestId} with status: "Cancelled"
  Future<bool> cancelBorrowRequest({
    required String requestId,
    String? userId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getStringList('user_borrow_history') ?? [];
      final allRequests = data.map((e) => jsonDecode(e)).toList();

      // Find and remove the request
      final index = allRequests.indexWhere((req) => req['id'] == requestId);
      if (index == -1) {
        debugPrint('❌ Request not found: $requestId');
        return false;
      }

      // Only allow cancellation of pending requests
      if (allRequests[index]['status'] != 'Pending') {
        debugPrint('❌ Cannot cancel non-pending request');
        return false;
      }

      allRequests.removeAt(index);

      await prefs.setStringList(
        'user_borrow_history',
        allRequests.map((e) => jsonEncode(e)).toList(),
      );

      debugPrint('✅ Request cancelled: $requestId');
      return true;
    } catch (e) {
      debugPrint('❌ Error cancelling request: $e');
      return false;
    }
  }

  /// Get borrow history (completed rentals only)
  Future<List<Map<String, dynamic>>> getUserHistory({
    String? userId,
    String? searchQuery,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList('user_borrow_history') ?? [];
      final history = <Map<String, dynamic>>[];

      for (final s in list) {
        try {
          final rec = jsonDecode(s) as Map<String, dynamic>;
          final status = (rec['status'] ?? '').toString();

          // Include approved and returned items
          if (status == 'Approved' || (rec['returnedAt'] != null)) {
            // Apply search filter if provided
            if (searchQuery != null && searchQuery.isNotEmpty) {
              final item = rec['item'];
              if (item is Map<String, dynamic>) {
                final id = (item['id'] ?? '').toString().toLowerCase();
                final title = (item['title'] ?? '').toString().toLowerCase();
                final query = searchQuery.toLowerCase();

                if (id.contains(query) || title.contains(query)) {
                  history.add(rec);
                }
              }
            } else {
              history.add(rec);
            }
          }
        } catch (_) {
          continue;
        }
      }

      return history;
    } catch (e) {
      debugPrint('❌ Error loading user history: $e');
      return [];
    }
  }
}
