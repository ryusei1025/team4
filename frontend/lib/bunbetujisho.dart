import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'drawer_menu.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  UiLang _lang = UiLang.ja;
  List<dynamic> _trashItems = [];
  bool _isLoading = false;
  String _errorMessage = ''; // エラーメッセージ保持用

  final String _baseUrl = 'http://10.0.2.2:5001';

  @override
  void initState() {
    super.initState();
    _fetchTrashData();
  }

  Future<void> _fetchTrashData({String? query}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // queryが送られてきたらURLに付ける、なければ全件取得
      String url = '$_baseUrl/api/getdictionary';
      if (query != null && query.isNotEmpty) {
        url += '?q=${Uri.encodeComponent(query)}';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        // 3. 成功したら、届いたJSONを解析してリストに保存
        final List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _trashItems = data; // これで画面上のデータが更新される
        });
      } else {
        setState(() {
          _errorMessage = 'サーバーエラー: ${response.statusCode}';
        });
      }
    } catch (e) {
      // ★ 通信失敗時に赤い文字で表示させるためのメッセージ
      setState(() {
        _errorMessage = 'Failed to fetch: 通信に失敗しました。\nサーバーを起動してください。';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      // ★ 左メニュー（ドロワー）を設定
      drawer: LeftMenuDrawer(lang: _lang, selectedArea: '中央区'),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        // ★ 左上に三本線メニューボタンを設置
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(
          _lang == UiLang.ja ? 'ゴミ分別辞書' : 'Dictionary',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          LanguageSelector(
            currentLang: _lang,
            onChanged: (v) => setState(() => _lang = v),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'キーワード入力',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey.shade200,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
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
                    child: Text(
                      _errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ) // ★ 通信失敗時に赤いエラーを表示
                : ListView.builder(
                    itemCount: _trashItems.length, // リストの件数分だけ繰り返す
                    itemBuilder: (context, index) {
                      final item = _trashItems[index]; // 今見ている1件のデータ
                      return Card(
                        child: ListTile(
                          title: Text(item['name']), // 「名前」を表示
                          subtitle: Text(item['trash_type_name']), // 「分別区分」を表示
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
