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
  List<dynamic> _cautions = [];

  final List<String> _cautionFiles = [
    'assets/caution_orders.json',
    'assets/caution_orders_1.json',
    'assets/caution_orders_2.json',
  ];
  String _selectedCautionFile = 'assets/caution_orders.json';
  final Distance distance = const Distance();
  final MapController _mapController = MapController();

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
    try {
      final jsonString = await rootBundle.loadString(_selectedCautionFile);
      setState(() {
        _cautions = json.decode(jsonString);
      });
    } catch (e) {
      setState(() {
        _cautions = [];
      });
    }
  }

  void _resetMapView() {
    if (_currentPosition != null) {
      _mapController.move(_currentPosition!, 14);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Railway Caution Viewer'),
        actions: [
          DropdownButton<String>(
            value: _selectedCautionFile,
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedCautionFile = value;
                });
                _loadCautionData();
              }
            },
            items: _cautionFiles.map((file) {
              return DropdownMenuItem(
                value: file,
                child: Text(file.split('/').last),
              );
            }).toList(),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: _currentPosition ?? LatLng(13.0827, 80.2707), // Chennai fallback
              zoom: 14,
              maxZoom: 18,
              minZoom: 5,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: ['a', 'b', 'c'],
              ),
              PolylineLayer(
                polylines: _railwaySegments.map((segment) {
                  return Polyline(
                    points: segment,
                    strokeWidth: 4.0,
                    color: Colors.blue,
                  );
                }).toList(),
              ),
              if (_currentPosition != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 60,
                      height: 60,
                      point: _currentPosition!,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: _resetMapView,
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}
