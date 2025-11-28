import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/request.dart';

/// Service for Hive-based offline caching
class HiveCacheService {
  static const String _requestsBoxName = 'requests_cache';
  static const String _cacheTimestampKey = 'cache_timestamp';
  static const int _cacheExpirationDays = 30; // Clear cache for requests older than 30 days

  static Box? _requestsBox;

  /// Initialize Hive and open boxes
  static Future<void> init() async {
    try {
      await Hive.initFlutter();
      _requestsBox = await Hive.openBox(_requestsBoxName);
      debugPrint('✅ Hive cache initialized');
      
      // Clean old cache entries
      await _cleanOldCache();
    } catch (e) {
      debugPrint('❌ Error initializing Hive cache: $e');
    }
  }

  /// Clean cache entries older than 30 days
  static Future<void> _cleanOldCache() async {
    try {
      if (_requestsBox == null) return;

      final now = DateTime.now();
      final expirationDate = now.subtract(Duration(days: _cacheExpirationDays));
      
      final keysToDelete = <String>[];
      
      for (var key in _requestsBox!.keys) {
        if (key.toString().startsWith('request_')) {
          final requestData = _requestsBox!.get(key);
          if (requestData != null) {
            try {
              final requestMap = Map<String, dynamic>.from(requestData as Map);
              dynamic createdAtValue = requestMap['createdAt'];
              
              DateTime? requestDate;
              if (createdAtValue is String) {
                requestDate = DateTime.parse(createdAtValue);
              } else if (createdAtValue is Timestamp) {
                requestDate = createdAtValue.toDate();
              }
              
              if (requestDate != null && requestDate.isBefore(expirationDate)) {
                keysToDelete.add(key.toString());
              }
            } catch (e) {
              debugPrint('⚠️ Error parsing request date: $e');
            }
          }
        }
      }

      for (var key in keysToDelete) {
        await _requestsBox!.delete(key);
      }

      if (keysToDelete.isNotEmpty) {
        debugPrint('🗑️ Cleaned ${keysToDelete.length} old cache entries');
      }
    } catch (e) {
      debugPrint('❌ Error cleaning old cache: $e');
    }
  }

  /// Cache requests
  static Future<void> cacheRequests(List<Request> requests) async {
    try {
      if (_requestsBox == null) return;

      for (var request in requests) {
        final key = 'request_${request.requestId}';
        final requestMap = request.toFirestore();
        
        // Convert Timestamp to DateTime for Hive storage
        final cacheMap = Map<String, dynamic>.from(requestMap);
        if (cacheMap['createdAt'] != null && cacheMap['createdAt'] is Timestamp) {
          cacheMap['createdAt'] = (cacheMap['createdAt'] as Timestamp).toDate().toIso8601String();
        }
        if (cacheMap['deadline'] != null && cacheMap['deadline'] is Timestamp) {
          cacheMap['deadline'] = (cacheMap['deadline'] as Timestamp).toDate().toIso8601String();
        }
        
        await _requestsBox!.put(key, cacheMap);
      }

      // Update cache timestamp
      await _requestsBox!.put(_cacheTimestampKey, DateTime.now().toIso8601String());
      debugPrint('✅ Cached ${requests.length} requests');
    } catch (e) {
      debugPrint('❌ Error caching requests: $e');
    }
  }

  /// Get cached requests
  static List<Request>? getCachedRequests() {
    try {
      if (_requestsBox == null) return null;

      final requests = <Request>[];
      
      for (var key in _requestsBox!.keys) {
        if (key.toString().startsWith('request_')) {
          final requestData = _requestsBox!.get(key);
          if (requestData != null) {
            try {
              final requestMap = Map<String, dynamic>.from(requestData as Map);
              
              // Convert DateTime strings back to Timestamp for fromFirestoreLightweight
              final processedMap = Map<String, dynamic>.from(requestMap);
              if (processedMap['createdAt'] != null && processedMap['createdAt'] is String) {
                processedMap['createdAt'] = Timestamp.fromDate(DateTime.parse(processedMap['createdAt'] as String));
              }
              if (processedMap['deadline'] != null && processedMap['deadline'] is String) {
                processedMap['deadline'] = Timestamp.fromDate(DateTime.parse(processedMap['deadline'] as String));
              }
              
              // Create a fake DocumentSnapshot that works with fromFirestoreLightweight
              final fakeDoc = _FakeDocumentSnapshot(processedMap, key.toString().replaceFirst('request_', ''));
              final request = Request.fromFirestoreLightweight(fakeDoc);
              requests.add(request);
            } catch (e) {
              debugPrint('⚠️ Error parsing cached request: $e');
            }
          }
        }
      }

      // Sort by createdAt descending
      requests.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (requests.isNotEmpty) {
        debugPrint('✅ Retrieved ${requests.length} cached requests');
      }

      return requests;
    } catch (e) {
      debugPrint('❌ Error getting cached requests: $e');
      return null;
    }
  }

  /// Fake DocumentSnapshot for Hive cache
  static dynamic _FakeDocumentSnapshot(Map<String, dynamic> data, String id) {
    return _FakeDocumentSnapshotImpl(data, id);
  }

  /// Clear all cached requests
  static Future<void> clearCache() async {
    try {
      if (_requestsBox == null) return;

      await _requestsBox!.clear();
      debugPrint('✅ Cache cleared');
    } catch (e) {
      debugPrint('❌ Error clearing cache: $e');
    }
  }

  /// Get cache timestamp
  static DateTime? getCacheTimestamp() {
    try {
      if (_requestsBox == null) return null;

      final timestampString = _requestsBox!.get(_cacheTimestampKey) as String?;
      if (timestampString != null) {
        return DateTime.parse(timestampString);
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error getting cache timestamp: $e');
      return null;
    }
  }

  /// Check if cache is valid (less than 3 minutes old)
  static bool isCacheValid() {
    final timestamp = getCacheTimestamp();
    if (timestamp == null) return false;

    final age = DateTime.now().difference(timestamp);
    return age.inMinutes < 3; // Cache valid for 3 minutes
  }
}

/// Fake DocumentSnapshot implementation for Hive cache
class _FakeDocumentSnapshotImpl {
  final Map<String, dynamic> _data;
  final String _id;

  _FakeDocumentSnapshotImpl(this._data, this._id);

  String get id => _id;

  Map<String, dynamic> data() => _data;
  
  // Make it compatible with DocumentSnapshot
  dynamic operator [](String key) => _data[key];
  
  bool get exists => _data.isNotEmpty;
}

