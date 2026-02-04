import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'trash_bin_api.dart'; // API側のTrashBinクラスを使用します
import 'drawer_menu.dart';

// ★削除: ここにあった class TrashBin { ... } は削除しました。
// trash_bin_api.dart の定義を使用することで型不一致エラーを解消します。

class TrashBinMapScreen extends StatefulWidget {
  const TrashBinMapScreen({super.key});

  @override
  State<TrashBinMapScreen> createState() => _TrashBinMapScreenState();
}

class _TrashBinMapScreenState extends State<TrashBinMapScreen> {
  GoogleMapController? _mapController;

  // ★追加: 言語設定用の変数 (Undefined name '_lang' エラーの修正)
  UiLang _lang = UiLang.ja;

  List<TrashBin> _allBins = [];
  List<TrashBin> _searchedBins = [];
  List<TrashBin> _filteredBins = [];
  Set<Marker> _markers = {};

  final TextEditingController _searchController = TextEditingController();

  static const LatLng _initialPosition = LatLng(43.062, 141.354); // 札幌中心

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
  }

  // ★追加: 画面遷移時に引数を受け取る処理
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is UiLang) {
      setState(() {
        _lang = args;
      });
    }
  }

  Future<void> _loadBins() async {
    final bins = await TrashBinApi.fetchBins();
    setState(() {
      _allBins = bins;
      _searchedBins = [];
      _filteredBins = [];
      _markers = {};
    });
  }

  /// ======================
  /// 地域検索
  /// ======================
  void _search(String keyword) {
    final normalized = keyword.toLowerCase().replaceAll(RegExp(r'\s+'), '');

    setState(() {
      if (normalized.isEmpty) {
        _searchedBins = [];
      } else {
        _searchedBins = _allBins.where((bin) {
          final name = bin.name.toLowerCase().replaceAll(RegExp(r'\s+'), '');
          final address = bin.address.toLowerCase().replaceAll(
            RegExp(r'\s+'),
            '',
          );
          return name.contains(normalized) || address.contains(normalized);
        }).toList();
      }
    });

    _applyFilters();
  }

  /// ======================
  /// 全件表示
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
    final active = _filters.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    setState(() {
      if (active.isEmpty) {
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
        // API側の定義(lon)を使用するため、ここはエラーになりません
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
  /// 詳細 BottomSheet
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
                final query = Uri.encodeComponent('${bin.name} ${bin.address}');

                final uri = Uri.parse(
                  'https://www.google.com/maps/search/?api=1&query=$query',
                );

                if (await canLaunchUrl(uri)) {
                  launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// ======================
  /// 絞り込み BottomSheet（適用ボタンあり）
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '絞り込み',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  ...tempFilters.keys.map((key) {
                    return CheckboxListTile(
                      title: Text(key),
                      value: tempFilters[key],
                      onChanged: (v) {
                        setModalState(() {
                          tempFilters[key] = v!;
                        });
                      },
                    );
                  }),

                  const SizedBox(height: 8),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            tempFilters.updateAll((k, v) => false);
                          });
                        },
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
      // ★修正: isJa変数を使用してタイトルを設定 (未使用エラーの解消)
      appBar: AppBar(
        title: Text(isJa ? 'ゴミ箱マップ' : 'Trash Map'),
        elevation: 0,
      ),

      // ★修正: onLangChangedを追加 (必須パラメータエラーの解消)
      drawer: LeftMenuDrawer(
        lang: _lang,
        selectedArea: '札幌市',
        onLangChanged: (newLang) => setState(() => _lang = newLang),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,

      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Material(
                elevation: 2,
                borderRadius: BorderRadius.circular(30),
                child: TextField(
                  controller: _searchController,
                  onSubmitted: _search,
                  decoration: const InputDecoration(
                    hintText: '地域を検索',
                    prefixIcon: Icon(Icons.search),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
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