import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
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
  List<Map<String, dynamic>> _cautionList = [];

  @override
  void initState() {
    super.initState();
    _loadRailwayLine();
    _getCurrentLocation();
    _loadCautionsFromFirebase();
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

  void _loadCautionsFromFirebase() {
    const String rakeId = 'Rake123';

    FirebaseFirestore.instance
        .collection('cautions')
        .where('rake', isEqualTo: rakeId)
        .orderBy('timestamp')
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _cautionList = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'startKM': data['startKM'],
            'endKM': data['endKM'],
            'speed': data['speed'],
            'reason': data['reason'],
            'latLng': LatLng(13.04, 80.25), // TODO: replace with actual LatLng mapping logic
          };
        }).toList();
      });
    });
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
                _loadCautionsFromFirebase();
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
    );
  }
}
