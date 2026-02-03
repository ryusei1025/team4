import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'constants.dart';
import 'drawer_menu.dart';

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
  double? _confidence;

  bool _isLoading = false;

  // 言語設定
  UiLang _lang = UiLang.ja;

  @override
  void initState() {
    super.initState();
  }

  // 画面遷移時に言語設定を受け取る
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is UiLang) {
      if (_lang != args) {
        setState(() {
          _lang = args;
        });
      }
    }
  }

  Color _getTrashColor(String type) {
    if (type.contains('燃やせる') || type.contains('Burnable'))
      return Colors.orange;
    if (type.contains('燃やせない') || type.contains('Non-burnable'))
      return Colors.blue;
    if (type.contains('プラ') || type.contains('Plastic')) return Colors.green;
    if (type.contains('瓶') || type.contains('カン') || type.contains('Bottle'))
      return Colors.brown;
    return Colors.grey;
  }

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

      _analyzeTrash(bytes);
    } catch (e) {
      print("Error picking image: $e");
    }
  }

  Future<void> _analyzeTrash(Uint8List imageBytes) async {
    setState(() => _isLoading = true);

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConstants.baseUrl}/api/predict_trash'),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          imageBytes,
          filename: 'upload.jpg',
        ),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _trashName = data['name'];
          _trashType = data['type'];
          _trashMessage = data['reason'];
          _confidence = (data['confidence'] is int)
              ? (data['confidence'] as int).toDouble()
              : data['confidence'];
        });
      } else {
        setState(() {
          _trashName = _lang == UiLang.ja ? "エラー" : "Error";
          _trashMessage = "Status: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _trashName = _lang == UiLang.ja ? "エラー" : "Error";
        _trashMessage = "$e";
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isJa = _lang == UiLang.ja;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFE8F5E9), Color(0xFFC8E6C9)],
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(isJa ? 'AIゴミ判定' : 'AI Trash Scan'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        // ★ 修正箇所：onLangChanged を追加
        drawer: LeftMenuDrawer(
          lang: _lang,
          selectedArea: '中央区',
          onLangChanged: (newLang) => setState(() => _lang = newLang),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: _webImageBytes == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image_search,
                              size: 80,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              isJa
                                  ? "写真を撮影または選択してください"
                                  : "Take a photo or select from gallery",
                              style: TextStyle(color: Colors.grey[500]),
                            ),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.memory(
                            _webImageBytes!,
                            fit: BoxFit.cover,
                          ),
                        ),
                ),

                const SizedBox(height: 32),

                if (_isLoading)
                  Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        isJa ? "AIが解析中..." : "Analyzing...",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  )
                else if (_trashName != null)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _getTrashColor(
                          _trashType ?? '',
                        ).withOpacity(0.5),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _getTrashColor(
                            _trashType ?? '',
                          ).withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          isJa ? "解析結果" : "Result",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _trashName ?? '',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        if (_confidence != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4, bottom: 8),
                            child: Text(
                              isJa
                                  ? 'AI確信度: ${(_confidence! * 100).toStringAsFixed(1)}%'
                                  : 'Confidence: ${(_confidence! * 100).toStringAsFixed(1)}%',
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                            ),
                          ),

                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _getTrashColor(_trashType ?? ''),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Text(
                            _trashType ?? '',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_trashMessage != null)
                          Text(
                            _trashMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[700],
                              height: 1.5,
                            ),
                          ),
                      ],
                    ),
                  ),

                const SizedBox(height: 80),
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
                onPressed: _isLoading
                    ? null
                    : () => _pickImage(ImageSource.gallery),
                backgroundColor: Colors.white,
                foregroundColor: Colors.green,
                icon: const Icon(Icons.photo_library),
                label: Text(isJa ? "アルバム" : "Gallery"),
              ),
              const SizedBox(width: 20),
              FloatingActionButton.extended(
                heroTag: 'camera',
                onPressed: _isLoading
                    ? null
                    : () => _pickImage(ImageSource.camera),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.camera_alt),
                label: Text(isJa ? "撮影" : "Camera"),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
      ),
    );
  }
}
