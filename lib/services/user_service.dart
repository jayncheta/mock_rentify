import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

/// Backend-ready service for all user borrow operations
/// TODO: Replace SharedPreferences implementation with HTTP API calls
class UserBorrowService {
  static final UserBorrowService _instance = UserBorrowService._internal();
  factory UserBorrowService() => _instance;
  UserBorrowService._internal();

  // TODO: Replace with your backend API base URL
  // static const String _baseUrl = 'https://api.yourdomain.com';

  /// Create a new borrow request
  /// TODO: Replace with API call: POST /api/borrow-requests
  /// Body: {
  ///   "userId": "...",
  ///   "itemId": "...",
  ///   "borrowDate": "...",
  ///   "returnDate": "...",
  ///   "pickUpTime": "...",
  ///   "returnTime": "...",
  ///   "reason": "..."
  /// }
  /// Response: { "id": "...", "status": "Pending", "createdAt": "..." }
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
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getStringList('user_borrow_history') ?? [];

      final newRequest = {
        'id': DateTime.now().millisecondsSinceEpoch
            .toString(), // TODO: Backend will generate ID
        'userId': userId, // TODO: Get from auth service
        'item': item,
        'borrowerName': borrowerName,
        'borrowDate': borrowDate,
        'pickUpTime': pickUpTime,
        'returnDate': returnDate,
        'returnTime': returnTime,
        'reason': reason,
        'status': 'Pending',
        'createdAt': DateTime.now().toIso8601String(),
      };

      data.add(jsonEncode(newRequest));
      await prefs.setStringList('user_borrow_history', data);

      debugPrint('✅ Borrow request created: ${newRequest['id']}');
      return true;
    } catch (e) {
      debugPrint('❌ Error creating borrow request: $e');
      return false;
    }
  }

  /// Get all borrow requests for a user
  /// TODO: Replace with API call: GET /api/users/{userId}/borrow-requests
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
  /// TODO: Replace with API call: GET /api/users/{userId}/borrow-stats
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
  /// TODO: Replace with API call: GET /api/users/{userId}/has-active-late
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
  /// TODO: Replace with API call: DELETE /api/borrow-requests/{requestId}
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
  /// TODO: Replace with API call: GET /api/users/{userId}/borrow-history
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

  /// Update request status (for testing - normally done by lender/staff)
  /// TODO: This will be handled by backend, not client-side
  Future<bool> _updateRequestStatus({
    required String requestId,
    required String status,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getStringList('user_borrow_history') ?? [];
      final allRequests = data.map((e) => jsonDecode(e)).toList();

      final request = allRequests.firstWhere(
        (req) => req['id'] == requestId,
        orElse: () => <String, dynamic>{},
      );

      if (request.isEmpty) return false;

      request['status'] = status;
      if (additionalData != null) {
        request.addAll(additionalData);
      }

      await prefs.setStringList(
        'user_borrow_history',
        allRequests.map((e) => jsonEncode(e)).toList(),
      );

      return true;
    } catch (e) {
      debugPrint('❌ Error updating request status: $e');
      return false;
    }
  }

  /// Clear all local data (for testing/development)
  /// TODO: Remove in production or use for logout
  Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_borrow_history');
      debugPrint('✅ All borrow data cleared');
    } catch (e) {
      debugPrint('❌ Error clearing data: $e');
    }
  }
}
