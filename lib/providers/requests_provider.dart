import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/request.dart';
import '../services/hive_cache_service.dart';

/// Provider for managing requests with caching and pagination
class RequestsNotifier extends StateNotifier<AsyncValue<List<Request>>> {
  static const int pageSize = 10;
  static const int cacheDurationMinutes = 3;
  
  List<Request> _cachedRequests = [];
  DateTime? _cacheTimestamp;
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  RequestsNotifier() : super(const AsyncValue.loading()) {
    _loadRequests();
  }

  /// Load initial requests
  Future<void> _loadRequests() async {
    try {
      state = const AsyncValue.loading();
      
      // Check in-memory cache first
      if (_cachedRequests.isNotEmpty && _cacheTimestamp != null) {
        final cacheAge = DateTime.now().difference(_cacheTimestamp!);
        if (cacheAge.inMinutes < cacheDurationMinutes) {
          debugPrint('✅ Using in-memory cached requests (${_cachedRequests.length} items)');
          state = AsyncValue.data(_cachedRequests);
          return;
        }
      }

      // Check Hive cache (offline support)
      if (HiveCacheService.isCacheValid()) {
        final hiveRequests = HiveCacheService.getCachedRequests();
        if (hiveRequests != null && hiveRequests.isNotEmpty) {
          debugPrint('✅ Using Hive cached requests (${hiveRequests.length} items)');
          _cachedRequests = hiveRequests.take(pageSize).toList();
          _cacheTimestamp = HiveCacheService.getCacheTimestamp() ?? DateTime.now();
          state = AsyncValue.data(_cachedRequests);
          
          // Try to load from Firestore in background (for fresh data)
          _loadFromFirestore();
          return;
        }
      }

      // Load from Firestore
      await _loadFromFirestore();
    } catch (e, st) {
      debugPrint('❌ Error loading requests: $e');
      
      // Try to use Hive cache as fallback
      final hiveRequests = HiveCacheService.getCachedRequests();
      if (hiveRequests != null && hiveRequests.isNotEmpty) {
        debugPrint('✅ Using Hive cache as fallback (${hiveRequests.length} items)');
        _cachedRequests = hiveRequests.take(pageSize).toList();
        _cacheTimestamp = HiveCacheService.getCacheTimestamp() ?? DateTime.now();
        state = AsyncValue.data(_cachedRequests);
      } else {
        state = AsyncValue.error(e, st);
      }
    }
  }

  /// Load requests from Firestore
  Future<void> _loadFromFirestore() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('requests')
        .where('isDeleted', isEqualTo: false)
        .orderBy('createdAt', descending: true)
        .limit(pageSize)
        .get();

    _cachedRequests = snapshot.docs
        .map((doc) => Request.fromFirestoreLightweight(doc))
        .toList();

    _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
    _hasMore = snapshot.docs.length == pageSize;
    _cacheTimestamp = DateTime.now();

    // Cache to Hive for offline support
    await HiveCacheService.cacheRequests(_cachedRequests);

    state = AsyncValue.data(_cachedRequests);
    debugPrint('✅ Loaded ${_cachedRequests.length} requests from Firestore');
  }

  /// Load more requests (pagination)
  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    try {
      _isLoadingMore = true;
      debugPrint('📄 Loading more requests...');

      final snapshot = await FirebaseFirestore.instance
          .collection('requests')
          .where('isDeleted', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(pageSize)
          .get();

      if (snapshot.docs.isEmpty) {
        _hasMore = false;
        _isLoadingMore = false;
        return;
      }

      final newRequests = snapshot.docs
          .map((doc) => Request.fromFirestoreLightweight(doc))
          .toList();

      _cachedRequests.addAll(newRequests);
      _lastDocument = snapshot.docs.last;
      _hasMore = snapshot.docs.length == pageSize;
      _cacheTimestamp = DateTime.now();

      state = AsyncValue.data(List.from(_cachedRequests));
      debugPrint('✅ Loaded ${newRequests.length} more requests (total: ${_cachedRequests.length})');
    } catch (e, st) {
      debugPrint('❌ Error loading more requests: $e');
      state = AsyncValue.error(e, st);
    } finally {
      _isLoadingMore = false;
    }
  }

  /// Refresh requests (clear cache and reload)
  Future<void> refresh() async {
    _cachedRequests.clear();
    _cacheTimestamp = null;
    _lastDocument = null;
    _hasMore = true;
    await _loadRequests();
  }

  /// Get cached requests
  List<Request> get cachedRequests => _cachedRequests;

  /// Check if has more requests
  bool get hasMore => _hasMore;

  /// Check if loading more
  bool get isLoadingMore => _isLoadingMore;
}

/// Provider for requests
final requestsProvider = StateNotifierProvider<RequestsNotifier, AsyncValue<List<Request>>>(
  (ref) => RequestsNotifier(),
);

