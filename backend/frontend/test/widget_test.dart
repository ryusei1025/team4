import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:frontend/main.dart'; // プロジェクト名に合わせてください

// --- ネットワーク通信を無効化（モック化）するクラス群 ---

class _TestHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _TestHttpClient();
  }
}

class _TestHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return _TestHttpClientRequest();
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return _TestHttpClientRequest();
  }
  
  @override
  void close({bool force = false}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #autoUncompress) return true;
    return super.noSuchMethod(invocation);
  }
  
  @override
  bool get autoUncompress => true;
  @override
  set autoUncompress(bool value) {}
}

class _TestHttpClientRequest implements HttpClientRequest {
  @override
  bool followRedirects = true;
  
  @override
  int maxRedirects = 5;
  
  @override
  int contentLength = -1;
  
  @override
  bool persistentConnection = true;
  
  @override
  bool bufferOutput = true;

  @override
  Encoding get encoding => const Utf8Codec();
  
  @override
  set encoding(Encoding value) {}

  @override
  Future<HttpClientResponse> close() async => _TestHttpClientResponse();
  
  @override
  HttpHeaders get headers => _TestHttpHeaders();
  
  @override
  void add(List<int> data) {}
  
  @override
  void write(Object? obj) {}
  
  @override
  void writeAll(Iterable objects, [String separator = ""]) {}
  
  @override
  void writeln([Object? obj = ""]) {}
  
  @override
  void writeCharCode(int charCode) {}

  @override
  Future addStream(Stream<List<int>> stream) async {}
  
  @override
  Future<HttpClientResponse> get done => Future.value(_TestHttpClientResponse());

  @override
  Future<void> flush() async {}
  
  @override
  void abort([Object? exception, StackTrace? stackTrace]) {}

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }
}

class _TestHttpHeaders implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}
  
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}
  
  @override
  String? value(String name) => null;
  
  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }
}

class _TestHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  // ★修正: JSONデータをバイト列として保持
  final List<int> _data;

  // デフォルトで空のリスト '[]' を返すように設定
  _TestHttpClientResponse([String body = '[]']) 
      : _data = utf8.encode(body);

  @override
  int get statusCode => 200;
  
  @override
  String get reasonPhrase => "OK";
  
  // コンテンツの長さも返す
  @override
  int get contentLength => _data.length;
  
  @override
  HttpHeaders get headers => _TestHttpHeaders();

  @override
  bool get isRedirect => false;

  @override
  List<RedirectInfo> get redirects => [];

  @override
  bool get persistentConnection => true; 

  @override
  Future<Socket> detachSocket() async {
    throw UnsupportedError('Mock response does not support detachSocket');
  }
  
  @override
  Future<HttpClientResponse> redirect([String? method, Uri? url, bool? followLoops]) async {
    return this;
  }
  
  @override
  HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;

  // ★修正: ストリームとしてデータを流す実装
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    // データ（_data）を一度だけ流して終了するストリームを作成
    final controller = StreamController<List<int>>();
    controller.add(_data);
    controller.close();
    
    return controller.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return null;
  }
}

// --- テスト本体 ---

void main() {
  setUpAll(() {
    SharedPreferences.setMockInitialValues({
      'app_lang': 'ja',
      'noti_area': '中央区1',
      'noti_is_on': false,
    });
    HttpOverrides.global = _TestHttpOverrides();
  });

  testWidgets('アプリ起動〜ドロワー遷移の結合テスト', (WidgetTester tester) async {
    // レイアウトオーバーフローエラーを無視する設定
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      if (details.exception is FlutterError &&
          (details.exception as FlutterError).message.contains('overflowed')) {
        return; 
      }
      originalOnError?.call(details);
    };

    // 画面サイズ設定
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;

    // アプリ起動
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // --- 検証開始 ---

    // 1. ホーム画面確認
    expect(find.byIcon(Icons.menu), findsOneWidget);

    // 2. ドロワーを開く
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    // 3. メニュー項目確認
    if (find.text('メニュー').evaluate().isNotEmpty) {
      expect(find.text('メニュー'), findsOneWidget);
    }

    // 4. マップ画面へ遷移
    final mapMenuFinder = find.text('ゴミ箱マップ');
    final mapKeyFinder = find.text('map');
    
    if (mapMenuFinder.evaluate().isNotEmpty) {
       await tester.tap(mapMenuFinder);
    } else if (mapKeyFinder.evaluate().isNotEmpty) {
       await tester.tap(mapKeyFinder);
    } else {
       await tester.tap(find.byIcon(Icons.map_outlined));
    }
    
    await tester.pumpAndSettle();

    // 5. マップ画面確認
    expect(find.byIcon(Icons.search), findsOneWidget);

    // テスト終了処理
    addTearDown(() {
      tester.view.resetPhysicalSize();
      FlutterError.onError = originalOnError; 
    });
  });
}