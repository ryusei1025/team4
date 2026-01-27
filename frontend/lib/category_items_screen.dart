import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class CategoryItemsScreen extends StatefulWidget {
  final int trashTypeId;
  final String typeName;
  final Color themeColor;

  const CategoryItemsScreen({
    super.key,
    required this.trashTypeId,
    required this.typeName,
    required this.themeColor,
  });

  @override
  State<CategoryItemsScreen> createState() => _CategoryItemsScreenState();
}

class _CategoryItemsScreenState extends State<CategoryItemsScreen> {
  List<dynamic> _items = [];
  bool _isLoading = true;
  String _errorMessage = '';
  final String _baseUrl = 'http://10.0.2.2:5000';

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
      final url = '$_baseUrl/api/trash_search?cat_id=${widget.trashTypeId}';
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));

        // ★ あいうえお順にソート（昇順）
        data.sort((a, b) {
          String nameA = (a['name'] ?? '').toString();
          String nameB = (b['name'] ?? '').toString();
          return nameA.compareTo(nameB);
        });

        if (mounted) {
          setState(() {
            _items = json.decode(utf8.decode(response.bodyBytes));
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'データの読み込みに失敗しました';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '通信エラーが発生しました';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBarはカテゴリーごとの色を活かしつつ、文字色を白で統一
      appBar: AppBar(
        title: Text('${widget.typeName} の一覧'),
        backgroundColor: widget.themeColor,
        foregroundColor: Colors.white,
      ),
      body: Container(
        // ★ 辞書画面と同じ斜めグラデーション
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Color(0xFFE8F5E9), // 薄い緑
              Color(0xFFC8E6C9), // 少し強めの緑
            ],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.green),
                    )
                  : _errorMessage.isNotEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_errorMessage),
                          ElevatedButton(
                            onPressed: _fetchCategoryItems,
                            child: const Text('再読み込み'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 10),
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return Card(
                          // ★ カードを少し透かしてグラデーションを見せる
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
                              item['note'] ?? '特になし',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // 下部の「戻る」ボタンエリア
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text(
                    '分別辞書に戻る',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700, // ボタンを深い緑に
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
