import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a queued offline operation across any role
class OfflineAction {
  final String id;
  final String role; // 'salesman', 'store_admin', 'field_sales_manager', 'super_admin'
  final String type; // 'sale', 'stock_intake', 'stock_transfer', 'settlement_approval', 'stock_accept'
  final String endpoint; // e.g. '/sales', '/stock/intake', '/stock/transfer'
  final String method; // 'POST', 'PUT', 'DELETE'
  final Map<String, dynamic> payload;
  final String title;
  final String createdAt;
  String status; // 'pending_sync', 'syncing', 'failed'
  int retryCount;
  String? lastError;
  final String? userId;

  OfflineAction({
    required this.id,
    required this.role,
    required this.type,
    required this.endpoint,
    required this.method,
    required this.payload,
    required this.title,
    required this.createdAt,
    this.status = 'pending_sync',
    this.retryCount = 0,
    this.lastError,
    this.userId,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role,
    'type': type,
    'endpoint': endpoint,
    'method': method,
    'payload': payload,
    'title': title,
    'created_at': createdAt,
    'status': status,
    'retry_count': retryCount,
    'last_error': lastError,
    'user_id': userId,
  };

  factory OfflineAction.fromJson(Map<String, dynamic> json) => OfflineAction(
    id: json['id']?.toString() ?? '',
    role: json['role']?.toString() ?? 'salesman',
    type: json['type']?.toString() ?? 'sale',
    endpoint: json['endpoint']?.toString() ?? '',
    method: json['method']?.toString() ?? 'POST',
    payload: Map<String, dynamic>.from(json['payload'] as Map? ?? {}),
    title: json['title']?.toString() ?? 'Action',
    createdAt: json['created_at']?.toString() ?? DateTime.now().toIso8601String(),
    status: json['status']?.toString() ?? 'pending_sync',
    retryCount: (json['retry_count'] as num?)?.toInt() ?? 0,
    lastError: json['last_error']?.toString(),
    userId: json['user_id']?.toString(),
  );
}

/// Result summary of synchronizing queued actions
class SyncResult {
  final int total;
  final int synced;
  final int failed;
  final List<String> errors;

  const SyncResult({
    required this.total,
    required this.synced,
    required this.failed,
    this.errors = const [],
  });

  bool get isSuccess => failed == 0 && synced > 0;
  bool get hasPending => failed > 0;
}

/// Universal Offline Sync Engine for ALL Roles:
/// - Salesman: Field sales, stock acceptance, settlement QR
/// - Store Admin: Retail sales, distributor billing, stock intakes, FSM distribution
/// - Field Sales Manager (FSM): Stock transfers, settlement approvals, depot receipts
///
/// Ensures zero data loss for any operation across all mobile users.
class OfflineSyncService {
  static const String _keyUniversalQueue = 'erp_universal_offline_queue_v1';
  static const Duration _defaultTimeout = Duration(seconds: 20);
  static const Duration _largePayloadTimeout = Duration(seconds: 60);

  /// Determine timeout based on payload size (e.g. base64 image uploads require more time)
  static Duration _getTimeout(Map<String, dynamic> payload, int bodyLength) {
    if (payload['receipt_base64'] != null || bodyLength > 50000) {
      return _largePayloadTimeout;
    }
    return _defaultTimeout;
  }

  /// Global reactive notifier for pending queue count
  static final ValueNotifier<int> pendingCountNotifier = ValueNotifier<int>(0);

  static bool _isSyncing = false;
  static bool get isSyncing => _isSyncing;

  /// Initialize queue count on application launch
  static Future<void> init() async {
    try {
      final count = await getPendingCount();
      pendingCountNotifier.value = count;
    } catch (_) {}
  }

  /// Retrieve all pending actions from persistent disk storage
  static Future<List<OfflineAction>> getQueue({String? role, String? userId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyUniversalQueue);
      if (raw == null || raw.trim().isEmpty) return [];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];

      var list = decoded
          .map((e) => OfflineAction.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

      if (role != null && role.isNotEmpty) {
        list = list.where((a) => a.role == role).toList();
      }
      if (userId != null && userId.isNotEmpty) {
        list = list.where((a) => a.userId == userId).toList();
      }
      return list;
    } catch (e) {
      debugPrint('OfflineSyncService: Failed to read queue: $e');
      return [];
    }
  }

  /// Get pending action count
  static Future<int> getPendingCount({String? role, String? userId}) async {
    final queue = await getQueue(role: role, userId: userId);
    return queue.length;
  }

  /// Save an offline action to local disk
  static Future<OfflineAction> enqueueAction({
    required String role,
    required String type,
    required String endpoint,
    required String method,
    required Map<String, dynamic> payload,
    required String title,
    String? userId,
  }) async {
    final rand = Random().nextInt(90000) + 10000;
    final id = 'act_${DateTime.now().millisecondsSinceEpoch}_$rand';

    final action = OfflineAction(
      id: id,
      role: role,
      type: type,
      endpoint: endpoint,
      method: method,
      payload: payload,
      title: title,
      createdAt: DateTime.now().toIso8601String(),
      userId: userId,
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final currentQueue = await getQueue();
      currentQueue.add(action);

      await prefs.setString(
        _keyUniversalQueue,
        jsonEncode(currentQueue.map((a) => a.toJson()).toList()),
      );
      pendingCountNotifier.value = currentQueue.length;
    } catch (e) {
      debugPrint('OfflineSyncService: Error saving action locally: $e');
    }

    return action;
  }

