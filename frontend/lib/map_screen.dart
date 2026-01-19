import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'trash_bin_api.dart';

class TrashBinMapScreen extends StatefulWidget {
  const TrashBinMapScreen({super.key});

  @override
  State<TrashBinMapScreen> createState() => _TrashBinMapScreenState();
}

class _TrashBinMapScreenState extends State<TrashBinMapScreen> {
  GoogleMapController? _mapController;

  List<TrashBin> _allBins = [];
  List<TrashBin> _filteredBins = [];

  final TextEditingController _searchController = TextEditingController();

  // 初期表示（札幌駅あたり）
  static const LatLng _initialPosition = LatLng(43.062, 141.354);

  @override
  void initState() {
    super.initState();
    _loadBins();
  }

  /// Flask API からゴミ箱一覧取得
  Future<void> _loadBins() async {
    final bins = await TrashBinApi.fetchBins();
    setState(() {
      _allBins = bins;
      _filteredBins = bins; // 初期は全表示
    });
  }

  /// あいまい検索（空白OK）＋ 0件対策
  void _search(String keyword) {
    final normalizedKeyword =
        keyword.toLowerCase().replaceAll(RegExp(r'\s+'), '');

    // 空なら全表示に戻す
    if (normalizedKeyword.isEmpty) {
      setState(() {
        _filteredBins = _allBins;
      });
      return;
    }

    final result = _allBins.where((bin) {
      final target = (bin.name + bin.address)
          .toLowerCase()
          .replaceAll(RegExp(r'\s+'), '');
      return target.contains(normalizedKeyword);
    }).toList();

    // 0件ならピン消失を防ぐ（全表示）
    if (result.isEmpty) {
      setState(() {
        _filteredBins = _allBins;
      });
      return;
    }

    setState(() {
      _filteredBins = result;
    });

    _moveCameraByResults(result);
  }

  /// 検索結果に応じてカメラ移動
  void _moveCameraByResults(List<TrashBin> results) {
    if (_mapController == null || results.isEmpty) return;

    // 1件だけならズームイン
    if (results.length == 1) {
      final bin = results.first;
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(bin.lat, bin.lon),
          17,
        ),
      );
      return;
    }

    // 複数件なら全ピンが入る範囲へ
    double minLat = results.first.lat;
    double maxLat = results.first.lat;
    double minLon = results.first.lon;
    double maxLon = results.first.lon;

    for (var bin in results) {
      minLat = min(minLat, bin.lat);
      maxLat = max(maxLat, bin.lat);
      minLon = min(minLon, bin.lon);
      maxLon = max(maxLon, bin.lon);
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLon),
          northeast: LatLng(maxLat, maxLon),
        ),
        80, // 余白
      ),
    );
  }

  /// Marker 作成（ピンタップでズーム）
  Set<Marker> _buildMarkers() {
    return _filteredBins.map((bin) {
      return Marker(
        markerId: MarkerId(bin.id.toString()),
        position: LatLng(bin.lat, bin.lon),
        infoWindow: InfoWindow(
          title: bin.name,
          snippet: bin.address,
        ),
        onTap: () {
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(bin.lat, bin.lon),
              17,
            ),
          );
        },
      );
    }).toSet();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ゴミ箱マップ'),
      ),
      body: Column(
        children: [
          // 🔍 検索バー（確定式）
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '住所・ゴミ箱名で検索',
                prefixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    _search(_searchController.text);
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                _search(value); // Enter 押下
              },
            ),
          ),

          // 🗺 マップ
          Expanded(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: _initialPosition,
                zoom: 14,
              ),
              markers: _buildMarkers(),
              onMapCreated: (controller) {
                _mapController = controller;
              },
            ),
          ),
        ],
      ),
    );
  }
}
