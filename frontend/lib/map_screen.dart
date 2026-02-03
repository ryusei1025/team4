import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'drawer_menu.dart';
import 'constants.dart';

// ゴミ箱データモデル
class TrashBin {
  final int id;
  final String name;
  final String address;
  final double lat;
  final double lng;
  final String type;

  TrashBin({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    required this.type,
  });

  factory TrashBin.fromJson(Map<String, dynamic> json) {
    return TrashBin(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      lat: (json['lat'] ?? 0.0).toDouble(),
      lng: (json['lng'] ?? 0.0).toDouble(),
      type: json['type'] ?? 'unknown',
    );
  }
}

class TrashBinMapScreen extends StatefulWidget {
  const TrashBinMapScreen({super.key});

  @override
  State<TrashBinMapScreen> createState() => _TrashBinMapScreenState();
}

class _TrashBinMapScreenState extends State<TrashBinMapScreen> {
  GoogleMapController? _mapController;

  List<TrashBin> _allBins = [];
  Set<Marker> _markers = {};

  final TextEditingController _searchController = TextEditingController();
  static const LatLng _initialPosition = LatLng(43.068661, 141.350755); // 札幌駅周辺

  UiLang _lang = UiLang.ja;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchBins();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is UiLang) {
      if (_lang != args) {
        setState(() {
          _lang = args;
        });
      }
    }
  }

  Future<void> _fetchBins() async {
    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('${AppConstants.baseUrl}/api/trash_bins');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        final List<TrashBin> loadedBins = data
            .map((json) => TrashBin.fromJson(json))
            .toList();

        setState(() {
          _allBins = loadedBins;
          _updateMarkers(_allBins);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('通信エラー: $e');
      setState(() => _isLoading = false);
    }
  }

  void _updateMarkers(List<TrashBin> bins) {
    final Set<Marker> newMarkers = bins.map((bin) {
      return Marker(
        markerId: MarkerId(bin.id.toString()),
        position: LatLng(bin.lat, bin.lng),
        infoWindow: InfoWindow(title: bin.name, snippet: bin.address),
        icon: BitmapDescriptor.defaultMarkerWithHue(_getPinColor(bin.type)),
      );
    }).toSet();

    setState(() {
      _markers = newMarkers;
    });
  }

  double _getPinColor(String type) {
    if (type.contains('燃やせる') || type == 'burnable')
      return BitmapDescriptor.hueOrange;
    if (type.contains('燃やせない') || type == 'non_burnable')
      return BitmapDescriptor.hueBlue;
    if (type.contains('資源') || type == 'recyclable')
      return BitmapDescriptor.hueGreen;
    if (type.contains('プラスチック') || type == 'plastic')
      return BitmapDescriptor.hueCyan;
    return BitmapDescriptor.hueRed;
  }

  void _search(String query) {
    if (query.isEmpty) {
      _updateMarkers(_allBins);
      return;
    }

    final filtered = _allBins.where((bin) {
      return bin.name.contains(query) || bin.address.contains(query);
    }).toList();

    _updateMarkers(filtered);

    if (filtered.isNotEmpty && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(filtered.first.lat, filtered.first.lng),
          15,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isJa = _lang == UiLang.ja;

    return Scaffold(
      appBar: AppBar(
        title: Text(isJa ? 'ゴミ箱マップ' : 'Trash Bin Map'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      // ★ 修正箇所：onLangChanged を追加
      drawer: LeftMenuDrawer(
        lang: _lang,
        selectedArea: '中央区',
        onLangChanged: (newLang) {
          setState(() {
            _lang = newLang;
          });
        },
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _initialPosition,
              zoom: 14,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            onMapCreated: (controller) {
              _mapController = controller;
            },
          ),

          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: isJa ? '住所や場所名で検索' : 'Search address or place',
                  prefixIcon: const Icon(Icons.search, color: Colors.green),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      _searchController.clear();
                      _search('');
                      FocusScope.of(context).unfocus();
                    },
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: _search,
              ),
            ),
          ),

          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_mapController != null) {
            _mapController!.animateCamera(
              CameraUpdate.newLatLng(_initialPosition),
            );
          }
        },
        backgroundColor: Colors.white,
        child: const Icon(Icons.my_location, color: Colors.green),
      ),
    );
  }
}
