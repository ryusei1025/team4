import 'package:flutter/material.dart';
import 'drawer_menu.dart'; // LanguageSelector, LeftMenuDrawer, UiLang を使用
import 'detail_screen.dart';

class RelatedItemsScreen extends StatefulWidget {
  final String category;

  const RelatedItemsScreen({super.key, required this.category});

  @override
  State<RelatedItemsScreen> createState() => _RelatedItemsScreenState();
}

class _RelatedItemsScreenState extends State<RelatedItemsScreen> {
  UiLang _lang = UiLang.ja;

  // サンプルデータ
  final List<Map<String, String>> relatedStaticItems = [
    {'name': 'ソファー', 'description': 'スプリング入りを含む'},
    {'name': 'ベッドフレーム', 'description': '木製・金属製'},
    {'name': '食器棚', 'description': '高さ120cm以上'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      // 共通メニュー
      drawer: LeftMenuDrawer(lang: _lang, selectedArea: '中央区'),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        // 左：メニューボタン
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        // 中央：タイトル
        title: Text(
          _lang == UiLang.ja ? '関連品目' : 'Related Items',
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        // 右：言語設定ボタン（共通パーツ）
        actions: [
          LanguageSelector(
            currentLang: _lang,
            onChanged: (v) => setState(() => _lang = v),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1, color: Colors.black26),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Text(
              '${widget.category}の一覧',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),

          // 関連品目リスト（枠線ありのデザイン）
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: relatedStaticItems.length,
              itemBuilder: (context, index) {
                final item = relatedStaticItems[index];
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black87),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ListTile(
                    title: Text(
                      item['name']!,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(item['description']!),
                    trailing: const Icon(
                      Icons.arrow_forward,
                      size: 20,
                      color: Colors.black,
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => DetailScreen(
                            itemName: item['name']!,
                            itemCategory: widget.category,
                            itemComment: '関連リストから選択されました。',
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),

          // 画像のデザインを再現した左下の「戻る」ボタン
          Padding(
            padding: const EdgeInsets.only(left: 20.0, bottom: 40.0, top: 20.0),
            child: InkWell(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFD9DEE2), // 指定のグレー背景
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_back, size: 18, color: Colors.black),
                    const SizedBox(width: 4),
                    Text(
                      _lang == UiLang.ja ? '戻る' : 'Back',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
