import 'dart:async';

/// A simple in-memory cache with TTL (Time-To-Live) support.
/// This helps avoid redundant API calls when navigating between screens.
class CacheService {
  // Singleton instance
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  // Cache storage: key -> (data, expiryTime)
  final Map<String, ({dynamic data, DateTime expiry})> _cache = {};

  // Default TTL values (in seconds)
  static const int shortTTL = 30; // 30 seconds - for frequently changing data
  static const int mediumTTL = 120; // 2 minutes - for moderately changing data
  static const int longTTL =
      300; // 5 minutes - for rarely changing data (users, categories)

  /// Get cached data if available and not expired
  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;

    if (DateTime.now().isAfter(entry.expiry)) {
      // Cache expired, remove it
      _cache.remove(key);
      return null;
    }

    return entry.data as T?;
  }

  /// Store data in cache with TTL
  void set<T>(String key, T data, {int ttlSeconds = mediumTTL}) {
    _cache[key] = (
      data: data,
      expiry: DateTime.now().add(Duration(seconds: ttlSeconds)),
    );
  }

  /// Get data from cache or fetch it using the provided function
  Future<T> getOrFetch<T>(
    String key,
    Future<T> Function() fetchFunction, {
    int ttlSeconds = mediumTTL,
  }) async {
    // Try to get from cache first
    final cached = get<T>(key);
    if (cached != null) {
      return cached;
    }

    // Fetch fresh data
    final data = await fetchFunction();

    // Store in cache
    set(key, data, ttlSeconds: ttlSeconds);

    return data;
  }

  /// Invalidate a specific cache key
  void invalidate(String key) {
    _cache.remove(key);
  }

  /// Invalidate all cache entries matching a prefix
  void invalidatePrefix(String prefix) {
    _cache.removeWhere((key, _) => key.startsWith(prefix));
  }

  /// Clear all cached data
  void clearAll() {
    _cache.clear();
  }

  /// Get cache stats for debugging
  Map<String, dynamic> getStats() {
    int validCount = 0;
    int expiredCount = 0;
    final now = DateTime.now();

    for (final entry in _cache.entries) {
      if (now.isAfter(entry.value.expiry)) {
        expiredCount++;
      } else {
        validCount++;
      }
    }

    return {
      'totalEntries': _cache.length,
      'validEntries': validCount,
      'expiredEntries': expiredCount,
      'keys': _cache.keys.toList(),
    };
  }
}

/// Cache keys for type-safe access
class CacheKeys {
  // Long TTL - rarely changes
  static const String allUsers = 'users.all';
  static const String allCategories = 'categories.all';
  static const String allRooms = 'rooms.all';

  // Medium TTL - changes occasionally
  static const String allAssets = 'assets.all';
  static const String assetStatistics = 'assets.statistics';
  static const String maintenanceStats = 'assets.maintenanceStats';
  static const String inventoryStats = 'inventory.stats';

  // Short TTL - changes frequently
  static const String recentActivities = 'activities.recent';
  static const String allInventoryItems = 'inventory.all';
}
