import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/point.dart';

class ApiService {
  final String baseUrl = "http://72.60.61.215:8001/";

  Future<List<Point>> getRoute(double startLat, double startLon, double endLat, double endLon) async {
    final url = Uri.parse("$baseUrl/route?origin=$startLon,$startLat&destination=$endLon,$endLat");
    
    print("🚀 Chamando: $url");
    
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      List pts = data['points'];
      return pts.map((p) => Point.fromJson(p)).toList();
    } else {
      throw Exception("Erro ao buscar rota: ${response.statusCode} - ${response.body}");
    }
  }

  Future<List<Point>> interpolate(List<Point> route) async {
    final url = Uri.parse("$baseUrl/interpolate");
    
    print("🚀 Chamando: $url");
    
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"points": route.map((p) => p.toJson()).toList()}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      List pts = data['points'];
      return pts.map((p) => Point.fromJson(p)).toList();
    } else {
      throw Exception("Erro interpolando: ${response.statusCode} - ${response.body}");
    }
  }

  Future<Map<String, dynamic>> simulate(List<Point> points, double speedKmh) async {
    final url = Uri.parse("$baseUrl/simulate");
    
    print("🚀 Chamando: $url");
    
    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "points": points.map((p) => p.toJson()).toList(),
        "speed_kmh": speedKmh,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Erro simulando: ${response.statusCode} - ${response.body}");
    }
  }
}