// lib/screens/related_items_screen.dart

import 'package:flutter/material.dart';
import 'detail_screen.dart';

// 画面3で表示する決め打ちのデータ
const List<Map<String, String>> relatedStaticItems = [
  {'name': '生ゴミ', 'description': '水気をよく切って出す。'},
  {'name': '衣類', 'description': '資源として回収可能な場合もある。'},
  {'name': '紙くず', 'description': 'リサイクルできないもの。'},
];

class RelatedItemsScreen extends StatelessWidget {
  final String category; // 画面2から受け取った分別カテゴリ
  const RelatedItemsScreen({required this.category, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ゴミ分別辞書'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: Center(
              child: Text('日本語', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
      drawer: const Drawer(),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              '$category 一覧', // 受け取ったカテゴリ名を表示
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),

          // 決め打ちの関連品目リスト
          Expanded(
            child: ListView.builder(
              itemCount: relatedStaticItems.length,
              itemBuilder: (context, index) {
                final item = relatedStaticItems[index];
                return ListTile(
                  title: Text(item['name']!),
                  subtitle: Text(item['description']!),
                  onTap: () {
                    // タップでその品目の詳細画面（画面2）に遷移（再帰的な遷移）
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => DetailScreen(
                          itemName: item['name']!,
                          itemCategory: category, // 画面3のカテゴリを引き継ぎ
                          itemComment: '一覧から選択された項目のコメント', // コメントはプレースホルダー
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // 戻るボタン
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('戻る'),
            ),
          ),
        ],
      ),
    );
  }
}
