import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';
import '../models/point.dart';


const String kGoogleApiKey = 'AIzaSyBD_-wfbVZsoJMI5RVW823qQ8vizmS27Hs';


const String _placesAutocompleteUrl =
    'https://maps.googleapis.com/maps/api/place/autocomplete/json';
const String _placeDetailsUrl =
    'https://maps.googleapis.com/maps/api/place/details/json';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final ApiService api = ApiService();

  final Completer<GoogleMapController> _mapController = Completer();
  GoogleMapController? _controller;

 
  LatLng? _origin;
  LatLng? _destination;

  
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  Marker? _movingMarker;

 
  List<Point> _routePoints = [];
  List<Point> _interpolatedPoints = [];


  double _speedKmh = 30.0;
  bool _isLoading = false;

 
  static const LatLng _initialCenter = LatLng(-23.55052, -46.633308);
  static const CameraPosition _initialCamera = CameraPosition(
    target: _initialCenter,
    zoom: 12,
  );

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    _controller = controller;
    _mapController.complete(controller);
  }

  
  Future<List<_PlaceSuggestion>> _fetchAutocomplete(String input) async {
    if (input.trim().isEmpty) return [];
    final uri = Uri.parse(
      '$_placesAutocompleteUrl?input=${Uri.encodeQueryComponent(input)}&key=$kGoogleApiKey&language=pt-BR',
    );
    final resp = await http.get(uri);
    if (resp.statusCode != 200) return [];
    final data = jsonDecode(resp.body);
    if (data['status'] != 'OK') return [];
    final List preds = data['predictions'] ?? [];
    return preds
        .map((p) => _PlaceSuggestion(
              description: p['description'] ?? '',
              placeId: p['place_id'] ?? '',
            ))
        .toList();
  }

  Future<LatLng?> _fetchPlaceLatLng(String placeId) async {
    final uri = Uri.parse(
      '$_placeDetailsUrl?place_id=$placeId&key=$kGoogleApiKey&fields=geometry',
    );
    final resp = await http.get(uri);
    if (resp.statusCode != 200) return null;
    final data = jsonDecode(resp.body);
    if (data['status'] != 'OK') return null;
    final loc = data['result']?['geometry']?['location'];
    if (loc == null) return null;
    return LatLng(loc['lat'].toDouble(), loc['lng'].toDouble());
  }

  
  void _updateMarkers() {
    final markers = <Marker>{};
    if (_origin != null) {
      markers.add(Marker(
          markerId: const MarkerId('origin'),
          position: _origin!,
          infoWindow: const InfoWindow(title: 'Origem'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)));
    }
    if (_destination != null) {
      markers.add(Marker(
          markerId: const MarkerId('destination'),
          position: _destination!,
          infoWindow: const InfoWindow(title: 'Destino'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)));
    }
    if (_movingMarker != null) {
      markers.add(_movingMarker!);
    }
    setState(() => _markers
      ..clear()
      ..addAll(markers));
  }

  Future<void> _fetchRoute() async {
    if (_origin == null || _destination == null) {
      _showSnack('Selecione origem e destino.');
      return;
    }
    setState(() {
      _isLoading = true;
      _polylines.clear();
      _routePoints = [];
      _interpolatedPoints = [];
    });

    try {
      final route = await api.getRoute(
          _origin!.latitude, _origin!.longitude, _destination!.latitude, _destination!.longitude);
      setState(() => _routePoints = route);

      _drawPolyline('route', Colors.blue, 5,
          route.map((p) => LatLng(p.latitude, p.longitude)).toList());
    } catch (e) {
      _showSnack('Erro ao buscar rota: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _interpolateRoute() async {
    if (_routePoints.isEmpty) {
      _showSnack('Calcule a rota antes de interpolar.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final interpolated = await api.interpolate(_routePoints);
      setState(() => _interpolatedPoints = interpolated);
      _drawPolyline('interpolated', Colors.orange, 4,
          interpolated.map((p) => LatLng(p.latitude, p.longitude)).toList());
    } catch (e) {
      _showSnack('Erro ao interpolar: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _simulateRoute() async {
    final points = _interpolatedPoints.isNotEmpty ? _interpolatedPoints : _routePoints;
    if (points.isEmpty) {
      _showSnack('Nenhuma rota para simular.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      await api.simulate(points, _speedKmh);
      _animateMarker(points);
    } catch (e) {
      _showSnack('Erro simulando: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

 
  Future<void> _animateMarker(List<Point> pts) async {
    for (final p in pts) {
      await Future.delayed(Duration(milliseconds: (1000 * 10 / _speedKmh).toInt()));
      setState(() {
        _movingMarker = Marker(
          markerId: const MarkerId('movingCar'),
          position: LatLng(p.latitude, p.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        );
        _updateMarkers();
      });
      if (_controller != null) {
        await _controller!.animateCamera(
          CameraUpdate.newLatLng(LatLng(p.latitude, p.longitude)),
        );
      }
    }
  }

  void _drawPolyline(String id, Color color, int width, List<LatLng> latlngs) {
    final polyline = Polyline(
      polylineId: PolylineId(id),
      points: latlngs,
      color: color,
      width: width,
      geodesic: true,
    );
    setState(() {
      _polylines.removeWhere((p) => p.polylineId.value == id);
      _polylines.add(polyline);
    });
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fake GPS Rotas')),
      body: Column(
        children: [
 
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                _AddressField(
                    label: "Local de Saída",
                    onSelected: (LatLng loc) {
                      setState(() => _origin = loc);
                      _updateMarkers();
                    }),
                const SizedBox(height: 8),
                _AddressField(
                    label: "Local de Chegada",
                    onSelected: (LatLng loc) {
                      setState(() => _destination = loc);
                      _updateMarkers();
                    }),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  icon: const Icon(Icons.alt_route),
                  label: const Text("Consultar Rota"),
                  onPressed: _fetchRoute,
                ),
              ],
            ),
          ),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: _initialCamera,
              onMapCreated: _onMapCreated,
              markers: _markers,
              polylines: _polylines,
              myLocationEnabled: true,
              zoomControlsEnabled: false,
              compassEnabled: true,
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text("Velocidade (km/h): "),
                    Expanded(
                      child: Slider(
                        min: 1,
                        max: 120,
                        divisions: 119,
                        value: _speedKmh,
                        label: _speedKmh.toStringAsFixed(0),
                        onChanged: (v) => setState(() => _speedKmh = v),
                      ),
                    ),
                    Text("${_speedKmh.toInt()}"),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.timeline),
                      label: const Text("Interpolar"),
                      onPressed: _interpolateRoute,
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text("Simulação"),
                      onPressed: _simulateRoute,
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}


class _AddressField extends StatefulWidget {
  final String label;
  final void Function(LatLng) onSelected;

  const _AddressField({required this.label, required this.onSelected, Key? key})
      : super(key: key);

  @override
  State<_AddressField> createState() => _AddressFieldState();
}

class _AddressFieldState extends State<_AddressField> {
  final TextEditingController _controller = TextEditingController();
  List<_PlaceSuggestion> _results = [];

  Future<void> _search(String text) async {
    final uri = Uri.parse(
        '$_placesAutocompleteUrl?input=${Uri.encodeComponent(text)}&key=$kGoogleApiKey&language=pt-BR');
    final resp = await http.get(uri);
    if (resp.statusCode != 200) return;
    final data = jsonDecode(resp.body);
    if (data['status'] != 'OK') return;
    final List preds = data['predictions'] ?? [];
    setState(() {
      _results = preds
          .map((p) => _PlaceSuggestion(description: p['description'], placeId: p['place_id']))
          .toList();
    });
  }

  Future<void> _selectPlace(_PlaceSuggestion suggestion) async {
    final uri = Uri.parse(
        '$_placeDetailsUrl?place_id=${suggestion.placeId}&key=$kGoogleApiKey&fields=geometry');
    final resp = await http.get(uri);
    if (resp.statusCode != 200) return;
    final data = jsonDecode(resp.body);
    final loc = data['result']?['geometry']?['location'];
    if (loc != null) {
      final latlng = LatLng(loc['lat'].toDouble(), loc['lng'].toDouble());
      widget.onSelected(latlng);
      setState(() {
        _controller.text = suggestion.description;
        _results = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      TextField(
        controller: _controller,
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
        ),
        onChanged: (v) {
          if (v.length > 2) _search(v);
        },
      ),
      ..._results.map((r) => ListTile(
            title: Text(r.description),
            onTap: () => _selectPlace(r),
          ))
    ]);
  }
}


class _PlaceSuggestion {
  final String description;
  final String placeId;

  _PlaceSuggestion({required this.description, required this.placeId});
}