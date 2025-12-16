// lib/screens/search_screen.dart

import 'package:flutter/material.dart';
import 'detail_screen.dart'; // 画面2へ遷移するためのインポート

// 表示する固定のデータ
const List<Map<String, String>> staticItems = [
  {'name': '勉強機', 'category': '粗大ごみ'},
  {'name': 'タンス', 'category': '粗大ごみ'},
  {'name': 'クローゼット', 'category': '粗大ごみ'},
  {'name': 'ティッシュペーパー', 'category': '燃えるゴミ'},
];

// 【変更点】ご要望のmain関数を使用
void main() {
  runApp(const MyApp());
}

// 【変更点】ご要望のMyAppをルートウィジェットとして定義
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      // 画面1をアプリのホームに設定
      home: SearchScreen(),
    );
  }
}

class SearchScreen extends StatelessWidget {
  // 画面1の本体ウィジェット
  const SearchScreen({super.key});

  // リストアイテム（粗大ごみチェック付き）を生成するカスタムウィジェット
  Widget _buildListItem(BuildContext context, Map<String, String> item) {
    final isBulky = item['category'] == '粗大ごみ';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      // リストアイテム全体をGestureDetectorでラップし、タップ時に画面2へ遷移
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => DetailScreen(
                itemName: item['name']!,
                itemCategory: item['category']!,
                itemComment: '「${item['name']!}」の分別に関するコメントです。', // プレースホルダー
              ),
            ),
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey.shade300, width: 1.0),
            borderRadius: BorderRadius.circular(8.0),
            boxShadow: [
              BoxShadow(
                // 【警告修正済み】withOpacity(0.2) を withAlpha(51) に変更
                color: Colors.grey.withAlpha(51),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 2), // 影を少しつける
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 品目名
                Text(
                  item['name']!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 6),
                // 分類タグ
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // チェックマーク（粗大ごみの場合のみ）
                      if (isBulky)
                        const Icon(
                          Icons.check,
                          size: 14,
                          color: Colors.black87,
                        ),
                      // 分類カテゴリ名
                      Text(
                        item['category']!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                // 右下の小さな角のマーク（ワイヤーフレームの装飾）
                if (isBulky)
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Transform.rotate(
                      angle: 45 * 3.14159 / 180, // 45度回転
                      child: const Icon(
                        Icons.square,
                        size: 8,
                        color: Color(0xFFE0E0E0),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100, // 背景色を少しグレーに
      appBar: AppBar(
        // AppBarのデザインを画像に合わせて調整
        backgroundColor: Colors.white,
        elevation: 0, // 影をなくす
        title: const Text(
          'ゴミ分別辞書',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.black), // ハンバーガーメニュー
          onPressed: () {
            // 動作は実装しない
          },
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: Center(
              child: Text(
                '日本語',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 検索バー
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Value', // 画像に合わせてhintTextを使用
                suffixIcon: const Icon(Icons.search, color: Colors.grey),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                // 背景に薄いグレーの塗りつぶし
                filled: true,
                fillColor: Colors.grey.shade200,
              ),
            ),
          ),

          // リストアイテムの表示
          Expanded(
            child: ListView.builder(
              itemCount: staticItems.length,
              itemBuilder: (context, index) {
                return _buildListItem(context, staticItems[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}
