import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  File? _image;
  String result = 'まだ判定していません';

  final ImagePicker _picker = ImagePicker();

  /// カメラ起動
  Future<void> takePhoto() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        result = '判定中...';
      });

      // ダミーAI判定（Flaskなし）
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        result = _dummyAIPrediction();
      });
    }
  }

  /// ダミーAI判定
  String _dummyAIPrediction() {
    final labels = ['可燃ごみ', '不燃ごみ', 'プラスチック', 'ビン・カン'];
    labels.shuffle();
    return labels.first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ゴミ判定カメラ')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_image != null)
            Image.file(_image!, height: 250)
          else
            const Icon(Icons.camera_alt, size: 150),

          const SizedBox(height: 20),

          Text(
            result,
            style: const TextStyle(fontSize: 22),
          ),

          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: takePhoto,
            child: const Text('写真を撮る'),
          ),
        ],
      ),
    );
  }
}
