import 'dart:async';

import 'package:compose_state/compose_state.dart';

enum CachePolicy {
  networkOnly,
  cacheAndNetwork,
  cacheElseNetwork,
  networkOrCache,
}

class ApiState<T> extends MutableState<UiState<T>>
    implements ObservableState<UiState<T>> {
  final Future<T> Function(int page, Map<String, dynamic> params) _apiCall;
  final StateErrorHandler _errorHandler;
  final CachePolicy _cachePolicy;
  final Duration _cacheDuration;
  final Map<String, dynamic> _apiCallParams;

  int _page = 1;
  bool _isFetching = false;

  static final Map<String, _CacheEntry> _cache = {};

  ApiState(
    this._apiCall, {
    StateErrorHandler? errorHandler,
    CachePolicy cachePolicy = CachePolicy.networkOnly,
    Duration cacheDuration = const Duration(minutes: 5),
    Map<String, dynamic> apiCallParams = const {},
  }) : _errorHandler = errorHandler ?? StateErrorHandler(),
       _cachePolicy = cachePolicy,
       _cacheDuration = cacheDuration,
       _apiCallParams = apiCallParams,
       super(UiState.loading());

  Future<void> fetch() async {
    if (_isFetching) return;
    _isFetching = true;

    final cacheKey = _generateCacheKey();

    if (_cachePolicy == CachePolicy.cacheElseNetwork ||
        _cachePolicy == CachePolicy.cacheAndNetwork) {
      final cachedData = _getCachedData(cacheKey);
      if (cachedData != null) {
        value = UiState.success(cachedData);
        if (_cachePolicy == CachePolicy.cacheElseNetwork) {
          _isFetching = false;
          return;
        }
      }
    }

    value = UiState.loading();

    try {
      final result = await _apiCall(_page, _apiCallParams);
      _updateCache(cacheKey, result);
      value = UiState.success(result);
    } catch (e, s) {
      final stateError = StateConsistencyException(
        'API call failed',
        cause: e,
        stackTrace: s,
        operation: 'api_fetch',
      );
      try {
        final recoveredResult = await _errorHandler.handleError(
          stateError,
          ErrorContext(
            stateKey: stateId,
            operation: 'api_fetch',
            valueType: T,
            metadata: {'page': _page},
          ),
          lastKnownValue: value.data,
        );
        _updateCache(cacheKey, recoveredResult);
        value = UiState.success(recoveredResult);
      } catch (recoveryError) {
        value = UiState.error(recoveryError.toString());
      }
    } finally {
      _isFetching = false;
    }
  }

  Future<void> refresh() async {
    _page = 1;
    await fetch();
  }

  String _generateCacheKey() {
    return '${_apiCall.hashCode}_$_apiCallParams';
  }

  T? _getCachedData(String key) {
    final entry = _cache[key];
    if (entry != null && !entry.isExpired) {
      return entry.data as T?;
    }
    _cache.remove(key);
    return null;
  }

  void _updateCache(String key, T data) {
    _cache[key] = _CacheEntry(data, DateTime.now().add(_cacheDuration));
  }
}

class _CacheEntry {
  final dynamic data;
  final DateTime expiry;

  _CacheEntry(this.data, this.expiry);

  bool get isExpired => DateTime.now().isAfter(expiry);
}

ApiState<T> apiStateOf<T>(
  Future<T> Function(int page, Map<String, dynamic> params) apiCall, {
  StateErrorHandler? errorHandler,
  CachePolicy cachePolicy = CachePolicy.networkOnly,
  Duration cacheDuration = const Duration(minutes: 5),
  Map<String, dynamic> apiCallParams = const {},
}) => ApiState<T>(
  apiCall,
  errorHandler: errorHandler,
  cachePolicy: cachePolicy,
  cacheDuration: cacheDuration,
  apiCallParams: apiCallParams,
);
