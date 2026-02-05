import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'constants.dart';
import 'drawer_menu.dart';

class CategoryItemsScreen extends StatefulWidget {
  final int trashTypeId;
  final String typeName;
  final Color themeColor;
  final UiLang lang; // 言語設定を受け取る

  const CategoryItemsScreen({
    super.key,
    required this.trashTypeId,
    required this.typeName,
    required this.themeColor,
    this.lang = UiLang.ja, // デフォルトは日本語
  });

  @override
  State<CategoryItemsScreen> createState() => _CategoryItemsScreenState();
}

class _CategoryItemsScreenState extends State<CategoryItemsScreen> {
  // リストデータ
  List<dynamic> _items = [];

  // ロード状態とエラーメッセージ
  bool _isLoading = true;
  String _errorMessage = '';

  // APIのベースURL
  final String _baseUrl = AppConstants.baseUrl;

  @override
  void initState() {
    super.initState();
    // 画面表示時にデータを取得
    _fetchCategoryItems();
  }

  // APIからデータを取得するメソッド
  Future<void> _fetchCategoryItems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // ★修正: 言語設定に基づいてパラメータを設定 (ja / en 等)
      // enumの名前をそのままAPIパラメータとして使用します
      final langCode = widget.lang.name;

      // APIエンドポイントの構築
      final url =
          '$_baseUrl/api/trash_search?cat_id=${widget.trashTypeId}&lang=$langCode';

      print('Fetching URL: $url'); // デバッグ用ログ

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        // ★修正: 日本語が文字化けしないように utf8.decode を明示的に使用
        final String responseBody = utf8.decode(response.bodyBytes);
        final List<dynamic> data = json.decode(responseBody);

        setState(() {
          _items = data;
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load items: Status ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: $e';
        _isLoading = false;
      });
      print('Error fetching category items: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 現在の言語設定を取得
    final isJa = widget.lang == UiLang.ja;

    // 言語に応じたテキストの定義
    final backButtonText = isJa ? '戻る' : 'Back';
    final noNotesText = isJa ? '特になし' : 'None';
    final noItemsText = isJa ? '項目が見つかりません' : 'No items found';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.typeName),
        backgroundColor: widget.themeColor,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: widget.themeColor))
          : _errorMessage.isNotEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: [
                // リスト表示部分
                Expanded(
                  child: _items.isEmpty
                      ? Center(
                          child: Text(
                            noItemsText,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                            ),
                          ),
                        )
                      : ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (context, index) => const Divider(),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return ListTile(
                              title: Text(
                                item['name'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Text(
                                item['note'] ?? noNotesText,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                              // 必要であればここに詳細モーダルへのonTapを追加可能
                              onTap: () {
                                // タップ時の処理（将来的な拡張用）
                              },
                            );
                          },
                        ),
                ),

                // 下部の「戻る」ボタンエリア
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    height: 55, // 元のボタンの高さを維持
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
    );
  }
}
