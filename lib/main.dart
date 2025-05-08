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
  List<LatLng> _railwayLine = [];

  @override
  void initState() {
    super.initState();
    _loadRailwayLine();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    LocationPermission permission = await Geolocator.checkPermission();

    if (!serviceEnabled || permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }

    Position position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
    });
  }

  Future<void> _loadRailwayLine() async {
    final geoJsonString = await rootBundle.loadString('assets/railway_line.geojson');
    final data = json.decode(geoJsonString);

    if (data['features'] != null && data['features'].isNotEmpty) {
      final coordinates = data['features'][0]['geometry']['coordinates'];
      List<LatLng> polyline = coordinates
          .map<LatLng>((coord) => LatLng(coord[1], coord[0]))
          .toList();
      setState(() {
        _railwayLine = polyline;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Railway Caution Viewer')),
      body: FlutterMap(
        options: MapOptions(
          center: _currentPosition ?? LatLng(13.0827, 80.2707), // Default: Chennai Central
          zoom: 10.0,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: ['a', 'b', 'c'],
          ),
          if (_railwayLine.isNotEmpty)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _railwayLine,
                  strokeWidth: 4.0,
                  color: Colors.blue,
                ),
              ],
            ),
          if (_currentPosition != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _currentPosition!,
                  width: 60,
                  height: 60,
                  builder: (ctx) => const Icon(Icons.location_pin, color: Colors.red, size: 30),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
