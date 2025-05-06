
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

void main() {
  runApp(const RailwayCautionViewerApp());
}

class RailwayCautionViewerApp extends StatelessWidget {
  const RailwayCautionViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CautionViewerScreen(),
    );
  }
}

class CautionViewerScreen extends StatefulWidget {
  const CautionViewerScreen({super.key});

  @override
  State<CautionViewerScreen> createState() => _CautionViewerScreenState();
}

class _CautionViewerScreenState extends State<CautionViewerScreen> {
  LatLng? _currentPosition;
  List<dynamic> _cautions = [];
  List<LatLng> _railwayLine = [];
  Map<String, dynamic>? _nearbyCaution;
  LatLng? _tappedPoint;
  double? _tappedKm;

  final Distance distance = const Distance();

  @override
  void initState() {
    super.initState();
    _loadCautionData();
    _loadRailwayLine();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (serviceEnabled &&
        (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse)) {
      Geolocator.getPositionStream().listen((Position position) {
        setState(() {
          _currentPosition = LatLng(position.latitude, position.longitude);
          _updateNearbyCaution();
        });
      });
    }
  }

  Future<void> _loadCautionData() async {
    final jsonString =
        await rootBundle.loadString('assets/caution_orders.json');
    final data = json.decode(jsonString);
    setState(() {
      _cautions = data;
    });
  }

  Future<void> _loadRailwayLine() async {
    final geojson = await rootBundle.loadString('assets/railway_line.geojson');
    final jsonData = json.decode(geojson);
    final coordinates = jsonData['features'][0]['geometry']['coordinates'];
    setState(() {
      _railwayLine =
          coordinates.map<LatLng>((c) => LatLng(c[1], c[0])).toList();
    });
  }

  void _updateNearbyCaution() {
    if (_currentPosition == null ||
        _cautions.isEmpty ||
        _railwayLine.isEmpty) return;

    for (final caution in _cautions) {
      final lat = _railwayLine.first.latitude;
      final lon = _railwayLine.first.longitude;
      final cautionPoint = LatLng(lat, lon);

      final dist =
          distance.as(LengthUnit.Kilometer, _currentPosition!, cautionPoint);

      if (dist < 2.0) {
        setState(() {
          _nearbyCaution = caution;
        });
        return;
      }
    }

    setState(() {
      _nearbyCaution = null;
    });
  }

  double _calculateKmFromStart(LatLng target) {
    double km = 0.0;
    for (int i = 0; i < _railwayLine.length - 1; i++) {
      final p1 = _railwayLine[i];
      final p2 = _railwayLine[i + 1];
      km += distance.as(LengthUnit.Kilometer, p1, p2);
      if ((p2.latitude == target.latitude && p2.longitude == target.longitude)) {
        break;
      }
    }
    return km;
  }

  LatLng _getPointForKm(double kmTarget) {
    double km = 0.0;
    for (int i = 0; i < _railwayLine.length - 1; i++) {
      final p1 = _railwayLine[i];
      final p2 = _railwayLine[i + 1];
      final segment = distance.as(LengthUnit.Kilometer, p1, p2);
      if (km + segment >= kmTarget) {
        final fraction = (kmTarget - km) / segment;
        final lat = p1.latitude + (p2.latitude - p1.latitude) * fraction;
        final lng = p1.longitude + (p2.longitude - p1.longitude) * fraction;
        return LatLng(lat, lng);
      }
      km += segment;
    }
    return _railwayLine.last;
  }

  void _showAddCautionDialog() {
    final startKmController = TextEditingController();
    final endKmController = TextEditingController();
    final speedController = TextEditingController();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Manual Caution'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: startKmController, decoration: const InputDecoration(labelText: 'Start KM')),
              TextField(controller: endKmController, decoration: const InputDecoration(labelText: 'End KM')),
              TextField(controller: speedController, decoration: const InputDecoration(labelText: 'Speed Limit')),
              TextField(controller: reasonController, decoration: const InputDecoration(labelText: 'Reason')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              setState(() {
                _cautions.add({
                  'start_km': startKmController.text,
                  'end_km': endKmController.text,
                  'speed_limit': speedController.text,
                  'reason': reasonController.text,
                });
              });
            },
            child: const Text('Add'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Marker> cautionMarkers = _cautions.map<Marker>((caution) {
      double startKm = double.tryParse(caution['start_km'].toString()) ?? 0.0;
      LatLng point = _getPointForKm(startKm);
      return Marker(
        point: point,
        width: 120,
        height: 60,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'KM ${caution['start_km']} → ${caution['end_km']}\n${caution['speed_limit']} km/h',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: Colors.white),
              ),
            ),
            const Icon(Icons.warning, color: Colors.red),
          ],
        ),
      );
    }).toList();

    return Scaffold(
      backgroundColor: Colors.black,
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddCautionDialog,
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InfoTile(
                      title: 'Current Speed',
                      value: _currentPosition != null ? 'Live' : 'Waiting...'),
                  InfoTile(
                      title: 'Current Location',
                      value: _currentPosition?.toString() ?? 'Detecting...'),
                  if (_tappedKm != null)
                    InfoTile(
                        title: 'Tapped KM',
                        value: '${_tappedKm!.toStringAsFixed(2)} km'),
                  if (_nearbyCaution != null)
                    InfoTile(
                        title: 'Upcoming Caution',
                        value: _nearbyCaution!['start_km'] +
                            ' → ' +
                            _nearbyCaution!['end_km']),
                  if (_nearbyCaution != null)
                    InfoTile(
                        title: 'Speed Limit',
                        value: _nearbyCaution!['speed_limit'] + ' km/h'),
                  if (_nearbyCaution != null)
                    InfoTile(
                        title: 'Reason', value: _nearbyCaution!['reason']),
                  if (_nearbyCaution == null)
                    const InfoTile(
                        title: 'Upcoming Caution',
                        value: 'None within 2 km'),
                ],
              ),
            ),
            const VerticalDivider(color: Colors.white30, width: 1),
            Expanded(
              flex: 3,
              child: FlutterMap(
                options: MapOptions(
                  center: _currentPosition ?? LatLng(13.08, 80.27),
                  zoom: 15.0,
                  onTap: (tapPosition, tapLatLng) {
                    if (_railwayLine.isEmpty) return;
                    LatLng nearest = _railwayLine.reduce((a, b) =>
                      distance(tapLatLng, a) < distance(tapLatLng, b) ? a : b);
                    setState(() {
                      _tappedPoint = nearest;
                      _tappedKm = _calculateKmFromStart(nearest);
                    });
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName:
                        'com.example.railway_caution_viewer',
                  ),
                  if (_railwayLine.isNotEmpty)
                    PolylineLayer(polylines: [
                      Polyline(
                        points: _railwayLine,
                        color: Colors.red,
                        strokeWidth: 4,
                      ),
                    ]),
                  MarkerLayer(markers: [
                    if (_currentPosition != null)
                      Marker(
                        point: _currentPosition!,
                        width: 20,
                        height: 20,
                        child: const Icon(Icons.train, color: Colors.blue),
                      ),
                    if (_tappedPoint != null && _tappedKm != null)
                      Marker(
                        point: _tappedPoint!,
                        width: 120,
                        height: 50,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.yellow.shade800,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'KM: ${_tappedKm!.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 12, color: Colors.black),
                              ),
                            ),
                            const Icon(Icons.location_on, color: Colors.yellow),
                          ],
                        ),
                      ),
                    ...cautionMarkers,
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class InfoTile extends StatelessWidget {
  final String title;
  final String value;
  const InfoTile({required this.title, required this.value, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
