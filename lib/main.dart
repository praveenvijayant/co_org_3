import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
      home: LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _rakeController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _error;

  void _login() {
    final rake = _rakeController.text.trim();
    final password = _passwordController.text.trim();

    if (password == 'rail123' && rake.isNotEmpty) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => CautionViewerScreen(rake: rake),
        ),
      );
    } else {
      setState(() {
        _error = 'Invalid login. Check rake number or password.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rake Login')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _rakeController,
              decoration: const InputDecoration(labelText: 'Rake Number (e.g., Rake-001)'),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _login,
              child: const Text('Login'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
    );
  }
}

class CautionViewerScreen extends StatefulWidget {
  final String rake;
  const CautionViewerScreen({super.key, required this.rake});

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
    final data = await DefaultAssetBundle.of(context).loadString('assets/railway_line.geojson');
    final geojson = await Future.delayed(const Duration(milliseconds: 100), () => data);
    // For demo purposes we skip actual parsing here
  }

  void _loadCautionsFromFirebase() {
    FirebaseFirestore.instance
        .collection('cautions')
        .where('rake', isEqualTo: widget.rake)
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
            'latLng': LatLng(13.04, 80.25), // placeholder
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
        title: Text('Rake: ${widget.rake}'),
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
