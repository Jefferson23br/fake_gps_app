import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../services/api_service.dart';
import '../models/point.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

const String kGoogleApiKey = 'AIzaSyBD_-wfbVZsoJMI5RVW823qQ8vizmS27Hs';

// Endpoints REST do Places API
const String _placesAutocompleteUrl =
    'https://maps.googleapis.com/maps/api/place/autocomplete/json';
const String _placeDetailsUrl =
    'https://maps.googleapis.com/maps/api/place/details/json';

class _MapScreenState extends State<MapScreen> {
  final ApiService api = ApiService();

  final Completer<GoogleMapController> _mapController = Completer();
  GoogleMapController? _controller;

  LatLng? _origin;
  LatLng? _destination;

  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};


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
    final lat = (loc['lat'] as num).toDouble();
    final lng = (loc['lng'] as num).toDouble();
    return LatLng(lat, lng);
  }

  Future<void> _pickLocation({
    required bool isOrigin,
  }) async {
    final result = await showModalBottomSheet<_PlacePickResult>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _PlacePickerSheet(
        onSearch: _fetchAutocomplete,
        onResolvePlaceId: _fetchPlaceLatLng,
      ),
    );

    if (result == null || result.latLng == null) return;

    setState(() {
      if (isOrigin) {
        _origin = result.latLng;
      } else {
        _destination = result.latLng;
      }
    });

    _updateMarkers();

    final controller = _controller;
    if (controller != null) {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: result.latLng!, zoom: 14),
        ),
      );
    }
  }

  void _updateMarkers() {
    final markers = <Marker>{};
    if (_origin != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('origin'),
          position: _origin!,
          infoWindow: const InfoWindow(title: 'Origem'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }
    if (_destination != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _destination!,
          infoWindow: const InfoWindow(title: 'Destino'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }
    setState(() => _markers
      ..clear()
      ..addAll(markers));
  }

  Future<void> _fitToBounds(List<LatLng> points) async {
    if (points.isEmpty || _controller == null) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    await _controller!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60));
  }

  Future<void> _fetchRoute() async {
    if (_origin == null || _destination == null) {
      _showSnack('Selecione origem e destino.');
      return;
    }

    setState(() {
      _isLoading = true;
      _polylines.clear();
      _interpolatedPoints = [];
      _routePoints = [];
    });

    try {

      final route = await api.getRoute(
        _origin!.latitude,
        _origin!.longitude,
        _destination!.latitude,
        _destination!.longitude,
      );

      setState(() {
        _routePoints = route;
      });


      _drawPolyline(
        id: 'route',
        color: Colors.blue,
        width: 5,
        latLngs: route.map((p) => LatLng(p.latitude, p.longitude)).toList(),
      );


      await _fitToBounds(
        route.map((p) => LatLng(p.latitude, p.longitude)).toList(),
      );
    } catch (e) {
      _showSnack('Erro ao buscar rota: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _interpolate() async {
    if (_routePoints.isEmpty) {
      _showSnack('Busque a rota antes de interpolar.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final interpolated = await api.interpolate(_routePoints);
      setState(() => _interpolatedPoints = interpolated);

      _drawPolyline(
        id: 'interpolated',
        color: Colors.orange,
        width: 4,
        latLngs:
            interpolated.map((p) => LatLng(p.latitude, p.longitude)).toList(),
      );
    } catch (e) {
      _showSnack('Erro ao interpolar: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _simulate() async {
    final pointsToSimulate =
        _interpolatedPoints.isNotEmpty ? _interpolatedPoints : _routePoints;

    if (pointsToSimulate.isEmpty) {
      _showSnack('Sem pontos para simulação. Busque a rota e/ou interpole.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final resp = await api.simulate(pointsToSimulate, _speedKmh);
      _showSnack('Simulação iniciada: ${resp['status'] ?? 'ok'}');
    } catch (e) {
      _showSnack('Erro ao iniciar simulação: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _drawPolyline({
    required String id,
    required Color color,
    required int width,
    required List<LatLng> latLngs,
  }) {
    final polyline = Polyline(
      polylineId: PolylineId(id),
      points: latLngs,
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
      appBar: AppBar(
        title: const Text('Rota e Simulação'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report_outlined),
            tooltip: 'Limpar',
            onPressed: () {
              setState(() {
                _origin = null;
                _destination = null;
                _markers.clear();
                _polylines.clear();
                _routePoints = [];
                _interpolatedPoints = [];
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialCamera,
            onMapCreated: _onMapCreated,
            markers: _markers,
            polylines: _polylines,
            myLocationButtonEnabled: true,
            myLocationEnabled: true,
            compassEnabled: true,
            mapToolbarEnabled: false,
            zoomControlsEnabled: false,
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          _PickButton(
                            label: _origin == null
                                ? 'Escolher origem'
                                : 'Origem: ${_origin!.latitude.toStringAsFixed(5)}, ${_origin!.longitude.toStringAsFixed(5)}',
                            icon: Icons.trip_origin,
                            color: Colors.green,
                            onTap: () => _pickLocation(isOrigin: true),
                          ),
                          const SizedBox(height: 8),
                          _PickButton(
                            label: _destination == null
                                ? 'Escolher destino'
                                : 'Destino: ${_destination!.latitude.toStringAsFixed(5)}, ${_destination!.longitude.toStringAsFixed(5)}',
                            icon: Icons.flag,
                            color: Colors.red,
                            onTap: () => _pickLocation(isOrigin: false),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _fetchRoute,
                          icon: const Icon(Icons.alt_route),
                          label: const Text('Rota'),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _interpolate,
                          icon: const Icon(Icons.timeline),
                          label: const Text('Interpolar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Text('Velocidade (km/h)'),
                        Expanded(
                          child: Slider(
                            min: 1,
                            max: 120,
                            divisions: 119,
                            value: _speedKmh,
                            label: _speedKmh.toStringAsFixed(0),
                            onChanged: _isLoading
                                ? null
                                : (v) => setState(() => _speedKmh = v),
                          ),
                        ),
                        SizedBox(
                          width: 48,
                          child: Text(
                            _speedKmh.toStringAsFixed(0),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Iniciar simulação'),
                        onPressed: _isLoading ? null : _simulate,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading)
            const IgnorePointer(
              ignoring: true,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}


class _PickButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _PickButton({
    Key? key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withOpacity(0.6)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _PlacePickResult {
  final LatLng? latLng;
  final String? description;

  _PlacePickResult({this.latLng, this.description});
}

class _PlaceSuggestion {
  final String description;
  final String placeId;

  _PlaceSuggestion({required this.description, required this.placeId});
}

class _PlacePickerSheet extends StatefulWidget {
  final Future<List<_PlaceSuggestion>> Function(String) onSearch;
  final Future<LatLng?> Function(String placeId) onResolvePlaceId;

  const _PlacePickerSheet({
    Key? key,
    required this.onSearch,
    required this.onResolvePlaceId,
  }) : super(key: key);

  @override
  State<_PlacePickerSheet> createState() => _PlacePickerSheetState();
}

class _PlacePickerSheetState extends State<_PlacePickerSheet> {
  final TextEditingController _controller = TextEditingController();
  List<_PlaceSuggestion> _results = [];
  bool _loading = false;

  Future<void> _search(String text) async {
    setState(() => _loading = true);
    try {
      final res = await widget.onSearch(text);
      setState(() => _results = res);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'Digite um endereço...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _controller.clear();
                            setState(() => _results = []);
                          },
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (v) {
                  if (v.trim().length >= 3) {
                    _search(v);
                  } else {
                    setState(() => _results = []);
                  }
                },
                textInputAction: TextInputAction.search,
                onSubmitted: (v) {
                  if (v.trim().length >= 3) _search(v);
                },
              ),
            ),
            const SizedBox(height: 8),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            Flexible(
              child: _results.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Digite ao menos 3 caracteres para buscar.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final item = _results[i];
                        return ListTile(
                          leading: const Icon(Icons.place_outlined),
                          title: Text(item.description),
                          onTap: () async {
                            final latLng =
                                await widget.onResolvePlaceId(item.placeId);
                            Navigator.of(context).pop(
                              _PlacePickResult(
                                latLng: latLng,
                                description: item.description,
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}