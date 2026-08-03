import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:movezy_driver_app/ApiUrls/api_urls.dart';

/// Road route between two points, for drawing on the maps.
///
/// Every map used to draw a straight line between pickup and drop, which
/// looked nothing like the trip the driver actually makes. This asks the
/// backend (which routes via OSRM and caches the result) for the real road
/// geometry.
///
/// Failure is never fatal: callers fall back to the straight line, so a
/// routing outage degrades the map rather than breaking the screen.
class RoutingService {
  /// Short-lived in-memory memo, so panning/rebuilding a map doesn't re-fetch.
  static final Map<String, List<LatLng>> _memo = {};

  static String _key(LatLng a, LatLng b) =>
      '${a.latitude.toStringAsFixed(4)},${a.longitude.toStringAsFixed(4)}'
      ':${b.latitude.toStringAsFixed(4)},${b.longitude.toStringAsFixed(4)}';

  /// Road polyline from [from] to [to]. Returns `[from, to]` (a straight line)
  /// when routing is unavailable, so the caller always has something to draw.
  static Future<List<LatLng>> route(LatLng from, LatLng to) async {
    final key = _key(from, to);
    final cached = _memo[key];
    if (cached != null) return cached;

    try {
      final uri = Uri.parse(
        '${ApiUrls.baseUrlApi}/routing/route'
        '?fromLat=${from.latitude}&fromLng=${from.longitude}'
        '&toLat=${to.latitude}&toLng=${to.longitude}',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final coords = body?['data']?['route']?['coordinates'];
        if (coords is List && coords.length >= 2) {
          final points = coords
              .whereType<List>()
              .map((c) => LatLng(
                    (c[0] as num).toDouble(),
                    (c[1] as num).toDouble(),
                  ))
              .toList();
          _memo[key] = points;
          return points;
        }
      }
    } catch (_) {
      // Fall through to the straight line below.
    }

    return [from, to];
  }
}
