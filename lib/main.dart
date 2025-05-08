// main.dart (Enhanced with Caution Zones, Zoom, Save/Load)

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const RailwayCautionViewerApp());

class RailwayCautionViewerApp extends StatelessWidget {
  const RailwayCautionViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const CautionViewerScreen(),
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
  List<Map<String, dynamic>> _manualCautions = [];
  final MapController _mapController = MapController();
  final Distance _distance = const Distance();

  @override
  void initState() {
    super.initState();
    _loadRailwayLine();
    _getCurrentLocation();
    _loadCautionsFromStorage();
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
    if (jsonData['features'].isNotEmpty) {
      final coordinates = jsonData['features'][0]['geometry']['coordinates'];
      setState(() {
        _railwayLine =
            coordinates.map<LatLng>((c) => LatLng(c[1], c[0])).toList();
      });
    }
  }

  Future<void> _saveCautionsToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('manualCautions', json.encode(_manualCautions));
  }

  Future<void> _loadCautionsFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('manualCautions');
    if (data != null) {
      setState(() {
        _manualCautions = List<Map<String, dynamic>>.from(json.decode(data));
      });
    }
  }

  void _addCaution() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final _startController = TextEditingController();
        final _endController = TextEditingController();
        final _speedController = TextEditingController();
        final _reasonController = TextEditingController();

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: SingleChildScrollView(
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
                  decoration: const InputDecoration(labelText: 'Speed Limit (kmph)'),
                  keyboardType: TextInputType.number,
                ),
                TextFormField(
                  controller: _reasonController,
                  decoration: const InputDecoration(labelText: 'Reason'),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _manualCautions.add({
                        'startKm': _startController.text,
                        'endKm': _endController.text,
                        'speed': _speedController.text,
                        'reason': _reasonController.text,
                      });
                    });
                    _saveCautionsToStorage();
                    Navigator.pop(context);
                  },
                  child: const Text('Add Caution'),
                )
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCautionList() {
    return ListView.builder(
      itemCount: _manualCautions.length,
      itemBuilder: (context, index) {
        final c = _manualCautions[index];
        return ListTile(
          leading: const Icon(Icons.warning, color: Colors.orange),
          title: Text('KM ${c['startKm']} to ${c['endKm']}'),
          subtitle: Text('Speed: ${c['speed']} kmph\n${c['reason']}'),
          onTap: () {
            final km = double.tryParse(c['startKm']) ?? 0;
            if (_railwayLine.isNotEmpty) {
              final segmentLength = _railwayLine.length;
              final pos = (km / 734.0 * segmentLength).clamp(0, segmentLength - 1).toInt();
              _mapController.move(_railwayLine[pos], 16);
            }
          },
        );
      },
    );
  }

  List<Polyline> _buildCautionZones() {
    List<Polyline> zones = [];
    for (var c in _manualCautions) {
      final startKm = double.tryParse(c['startKm'] ?? '') ?? 0;
      final endKm = double.tryParse(c['endKm'] ?? '') ?? 0;
      final totalLength = _railwayLine.length;
      final startIndex = (startKm / 734.0 * totalLength).clamp(0, totalLength - 1).toInt();
      final endIndex = (endKm / 734.0 * totalLength).clamp(0, totalLength - 1).toInt();
      if (startIndex < endIndex) {
        zones.add(
          Polyline(
            points: _railwayLine.sublist(startIndex, endIndex),
            strokeWidth: 6.0,
            color: Colors.red.withOpacity(0.5),
          ),
        );
      }
    }
    return zones;
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Railway Caution Viewer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addCaution,
            tooltip: 'Add Caution',
          ),
        ],
      ),
      body: isLandscape
          ? Row(
              children: [
                Flexible(
                  flex: 1,
                  child: Container(
                    color: Colors.grey[100],
                    child: _buildCautionList(),
                  ),
                ),
                Flexible(
                  flex: 2,
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      center: _currentPosition ?? const LatLng(13.0827, 80.2707),
                      zoom: 14,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                        subdomains: ['a', 'b', 'c'],
                      ),
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _railwayLine,
                            strokeWidth: 4.0,
                            color: Colors.blue,
                          ),
                          ..._buildCautionZones(),
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
                        ],
                      )
                    ],
                  ),
                ),
              ],
            )
          : const Center(
              child: Text('Please rotate your device to landscape mode.'),
            ),
    );
  }
}
