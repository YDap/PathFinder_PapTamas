import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'dart:convert';

class RouteData {
  final List<LatLng> polyline;
  final double distance; // in meters

  RouteData({required this.polyline, required this.distance});
}

class RoutingService {
  // Using OSRM (Open Source Routing Machine) public API
  static const String osrmBase =
      'https://router.project-osrm.org/route/v1/driving';

  /// Fetch route data from OSRM API between two locations
  /// Returns RouteData containing polyline and distance
  Future<RouteData> getRoute(LatLng start, LatLng end) async {
    try {
      final url =
          '$osrmBase/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?geometries=geojson&overview=full';

      final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 15),
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List;

        if (routes.isEmpty) {
          throw Exception('No route found');
        }

        final firstRoute = routes[0];
        final geometry = firstRoute['geometry'] as Map;
        final coordinates = geometry['coordinates'] as List;
        final distance = firstRoute['distance'] as double;

        final polyline = coordinates.map((coord) {
          return LatLng(coord[1] as double, coord[0] as double);
        }).toList();

        return RouteData(polyline: polyline, distance: distance);
      } else {
        throw Exception('Failed to fetch route: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Calculate distance between two points in meters
  static double calculateDistance(LatLng start, LatLng end) {
    const distance = Distance();
    return distance.as(LengthUnit.Meter, start, end);
  }

  /// Calculate total distance along a polyline in meters
  static double calculatePolylineDistance(List<LatLng> polyline) {
    if (polyline.length < 2) return 0.0;

    double totalDistance = 0.0;
    for (int i = 0; i < polyline.length - 1; i++) {
      totalDistance += calculateDistance(polyline[i], polyline[i + 1]);
    }
    return totalDistance;
  }

  /// Find the closest point on a polyline to a given location
  /// Returns the index of the closest segment and the remaining polyline
  static MapEntry<int, List<LatLng>> findClosestPointAndRemovePath(
    List<LatLng> polyline,
    LatLng userLocation,
  ) {
    if (polyline.length < 2) {
      return MapEntry(0, polyline);
    }

    const distance = Distance();
    double minDistance = double.infinity;
    int closestIndex = 0;

    for (int i = 0; i < polyline.length; i++) {
      final dist = distance.as(
        LengthUnit.Meter,
        userLocation,
        polyline[i],
      );

      if (dist < minDistance) {
        minDistance = dist;
        closestIndex = i;
      }
    }

    // Remove all points up to and including the closest point
    final remainingPolyline = polyline.sublist(closestIndex);

    return MapEntry(closestIndex, remainingPolyline);
  }
}
