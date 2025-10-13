

/// Function signature for custom equality comparisons.
typedef EqualityFunction<T> = bool Function(T a, T b);

/// Function signature for custom hash code generation.
typedef HashFunction<T> = int Function(T value);

/// A comprehensive equality checker that supports deep comparison
/// with caching mechanisms for performance optimization.
class EqualityChecker<T> {
  final EqualityFunction<T>? _customEquals;
  final HashFunction<T>? _customHashCode;
  final Map<String, bool> _equalityCache = {};
  final int _maxCacheSize;
  final bool _enableCaching;

  /// Creates an equality checker with optional custom equality and hash functions.
  /// 
  /// [customEquals] - Custom equality function for user-defined types
  /// [customHashCode] - Custom hash function for caching optimization
  /// [maxCacheSize] - Maximum number of cached equality results (default: 1000)
  /// [enableCaching] - Whether to enable caching for expensive comparisons (default: true)
  EqualityChecker({
    EqualityFunction<T>? customEquals,
    HashFunction<T>? customHashCode,
    int maxCacheSize = 1000,
    bool enableCaching = true,
  }) : _customEquals = customEquals,
       _customHashCode = customHashCode,
       _maxCacheSize = maxCacheSize,
       _enableCaching = enableCaching;

  /// Checks if two values are equal using deep comparison.
  /// 
  /// Uses caching for expensive comparisons when enabled.
  /// Falls back to custom equality function if provided, otherwise uses deep equality.
  bool equals(T a, T b) {
    // Quick reference check
    if (identical(a, b)) return true;
    
    // Handle null cases
    if (a == null || b == null) return a == b;

    // Use caching for expensive comparisons
    if (_enableCaching && _shouldCache(a, b)) {
      final cacheKey = _generateCacheKey(a, b);
      final cachedResult = _equalityCache[cacheKey];
      if (cachedResult != null) {
        return cachedResult;
      }
      
      final result = _performEquality(a, b);
      _cacheResult(cacheKey, result);
      return result;
    }

    return _performEquality(a, b);
  }

  /// Performs the actual equality comparison.
  bool _performEquality(T a, T b) {
    // Use custom equality function if provided
    if (_customEquals != null) {
      return _customEquals(a, b);
    }

    // Use deep equality for complex types
    return _deepEquals(a, b);
  }

  /// Performs deep equality comparison for complex objects.
  bool _deepEquals(dynamic a, dynamic b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return a == b;
    if (a.runtimeType != b.runtimeType) return false;

    // Handle primitive types
    if (_isPrimitive(a)) {
      return a == b;
    }

    // Handle collections
    if (a is List && b is List) {
      return _listEquals(a, b);
    }
    if (a is Set && b is Set) {
      return _setEquals(a, b);
    }
    if (a is Map && b is Map) {
      return _mapEquals(a, b);
    }

    // Handle Iterable (covers most collection types)
    if (a is Iterable && b is Iterable) {
      return _iterableEquals(a, b);
    }

    // For custom objects, fall back to == operator
    return a == b;
  }

  /// Checks if a value is a primitive type.
  bool _isPrimitive(dynamic value) {
    return value is num || 
           value is String || 
           value is bool || 
           value is DateTime ||
           value is Duration ||
           value is RegExp;
  }

  /// Compares two lists for deep equality.
  bool _listEquals(List a, List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) return false;
    }
    return true;
  }

  /// Compares two sets for deep equality.
  bool _setEquals(Set a, Set b) {
    if (a.length != b.length) return false;
    for (final element in a) {
      bool found = false;
      for (final otherElement in b) {
        if (_deepEquals(element, otherElement)) {
          found = true;
          break;
        }
      }
      if (!found) return false;
    }
    return true;
  }

  /// Compares two maps for deep equality.
  bool _mapEquals(Map a, Map b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (!_deepEquals(a[key], b[key])) return false;
    }
    return true;
  }

  /// Compares two iterables for deep equality.
  bool _iterableEquals(Iterable a, Iterable b) {
    final iteratorA = a.iterator;
    final iteratorB = b.iterator;
    
    while (true) {
      final hasNextA = iteratorA.moveNext();
      final hasNextB = iteratorB.moveNext();
      
      if (hasNextA != hasNextB) return false;
      if (!hasNextA) return true; // Both iterators are exhausted
      
      if (!_deepEquals(iteratorA.current, iteratorB.current)) return false;
    }
  }

  /// Determines if the comparison should be cached based on complexity.
  bool _shouldCache(T a, T b) {
    return _isComplexType(a) || _isComplexType(b);
  }

  /// Checks if a type is complex enough to benefit from caching.
  bool _isComplexType(T value) {
    if (value == null) return false;
    
    return value is List ||
           value is Set ||
           value is Map ||
           (value is Iterable && value.length > 10) ||
           (!_isPrimitive(value) && value.toString().length > 100);
  }

  /// Generates a cache key for the given values.
  String _generateCacheKey(T a, T b) {
    final hashA = _customHashCode?.call(a) ?? a.hashCode;
    final hashB = _customHashCode?.call(b) ?? b.hashCode;
    return '${hashA}_${hashB}';
  }

  /// Caches the equality result with LRU eviction.
  void _cacheResult(String key, bool result) {
    if (_equalityCache.length >= _maxCacheSize) {
      // Simple LRU: remove the first entry
      final firstKey = _equalityCache.keys.first;
      _equalityCache.remove(firstKey);
    }
    _equalityCache[key] = result;
  }

  /// Clears the equality cache.
  void clearCache() {
    _equalityCache.clear();
  }

  /// Gets the current cache size.
  int get cacheSize => _equalityCache.length;

  /// Gets cache statistics for debugging.
  Map<String, dynamic> getCacheStats() {
    return {
      'cacheSize': _equalityCache.length,
      'maxCacheSize': _maxCacheSize,
      'cachingEnabled': _enableCaching,
      'hasCustomEquals': _customEquals != null,
      'hasCustomHashCode': _customHashCode != null,
    };
  }
}

/// Default equality checker instance for general use.
final defaultEqualityChecker = EqualityChecker<dynamic>();

/// Creates a specialized equality checker for a specific type.
EqualityChecker<T> createEqualityChecker<T>({
  EqualityFunction<T>? customEquals,
  HashFunction<T>? customHashCode,
  int maxCacheSize = 1000,
  bool enableCaching = true,
}) {
  return EqualityChecker<T>(
    customEquals: customEquals,
    customHashCode: customHashCode,
    maxCacheSize: maxCacheSize,
    enableCaching: enableCaching,
  );
}