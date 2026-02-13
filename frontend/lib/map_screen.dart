import 'dart:math';
import 'dart:convert';
import 'package:flutter/services.dart';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
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
  
  // 翻訳データを入れる変数
  Map<String, dynamic> _trans = {};

  List<TrashBin> _allBins = [];
  List<TrashBin> _searchedBins = [];
  List<TrashBin> _filteredBins = [];
  Set<Marker> _markers = {};

  final TextEditingController _searchController = TextEditingController();
  static const LatLng _initialPosition = LatLng(43.062, 141.354); // 札幌

  bool _isInitLangFromArgs = false;

  // ===== 絞り込み状態 =====
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
    // 言語設定を読み込み、その後JSONも読み込む
    _loadLanguageSetting().then((_) {
      _loadTranslations();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // ★修正: まだ引数から設定していない場合のみ実行する
    if (!_isInitLangFromArgs) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is UiLang) {
        // 引数と言語が違う場合のみ適用（ここは初期表示用）
        if (_lang != args) {
          setState(() {
            _lang = args;
          });
          _loadTranslations();
        }
      }
      _isInitLangFromArgs = true; // 完了フラグを立てる
    }
  }

  // ★翻訳ファイルを読み込む関数
  Future<void> _loadTranslations() async {
    try {
      final langCode = _lang.name;
      final jsonString = await rootBundle.loadString('assets/translations/$langCode.json');
      final data = json.decode(jsonString);
      if (mounted) {
        setState(() {
          _trans = Map<String, dynamic>.from(data);
        });
      }
    } catch (e) {
      debugPrint('Error loading translation file: $e');
    }
  }

  // 翻訳ヘルパー関数（キーが無ければそのままキーを表示）
  String _t(String key) {
    return _trans[key] ?? key;
  }

  Future<void> _loadLanguageSetting() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLang = prefs.getString('app_lang');
    if (savedLang != null) {
      setState(() {
        _lang = UiLang.values.firstWhere(
          (e) => e.name == savedLang,
          orElse: () => UiLang.ja,
        );
      });
      // 言語設定をロードしたら翻訳も更新
      _loadTranslations();
    }
  }

  // ピンの色設定（省略：変更なし）
  double _getPinColor(String type) {
    if (type.contains('古紙') || type.contains('びん')) return BitmapDescriptor.hueGreen;
    if (type.contains('小型家電')) return BitmapDescriptor.hueBlue;
    if (type.contains('蛍光管') || type.contains('電池')) return BitmapDescriptor.hueOrange;
    if (type.contains('古着')) return BitmapDescriptor.hueViolet;
    if (type.contains('油')) return BitmapDescriptor.hueYellow;
    return BitmapDescriptor.hueRed;
  }
  
  // UI色設定（省略：変更なし）
  Color _getUiColor(String type) {
    if (type.contains('古紙') || type.contains('びん')) return Colors.green;
    if (type.contains('小型家電')) return Colors.blue;
    if (type.contains('蛍光管') || type.contains('電池')) return Colors.orange;
    if (type.contains('古着')) return Colors.purple;
    if (type.contains('油')) return Colors.yellow; 
    return Colors.red;
  }

  // API取得（省略：変更なし）
  Future<void> _loadBins() async {
    final bins = await TrashBinApi.fetchBins();
    setState(() {
      _allBins = bins;
      _searchedBins = [];
      _filteredBins = [];
      _markers.clear();
    });
  }

  // 検索（省略：変更なし）
  void _search(String keyword) {
    final normalized = keyword.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    setState(() {
      if (normalized.isEmpty) {
        _searchedBins = [];
      } else {
        _searchedBins = _allBins.where((bin) {
          final name = bin.name.toLowerCase().replaceAll(RegExp(r'\s+'), '');
          final address = bin.address.toLowerCase().replaceAll(RegExp(r'\s+'), '');
          return name.contains(normalized) || address.contains(normalized);
        }).toList();
      }
    });
    _applyFilters();
  }

  // 全件表示（省略：変更なし）
  void _showAllBins() {
    setState(() {
      _searchController.clear();
      _searchedBins = List.from(_allBins);
    });
    _applyFilters();
  }

  // 絞り込み適用（省略：変更なし）
  void _applyFilters() {
    final active = _filters.entries.where((e) => e.value).map((e) => e.key).toList();
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

  // マーカー生成（省略：変更なし）
  void _updateMarkers() {
    _markers = _filteredBins.map((bin) {
      return Marker(
        markerId: MarkerId(bin.id.toString()),
        position: LatLng(bin.lat, bin.lon),
        icon: BitmapDescriptor.defaultMarkerWithHue(_getPinColor(bin.type)),
        // ★ここは日本語のまま（ピンの情報）
        infoWindow: InfoWindow(
          title: bin.name,
          snippet: bin.type,
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

  // 詳細BottomSheet
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
            // ★住所や名前はAPIから来る日本語のまま
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
              label: Text(_t('open_google_map')),
              onPressed: () async {
                // 修正: Google Mapsのルート案内URLスキームを使用
                // api=1: API使用宣言
                // destination: 目的地の緯度経度
                // dir_action=navigate: ナビゲーションモード（省略可だが明示的）
                final urlString = 'https://www.google.com/maps/dir/?api=1&destination=${bin.lat},${bin.lon}';
    
                final uri = Uri.parse(urlString);
    
                // URLを開く（外部アプリ起動モード）
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  // 万が一開けない場合のエラーハンドリング（デバッグ用）
                  debugPrint('Could not launch $uri');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  // 絞り込みシート
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
                  // ★修正: タイトルを翻訳キーに
                  Text(_t('filter_title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ...tempFilters.keys.map((key) {
                    return CheckboxListTile(
                      title: Row(
                        children: [
                          Text(key), // フィルターの種類名は日本語データのまま
                          const SizedBox(width: 8),
                          Icon(Icons.circle, color: _getUiColor(key), size: 16),
                        ],
                      ),
                      value: tempFilters[key],
                      onChanged: (v) => setModalState(() => tempFilters[key] = v!),
                      activeColor: _getUiColor(key),
                    );
                  }),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => setModalState(() => tempFilters.updateAll((k, v) => false)),
                        // ★修正: リセットボタン
                        child: Text(_t('filter_reset')), 
                      ),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _filters.clear();
                            _filters.addAll(tempFilters);
                          });
                          _applyFilters();
                          Navigator.pop(context);
                        },
                        // ★修正: 適用ボタン
                        child: Text(_t('filter_apply')), 
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

  Future<void> _getCurrentLocation() async {
    // 1. 位置情報サービスが有効か確認
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    // 2. 権限の確認
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // 権限がない場合はリクエストする
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied.');
    }

    // 3. 現在地を取得
    final position = await Geolocator.getCurrentPosition();

    // 4. マップカメラを現在地に移動
    _mapController?.animateCamera(
      CameraUpdate.newLatLng(
        LatLng(position.latitude, position.longitude),
      ),
    );
  }

  // 「？」ボタン説明ダイアログ
  void _showMapHelp() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _t('map_help_title'),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _t('map_help_desc_1'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  _t('map_help_desc_2'),
                  style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(_t('map_help_desc_3')),
                // ... (省略：ここは既に _t() になっていたのでOK)
                const SizedBox(height: 12),
                Text(
                  _t('map_help_source'),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(_t('map_help_close')),
            ),
          ],
        );
      },
    );
  }

  // ======================
  // UI Build
  // ======================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // ★修正: .tr()を削除し、_t()のみを使用
        title: Text(_t("map_title")), 
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: _t('map_help_title'),
            onPressed: _showMapHelp,
          ),
        ],
      ),
      drawer: LeftMenuDrawer(
        lang: _lang,
        selectedArea: '札幌市',
        onLangChanged: (newLang) async { // ★asyncにする
          // 1. 画面の言語更新
          setState(() {
            _lang = newLang;
          });
    
          // 2. 翻訳ファイル再読み込み
          await _loadTranslations();
    
          // 3. ★追加: 設定を保存しないと次回起動時に戻ってしまう
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('app_lang', newLang.name);
        },
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              onSubmitted: _search,
              decoration: InputDecoration(
                hintText: _t('search_hint'), // ここはOK
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(30)),
                ),
                filled: true,
                fillColor: Colors.white,
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
              onMapCreated: (c) {
                _mapController = c;
                _getCurrentLocation(); // ここで呼び出す
              },
              myLocationEnabled: true,       // 青い点を表示（権限があれば出る）
              myLocationButtonEnabled: true, // 現在地に戻るボタンを表示
              padding: const EdgeInsets.only(bottom: 20),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FloatingActionButton.extended(
            heroTag: 'filter',
            onPressed: _openFilterSheet,
            backgroundColor: Colors.white,
            icon: const Icon(Icons.tune, color: Colors.black87),
            // ★修正: ハードコーディングされていた「絞り込み」を翻訳キーに
            label: Text(_t('btn_filter'), style: const TextStyle(color: Colors.black87)),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'all',
            icon: const Icon(Icons.map),
            // ★修正: ハードコーディングされていた「全件表示」を翻訳キーに
            label: Text(_t('btn_show_all')),
            onPressed: _showAllBins,
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}