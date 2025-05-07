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
  List<List<LatLng>> _railwaySegments = [];
  List<String> _cautionFiles = [
    'assets/caution_orders.json',
    'assets/caution_orders_1.json',
    'assets/caution_orders_2.json'
  ];
  String _selectedCautionFile = 'assets/caution_orders.json';
  List<dynamic> _cautions = [];
  final Distance distance = const Distance();

  @override
  void initState() {
    super.initState();
    _loadRailwayLine();
    _getCurrentLocation();
    _loadCautionData();
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
        });
      });
    }
  }

  Future<void> _loadRailwayLine() async {
    final geojson = await rootBundle.loadString('assets/railway_line.geojson');
    final jsonData = json.decode(geojson);
    final List<List<LatLng>> segments = [];

    for (var feature in jsonData['features']) {
      if (feature['geometry']['type'] == 'LineString') {
        final coordinates = feature['geometry']['coordinates'];
        final List<LatLng> points =
            coordinates.map<LatLng>((c) => LatLng(c[1], c[0])).toList();

        // Filter out abnormal jumps between points
        final List<LatLng> filtered = [];
        for (int i = 0; i < points.length - 1; i++) {
          final d = distance(points[i], points[i + 1]);
          if (d < 5.0) {
            filtered.add(points[i]);
          }
        }
        if (filtered.length >= 2) segments.add(filtered);
      }
    }

    setState(() {
      _railwaySegments = segments;
    });
  }

  Future<void> _loadCautionData() async {
    final jsonString = await rootBundle.loadString(_selectedCautionFile);
    final data = json.decode(jsonString);
    setState(() {
      _cautions = data;
    });
  }

  void _onCautionFileChanged(String? newFile) {
    if (newFile != null) {
      setState(() {
        _selectedCautionFile = newFile;
      });
      _loadCautionData();
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Marker> cautionMarkers = _cautions.map<Marker>((caution) {
      LatLng fallbackPoint =
          _railwaySegments.isNotEmpty ? _railwaySegments.first.first : LatLng(0, 0);
      return Marker(
        point: fallbackPoint,
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
                'KM ${caution['start_km']}\n${caution['speed_limit']} km/h',
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
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text('Menu', style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              title: const Text('Select Caution File'),
              subtitle: DropdownButton<String>(
                value: _selectedCautionFile,
                items: _cautionFiles.map((file) {
                  return DropdownMenuItem(value: file, child: Text(file.split('/').last));
                }).toList(),
                onChanged: _onCautionFileChanged,
              ),
            )
          ],
        ),
      ),
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InfoTile(title: 'Current Speed', value: _currentPosition != null ? 'Live' : 'Waiting...'),
                  InfoTile(title: 'Current Location', value: _currentPosition?.toString() ?? 'Detecting...'),
                  InfoTile(title: 'File', value: _selectedCautionFile.split('/').last),
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
                  if (_railwaySegments.isNotEmpty)
                    PolylineLayer(
                      polylines: _railwaySegments.map((segment) =>
                        Polyline(points: segment, color: Colors.red, strokeWidth: 4)).toList(),
                    ),
                  MarkerLayer(markers: [
                    if (_currentPosition != null)
                      Marker(
                        point: _currentPosition!,
                        width: 20,
                        height: 20,
                        child: const Icon(Icons.train, color: Colors.blue),
                      ),
                    ...cautionMarkers,
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
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 14)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
