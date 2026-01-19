import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'trash_bin_api.dart';
import 'drawer_menu.dart';

class TrashBinMapScreen extends StatefulWidget {
  const TrashBinMapScreen({super.key});

  @override
  State<TrashBinMapScreen> createState() => _TrashBinMapScreenState();
}

class _TrashBinMapScreenState extends State<TrashBinMapScreen> {
  GoogleMapController? _mapController;
  List<TrashBin> _allBins = [];
  List<TrashBin> _filteredBins = [];
  Set<Marker> _markers = {}; // マーカーをセットとして保持
  final TextEditingController _searchController = TextEditingController();
  static const LatLng _initialPosition = LatLng(43.062, 141.354);

  @override
  void initState() {
    super.initState();
    _loadBins();
  }

  /// Flask API からゴミ箱一覧取得
  Future<void> _loadBins() async {
    try {
      final bins = await TrashBinApi.fetchBins();
      setState(() {
        _allBins = bins;
        _filteredBins = bins;
        _updateMarkers(); // 取得後にマーカーを生成
      });
    } catch (e) {
      debugPrint("API Error: $e");
    }
  }

  /// マーカーセットを更新する
  void _updateMarkers() {
    final newMarkers = _filteredBins.map((bin) {
      return Marker(
        markerId: MarkerId(bin.id.toString()),
        position: LatLng(bin.lat, bin.lon),
        infoWindow: InfoWindow(title: bin.name, snippet: bin.address),
        onTap: () {
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(LatLng(bin.lat, bin.lon), 17),
          );
        },
      );
    }).toSet();

    setState(() {
      _markers = newMarkers;
    });
  }

  /// あいまい検索
  void _search(String keyword) {
    final normalizedKeyword = keyword.toLowerCase().replaceAll(
      RegExp(r'\s+'),
      '',
    );
    setState(() {
      if (normalizedKeyword.isEmpty) {
        _filteredBins = _allBins;
      } else {
        _filteredBins = _allBins.where((bin) {
          final name = bin.name.toLowerCase().replaceAll(RegExp(r'\s+'), '');
          final address = bin.address.toLowerCase().replaceAll(
            RegExp(r'\s+'),
            '',
          );
          return name.contains(normalizedKeyword) ||
              address.contains(normalizedKeyword);
        }).toList();
      }
      _updateMarkers(); // 検索後にマーカーを再生成
    });

    if (_filteredBins.isNotEmpty && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(_filteredBins[0].lat, _filteredBins[0].lon),
          15,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // メニュー（drawer_menu.dart）を呼び出し
      drawer: const LeftMenuDrawer(lang: UiLang.ja, selectedArea: '札幌市'),
      appBar: AppBar(
        title: const Text(
          'ゴミ箱マップ',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '住所・ゴミ箱名で検索',
                  prefixIcon: const Icon(Icons.search, color: Colors.green),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.85),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: _search,
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
                child: GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: _initialPosition,
                    zoom: 14,
                  ),
                  markers: _markers, // 保持しているマーカーセットを表示
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
