import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'trash_bin_api.dart';
import 'drawer_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TrashBinMapScreen extends StatefulWidget {
  const TrashBinMapScreen({super.key});

  @override
  State<TrashBinMapScreen> createState() => _TrashBinMapScreenState();
}

class _TrashBinMapScreenState extends State<TrashBinMapScreen> {
  GoogleMapController? _mapController;

  UiLang _lang = UiLang.ja;

  List<TrashBin> _allBins = [];
  List<TrashBin> _searchedBins = [];
  List<TrashBin> _filteredBins = [];
  Set<Marker> _markers = {};

  final TextEditingController _searchController = TextEditingController();

  static const LatLng _initialPosition = LatLng(43.062, 141.354); // 札幌

  /// ===== 絞り込み状態 =====
  final Map<String, bool> _filters = {
    '古紙・リターナブルびん': false,
    '小型家電': false,
    '蛍光管': false,
    '古着': false,
    '使用済み食用油': false,
  };

  @override
  void initState() {
    super.initState();
    _loadBins();
    _loadLanguageSetting();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is UiLang) {
      _lang = args;
    }
  }

  /// ======================
  /// API取得（※ 起動時は表示しない）
  /// ======================
  Future<void> _loadBins() async {
    final bins = await TrashBinApi.fetchBins();
    setState(() {
      _allBins = bins;
      _searchedBins = [];
      _filteredBins = [];
      _markers.clear(); // ★起動時はピン0
    });
  }

  Future<void> _loadLanguageSetting() async {
    final prefs = await SharedPreferences.getInstance(); // import 'package:shared_preferences/shared_preferences.dart'; が必要です
    final savedLang = prefs.getString('app_lang');
    if (savedLang != null) {
      setState(() {
        _lang = UiLang.values.firstWhere(
          (e) => e.name == savedLang,
          orElse: () => UiLang.ja,
        );
      });
    }
  }

  /// ======================
  /// 検索
  /// ======================
  void _search(String keyword) {
    final normalized = keyword.toLowerCase().replaceAll(RegExp(r'\s+'), '');

    setState(() {
      if (normalized.isEmpty) {
        _searchedBins = [];
      } else {
        _searchedBins = _allBins.where((bin) {
          final name = bin.name.toLowerCase().replaceAll(RegExp(r'\s+'), '');
          final address =
              bin.address.toLowerCase().replaceAll(RegExp(r'\s+'), '');
          return name.contains(normalized) || address.contains(normalized);
        }).toList();
      }
    });

    _applyFilters();
  }

  /// ======================
  /// 全件表示（← 押した時だけピン出る）
  /// ======================
  void _showAllBins() {
    setState(() {
      _searchController.clear();
      _searchedBins = List.from(_allBins);
    });
    _applyFilters();
  }

  /// ======================
  /// 絞り込み適用
  /// ======================
  void _applyFilters() {
    final active =
        _filters.entries.where((e) => e.value).map((e) => e.key).toList();

    setState(() {
      if (_searchedBins.isEmpty) {
        _filteredBins = [];
      } else if (active.isEmpty) {
        _filteredBins = List.from(_searchedBins);
      } else {
        _filteredBins = _searchedBins.where((bin) {
          return active.any((f) => bin.type.contains(f));
        }).toList();
      }
    });

    _updateMarkers();
    _moveCameraToBounds();
  }

  /// ======================
  /// マーカー生成
  /// ======================
  void _updateMarkers() {
    _markers = _filteredBins.map((bin) {
      return Marker(
        markerId: MarkerId(bin.id.toString()),
        position: LatLng(bin.lat, bin.lon),
        infoWindow: InfoWindow(
          title: bin.name,
          snippet: '${bin.address}\n種類: ${bin.type}',
        ),
        onTap: () => _showBinSheet(bin),
      );
    }).toSet();

    setState(() {});
  }

  void _moveCameraToBounds() {
    if (_filteredBins.isEmpty || _mapController == null) return;

    double minLat = _filteredBins.first.lat;
    double maxLat = _filteredBins.first.lat;
    double minLon = _filteredBins.first.lon;
    double maxLon = _filteredBins.first.lon;

    for (final b in _filteredBins) {
      minLat = min(minLat, b.lat);
      maxLat = max(maxLat, b.lat);
      minLon = min(minLon, b.lon);
      maxLon = max(maxLon, b.lon);
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLon),
          northeast: LatLng(maxLat, maxLon),
        ),
        80,
      ),
    );
  }

  /// ======================
  /// 詳細BottomSheet
  /// ======================
  void _showBinSheet(TrashBin bin) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              bin.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(bin.address),
            Text('種類: ${bin.type}'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.map),
              label: const Text('Googleマップで開く'),
              onPressed: () async {
                final query =
                    Uri.encodeComponent('${bin.name} ${bin.address}');
                final uri = Uri.parse(
                  'https://www.google.com/maps/search/?api=1&query=$query',
                );
                if (await canLaunchUrl(uri)) {
                  launchUrl(uri,
                      mode: LaunchMode.externalApplication);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// ======================
  /// 絞り込みシート
  /// ======================
  void _openFilterSheet() {
    final tempFilters = Map<String, bool>.from(_filters);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('絞り込み',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ...tempFilters.keys.map((key) {
                    return CheckboxListTile(
                      title: Text(key),
                      value: tempFilters[key],
                      onChanged: (v) =>
                          setModalState(() => tempFilters[key] = v!),
                    );
                  }),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => setModalState(() =>
                            tempFilters.updateAll((k, v) => false)),
                        child: const Text('リセット'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _filters
                              ..clear()
                              ..addAll(tempFilters);
                          });
                          _applyFilters();
                          Navigator.pop(context);
                        },
                        child: const Text('適用'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// ======================
  /// UI
  /// ======================
  @override
  Widget build(BuildContext context) {
    final isJa = _lang == UiLang.ja;

    return Scaffold(
      appBar: AppBar(
        title: Text(isJa ? 'ゴミ箱マップ' : 'Trash Map'),
      ),
      drawer: LeftMenuDrawer(
        lang: _lang,
        selectedArea: '札幌市',
        onLangChanged: (l) => setState(() => _lang = l),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onSubmitted: _search,
              decoration: const InputDecoration(
                hintText: '地域を検索',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(30)),
                ),
              ),
            ),
          ),
          Expanded(
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: _initialPosition,
                zoom: 14,
              ),
              markers: _markers,
              onMapCreated: (c) => _mapController = c,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'all',
            icon: const Icon(Icons.list),
            label: const Text('全件'),
            onPressed: _showAllBins,
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'filter',
            onPressed: _openFilterSheet,
            child: const Icon(Icons.tune),
          ),
        ],
      ),
    );
  }
}
