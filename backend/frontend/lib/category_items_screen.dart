import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'constants.dart';
import 'drawer_menu.dart';

class CategoryItemsScreen extends StatefulWidget {
  final int trashTypeId;
  final String typeName;
  final Color themeColor;
  final UiLang lang;

  const CategoryItemsScreen({
    super.key,
    required this.trashTypeId,
    required this.typeName,
    required this.themeColor,
    this.lang = UiLang.ja,
  });

  @override
  State<CategoryItemsScreen> createState() => _CategoryItemsScreenState();
}

class _CategoryItemsScreenState extends State<CategoryItemsScreen> {
  List<dynamic> _items = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final String _baseUrl = AppConstants.baseUrl;

  @override
  void initState() {
    super.initState();
    _fetchCategoryItems();
  }

  Future<void> _fetchCategoryItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    try {
      final langCode = widget.lang == UiLang.ja ? 'ja' : 'en';
      final url =
          '$_baseUrl/api/trash_search?cat_id=${widget.trashTypeId}&lang=$langCode';

      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));

        // ★ 修正：勝手なソート処理を削除しました。
        // サーバーから「あかさたな順」で送られてくるデータをそのまま使います。

        if (mounted) {
          setState(() {
            _items = data;
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _errorMessage = widget.lang == UiLang.ja
              ? 'データの読み込みに失敗しました'
              : 'Failed to load data';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = widget.lang == UiLang.ja
              ? '通信エラーが発生しました'
              : 'Connection error';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isJa = widget.lang == UiLang.ja;
    final titleText = isJa
        ? '${widget.typeName} の一覧'
        : 'List of ${widget.typeName}';
    final noNotesText = isJa ? '特になし' : '-';
    final backButtonText = isJa ? '分別辞書に戻る' : 'Back to Dictionary';
    final retryText = isJa ? '再読み込み' : 'Retry';

    return Scaffold(
      appBar: AppBar(
        title: Text(titleText),
        backgroundColor: widget.themeColor,
        foregroundColor: Colors.white,
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
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: widget.themeColor,
                      ),
                    )
                  : _errorMessage.isNotEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_errorMessage),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: _fetchCategoryItems,
                            child: Text(retryText),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 10, bottom: 80),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return Card(
                          color: Colors.white.withOpacity(0.85),
                          elevation: 0.5,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            title: Text(
                              item['name'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              item['note'] ?? noNotesText,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: Text(
                    backButtonText,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.themeColor,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
