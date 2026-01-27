import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'drawer_menu.dart';
import 'category_items_screen.dart';
import 'constants.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  UiLang _lang = UiLang.ja;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _trashItems = []; // サーバーからの検索結果を格納
  List<dynamic> _groupedTrashList = []; // 初期表示用の50音リスト
  bool _isLoading = false;
  Timer? _debounce;

  // final String _baseUrl = 'http://10.0.2.2:5000';
  final String _baseUrl = AppConstants.baseUrl;

  @override
  void initState() {
    super.initState();
    _fetchDictionary(); // 最初の「あかさたな」リストを取得
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // 初期リスト取得
  Future<void> _fetchDictionary() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });
    try {
      final String langCode = _lang == UiLang.ja ? 'ja' : 'en';
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
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _isLoading = false;
        });
    }
  }

  // --- ★ サーバーのDB(name_kana)に対して検索をかける関数 ---
  Future<void> _fetchTrashData(String query) async {
    if (query.isEmpty) {
      setState(() {
        _trashItems = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });
    try {
      // サーバーの /api/trash_search にクエリを送る
      final response = await http.get(
        Uri.parse('$_baseUrl/api/trash_search?q=${Uri.encodeComponent(query)}'),
      );

      if (response.statusCode == 200) {
        setState(() {
          _trashItems = json.decode(utf8.decode(response.bodyBytes));
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String text) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchTrashData(text); // 入力が止まって500ms後にDB検索実行
    });
  }

  // インデックスジャンプ（初期リスト用）
  void _jumpToSection(String header) {
    int targetIndex = _groupedTrashList.indexWhere(
      (group) => group['header'] == header,
    );
    if (targetIndex != -1) {
      double offset = 0;
      for (int i = 0; i < targetIndex; i++) {
        offset += 40.0;
        offset += (_groupedTrashList[i]['items'] as List).length * 80.0;
      }
      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  String _getTrashTypeName(dynamic item) {
    final String serverName =
        item['trash_type'] ?? item['trash_type_name'] ?? '不明';
    final id = int.tryParse(item['trash_type_id']?.toString() ?? '') ?? 0;
    switch (id) {
      case 1:
        return '燃やせるごみ';
      case 2:
        return '燃やせないごみ';
      case 3:
        return '資源物';
      case 4:
        return '粗大ごみ';
      case 5:
        return 'びん・缶・ペットボトル';
      case 6:
        return '容器包装プラスチック';
      case 7:
        return 'スプレー缶・電池';
      default:
        return serverName;
    }
  }

  Color _getTrashColor(dynamic item) {
    final id = int.tryParse(item['trash_type_id']?.toString() ?? '') ?? 0;
    switch (id) {
      case 1:
        return Colors.orange;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.green;
      case 4:
        return Colors.brown;
      case 5:
        return Colors.teal;
      case 6:
        return Colors.pinkAccent;
      case 7:
        return Colors.purple;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: LeftMenuDrawer(lang: _lang, selectedArea: '札幌市'),
      appBar: AppBar(title: const Text('分別辞書検索')),
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
                decoration: InputDecoration(
                  hintText: 'ゴミの名前で検索...',
                  prefixIcon: const Icon(Icons.search, color: Colors.green),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.85),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: _onSearchChanged, // DB検索をトリガー
              ),
            ),
            Expanded(
              child: Row(
                children: [
                  if (_searchController.text.isEmpty &&
                      _groupedTrashList.isNotEmpty)
                    _buildIndexBar(),

                  Expanded(
                    child: _isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Colors.green,
                            ),
                          )
                        : _searchController.text.isEmpty
                        ? _buildGroupedList()
                        : _buildSearchResultList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndexBar() {
    final headers = ["あ", "か", "さ", "た", "な", "は", "ま", "や", "ら", "わ"];
    return Container(
      width: 45,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.3),
        border: Border(right: BorderSide(color: Colors.green.withOpacity(0.1))),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: headers
            .map(
              (h) => GestureDetector(
                onTap: () => _jumpToSection(h),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    h,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade900,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildGroupedList() {
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
            Padding(
              padding: const EdgeInsets.only(
                left: 16.0,
                top: 12.0,
                bottom: 4.0,
              ),
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

  Widget _buildSearchResultList() {
    return ListView.builder(
      itemCount: _trashItems.length,
      itemBuilder: (context, index) => _buildItemCard(_trashItems[index]),
    );
  }

  Widget _buildItemCard(dynamic item) {
    return Card(
      color: Colors.white.withOpacity(0.8),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
          ),
        ),
        trailing: const Icon(Icons.chevron_right, size: 18),
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
              const Text(
                'ゴミの種類（タップで一覧を表示）',
                style: TextStyle(color: Colors.grey, fontSize: 12),
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
              const Text(
                '出し方のポイント',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item['note'] ?? '特になし',
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
