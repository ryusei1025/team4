import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

void main() {
  runApp(const MapTestApp());
}

class MapTestApp extends StatelessWidget {
  const MapTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: TrashBinMapScreen(),
    );
  }
}

class TrashBinMapScreen extends StatelessWidget {
  const TrashBinMapScreen({super.key});

  // ダミーのゴミ箱位置（札幌駅周辺）
  final List<LatLng> trashBins = const [
    LatLng(43.062, 141.354),
    LatLng(43.0635, 141.356),
    LatLng(43.061, 141.352),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ゴミステーションマップ')),
      body: FlutterMap(
        options: const MapOptions(
          initialCenter: LatLng(43.062, 141.354),
          initialZoom: 15,
        ),
        children: [
          // 地図本体（OpenStreetMap）
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.frontend',
          ),

          // ピン
          MarkerLayer(
            markers: trashBins.map((pos) {
              return Marker(
                point: pos,
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.location_pin,
                  size: 40,
                  color: Colors.red,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
