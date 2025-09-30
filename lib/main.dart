import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'models/point.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fake GPS Tester',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ApiTestPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ApiTestPage extends StatefulWidget {
  const ApiTestPage({super.key});

  @override
  State<ApiTestPage> createState() => _ApiTestPageState();
}

class _ApiTestPageState extends State<ApiTestPage> {
  final ApiService api = ApiService();
  String result = "Clique em um botão para testar";

  Future<void> testRoute() async {
    try {
      final points = await api.getRoute(-23.5632, -46.6543, -23.5678, -46.6430);
      setState(() {
        result = "Route: Recebidos ${points.length} pontos";
      });
    } catch (e) {
      setState(() => result = "Erro: $e");
    }
  }

  Future<void> testInterpolate() async {
    try {
      final route = await api.getRoute(-23.5632, -46.6543, -23.5678, -46.6430);
      final interpolated = await api.interpolate(route);
      setState(() {
        result = "Interpolate: ${interpolated.length} pontos interpolados";
      });
    } catch (e) {
      setState(() => result = "Erro: $e");
    }
  }

  Future<void> testSimulate() async {
    try {
      final route = await api.getRoute(-23.5632, -46.6543, -23.5678, -46.6430);
      final interpolated = await api.interpolate(route);
      final simulated = await api.simulate(interpolated, 60.0);
      setState(() {
        result = "Simulate: ${simulated["route"].length} pontos com tempo";
      });
    } catch (e) {
      setState(() => result = "Erro: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Fake GPS Backend Tester")),
      body: Center(child: Text(result, textAlign: TextAlign.center)),
      bottomNavigationBar: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton(onPressed: testRoute, child: const Text("Route")),
          ElevatedButton(onPressed: testInterpolate, child: const Text("Interpolate")),
          ElevatedButton(onPressed: testSimulate, child: const Text("Simulate")),
        ],
      ),
    );
  }
}