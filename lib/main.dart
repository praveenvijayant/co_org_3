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
    final jsonString = await rootBundle.loadString('assets/caution_orders.json');
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
      _railwayLine = coordinates.map<LatLng>((c) => LatLng(c[1], c[0])).toList();
    });
  }

  void _updateNearbyCaution() {
    if (_currentPosition == null || _cautions.isEmpty || _railwayLine.isEmpty) return;

    for (final caution in _cautions) {
      final lat = _railwayLine.first.latitude;
      final lon = _railwayLine.first.longitude;
      final cautionPoint = LatLng(lat, lon);

      final dist = distance.as(LengthUnit.Kilometer, _currentPosition!, cautionPoint);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InfoTile(title: 'Current Speed', value: _currentPosition != null ? 'Live' : 'Waiting...'),
                  InfoTile(title: 'Current Location', value: _currentPosition?.toString() ?? 'Detecting...'),
                  if (_nearbyCaution != null)
                    InfoTile(title: 'Upcoming Caution', value: _nearbyCaution!['start_km'] + ' → ' + _nearbyCaution!['end_km']),
                  if (_nearbyCaution != null)
                    InfoTile(title: 'Speed Limit', value: _nearbyCaution!['speed_limit'] + ' km/h'),
                  if (_nearbyCaution != null)
                    InfoTile(title: 'Reason', value: _nearbyCaution!['reason']),
                  if (_nearbyCaution == null)
                    const InfoTile(title: 'Upcoming Caution', value: 'None within 2 km'),
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
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.railway_caution_viewer',
                  ),
                  if (_railwayLine.isNotEmpty)
                    PolylineLayer(polylines: [
                      Polyline(
                        points: _railwayLine,
                        color: Colors.red,
                        strokeWidth: 4,
                      ),
                    ]),
                  if (_currentPosition != null)
                    MarkerLayer(markers: [
                      Marker(
                        point: _currentPosition!,
                        width: 20,
                        height: 20,
                        builder: (ctx) => const Icon(Icons.train, color: Colors.blue),
                      ),
                    ])
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
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
