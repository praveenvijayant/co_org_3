// main.dart

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
  List<double> _railwayKms = [];
  List<Map<String, dynamic>> _manualCautions = [];
  final MapController _mapController = MapController();
  final Distance _distance = const Distance();

  @override
  void initState() {
    super.initState();
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
        });
      });
    }
  }

  Future<void> _loadRailwayLine() async {
    final geojson = await rootBundle.loadString('assets/railway_line.geojson');
    final jsonData = json.decode(geojson);
    final List<LatLng> points = [];

    for (var feature in jsonData['features']) {
      if (feature['geometry']['type'] == 'LineString') {
        final coordinates = feature['geometry']['coordinates'];
        points.addAll(
            coordinates.map<LatLng>((c) => LatLng(c[1], c[0])).toList());
      }
    }

    // Cumulative KMs from Chennai Central
    final List<double> kms = [0.0];
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      kms.add(kms.last + _distance(prev, curr) / 1000.0);
    }

    setState(() {
      _railwayLine = points;
      _railwayKms = kms;
    });
  }

  void _addCaution() {
    showModalBottomSheet(
        context: context,
        builder: (context) {
          final _formKey = GlobalKey<FormState>();
          final _startController = TextEditingController();
          final _endController = TextEditingController();
          final _speedController = TextEditingController();
          final _reasonController = TextEditingController();

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _startController,
                    decoration: const InputDecoration(labelText: 'Start KM'),
                    keyboardType: TextInputType.number,
                  ),
                  TextFormField(
                    controller: _endController,
                    decoration: const InputDecoration(labelText: 'End KM'),
                    keyboardType: TextInputType.number,
                  ),
                  TextFormField(
                    controller: _speedController,
                    decoration:
                        const InputDecoration(labelText: 'Speed Limit (kmph)'),
                    keyboardType: TextInputType.number,
                  ),
                  TextFormField(
                    controller: _reasonController,
                    decoration:
                        const InputDecoration(labelText: 'Reason for Caution'),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    child: const Text('Add Caution'),
                    onPressed: () {
                      setState(() {
                        _manualCautions.add({
                          'startKm': double.tryParse(_startController.text) ?? 0,
                          'endKm': double.tryParse(_endController.text) ?? 0,
                          'speed': _speedController.text,
                          'reason': _reasonController.text,
                        });
                      });
                      Navigator.pop(context);
                    },
                  )
                ],
              ),
            ),
          );
        });
  }

  void _onMapTap(LatLng tapPoint) {
    double minDist = double.infinity;
    int closestIndex = 0;
    for (int i = 0; i < _railwayLine.length; i++) {
      final d = _distance(_railwayLine[i], tapPoint);
      if (d < minDist) {
        minDist = d;
        closestIndex = i;
      }
    }
    double kmFromStart = _railwayKms[closestIndex];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Track Tapped'),
        content: Text(
            'Approximate KM from Chennai Central: ${kmFromStart.toStringAsFixed(2)}'),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(ctx),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Railway Caution Viewer')),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          center: _currentPosition ?? const LatLng(13.0827, 80.2707),
          zoom: 14,
          onTap: (_, latlng) => _onMapTap(latlng),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
            subdomains: ['a', 'b', 'c'],
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: _railwayLine,
                strokeWidth: 4.0,
                color: Colors.blue,
              )
            ],
          ),
          MarkerLayer(
            markers: [
              if (_currentPosition != null)
                Marker(
                  width: 60,
                  height: 60,
                  point: _currentPosition!,
                  child: const Icon(
                    Icons.my_location,
                    color: Colors.red,
                    size: 40,
                  ),
                ),
              ..._manualCautions.map((c) {
                final km = c['startKm'];
                int closestIndex = 0;
                double minDist = double.infinity;
                for (int i = 0; i < _railwayKms.length; i++) {
                  final diff = (_railwayKms[i] - km).abs();
                  if (diff < minDist) {
                    minDist = diff;
                    closestIndex = i;
                  }
                }
                return Marker(
                  width: 40,
                  height: 40,
                  point: _railwayLine[closestIndex],
                  child: Tooltip(
                    message:
                        "KM ${c['startKm']} - ${c['endKm']}, ${c['speed']} kmph: ${c['reason']}",
                    child: const Icon(
                      Icons.warning,
                      color: Colors.orange,
                      size: 30,
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCaution,
        child: const Icon(Icons.add),
      ),
    );
  }
}
