import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
// ★修正: 使われていない import 'constants.dart'; を削除しました

class TrashBin {
  final int id;
  final String name;
  final String address;
  final double lat;
  final double lon;
  final String type;

  TrashBin({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lon,
    required this.type,
  });

  factory TrashBin.fromJson(Map<String, dynamic> json) {
    return TrashBin(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      type: json['type'],
    );
  }
}

class TrashBinApi {
  /// 実行環境ごとにAPIのURLを切り替える
  static String get baseUrl {
    if (kIsWeb) {
      // Chrome（Flutter Web）
      return 'http://localhost:5000';
    } else {
      // Androidエミュレータ
      return 'http://10.0.2.2:5000';
    }
  }

  static Future<List<TrashBin>> fetchBins() async {
    final res = await http.get(Uri.parse('$baseUrl/api/bins'));

    if (res.statusCode != 200) {
      throw Exception('API error: ${res.statusCode}');
    }

    final List data = jsonDecode(res.body);
    return data.map((e) => TrashBin.fromJson(e)).toList();
  }
}