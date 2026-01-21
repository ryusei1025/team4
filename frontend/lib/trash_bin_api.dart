import 'dart:convert';
import 'package:http/http.dart' as http;
import 'constants.dart';

class TrashBin {
  final int id;
  final String name;
  final String address;
  final double lat;
  final double lon;

  TrashBin({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lon,
  });

  factory TrashBin.fromJson(Map<String, dynamic> json) {
    return TrashBin(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
    );
  }
}

class TrashBinApi {
  static const baseUrl = AppConstants.baseUrl;

  static Future<List<TrashBin>> fetchBins() async {
    final res = await http.get(Uri.parse('$baseUrl/api/bins'));

    if (res.statusCode != 200) {
      throw Exception('API error');
    }

    final List data = jsonDecode(res.body);
    return data.map((e) => TrashBin.fromJson(e)).toList();
  }
}
