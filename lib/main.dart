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
  List<Polyline> _railwayPolylines = [];
  List<LatLng> _allPoints = [];
  List<double> _railwayKms = [];
  List<Map<String, dynamic>> _manualCautions = [];
  final MapController _mapController = MapController();
  final Distance _distance = const Distance();
  double _totalMappedKm = 0.0;

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
    final List<Polyline> polylines = [];
    final List<LatLng> combinedPoints = [];

    for (var feature in jsonData['features']) {
      if (feature['geometry']['type'] == 'LineString') {
        final coordinates = feature['geometry']['coordinates'];
        final segment = coordinates.map<LatLng>((c) => LatLng(c[1], c[0])).toList();
        combinedPoints.addAll(segment);
        polylines.add(Polyline(points: segment, strokeWidth: 4.0, color: Colors.blue));
      }
    }

    final List<double> kms = [0.0];
    for (int i = 1; i < combinedPoints.length; i++) {
      final prev = combinedPoints[i - 1];
      final curr = combinedPoints[i];
      kms.add(kms.last + _distance(prev, curr) / 1000.0);
    }

    setState(() {
      _railwayPolylines = polylines;
      _allPoints = combinedPoints;
      _railwayKms = kms;
      _totalMappedKm = kms.last;
    });
  }

  void _addCaution() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final _formKey = GlobalKey<FormState>();
        final _startController = TextEditingController();
        final _endController = TextEditingController();
        final _speedController = TextEditingController();
        final _reasonController = TextEditingController();

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16, right: 16, top: 16,
          ),
          child: SingleChildScrollView(
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
          ),
        );
      },
    );
  }

  void _onCautionTap(Map<String, dynamic> caution) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Caution Details"),
        content: Text(
          'Start KM: ${caution['startKm']}\n'
          'End KM: ${caution['endKm']}\n'
          'Speed Limit: ${caution['speed']} kmph\n'
          'Reason: ${caution['reason']}\n'
          'Positioned at ~${caution['startKm']} KM from origin'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          )
        ],
      ),
    );
  }

  void _onMapTap(LatLng tapPoint) {
    double minDist = double.infinity;
    int closestIndex = 0;
    for (int i = 0; i < _allPoints.length; i++) {
      final d = _distance(_allPoints[i], tapPoint);
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
      appBar: AppBar(
        title: const Text('Railway Caution Viewer'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Text(
            'Mapped Distance: ~${_totalMappedKm.toStringAsFixed(2)} KM',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
      ),
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
            polylines: _railwayPolylines,
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
                  point: _allPoints[closestIndex],
                  child: GestureDetector(
                    onTap: () => _onCautionTap(c),
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
