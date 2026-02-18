import 'dart:convert';
import 'package:http/http.dart' as http;

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
    static const String baseUrl = 'https://unanimated-susannah-useably.ngrok-free.dev';


  static Future<List<TrashBin>> fetchBins() async {
    final res = await http.get(Uri.parse('$baseUrl/api/trash_bins')); // ★app.pyのエンドポイントに合わせて修正

    if (res.statusCode != 200) {
      throw Exception('API error: ${res.statusCode}');
    }

    final List data = jsonDecode(res.body);
    return data.map((e) => TrashBin.fromJson(e)).toList();
  }
}