  /// Remove an action after successful sync
  static Future<void> removeAction(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final currentQueue = await getQueue();
      currentQueue.removeWhere((a) => a.id == id);

      await prefs.setString(
        _keyUniversalQueue,
        jsonEncode(currentQueue.map((a) => a.toJson()).toList()),
      );
      pendingCountNotifier.value = currentQueue.length;
    } catch (e) {
      debugPrint('OfflineSyncService: Failed to remove action: $e');
    }
  }

  /// Execute an HTTP request with offline-first durability:
  /// Tries online execution first. If connection fails or times out,
  /// saves to persistent disk queue and returns offline fallback response.
  static Future<Map<String, dynamic>> executeWithOfflineFallback({
    required String apiBaseUrl,
    required String endpoint,
    required String method,
    required Map<String, dynamic> payload,
    required String role,
    required String type,
    required String title,
    String? userId,
  }) async {
    final url = Uri.parse('$apiBaseUrl$endpoint');
    final resolvedPayload = Map<String, dynamic>.from(payload);
    if (resolvedPayload['idempotency_key'] == null || resolvedPayload['idempotency_key'].toString().isEmpty) {
      resolvedPayload['idempotency_key'] = 'idem_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';
    }
    final jsonBody = jsonEncode(resolvedPayload);
    final timeout = _getTimeout(resolvedPayload, jsonBody.length);
    final headers = {
      'Content-Type': 'application/json',
      'x-idempotency-key': resolvedPayload['idempotency_key'].toString(),
    };

    try {
      http.Response res;
      if (method.toUpperCase() == 'POST') {
        res = await http
            .post(url, headers: headers, body: jsonBody)
            .timeout(timeout);
      } else if (method.toUpperCase() == 'PUT') {
        res = await http
            .put(url, headers: headers, body: jsonBody)
            .timeout(timeout);
      } else if (method.toUpperCase() == 'DELETE') {
        res = await http
            .delete(url, headers: headers, body: jsonBody)
            .timeout(timeout);
      } else {
        res = await http.get(url, headers: headers).timeout(timeout);
      }

      if (res.statusCode >= 200 && res.statusCode < 300) {
        dynamic data;
        try {
          data = jsonDecode(res.body);
        } catch (_) {
          data = {'message': 'Success'};
        }
        return {
          'success': true,
          'is_offline': false,
          'data': data,
        };
      } else {
        // Business logic error (e.g. 400 validation error)
        String errMsg = 'Request failed (HTTP ${res.statusCode})';
        try {
          final errBody = jsonDecode(res.body);
          if (errBody['error'] != null) errMsg = errBody['error'].toString();
        } catch (_) {}

        // If it's a 5xx server crash, queue offline for retry
        if (res.statusCode >= 500) {
          throw Exception(errMsg);
        }

        return {
          'success': false,
          'is_offline': false,
          'error': errMsg,
        };
      }
    } catch (e) {
      // Network disconnect, socket failure, or timeout -> Save to offline queue
      debugPrint('OfflineSyncService: Network unavailable ($e). Enqueuing action "$title" to disk.');
      final queuedAction = await enqueueAction(
        role: role,
        type: type,
        endpoint: endpoint,
        method: method,
        payload: resolvedPayload,
        title: title,
        userId: userId,
      );

      return {
        'success': true,
        'is_offline': true,
        'action_id': queuedAction.id,
        'message': 'Saved offline. Will sync automatically when network returns.',
        'data': {
          'id': queuedAction.id,
          'offline': true,
        },
      };
    }
  }

  /// Synchronize all pending actions across the network
  static Future<SyncResult> syncAll({
    required String apiBaseUrl,
    String? role,
    String? userId,
  }) async {
    if (_isSyncing) {
      return const SyncResult(total: 0, synced: 0, failed: 0, errors: ['Sync already in progress']);
    }

    _isSyncing = true;
    final queue = await getQueue(role: role, userId: userId);
    if (queue.isEmpty) {
      _isSyncing = false;
      pendingCountNotifier.value = 0;
      return const SyncResult(total: 0, synced: 0, failed: 0);
    }

    int syncedCount = 0;
    int failedCount = 0;
    final List<String> errors = [];

    for (final action in queue) {
      try {
        final url = Uri.parse('$apiBaseUrl${action.endpoint}');
        final payloadMap = Map<String, dynamic>.from(action.payload);
        final idempotencyKey = payloadMap['idempotency_key']?.toString() ?? action.id;
        final body = jsonEncode(payloadMap);
        final timeout = _getTimeout(payloadMap, body.length);
        final headers = {
          'Content-Type': 'application/json',
          'x-idempotency-key': idempotencyKey,
        };

        http.Response res;
        if (action.method.toUpperCase() == 'POST') {
          res = await http
              .post(url, headers: headers, body: body)
              .timeout(timeout);
        } else if (action.method.toUpperCase() == 'PUT') {
          res = await http
              .put(url, headers: headers, body: body)
              .timeout(timeout);
        } else if (action.method.toUpperCase() == 'DELETE') {
          res = await http
              .delete(url, headers: headers, body: body)
              .timeout(timeout);
        } else {
          res = await http.get(url, headers: headers).timeout(timeout);
        }

        if (res.statusCode >= 200 && res.statusCode < 300) {
          await removeAction(action.id);
          syncedCount++;
        } else {
          failedCount++;
          String err = 'HTTP ${res.statusCode}';
          try {
            final b = jsonDecode(res.body);
            if (b['error'] != null) err = b['error'].toString();
          } catch (_) {}
          errors.add(err);
        }
      } catch (err) {
        failedCount++;
        errors.add(err.toString());
      }
    }

    _isSyncing = false;
    final remainingCount = await getPendingCount(role: role, userId: userId);
    pendingCountNotifier.value = remainingCount;

    return SyncResult(
      total: queue.length,
      synced: syncedCount,
      failed: failedCount,
      errors: errors,
    );
  }
}
