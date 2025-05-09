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

  // Sample caution list with LatLng demo locations
  List<Map<String, dynamic>> _cautionList = [
    {
      'startKM': '5/0',
      'endKM': '5/5',
      'speed': '60',
      'reason': 'Track work',
      'latLng': LatLng(13.0750, 80.2100),
    },
    {
      'startKM': '12/0',
      'endKM': '12/3',
      'speed': '45',
      'reason': 'Bridge repair',
      'latLng': LatLng(13.0350, 80.1200),
    },
  ];

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

  void _showAddCautionDialog() {
    final startKMController = TextEditingController();
    final endKMController = TextEditingController();
    final speedController = TextEditingController();
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Caution"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: startKMController, decoration: const InputDecoration(labelText: 'Start KM')),
            TextField(controller: endKMController, decoration: const InputDecoration(labelText: 'End KM')),
            TextField(controller: speedController, decoration: const InputDecoration(labelText: 'Speed Limit')),
            TextField(controller: reasonController, decoration: const InputDecoration(labelText: 'Reason')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _cautionList.add({
                  'startKM': startKMController.text,
                  'endKM': endKMController.text,
                  'speed': speedController.text,
                  'reason': reasonController.text,
                  'latLng': _currentPosition ?? LatLng(13.0827, 80.2707), // fallback location
                });
              });
              Navigator.pop(context);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Railway Caution Viewer'),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: Colors.blue),
              child: Text('Menu', style: TextStyle(color: Colors.white, fontSize: 24)),
            ),
            ListTile(
              leading: const Icon(Icons.sync),
              title: const Text('Sync Firebase'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      body: isLandscape
          ? Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Container(
                    color: Colors.grey[200],
                    child: ListView(
                      padding: const EdgeInsets.all(8),
                      children: [
                        const Text("🚧 Caution Details", style: TextStyle(fontWeight: FontWeight.bold)),
                        const Divider(),
                        for (var caution in _cautionList)
                          ListTile(
                            title: Text("KM ${caution['startKM']} to ${caution['endKM']}"),
                            subtitle: Text("Speed Limit: ${caution['speed']} kmph\nReason: ${caution['reason']}"),
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: FlutterMap(
                    options: MapOptions(
                      center: _currentPosition ?? LatLng(13.0827, 80.2707),
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
                              child: const Icon(Icons.location_pin, color: Colors.red, size: 30),
                            ),
                          ],
                        ),
                      // Caution markers
                      MarkerLayer(
                        markers: _cautionList.map((caution) {
                          return Marker(
                            point: caution['latLng'],
                            width: 40,
                            height: 40,
                            child: const Icon(Icons.warning, color: Colors.orange, size: 30),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : const Center(child: Text("Please rotate to landscape mode.")),

      floatingActionButton: isLandscape
          ? FloatingActionButton(
              onPressed: _showAddCautionDialog,
              child: const Icon(Icons.add),
              tooltip: 'Add Caution',
            )
          : null,
    );
  }
}
