import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'drawer_menu.dart';
import 'category_items_screen.dart';
import 'constants.dart';
import 'package:flutter/services.dart';

class SearchScreen extends StatefulWidget {
  // 親画面から言語設定を受け取る変数
  final UiLang initialLang;

  const SearchScreen({super.key, this.initialLang = UiLang.ja});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late UiLang _lang;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _trashItems = [];
  List<dynamic> _groupedTrashList = [];
  bool _isLoading = false;
  bool _hasError = false;
  Timer? _debounce;

  final String _baseUrl = AppConstants.baseUrl;

  String _selectedArea = '中央区';

  Map<String, dynamic> _trans = {};

  @override
  void initState() {
    super.initState();
    // 受け取った言語設定で初期化
    _lang = widget.initialLang;
    _fetchDictionary();
    // 念のため保存設定も確認（非同期）
    _checkSavedLanguage();
    _loadMenuSettings();
    _loadLanguageSetting().then((_) {
      // 言語設定の読み込みが終わってから翻訳ファイルをロード
      _loadTranslations();
    });
  }

  Future<void> _loadTranslations() async {
    try {
      final langCode = _lang.name; // 'ja', 'en' など
      final jsonString = await rootBundle.loadString(
        'assets/translations/$langCode.json',
      );
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

  String _t(String key) {
    return _trans[key] ?? key;
  }

  // ★追加: メニュー表示用に保存された地域を読み込む
  Future<void> _loadMenuSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // 通知設定で保存された地域があればそれを、なければデフォルトを表示
      _selectedArea = prefs.getString('noti_area') ?? '中央区';
    });
  }

  // ★追加: 保存された言語を読み込む関数
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
    }
  }

  Future<void> _checkSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLangStr = prefs.getString('app_lang');
      if (savedLangStr != null) {
        // 保存された文字列からUiLangを復元
        final foundLang = UiLang.values.firstWhere(
          (e) => e.name == savedLangStr,
          orElse: () => UiLang.ja,
        );
        // もし初期値と違っていたら更新
        if (mounted && _lang != foundLang) {
          setState(() {
            _lang = foundLang;
          });
          _fetchDictionary();
        }
      }
    } catch (e) {
      print("設定読み込みエラー: $e");
    }
  }

  Future<void> _saveLanguageSetting(UiLang lang) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_lang', lang.name);
    } catch (e) {
      print("設定保存エラー: $e");
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchDictionary() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final langCode = _lang.name;
      final response = await http
          .get(Uri.parse('$_baseUrl/api/trash_dictionary?lang=$langCode'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        if (mounted) {
          setState(() {
            _groupedTrashList = data;
            _isLoading = false;
          });
        }
      } else {
        if (mounted)
          setState(() {
            _isLoading = false;
            _hasError = true;
          });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
    }
  }

  Future<void> _fetchTrashData(String query) async {
    if (query.isEmpty) {
      setState(() => _trashItems = []);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final langCode = _lang.name;
      final encodedQuery = Uri.encodeComponent(query);
      final response = await http.get(
        Uri.parse('$_baseUrl/api/trash_search?q=$encodedQuery&lang=$langCode'),
      );

      if (response.statusCode == 200) {
        setState(() {
          _trashItems = json.decode(utf8.decode(response.bodyBytes));
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged(String text) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchTrashData(text);
    });
  }

  void _onLanguageChanged(UiLang newLang) async {
    // 1. 設定保存
    _saveLanguageSetting(newLang);

    // 2. 状態更新（UI言語を変更）
    setState(() {
      _lang = newLang;
      _isLoading = true; // 読み込み中の表示にする
    });

    // 3. UI翻訳テキスト（JSON）を再読み込み
    await _loadTranslations();

    // 4. ★ここを追加: サーバーから新しい言語でデータを再取得する
    if (_searchController.text.isEmpty) {
      // 検索していない場合 → 分別辞書リスト全体を再取得
      await _fetchDictionary();
    } else {
      // 検索中の場合 → 同じキーワードで再検索（結果を新言語にするため）
      await _fetchTrashData(_searchController.text);
    }
    
    // 念のためローディングを解除（各fetch関数内でも制御されていますが安全策として）
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _jumpToSection(String header) {
    int targetIndex = _groupedTrashList.indexWhere(
      (g) => g['header'] == header,
    );
    if (targetIndex != -1) {
      double offset = 0;
      for (int i = 0; i < targetIndex; i++) {
        offset += 40.0;
        final items = _groupedTrashList[i]['items'] as List;
        offset += items.length * 80.0;
      }

      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        if (offset > maxScroll) offset = maxScroll;
        _scrollController.animateTo(
          offset,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  // ★UI翻訳ヘルパー
  String _getUiText(String key) {
    // 簡易辞書
    final Map<String, Map<String, String>> dict = {
      'title': {'ja': '分別辞書検索', 'en': 'Dictionary', 'zh': '垃圾分类词典'},
      'hint': {'ja': 'ゴミの名前で検索...', 'en': 'Search...', 'zh': '搜索...'},
      'type': {'ja': 'ゴミの種類', 'en': 'Type', 'zh': '垃圾种类'},
      'tips': {'ja': '出し方のポイント', 'en': 'Disposal Tips', 'zh': '投放要点'},
      'none': {'ja': '特になし', 'en': 'None', 'zh': '无'},
      'no_data': {'ja': 'データがありません', 'en': 'No Data', 'zh': '无数据'},
      'not_found': {
        'ja': '見つかりませんでした',
        'en': 'No results found',
        'zh': '未找到结果',
      },
      'error': {
        'ja': 'データを取得できませんでした',
        'en': 'Failed to load data',
        'zh': '加载失败',
      },
      'retry': {'ja': '再読み込み', 'en': 'Retry', 'zh': '重试'},
    };

    String langKey = 'en';
    if (_lang == UiLang.ja)
      langKey = 'ja';
    else if (_lang.name.startsWith('zh'))
      langKey = 'zh'; // 中国語系対応

    return dict[key]?[langKey] ?? dict[key]?['en'] ?? '';
  }

  // ゴミ種別のフォールバック名（サーバーデータがない場合のみ使用）
  String _getTrashTypeName(dynamic item) {
    if (item['type'] != null && item['type'].toString().isNotEmpty) {
      return item['type'];
    }

    // フォールバック辞書
    final id = int.tryParse(item['trash_type_id']?.toString() ?? '') ?? 0;

    // 日本語
    if (_lang == UiLang.ja) {
      switch (id) {
        case 1:
          return '燃やせるごみ';
        case 2:
          return '燃やせないごみ';
        case 8:
          return 'びん・缶・ペットボトル';
        case 9:
          return '容器包装プラスチック';
        case 10:
          return '雑がみ';
        case 11:
          return '枝・葉・草';
        case 99:
          return '大型ごみ';
        case 7:
          return 'スプレー缶・電池';
        default:
          return '不明';
      }
    }
    // 中国語
    else if (_lang.name.startsWith('zh')) {
      switch (id) {
        case 1:
          return '可燃垃圾';
        case 2:
          return '不可燃垃圾';
        case 8:
          return '瓶/罐/塑料瓶';
        case 9:
          return '塑料容器包装';
        case 10:
          return '杂纸';
        case 11:
          return '树枝/树叶/草';
        case 99:
          return '大件垃圾';
        case 7:
          return '喷雾罐/电池';
        default:
          return '未知';
      }
    }
    // 英語（その他）
    else {
      switch (id) {
        case 1:
          return 'Burnable Waste';
        case 2:
          return 'Non-burnable Waste';
        case 8:
          return 'Bottles/Cans/PET';
        case 9:
          return 'Plastic Containers';
        case 10:
          return 'Mixed Paper';
        case 11:
          return 'Leaves/Grass';
        case 99:
          return 'Oversized Garbage';
        case 7:
          return 'Spray Cans/Batteries';
        default:
          return 'Unknown';
      }
    }
  }

  Color _getTrashColor(dynamic item) {
    final id = int.tryParse(item['trash_type_id']?.toString() ?? '') ?? 0;
    switch (id) {
      case 1:
        return Colors.orange;
      case 2:
        return Colors.blue;
      case 8:
        return Colors.teal;
      case 9:
        return const Color.fromARGB(255, 23, 19, 224);
      case 10:
        return Colors.indigo;
      case 11:
        return Colors.lightGreen;
      case 99:
        return Colors.brown;
      case 7:
        return Colors.purple;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    // UIテキスト取得
    final title = _t('dictionary');
    final hintText = _t('search_hint');
    final isSearching = _searchController.text.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color.fromARGB(
          255,
          3,
          240,
          169,
        ).withOpacity(0.8),
        foregroundColor: const Color.fromARGB(255, 0, 0, 0),
        centerTitle: false,
      ),
      drawer: LeftMenuDrawer(
        lang: _lang,
        selectedArea: _selectedArea,
        onLangChanged: _onLanguageChanged,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: hintText,
                  prefixIcon: const Icon(Icons.search, color: Colors.green),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.85),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: _buildListContent(isSearching)),
                  if (!isSearching && _groupedTrashList.isNotEmpty)
                    _buildIndexBar(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListContent(bool isSearching) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.green),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              _getUiText('error'),
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchDictionary,
              icon: const Icon(Icons.refresh),
              label: Text(_getUiText('retry')),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    if (isSearching) {
      return _buildSearchResults();
    } else {
      return _buildGroupedList();
    }
  }

  Widget _buildSearchResults() {
    if (_trashItems.isEmpty) {
      return Center(
        child: Text(
          _getUiText('not_found'),
          style: const TextStyle(color: Colors.black54),
        ),
      );
    }
    return ListView.builder(
      itemCount: _trashItems.length,
      itemBuilder: (context, index) => _buildItemCard(_trashItems[index]),
    );
  }

  Widget _buildIndexBar() {
    final List<String> headers;
    if (_lang == UiLang.ja) {
      headers = ["あ", "か", "さ", "た", "な", "は", "ま", "や", "ら", "わ", "他"];
    } else {
      headers = List.generate(
        26,
        (index) => String.fromCharCode('A'.codeUnitAt(0) + index),
      );
      headers.add('#');
    }

    return Container(
      width: 40,
      margin: const EdgeInsets.only(left: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.4),
        border: Border(left: BorderSide(color: Colors.green.withOpacity(0.2))),
      ),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: headers
                .map(
                  (h) => GestureDetector(
                    onTap: () => _jumpToSection(h),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        h,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupedList() {
    if (_groupedTrashList.isEmpty) {
      return Center(
        child: Text(
          _getUiText('no_data'),
          style: const TextStyle(color: Colors.black54),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: _groupedTrashList.length,
      itemBuilder: (context, index) {
        final group = _groupedTrashList[index];
        final String header = group['header'] ?? '';
        final List<dynamic> items = group['items'] ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              color: Colors.white.withOpacity(0.5),
              padding: const EdgeInsets.only(left: 16.0, top: 8.0, bottom: 8.0),
              child: Text(
                header,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            ...items.map((item) => _buildItemCard(item)).toList(),
          ],
        );
      },
    );
  }

  Widget _buildItemCard(dynamic item) {
    return Card(
      color: Colors.white.withOpacity(0.9),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        onTap: () => _showDetail(item),
        title: Text(
          item['name'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          _getTrashTypeName(item),
          style: TextStyle(
            color: _getTrashColor(item),
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
      ),
    );
  }

  void _showDetail(dynamic item) {
    final Color themeColor = _getTrashColor(item);
    final String typeName = _getTrashTypeName(item);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                item['name'] ?? '',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _getUiText('type'), // ★翻訳対応
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    final int tid =
                        int.tryParse(item['trash_type_id']?.toString() ?? '') ??
                        0;
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CategoryItemsScreen(
                          trashTypeId: tid,
                          typeName: typeName,
                          themeColor: themeColor,
                          lang: _lang, // 言語設定を引き継ぎ
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: themeColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: themeColor.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          typeName,
                          style: TextStyle(
                            color: themeColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: themeColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Divider(height: 40),
              Text(
                _getUiText('tips'), // ★翻訳対応
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item['note'] ?? _getUiText('none'), // ★翻訳対応
                style: const TextStyle(fontSize: 16, height: 1.6),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}
