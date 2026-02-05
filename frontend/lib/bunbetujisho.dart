import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'drawer_menu.dart';
import 'category_items_screen.dart';
import 'constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  UiLang _lang = UiLang.ja;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _trashItems = []; // 検索結果用
  List<dynamic> _groupedTrashList = []; // 索引リスト用
  bool _isLoading = false;
  bool _hasError = false;
  Timer? _debounce;

  final String _baseUrl = AppConstants.baseUrl;

  @override
  void initState() {
    super.initState();
    _fetchDictionary();
    _loadLanguageSetting();
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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
      final langCode = _lang == UiLang.ja ? 'ja' : 'en';
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
      final langCode = _lang == UiLang.ja ? 'ja' : 'en';
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

  void _onLanguageChanged(UiLang newLang) {
    setState(() {
      _lang = newLang;
      _searchController.clear();
      _trashItems = [];
    });
    _fetchDictionary();
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

  // ★ここを修正しました：DBの画像に合わせてIDを更新
  String _getTrashTypeName(dynamic item) {
    final id = int.tryParse(item['trash_type_id']?.toString() ?? '') ?? 0;

    if (_lang == UiLang.ja) {
      switch (id) {
        case 1:
          return '燃やせるごみ';
        case 2:
          return '燃やせないごみ';
        case 3:
          return '資源物'; // 念のため残す
        case 8:
          return 'びん・缶・ペットボトル'; // DB画像参照
        case 9:
          return '容器包装プラスチック'; // DB画像参照
        case 10:
          return '雑がみ'; // DB画像参照
        case 11:
          return '枝・葉・草'; // DB画像参照
        case 99:
          return '大型ごみ'; // DB画像参照
        case 7:
          return 'スプレー缶・電池'; // 従来通り
        default:
          return item['trash_type'] ?? '不明';
      }
    } else {
      switch (id) {
        case 1:
          return 'Burnable Waste';
        case 2:
          return 'Non-burnable Waste';
        case 3:
          return 'Recyclables';
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
          return item['trash_type_en'] ?? item['trash_type'] ?? 'Unknown';
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
        return Colors.teal; // びん・缶・ペット
      case 9:
        return const Color.fromARGB(255, 23, 19, 224); // プラスチック
      case 10:
        return Colors.indigo; // 雑がみ
      case 11:
        return Colors.lightGreen; // 枝・葉
      case 99:
        return Colors.brown; // 大型ごみ
      case 7:
        return Colors.purple;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isJa = _lang == UiLang.ja;
    final title = isJa ? '分別辞書検索' : 'Waste Dictionary';
    final hintText = isJa ? 'ゴミの名前で検索...' : 'Search waste name...';

    final isSearching = _searchController.text.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color.fromARGB(
          255,
          0,
          221,
          155,
        ).withOpacity(0.8),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      drawer: LeftMenuDrawer(
        lang: _lang,
        selectedArea: '札幌市',
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
              _lang == UiLang.ja ? 'データを取得できませんでした' : 'Failed to load data',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchDictionary,
              icon: const Icon(Icons.refresh),
              label: Text(_lang == UiLang.ja ? '再読み込み' : 'Retry'),
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
          _lang == UiLang.ja ? '見つかりませんでした' : 'No results found',
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
          _lang == UiLang.ja ? 'データがありません' : 'No Data',
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
                _lang == UiLang.ja ? 'ゴミの種類' : 'Type',
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
                          lang: _lang,
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
                _lang == UiLang.ja ? '出し方のポイント' : 'Disposal Tips',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item['note'] ?? (_lang == UiLang.ja ? '特になし' : 'None'),
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
