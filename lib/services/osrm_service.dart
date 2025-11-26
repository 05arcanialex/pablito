// services/osrm_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class OSRMService {
  static const String _baseUrl = 'https://router.project-osrm.org/route/v1';

  Future<OSRMRouteResponse?> getRoute(LatLng start, LatLng end) async {
    final url =
        '$_baseUrl/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?overview=full&geometries=geojson';

    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        return OSRMRouteResponse.fromJson(json.decode(response.body));
      } else {
        print('OSRM API error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error getting OSRM route: $e');
      return null;
    }
  }

  // Calcular ETA (Tiempo Estimado de Llegada)
  Future<Duration?> calculateETA(LatLng start, LatLng end) async {
    final route = await getRoute(start, end);
    if (route != null && route.routes.isNotEmpty) {
      return Duration(seconds: route.routes.first.duration.toInt());
    }
    return null;
  }

  // Calcular distancia
  Future<double?> calculateDistance(LatLng start, LatLng end) async {
    final route = await getRoute(start, end);
    if (route != null && route.routes.isNotEmpty) {
      return route.routes.first.distance;
    }
    return null;
  }
}

class OSRMRouteResponse {
  final String code;
  final List<OSRMRoute> routes;
  final List<OSRMWaypoint> waypoints;

  OSRMRouteResponse({
    required this.code,
    required this.routes,
    required this.waypoints,
  });

  factory OSRMRouteResponse.fromJson(Map<String, dynamic> json) {
    return OSRMRouteResponse(
      code: json['code'],
      routes: (json['routes'] as List)
          .map((route) => OSRMRoute.fromJson(route))
          .toList(),
      waypoints: (json['waypoints'] as List)
          .map((waypoint) => OSRMWaypoint.fromJson(waypoint))
          .toList(),
    );
  }
}

class OSRMRoute {
  final String geometry;
  final List<LatLng> geometryDecoded;
  final double distance;
  final double duration;
  final String weightName;
  final double weight;

  OSRMRoute({
    required this.geometry,
    required this.geometryDecoded,
    required this.distance,
    required this.duration,
    required this.weightName,
    required this.weight,
  });

  factory OSRMRoute.fromJson(Map<String, dynamic> json) {
    final geometry = json['geometry'] as String;
    final geometryDecoded = _decodePolyline(geometry);
    
    return OSRMRoute(
      geometry: geometry,
      geometryDecoded: geometryDecoded,
      distance: (json['distance'] as num).toDouble(),
      duration: (json['duration'] as num).toDouble(),
      weightName: json['weight_name'],
      weight: (json['weight'] as num).toDouble(),
    );
  }

  static List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }
}

class OSRMWaypoint {
  final String name;
  final LatLng location;
  final double distance;

  OSRMWaypoint({
    required this.name,
    required this.location,
    required this.distance,
  });

  factory OSRMWaypoint.fromJson(Map<String, dynamic> json) {
    final location = json['location'] as List;
    return OSRMWaypoint(
      name: json['name'],
      location: LatLng(
        (location[1] as num).toDouble(),
        (location[0] as num).toDouble(),
      ),
      distance: (json['distance'] as num).toDouble(),
    );
  }
}