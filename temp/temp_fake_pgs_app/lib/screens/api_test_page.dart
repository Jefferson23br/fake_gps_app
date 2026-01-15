import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/point.dart';

class ApiTestPage extends StatefulWidget {
  const ApiTestPage({super.key});

  @override
  State<ApiTestPage> createState() => _ApiTestPageState();
}

class _ApiTestPageState extends State<ApiTestPage> {
  final ApiService api = ApiService();
  String result = "Clique em um botão para testar a API do backend";
  bool isLoading = false;

  Future<void> testRoute() async {
    setState(() {
      isLoading = true;
      result = "Buscando rota...";
    });

    try {

      final points = await api.getRoute(-23.5505, -46.6333, -23.6266, -46.6556);
      setState(() {
        result = "✅ Route: Recebidos ${points.length} pontos\n"
                "Primeiro ponto: ${points.first}\n"
                "Último ponto: ${points.last}";
      });
    } catch (e) {
      setState(() => result = "❌ Erro Route: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> testInterpolate() async {
    setState(() {
      isLoading = true;
      result = "Interpolando pontos...";
    });

    try {

      final route = await api.getRoute(-23.5505, -46.6333, -23.6266, -46.6556);
      

      final interpolated = await api.interpolate(route);
      
      setState(() {
        result = "✅ Interpolate: ${interpolated.length} pontos interpolados\n"
                "Rota original: ${route.length} pontos\n"
                "Após interpolação: ${interpolated.length} pontos";
      });
    } catch (e) {
      setState(() => result = "❌ Erro Interpolate: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> testSimulate() async {
    setState(() {
      isLoading = true;
      result = "Simulando movimento...";
    });

    try {

      final route = await api.getRoute(-23.5505, -46.6333, -23.6266, -46.6556);
      

      final interpolated = await api.interpolate(route);
      

      final simulated = await api.simulate(interpolated, 60.0);
      
      setState(() {
        result = "✅ Simulate: ${simulated["route"].length} pontos com tempo\n"
                "Velocidade: 60 km/h\n"
                "Duração total: ${simulated["total_duration_seconds"]}s\n"
                "Distância: ${simulated["total_distance_km"]} km";
      });
    } catch (e) {
      setState(() => result = "❌ Erro Simulate: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Fake GPS Backend Tester"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    result,
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            if (isLoading)
              const CircularProgressIndicator()
            else
              const SizedBox(height: 20),
            
            const SizedBox(height: 20),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: isLoading ? null : testRoute,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text("Route"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isLoading ? null : testInterpolate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text("Interpolate"),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isLoading ? null : testSimulate,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text("Simulate"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}