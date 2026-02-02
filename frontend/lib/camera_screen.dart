import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // 画像選択用
import 'package:http/http.dart' as http; // 通信用
import 'dart:convert'; // JSON用
import 'dart:typed_data'; // Webでの画像データ扱いに必要
import 'constants.dart';
import 'drawer_menu.dart'; // LeftMenuDrawerを使うために必要

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  // WebではFile型が使えないため、データ(Uint8List)とXFileで管理します
  Uint8List? _webImageBytes; // 画面表示用の画像データ

  final ImagePicker _picker = ImagePicker();
  
  String? _trashName;
  String? _trashType;
  String? _trashMessage;
  bool _isLoading = false;
  UiLang _lang = UiLang.ja;

  Color _getTrashColor(String type) {
    if (type.contains('燃やせる') || type.contains('可燃')) return Colors.orange;
    if (type.contains('燃やせない') || type.contains('不燃')) return Colors.blue;
    if (type.contains('プラ')) return Colors.green;
    if (type.contains('瓶') || type.contains('ビン') || type.contains('缶') || type.contains('カン')) return Colors.grey;
    return Colors.black;
  }

  // 画像を選択・撮影する関数
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 600,
        imageQuality: 80,
      );

      if (image != null) {
        // Web用にデータを読み込む
        final bytes = await image.readAsBytes();
        
        setState(() {
          _webImageBytes = bytes;
          _trashName = null;
          _trashType = null;
          _trashMessage = null;
          _isLoading = true;
        });

        // 判定開始
        await _uploadAndAnalyzeImage(image, bytes);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('カメラの起動に失敗しました: $e')),
      );
    }
  }

  // 画像をアップロードして判定する関数（Web対応版）
  Future<void> _uploadAndAnalyzeImage(XFile file, Uint8List bytes) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConstants.baseUrl}/api/analyze_trash'), // エンドポイント修正
      );

      // ★重要修正ポイント：パスではなく、データ(bytes)を直接送る
      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: file.name, // ファイル名
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        // レスポンスのデコード（文字化け対策）
        final String responseBody = utf8.decode(response.bodyBytes);
        final Map<String, dynamic> data = json.decode(responseBody);

        setState(() {
          _trashName = data['name'];
          _trashType = data['type'];
          _trashMessage = data['message'];
          _isLoading = false;
        });
      } else {
        setState(() {
          _trashName = "エラー";
          _trashMessage = "サーバーエラー: ${response.statusCode}";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _trashName = "通信エラー";
        _trashMessage = "エラー詳細: $e";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_lang == UiLang.ja ? 'AI分別判定' : 'AI Analysis'),
        actions: [
          LanguageSelector(
            currentLang: _lang,
            onChanged: (lang) => setState(() => _lang = lang),
          ),
        ],
      ),
      // ▼▼▼ 修正箇所：正しいクラス名とパラメータに変更 ▼▼▼
      drawer: LeftMenuDrawer(
        lang: _lang,
        selectedArea: '中央区', // 必須パラメータなのでダミーを渡す
      ),
      // ▲▲▲ 修正箇所ここまで ▲▲▲
      
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // --- 画像表示エリア (Web対応) ---
              if (_webImageBytes != null)
                Container(
                  height: 300,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      _webImageBytes!, // メモリ上のデータを表示
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                Container(
                  height: 300,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.camera_alt, size: 80, color: Colors.grey),
                      SizedBox(height: 10),
                      Text("写真を撮影または選択してください"),
                    ],
                  ),
                ),
              
              const SizedBox(height: 20),

              // --- 判定結果エリア ---
              if (_isLoading)
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 10),
                    Text("AIが画像を解析中..."),
                  ],
                )
              else if (_trashName != null)
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Text(
                          _trashName!,
                          style: const TextStyle(
                              fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: _getTrashColor(_trashType ?? ''),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _trashType ?? '',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(height: 15),
                        Text(
                          _trashMessage ?? '',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 80), // 下部ボタン用の余白
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FloatingActionButton.extended(
              heroTag: 'gallery',
              onPressed: _isLoading ? null : () => _pickImage(ImageSource.gallery),
              backgroundColor: Colors.white,
              foregroundColor: Colors.green,
              icon: const Icon(Icons.photo_library),
              label: const Text("アルバム"),
            ),
            const SizedBox(width: 20),
            FloatingActionButton.extended(
              heroTag: 'camera',
              onPressed: _isLoading ? null : () => _pickImage(ImageSource.camera),
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.camera_alt),
              label: const Text("撮影"),
            ),
          ],
        ),
      ),
    );
  }
}