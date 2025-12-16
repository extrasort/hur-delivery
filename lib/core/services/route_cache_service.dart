import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Simple caching layer for Mapbox route geometry to avoid duplicate billing.
///
/// Routes are cached per order and pickup/dropoff coordinate pair so that if an
/// order moves to a different location we automatically invalidate the cache.
class RouteCacheService {
  RouteCacheService._();

  static const _cachePrefix = 'order_route_cache_';
  static const _cacheDuration = Duration(hours: 12);

  static final Map<String, List<List<double>>> _memoryCache = {};
  static SharedPreferences? _prefs;

  static Future<void> _ensurePrefsLoaded() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static String _buildKey({
    required String orderId,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
  }) {
    // Round to 5 decimal places (~1.1m precision) to keep cache keys stable.
    String round(double value) => value.toStringAsFixed(5);
    return '$_cachePrefix$orderId'
        '_${round(pickupLat)}_${round(pickupLng)}'
        '_${round(dropoffLat)}_${round(dropoffLng)}';
  }

  static Future<List<List<double>>?> getCachedRoute({
    required String orderId,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
  }) async {
    final key = _buildKey(
      orderId: orderId,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      dropoffLat: dropoffLat,
      dropoffLng: dropoffLng,
    );

    // First check the in-memory cache for warm lookups.
    final memoryHit = _memoryCache[key];
    if (memoryHit != null && memoryHit.isNotEmpty) {
      return memoryHit;
    }

    await _ensurePrefsLoaded();
    final raw = _prefs?.getString(key);
    if (raw == null) return null;

    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      final expiresAt = decoded['expiresAt'] as int?;
      if (expiresAt != null &&
          DateTime.now().millisecondsSinceEpoch > expiresAt) {
        await invalidate(
          orderId: orderId,
          pickupLat: pickupLat,
          pickupLng: pickupLng,
          dropoffLat: dropoffLat,
          dropoffLng: dropoffLng,
        );
        return null;
      }

      final data = decoded['coordinates'] as List?;
      if (data == null) return null;

      final coordinates = data
          .map<List<double>>((point) {
            final values = (point as List).cast<num>();
            return [values[0].toDouble(), values[1].toDouble()];
          })
          .where((pair) => pair.length == 2)
          .toList();

      if (coordinates.isNotEmpty) {
        _memoryCache[key] = coordinates;
      }

      return coordinates;
    } catch (_) {
      // If parsing fails, fall back to no cache.
      await invalidate(
        orderId: orderId,
        pickupLat: pickupLat,
        pickupLng: pickupLng,
        dropoffLat: dropoffLat,
        dropoffLng: dropoffLng,
      );
      return null;
    }
  }

  static Future<void> cacheRoute({
    required String orderId,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
    required List<List<double>> coordinates,
  }) async {
    if (coordinates.isEmpty) return;

    final key = _buildKey(
      orderId: orderId,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      dropoffLat: dropoffLat,
      dropoffLng: dropoffLng,
    );

    _memoryCache[key] = coordinates;

    await _ensurePrefsLoaded();
    final payload = json.encode({
      'coordinates': coordinates,
      'expiresAt': DateTime.now().add(_cacheDuration).millisecondsSinceEpoch,
    });
    await _prefs?.setString(key, payload);
  }

  static Future<void> invalidate({
    required String orderId,
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
  }) async {
    final key = _buildKey(
      orderId: orderId,
      pickupLat: pickupLat,
      pickupLng: pickupLng,
      dropoffLat: dropoffLat,
      dropoffLng: dropoffLng,
    );
    _memoryCache.remove(key);
    await _ensurePrefsLoaded();
    await _prefs?.remove(key);
  }
}
