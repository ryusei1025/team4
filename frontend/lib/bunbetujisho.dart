import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'drawer_menu.dart';
import 'category_items_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  UiLang _lang = UiLang.ja;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<dynamic> _trashItems = [];
  bool _isLoading = false;
  String _errorMessage = '';

  final String _baseUrl = 'http://10.0.2.2:5000';

  @override
  void initState() {
    super.initState();
    _fetchTrashData(query: '');
    // 画面表示時に検索窓にフォーカスを当てる
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // IDから名前を判定
  String _getTrashTypeName(dynamic item) {
    final id = int.tryParse(item['trash_type_id']?.toString() ?? '') ?? 0;
    final String fallbackName =
        item['trash_type_name'] ?? item['trash_type'] ?? '不明';

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
        return fallbackName == '不明' ? '不明' : fallbackName;
    }
  }

  // IDから色を判定
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

  // 詳細モーダル表示
  void _showDetail(dynamic item) {
    final Color themeColor = _getTrashColor(item);
    final String typeName = _getTrashTypeName(item);
    final String feeText = item['fee']?.toString() ?? '無料';
    final bool isFree = feeText.contains('無料') || feeText == '0';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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

              // ★ カテゴリー一覧へのボタン
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    final int tid =
                        int.tryParse(item['trash_type_id']?.toString() ?? '') ??
                        0;

                    if (tid == 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('カテゴリーIDが見つかりません')),
                      );
                      return;
                    }

                    // 1. モーダルを閉じる
                    Navigator.of(context).pop();

                    // 2. 確実に次の画面を開く（少し遅延させて安定させる）
                    Future.delayed(const Duration(milliseconds: 150), () {
                      if (!mounted) return;
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
                    });
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
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isFree ? Colors.green.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      isFree
                          ? Icons.check_circle_outline
                          : Icons.payments_outlined,
                      color: isFree ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        feeText,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isFree
                              ? Colors.green.shade700
                              : Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '捨て方のポイント',
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

  Future<void> _fetchTrashData({String query = ''}) async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final String langCode = _lang == UiLang.ja ? 'ja' : 'en';
      final response = await http
          .get(
            Uri.parse(
              '$_baseUrl/api/trash_search?q=${Uri.encodeComponent(query)}&lang=$langCode',
            ),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        if (mounted)
          setState(() {
            _trashItems = data;
            _isLoading = false;
          });
      } else {
        if (mounted)
          setState(() {
            _isLoading = false;
            _errorMessage = 'エラー: ${response.statusCode}';
          });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _isLoading = false;
          _errorMessage = 'サーバーに接続できません';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      drawer: LeftMenuDrawer(lang: _lang, selectedArea: '札幌市'),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _lang == UiLang.ja ? '分別辞書検索' : 'Trash Search',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.language),
            onPressed: () {
              setState(() {
                _lang = (_lang == UiLang.ja) ? UiLang.en : UiLang.ja;
              });
              _fetchTrashData(query: _searchController.text);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                hintText: _lang == UiLang.ja ? 'ゴミの名前で検索...' : 'Search...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade200,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (text) => _fetchTrashData(query: text),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage.isNotEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _errorMessage,
                          style: const TextStyle(color: Colors.red),
                        ),
                        TextButton(
                          onPressed: () =>
                              _fetchTrashData(query: _searchController.text),
                          child: const Text('再試行'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _trashItems.length,
                    itemBuilder: (context, index) {
                      final item = _trashItems[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
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
                          trailing: const Icon(Icons.chevron_right),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
