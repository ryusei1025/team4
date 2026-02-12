import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart'; 
import 'package:intl/date_symbol_data_local.dart'; 

import 'constants.dart';
import 'drawer_menu.dart';
import 'bunbetujisho.dart'; // ★検索画面への遷移に必要

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  Uint8List? _webImageBytes;
  final ImagePicker _picker = ImagePicker();

  String? _trashName;
  String? _trashType;
  String? _trashMessage;
  double? _confidence;
  String? _collectionSchedule; 

  // ★追加: エラー時に検索ボタンを表示するためのフラグ
  bool _showSearchButton = false;

  bool _isLoading = false;

  UiLang _lang = UiLang.ja;
  String _selectedArea = '中央区';
  int? _selectedAreaId; 

  Map<String, dynamic> _trans = {};

  @override
  void initState() {
    super.initState();
    initializeDateFormatting(); 
    _loadMenuSettings();
    _loadLanguageSetting().then((_) {
      _loadTranslations();
    });
  }

  Future<void> _loadTranslations() async {
    try {
      final langCode = _lang.name;
      final jsonString = await rootBundle.loadString('assets/translations/$langCode.json');
      final data = json.decode(jsonString);
      if (mounted) {
        setState(() {
          _trans = Map<String, dynamic>.from(data);
        });
      }
    } catch (e) {
      debugPrint('Error loading translation file: $e');
    }
  }

  String _t(String key) {
    return _trans[key] ?? key;
  }

  Future<void> _loadMenuSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedArea = prefs.getString('noti_area') ?? '中央区';
      _selectedAreaId = prefs.getInt('noti_area_id') ?? 1; // デフォルトを1(中央区1)にする
    });
  }

  Future<void> _loadLanguageSetting() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLang = prefs.getString('app_lang');
    if (savedLang != null) {
      setState(() {
        _lang = UiLang.values.firstWhere(
          (e) => e.name == savedLang,
          orElse: () => UiLang.ja,
        );
      });
    }
  }

  Color _getTrashColor(String type) {
    if (type.contains('燃やせる') || type.contains('Burnable')) return Colors.orange;
    if (type.contains('燃やせない') || type.contains('Non-burnable')) return Colors.blue;
    if (type.contains('プラ') || type.contains('Plastic')) return Colors.green;
    if (type.contains('瓶') || type.contains('カン') || type.contains('Bottle')) return Colors.brown;
    return Colors.grey;
  }

  String _formatScheduleDate(String dateStr) {
    try {
      if (dateStr == "Schedule not found" || dateStr.isEmpty) return "";
      DateTime date = DateTime.parse(dateStr);
      String locale = _lang.name; 
      return DateFormat.MEd(locale).format(date);
    } catch (e) {
      return dateStr;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 600,
        imageQuality: 80,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _webImageBytes = bytes;
          _trashName = null;
          _trashType = null;
          _trashMessage = null;
          _collectionSchedule = null;
          _showSearchButton = false; // リセット
          _isLoading = true;
        });
        _analyzeTrash(bytes);
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
    }
  }

  Future<void> _analyzeTrash(Uint8List imageBytes) async {
    setState(() {
      _isLoading = true;
      _trashName = null;
      _trashType = null;
      _trashMessage = null;
      _collectionSchedule = null;
      _showSearchButton = false;
    });

    try {
      var uri = Uri.parse('${AppConstants.baseUrl}/api/predict_trash');
      var request = http.MultipartRequest('POST', uri);

      request.files.add(http.MultipartFile.fromBytes(
        'image',
        imageBytes,
        filename: 'upload.jpg',
      ));

      request.fields['lang'] = _lang.name;
      
      // エリアIDを送信 (デフォルト1)
      request.fields['area_id'] = (_selectedAreaId ?? 1).toString();

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        // 成功時
        final data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _trashName = data['name'];
          _trashType = data['type'];
          _trashMessage = data['reason'];
          _confidence = (data['confidence'] is int)
              ? (data['confidence'] as int).toDouble()
              : data['confidence'];
          _collectionSchedule = data['collection_schedule'];
        });
      } else if (response.statusCode == 503) {
        // ★AI制限エラー時 (バックエンドが503を返す設定の場合)
        setState(() {
          // JSONに 'ai_limit_title' があればそれを表示、なければ英語を表示
          String titleKey = 'ai_limit_title';
          String msgKey = 'ai_limit_msg';
          
          _trashName = _t(titleKey) != titleKey ? _t(titleKey) : 'AI Limit Reached';
          _trashMessage = _t(msgKey) != msgKey ? _t(msgKey) : 'Please search from the dictionary.';
          
          _showSearchButton = true; // 検索ボタンを表示
        });
      } else {
        // その他のエラー
        setState(() {
          _trashName = "Error";
          _trashMessage = "Status: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _trashName = "Connection Error";
        _trashMessage = "$e";
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 検索画面へ移動するメソッド
  void _navigateToSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchScreen(initialLang: _lang),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Color themeColor = _trashType != null ? _getTrashColor(_trashType!) : Colors.green;

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
          title: Text(_t('camera_title')),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        drawer: LeftMenuDrawer(
          lang: _lang,
          selectedArea: _selectedArea,
          onLangChanged: (newLang) {
            setState(() {
              _lang = newLang;
            });
            _loadTranslations();
          },
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. 画像表示エリア
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
                            Icon(Icons.image_search, size: 80, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(_t('camera_guide'), style: TextStyle(color: Colors.grey[500])),
                          ],
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.memory(_webImageBytes!, fit: BoxFit.cover),
                        ),
                ),
                const SizedBox(height: 32),

                // 2. ローディング表示
                if (_isLoading)
                  Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(_t('camera_analyzing'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  )
                
                // 3. 結果表示エリア
                else if (_trashName != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 結果カード
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _showSearchButton ? Colors.red : themeColor.withOpacity(0.5), width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: (_showSearchButton ? Colors.red : themeColor).withOpacity(0.2),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Text(
                              _showSearchButton ? "Error" : _t('camera_result'),
                              style: TextStyle(color: Colors.grey[600], fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _trashName ?? '',
                              style: TextStyle(
                                fontSize: 28, 
                                fontWeight: FontWeight.bold,
                                color: _showSearchButton ? Colors.red : Colors.black,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_confidence != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4, bottom: 8),
                                child: Text(
                                  '${_t('camera_confidence')}: ${(_confidence! * 100).toStringAsFixed(1)}%',
                                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                                ),
                              ),
                            const SizedBox(height: 8),
                            
                            // 検索ボタンがあるときはタイプを表示しない
                            if (!_showSearchButton)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: themeColor,
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Text(
                                  _trashType ?? '',
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                                ),
                              ),

                            const SizedBox(height: 16),
                            if (_trashMessage != null)
                              Text(
                                _trashMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[700], height: 1.5),
                              ),
                            
                            // ★追加: 検索ボタン (AI制限時)
                            if (_showSearchButton)
                              Padding(
                                padding: const EdgeInsets.only(top: 20),
                                child: ElevatedButton.icon(
                                  onPressed: _navigateToSearch,
                                  icon: const Icon(Icons.search),
                                  // ★ここも翻訳キーを使うように修正
                                  label: Text(
                                    _t('btn_open_dictionary') != 'btn_open_dictionary' 
                                      ? _t('btn_open_dictionary') 
                                      : "Open Dictionary"
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),

                      // 次の収集日ウィジェット (成功時のみ)
                      if (_collectionSchedule != null && _collectionSchedule!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                          decoration: BoxDecoration(
                            color: themeColor.withOpacity(0.1), 
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: themeColor.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                     BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)
                                  ]
                                ),
                                child: Icon(Icons.calendar_month, color: themeColor, size: 30),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _t('next_collection') != 'next_collection' ? _t('next_collection') : "Next Collection", 
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatScheduleDate(_collectionSchedule!),
                                      style: const TextStyle(
                                        color: Colors.black87,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
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
                onPressed: _isLoading ? null : () => _pickImage(ImageSource.gallery),
                backgroundColor: Colors.white,
                foregroundColor: Colors.green,
                icon: const Icon(Icons.photo_library),
                label: Text(_t('camera_btn_gallery')),
              ),
              const SizedBox(width: 20),
              FloatingActionButton.extended(
                heroTag: 'camera',
                onPressed: _isLoading ? null : () => _pickImage(ImageSource.camera),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.camera_alt),
                label: Text(_t('camera_btn_camera')),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
      ),
    );
  }
}