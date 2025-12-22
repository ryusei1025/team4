import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'drawer_menu.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  File? _image;
  String result = 'まだ判定していません';
  UiLang _lang = UiLang.ja;
  final ImagePicker _picker = ImagePicker();

  Future<void> takePhoto() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.camera,
    );
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        result = '判定中...';
      });
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        result = '可燃ごみ';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
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
          _lang == UiLang.ja ? 'AIカメラ判定' : 'AI Camera',
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
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _image != null
                ? Image.file(_image!, height: 250)
                : const Icon(Icons.camera_alt, size: 100, color: Colors.grey),
            const SizedBox(height: 20),
            Text('${_lang == UiLang.ja ? "結果" : "Result"}: $result'),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: takePhoto,
              child: Text(_lang == UiLang.ja ? '撮影する' : 'Take Photo'),
            ),
          ],
        ),
      ),
    );
  }
}
