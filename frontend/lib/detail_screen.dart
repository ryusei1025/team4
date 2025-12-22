import 'package:flutter/material.dart';
import 'drawer_menu.dart';
import 'related_items_screen.dart';

class DetailScreen extends StatefulWidget {
  final String itemName;
  final String itemCategory;
  final String itemComment;

  const DetailScreen({
    super.key,
    required this.itemName,
    required this.itemCategory,
    required this.itemComment,
  });

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  UiLang _lang = UiLang.ja;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: LeftMenuDrawer(lang: _lang, selectedArea: '中央区'),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Text(
          _lang == UiLang.ja ? '品目詳細' : 'Detail',
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 1), // AppBar下の線
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel('品目名'),
                  const SizedBox(height: 8),
                  _buildDisplayField(widget.itemName),
                  const SizedBox(height: 24),

                  _buildLabel('分別'),
                  const SizedBox(height: 8),
                  _buildCategoryField(widget.itemCategory),
                  const SizedBox(height: 24),

                  _buildLabel('コメント'),
                  const SizedBox(height: 8),
                  _buildDisplayField(widget.itemComment, maxLines: 5),

                  const SizedBox(height: 30),

                  // 左下に「戻る」ボタン
                  _buildGrayBackButton(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ラベル作成
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  // テキスト表示枠（画像に合わせたスタイル）
  Widget _buildDisplayField(String text, {int maxLines = 1}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black87),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text, style: const TextStyle(fontSize: 16)),
    );
  }

  // 分別フィールド（矢印付き）
  Widget _buildCategoryField(String text) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) =>
                RelatedItemsScreen(category: widget.itemCategory),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.black87),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(text, style: const TextStyle(fontSize: 16)),
            const Icon(Icons.arrow_forward, size: 20),
          ],
        ),
      ),
    );
  }

  // ★ 画像のデザインに合わせた戻るボタン
  Widget _buildGrayBackButton(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFD9DEE2), // 画像のような薄いグレー
          borderRadius: BorderRadius.circular(2), // 少し角ばったデザイン
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_back, size: 18),
            const SizedBox(width: 4),
            Text(
              _lang == UiLang.ja ? '戻る' : 'Back',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}
