// lib/screens/detail_screen.dart

import 'package:flutter/material.dart';
import 'related_items_screen.dart';

class DetailScreen extends StatelessWidget {
  // 画面1から受け取る決め打ちのデータ（プレースホルダー）
  final String itemName;
  final String itemCategory;
  final String itemComment;

  const DetailScreen({
    required this.itemName,
    required this.itemCategory,
    required this.itemComment,
    super.key,
  });

  // 画面3へ遷移する関数
  void _navigateToRelatedItems(BuildContext context) {
    // 決め打ちのカテゴリ情報を持って画面3へ遷移
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RelatedItemsScreen(category: itemCategory),
      ),
    );
  }

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 品目名
            const Text('品目名', style: TextStyle(fontWeight: FontWeight.bold)),
            TextFormField(
              initialValue: itemName, // 受け取った値を表示
              readOnly: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),

            const SizedBox(height: 20),

            // 分別カテゴリ（タップで画面3へ遷移）
            const Text('分別', style: TextStyle(fontWeight: FontWeight.bold)),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                itemCategory, // 受け取ったカテゴリを表示
                style: const TextStyle(fontSize: 18),
              ),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => _navigateToRelatedItems(context),
            ),
            const Divider(),

            const SizedBox(height: 20),

            // コメント欄
            const Text('コメント', style: TextStyle(fontWeight: FontWeight.bold)),
            TextField(
              maxLines: 4,
              controller: TextEditingController(
                text: itemComment,
              ), // 受け取ったコメントを表示
              readOnly: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),

            const SizedBox(height: 40),

            // 戻るボタン
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('戻る'),
            ),
          ],
        ),
      ),
    );
  }
}
