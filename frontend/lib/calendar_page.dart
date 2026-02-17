import 'package:flutter/gestures.dart'; // マウスホイール操作用
import 'package:flutter/material.dart'; // UI部品用
import 'drawer_menu.dart'; // ドロワーメニューや言語設定
import 'package:csv/csv.dart'; // CSV解析用
import 'package:flutter/services.dart' show rootBundle; // アセット読み込み用
import 'dart:convert'; // JSONデコード用
import 'package:shared_preferences/shared_preferences.dart';

// ==========================================
// 1. 共通定義：ゴミ種別・基本設定
// ==========================================

/// ゴミの種類（判定・表示・色・アイコンの基準）
// ★Excelに合わせて細分化
enum GarbageType {
  burnable, // 燃やせる
  spray, // スプレー缶（ID1の右半分）
  nonBurnable, // 燃やせない
  lighter, // ライター・電池など（ID2の右半分）
  recyclable, // びん・缶・ペット
  battery, // 電池
  plastic, // プラ
  paper, // 雑がみ
  green, // 枝・葉
}

/// ゴミの表示順序（複数のゴミが重なった時の優先順位）
const List<GarbageType> garbageTypeDisplayOrder = <GarbageType>[
  GarbageType.burnable,
  GarbageType.spray,
  GarbageType.nonBurnable,
  GarbageType.lighter,
  GarbageType.recyclable,
  GarbageType.plastic,
  GarbageType.paper,
  GarbageType.green,
];

/// 日付を整数のキーに変換するヘルパー関数
/// 例：1月3日 → 103, 12月31日 → 1231
int mdKey(DateTime date) => date.month * 100 + date.day;

// ==========================================
// 2. ルール判定クラス & ヘルパー関数
// ==========================================

/// 「第N週 × 曜日 → ゴミ種別」を表すルールクラス
class GarbageRule {
  /// 対象週（例：{1,3}なら第1・第3週）
  final Set<int> weeks;

  /// 対象曜日（0=日, 1=月, ... 6=土）
  final int weekday0to6;

  /// このルールのゴミ種別
  final GarbageType type;

  const GarbageRule({
    required this.weeks,
    required this.weekday0to6,
    required this.type,
  });

  /// 与えられた日付がこのルールに一致するか判定
  bool matches(DateTime date) {
    final w = weekOfMonth(date); // 第何週か
    final wd = weekdayIndex0to6(date); // 曜日(0-6)
    return weeks.contains(w) && wd == weekday0to6;
  }

  /// 月内の第何週かを計算（簡易版: 1..7日=第1週...）
  static int weekOfMonth(DateTime date) => ((date.day - 1) ~/ 7) + 1;
}

/// DateTimeの曜日(1=月..7=日)を、(0=日..6=土)に変換
int weekdayIndex0to6(DateTime date) => date.weekday % 7;

// ★背景色（Excel指定）
Color garbageBgColor(GarbageType type) {
  switch (type) {
    case GarbageType.burnable:
      return const Color(0xFFFFF176); // 黄色 (Yellow300)
    case GarbageType.spray:
      return const Color(0xFF80DEEA); // 水色 (Cyan200)
    case GarbageType.nonBurnable:
      return const Color(0xFFFFCC80); // オレンジ (Orange200)
    case GarbageType.lighter:
      return Colors.white; // 白
    case GarbageType.recyclable:
      return Colors.white; // 白
    case GarbageType.battery:
      return const Color(0xFFF8BBD0); // ピンク
    case GarbageType.plastic:
      return Colors.white; // 白
    case GarbageType.paper:
      return const Color(0xFFE1BEE7); // 薄紫 (Purple100)
    case GarbageType.green:
      return const Color(0xFFC8E6C9); // 薄緑 (Green100)
  }
}

/// ゴミ種別ごとの「表示名」（多言語対応）
String garbageLabel(GarbageType type, Map<String, dynamic> trans) {
  switch (type) {
    case GarbageType.burnable:
      return trans['trash_burnable'] ?? '燃やせるごみ（有料）';
    case GarbageType.spray:
      return trans['trash_spray'] ?? 'スプレー缶類（別袋無料）';
    case GarbageType.nonBurnable:
      return trans['trash_non_burnable'] ?? '燃やせないごみ（有料）';
    case GarbageType.lighter:
      return trans['trash_lighter'] ?? '加熱式たばこ・ライター・筒型乾電池（別袋無料）';
    case GarbageType.recyclable:
      return trans['trash_recyclable'] ?? 'びん・缶・ペットボトル（無料）';
    case GarbageType.battery:
      return trans['trash_battery'] ?? '乾電池（無料）';
    case GarbageType.plastic:
      return trans['trash_plastic'] ?? '容器包装プラスチック（無料）';
    case GarbageType.paper:
      return trans['trash_paper'] ?? '雑がみ（無料）';
    case GarbageType.green:
      return trans['trash_green'] ?? '枝・葉・草（無料）';
  }
}

/// 曜日ラベルの取得 (0=日 ... 6=土)
// ※変更なし（そのまま使えます）
String weekdayLabel0to6(int wd0to6, UiLang lang) {
  final ja = const ['日', '月', '火', '水', '木', '金', '土'];
  final en = const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  // 安全のためclampで範囲を制限
  return (lang == UiLang.ja ? ja : en)[wd0to6.clamp(0, 6)];
}

/// 第N週のラベル取得
// ※変更なし（そのまま使えます）
String weekLabel(int week, UiLang lang) {
  if (lang == UiLang.ja) return '第$week';
  switch (week) {
    case 1:
      return '1st';
    case 2:
      return '2nd';
    case 3:
      return '3rd';
    default:
      return '${week}th';
  }
}

/// ゴミ種別ごとの「アイコン」（Excel準拠）
IconData garbageIcon(GarbageType type) {
  switch (type) {
    case GarbageType.burnable:
      return Icons.local_fire_department;
    case GarbageType.spray:
      return Icons.sanitizer; // スプレー
    case GarbageType.nonBurnable:
      return Icons.block; // 禁止マーク
    case GarbageType.lighter:
      return Icons.smoking_rooms; // 電池・ライター
    case GarbageType.recyclable:
      return Icons.local_drink; // びん・缶
    case GarbageType.battery:
      return Icons.battery_std; // 乾電池
    case GarbageType.plastic:
      return Icons.recycling; // プラ
    case GarbageType.paper:
      return Icons.description; // 紙
    case GarbageType.green:
      return Icons.park; // 草木
  }
}

/// ゴミ種別ごとの「アイコン色」（Excel準拠）
Color garbageIconColor(GarbageType type) {
  switch (type) {
    case GarbageType.burnable:
      return Colors.red;
    case GarbageType.spray:
      return Colors.grey.shade700;
    case GarbageType.nonBurnable:
      return Colors.red;
    case GarbageType.lighter:
      return Colors.grey.shade700;
    case GarbageType.recyclable:
      return Colors.blue;
    case GarbageType.battery:
      return Colors.grey.shade800;
    case GarbageType.plastic:
      return const Color(0xFFC2185B); // 濃いピンク
    case GarbageType.paper:
      return Colors.purple;
    case GarbageType.green:
      return Colors.green.shade800;
  }
}

// ==========================================
// 3. カレンダー画面本体 (CalendarScreen)
// ==========================================

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  // 翻訳データを保持するマップ
  Map<String, dynamic> _trans = {};

  // 動的に設定するための変数定義
  late int baseYear; // 開始年（今年）
  late int maxYear; // 終了年（3年後など）
  late int totalMonths; // 総月数

  // --- 状態変数 ---
  late final PageController _pageController; // ページ制御
  late int _visibleYear; // 現在表示中の年
  late int _visibleMonth; // 現在表示中の月
  late int _pickedYear; // ドロップダウン選択年
  late int _pickedMonth; // ドロップダウン選択月
  DateTime? _selectedDate; // タップされた日付

  final Map<String, List<String>> _areaData = {
    '中央区': ['中央区1', '中央区2', '中央区3', '中央区4', '中央区5', '中央区6'],
    '豊平区': ['豊平区1', '豊平区2', '豊平区3', '豊平区4'],
    '清田区': ['清田区1', '清田区2'],
    '北区': ['北区1', '北区2', '北区3', '北区4', '北区5', '北区6'],
    '東区': ['東区1', '東区2', '東区3', '東区4', '東区5', '東区6'],
    '白石区': ['白石区1', '白石区2', '白石区3', '白石区4'],
    '厚別区': ['厚別区1', '厚別区2', '厚別区3', '厚別区4'],
    '南区': ['南区1', '南区2', '南区3', '南区4', '南区5', '南区6', '南区7'],
    '西区': ['西区1', '西区2', '西区3', '西区4'],
    '手稲区': ['手稲区1', '手稲区2', '手稲区3'],
  };

  // 区名の英語マッピング
  final Map<String, String> _wardNamesEn = {
    '中央区': 'Chuo',
    '北区': 'Kita',
    '東区': 'Higashi',
    '白石区': 'Shiroishi',
    '厚別区': 'Atsubetsu',
    '豊平区': 'Toyohira',
    '清田区': 'Kiyota',
    '南区': 'Minami',
    '西区': 'Nishi',
    '手稲区': 'Teine',
  };

  // 区のリスト（中央区, 豊平区...）を取得するゲッター
  List<String> get _wardList => _areaData.keys.toList();

  // 現在選択されている地域（初期値）
  String _selectedArea = '中央区1';

  // 現在選択されている「区」（初期値は仮置き、initStateで確定させる）
  String _selectedWard = '中央区';

  UiLang _lang = UiLang.ja;
  bool _showGuide = false; // ガイド表示フラグ

  // ★追加: 言語ファイルを読み込むメソッド
  Future<void> _loadTranslations(UiLang lang) async {
    // 言語コードの決定 (ja, en, zh, ko...)
    String langCode = lang.name; // enumの名前をそのまま使う場合 (ja, en)
    // ※中国語などが enum にない場合は別途マッピングが必要です
    // 例: if (lang == UiLang.zh) langCode = 'zh';

    try {
      // JSONファイルを読み込む
      String jsonString = await rootBundle.loadString(
        'assets/translations/$langCode.json',
      );
      Map<String, dynamic> jsonMap = json.decode(jsonString);

      setState(() {
        _trans = jsonMap;
        _lang = lang; // 言語状態も更新
      });
    } catch (e) {
      debugPrint('Translation load error: $e');
      // エラー時は日本語をデフォルトにするなどの処理
    }
  }

  // ★【追加】読み込んだスケジュールデータ（日付 -> ゴミ種別リスト）
  Map<DateTime, List<GarbageType>> _scheduleCache = {};

  // ==========================================
  // 6. 初期化とロジックメソッド
  // ==========================================

  @override
  void initState() {
    super.initState();

    _updateWardFromArea();
    _loadLanguageSetting();
    _loadAreaSelection();

    final now = DateTime.now();

    baseYear = now.year; // 今年を基準にする
    maxYear = baseYear + 3; // 3年後まで（例: 2026〜2029）
    totalMonths = (maxYear - baseYear + 1) * 12; // 月数を計算

    _visibleYear = now.year;
    _visibleMonth = now.month;
    _pickedYear = now.year;
    _pickedMonth = now.month;

    // 起動時に「今日」の日付を選択状態にする（時刻は00:00:00に丸める）
    _selectedDate = DateTime(now.year, now.month, now.day);

    // PageViewの初期ページ位置を計算
    // 「今の年月」が「開始年月」から見て何ヶ月目かを計算
    final initialIndex = (now.year - baseYear) * 12 + (now.month - 1);

    _pageController = PageController(
      initialPage: initialIndex.clamp(0, totalMonths - 1),
    );

    // CSVデータを読み込む
    _loadScheduleData();

    _loadTranslations(_lang);
  }

  // ★【追加】CSVデータを読み込んで解析するメソッド
  Future<void> _loadScheduleData() async {
    try {
      // 1. CSVファイルを文字列として読み込む
      final rawData = await rootBundle.loadString('assets/schedules.csv');

      // 2. CSVをリスト形式に変換
      List<List<dynamic>> rows = const CsvToListConverter().convert(rawData);

      if (rows.isEmpty) return;

      // 3. ヘッダー行（1行目）から、現在選択されているエリア（例: "中央区1"）の列番号を探す
      final header = rows[0].map((e) => e.toString()).toList();
      final columnIndex = header.indexOf(_selectedArea);

      if (columnIndex == -1) {
        print('Error: Area $_selectedArea not found in CSV header');
        return;
      }

      // 4. データを解析してキャッシュを作る
      final Map<DateTime, List<GarbageType>> newCache = {};

      // 1行目はヘッダーなのでスキップして2行目からループ
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length <= columnIndex) continue; // データが欠けている行は飛ばす

        // 日付を解析 (2列目にあると想定: "2025-10-01T00:00:00" 形式)
        // ※CSVの仕様に合わせて列番号を調整してください。今回は日付が2列目(index 1)と仮定
        final dateStr = row[1].toString();
        DateTime? date;
        try {
          date = DateTime.parse(dateStr);
        } catch (e) {
          continue; // 日付パースエラーなら飛ばす
        }

        // ゴミIDを取得（CSV上の数字）
        final cellValue = row[columnIndex];
        final garbageId = int.tryParse(cellValue.toString());

        if (garbageId != null) {
          // ★修正：リストで返ってくるメソッドを使用
          final types = _convertIdToGarbageList(garbageId);

          if (types.isNotEmpty) {
            final dateKey = DateTime(date.year, date.month, date.day);

            // まだキーがなければ空リストを作成
            if (!newCache.containsKey(dateKey)) {
              newCache[dateKey] = [];
            }

            // ★修正：リストの中身をすべて追加
            newCache[dateKey]!.addAll(types);
          }
        }
      }

      // 5. 完了したら画面更新
      setState(() {
        _scheduleCache = newCache;
      });
    } catch (e) {
      print('Error loading CSV: $e');
    }
  }

  // ==========================================
  // ★追加: 設定の保存と読み込み
  // ==========================================

  // 地域と番号を端末に保存する
  Future<void> _saveAreaSelection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'calendar_selected_ward',
      _selectedWard,
    ); // 区 (例: 中央区)
    await prefs.setString(
      'calendar_selected_area',
      _selectedArea,
    ); // 詳細 (例: 中央区1)
  }

  // 保存された設定を読み込む
  Future<void> _loadAreaSelection() async {
    final prefs = await SharedPreferences.getInstance();
    final savedWard = prefs.getString('calendar_selected_ward');
    final savedArea = prefs.getString('calendar_selected_area');

    // 保存されたデータがあり、かつ現在のリストに存在する場合のみ反映
    if (savedWard != null && savedArea != null) {
      if (_areaData.containsKey(savedWard) &&
          (_areaData[savedWard]?.contains(savedArea) ?? false)) {
        setState(() {
          _selectedWard = savedWard;
          _selectedArea = savedArea;
        });

        // ★重要: 地域が変わったのでCSVデータを再読み込みしてカレンダーを更新
        _loadScheduleData();
      }
    }
  }

  Future<void> _loadLanguageSetting() async {
    final prefs = await SharedPreferences.getInstance();
    final savedLang = prefs.getString('app_lang'); // 保存された言語を取得
    if (savedLang != null) {
      setState(() {
        // 保存された言語コード(ja, en...)をUiLang型に変換してセット
        _lang = UiLang.values.firstWhere(
          (e) => e.name == savedLang,
          orElse: () => UiLang.ja,
        );
      });

      // ★重要: 言語が変わったので、カレンダーの翻訳データも再読み込みが必要かもしれません
      // もし _loadTranslations(_lang); のような処理がある場合は、ここでも呼んでください
      _loadTranslations(_lang);
    }
  }

  // ★修正：Excel定義に合わせてIDをリストに変換
  List<GarbageType> _convertIdToGarbageList(int id) {
    switch (id) {
      case 1:
        // 燃やせる（黄） ＋ スプレー（水色）
        return [GarbageType.burnable, GarbageType.spray];
      case 2:
        // 燃やせない（オレンジ） ＋ ライター（白）
        return [GarbageType.nonBurnable, GarbageType.lighter];
      case 8:
        // びん・缶・ペット, 乾電池
        return [GarbageType.recyclable, GarbageType.battery];
      case 9:
        return [GarbageType.plastic]; // プラ
      case 10:
        return [GarbageType.paper]; // 雑がみ
      case 11:
        return [GarbageType.green]; // 枝・葉
      default:
        return [];
    }
  }

  // エリア名から区名を逆算してセットするメソッド
  void _updateWardFromArea() {
    for (var ward in _areaData.keys) {
      if (_selectedArea.startsWith(ward)) {
        _selectedWard = ward;
        break;
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // 基準月からターゲット月までの月数（インデックス）を計算
  int _monthIndexFrom(DateTime base, DateTime target) =>
      (target.year - base.year) * 12 + (target.month - base.month);

  // インデックスからDateTimeを復元
  DateTime _monthFromIndex(int index) =>
      DateTime(baseYear + (index ~/ 12), 1 + (index % 12), 1);

  // マウスホイールでのページ送り処理
  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      if (event.scrollDelta.dy > 18.0) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      } else if (event.scrollDelta.dy < -18.0) {
        _pageController.previousPage(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    }
  }

  // ドロップダウンで選んだ年月にジャンプ
  void _goToPickedMonth() {
    final target = DateTime(_pickedYear, _pickedMonth, 1);

    // (baseYear は initState で設定された「今年の年」です)
    final baseMonth = DateTime(baseYear, 1, 1);

    final idx = _monthIndexFrom(baseMonth, target).clamp(0, totalMonths - 1);

    _pageController.animateToPage(
      idx,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  // カレンダーの日付セルをタップした時の処理
  void _onDateTap(DateTime date, {required DateTime currentMonth}) {
    setState(() => _selectedDate = date);

    // 月をまたいでタップした場合、ドロップダウンも更新して移動
    if (date.year != currentMonth.year || date.month != currentMonth.month) {
      setState(() {
        _pickedYear = date.year.clamp(baseYear, maxYear);
        _pickedMonth = date.month;
      });
      _goToPickedMonth();
    }
  }

  /// 指定された日付のゴミ種別を取得（複数対応）
  List<GarbageType> _garbageTypesFor(DateTime date) {
    // 日付キーを作成（時刻情報を捨てて年月日だけにする）
    final dateKey = DateTime(date.year, date.month, date.day);

    // CSVから読み込んだキャッシュから取得。データがなければ空リストを返す
    return _scheduleCache[dateKey] ?? [];
  }

  /// 日付選択時に表示するテキストを作成
  String _garbageTextFor(DateTime date) {
    // 1. CSVデータから、その日のゴミ種別を取得
    // （先ほど修正したメソッドを使います）
    final types = _garbageTypesFor(date);

    // 2. 収集なしの場合
    if (types.isEmpty) {
      return _trans['no_collection'] ??
          (_lang == UiLang.ja ? '収集なし' : 'No collection');
    }

    // 3. ゴミ種別を文字に変換して連結（例：「燃やせるごみ・プラスチック」）
    // garbageLabelメソッドは元のコードにあるはずなので、そのまま使います
    final gText = types
        .map((t) => garbageLabel(t, _trans))
        .join(_lang == UiLang.ja ? '・' : ' / ');

    // 4. シンプルにゴミの内容だけを返す
    // （日付や曜日は画面の他の場所に表示されるため、ここでは不要です）
    return gText;
  }

  /// 選択中の地域名から、対応する地図画像のパスを返す
  String _getAreaMapAssetPath(String areaName) {
    // プレフィックス（前方一致）で判定します
    if (areaName.startsWith('中央区'))
      return 'assets/images/01_chuo_area_map_1.gif';
    if (areaName.startsWith('北区'))
      return 'assets/images/02_kita_area_map_1.gif';
    if (areaName.startsWith('東区'))
      return 'assets/images/03_higashi_area_map_1.gif';
    if (areaName.startsWith('白石区'))
      return 'assets/images/04_shiroishi_area_map_1.gif';
    if (areaName.startsWith('厚別区'))
      return 'assets/images/05_atsubetsu_area_map_1.gif';
    if (areaName.startsWith('豊平区'))
      return 'assets/images/06_toyohira_area_map_1.gif';
    if (areaName.startsWith('清田区'))
      return 'assets/images/07_kiyota_area_map_1.gif';
    if (areaName.startsWith('南区'))
      return 'assets/images/08_minami_area_map_2.gif';
    if (areaName.startsWith('西区'))
      return 'assets/images/09_nishi_area_map_1.gif';
    if (areaName.startsWith('手稲区'))
      return 'assets/images/10_teine_area_map_1.gif';

    return ''; // 画像がない場合
  }

  /// 地図画像をポップアップで表示する（ドロップダウンで切り替え可能）
  void _showAreaMapDialog() {
    // 1. 現在選択中のエリア（例："中央区1"）から、区の名前（例："中央区"）を取り出して初期値にする
    String currentViewArea = _selectedArea.replaceAll(RegExp(r'[0-9]'), '');

    // 万が一リストにない名前だった場合の安全策
    if (!_areaData.containsKey(currentViewArea)) {
      currentViewArea = _areaData.keys.first; // リストの最初（中央区）にする
    }

    showDialog(
      context: context,
      builder: (context) {
        // ★重要: ダイアログの中で画面を書き換えるために StatefulBuilder を使う
        return StatefulBuilder(
          builder: (context, setStateInDialog) {
            // 選択された区に対応する画像パスを取得
            final path = _getAreaMapAssetPath(currentViewArea);

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- ヘッダー（ドロップダウンと閉じるボタン） ---
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // ▼ ここをテキストからドロップダウンに変更
                          Row(
                            children: [
                              DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: currentViewArea,
                                  icon: const Icon(
                                    Icons.arrow_drop_down,
                                    color: Colors.green,
                                  ),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18, // 少し大きくして見やすく
                                  ),
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      // ★ダイアログ内の表示を更新（画像を切り替え）
                                      setStateInDialog(() {
                                        currentViewArea = newValue;
                                      });
                                    }
                                  },
                                  // _areaDataのキー（区の名前一覧）からリストを作る
                                  items: _areaData.keys
                                      .map<DropdownMenuItem<String>>((
                                        String value,
                                      ) {
                                        return DropdownMenuItem<String>(
                                          value: value,
                                          child: Text(value),
                                        );
                                      })
                                      .toList(),
                                ),
                              ),
                              const Text(
                                ' のエリア',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                            ],
                          ),

                          // 閉じるボタン
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),

                    // --- 画像表示エリア（拡大縮小対応） ---
                    Flexible(
                      child: Container(
                        color: Colors.grey[100],
                        width: double.infinity,
                        height: 400,
                        child: InteractiveViewer(
                          minScale: 0.5,
                          maxScale: 5.0,
                          panEnabled: true,
                          child: Image.asset(
                            path,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(20.0),
                                  child: Text(
                                    '画像が見つかりませんでした。\n(assets/images/を確認してください)',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ★指定した年月にジャンプするメソッド
  void _jumpToMonth(int year, int month) {
    // 開始年(baseYear)からの月数（インデックス）を計算
    final targetIndex = (year - baseYear) * 12 + (month - 1);

    // 範囲内に収めてページ移動のアニメーションを実行
    _pageController.animateToPage(
      targetIndex.clamp(0, totalMonths - 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      drawer: LeftMenuDrawer(
        lang: _lang,
        selectedArea: _selectedArea,

        onLangChanged: (UiLang newLang) {
          _loadTranslations(newLang);
        },

        onAreaChanged: () async {
          // 1. ドロワーを閉じる
          Navigator.pop(context);

          // 2. 保存された新しい地域情報を読み込み直す
          // この関数の中で setState と _loadScheduleData() が呼ばれるので、
          // 画面は自動的に新しい地域のカレンダーに切り替わります。
          await _loadAreaSelection();
        },
      ),

      // --- AppBar ---
      appBar: AppBar(
        centerTitle: true, // これが重要
        titleSpacing: 0,
        backgroundColor: const Color.fromARGB(
          255,
          0,
          255,
          170,
        ).withOpacity(0.8),
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        // ★修正: Containerをやめて、制約のない状態でRowを置く
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center, // 中央寄せ
          mainAxisSize: MainAxisSize.min, // コンテンツの幅に合わせる
          children: [
            // ① 区を選ぶドロップダウン
            // Flexibleだと縮みすぎてしまうことがあるので、Containerで幅を指定するか、
            // そのまま置いてみるのが良いです。ここではConstrainedBoxで最大幅を制限します。
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140), // 幅を程よく制限
              child: _HeaderDropdown<String>(
                label: _trans['ward'] ?? '区',
                value: _selectedWard,
                items: _wardList,
                itemLabel: (v) =>
                    _lang == UiLang.ja ? v : (_wardNamesEn[v] ?? v),
                width: null,
                onChanged: (newWard) {
                  setState(() {
                    _selectedWard = newWard;
                    _selectedArea = _areaData[newWard]!.first;
                  });
                  _saveAreaSelection();
                  _loadScheduleData();
                },
              ),
            ),

            const SizedBox(width: 8),

            // ② 番号を選ぶドロップダウン
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 100), // 幅を程よく制限
              child: _HeaderDropdown<String>(
                label: 'No.',
                value: _selectedArea,
                items: _areaData[_selectedWard]!,
                itemLabel: (v) => v.replaceFirst(_selectedWard, ''),
                width: null,
                onChanged: (String? newArea) {
                  if (newArea == null) return;
                  setState(() {
                    _selectedArea = newArea;
                  });
                  _saveAreaSelection();
                  _loadScheduleData();
                },
              ),
            ),

            const SizedBox(width: 8),

            // ③ マップ確認ボタン
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFE7EBF3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE1E5EE)),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(
                  Icons.map_outlined,
                  size: 20,
                  color: Colors.blueGrey,
                ),
                tooltip: _lang == UiLang.ja ? '地図を確認' : 'Check Map',
                onPressed: _showAreaMapDialog,
              ),
            ),
          ],
        ),
      ),

      // --- Body ---
      body: Container(
        // ★ グラデーション背景の適用
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromARGB(255, 250, 250, 227), // #ffffe0
              Color.fromARGB(255, 199, 228, 199), // #f0fff0
            ],
          ),
        ),
        child: Scrollbar(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  children: [
                    // 1. カレンダーカード
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE1E5EE)),
                      ),
                      child: Column(
                        children: [
                          // --- 年月操作 ---
                          Row(
                            children: [
                              // 年の操作
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.arrow_back_ios,
                                      size: 16,
                                    ),
                                    onPressed: _visibleYear > baseYear
                                        ? () => _jumpToMonth(
                                            _visibleYear - 1,
                                            _visibleMonth,
                                          )
                                        : null,
                                  ),
                                  // ★修正: 「年」の表示切り替え
                                  Text(
                                    _lang == UiLang.ja
                                        ? ' $_visibleYear年 ' // 日本語: 2026年
                                        : ' $_visibleYear ', // 英語: 2026
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                    ),
                                    onPressed: _visibleYear < maxYear
                                        ? () => _jumpToMonth(
                                            _visibleYear + 1,
                                            _visibleMonth,
                                          )
                                        : null,
                                  ),
                                ],
                              ),

                              const SizedBox(width: 10),

                              // 月の選択ドロップダウン
                              Expanded(
                                child: _LabeledDropdown<int>(
                                  // ★修正: ラベルを「月」か「Month」に切り替え
                                  label: _trans['month'] ?? '月',
                                  value: _visibleMonth,
                                  items: List.generate(12, (i) => i + 1),
                                  itemLabel: (v) => '$v', // 数字はそのまま
                                  onChanged: (v) {
                                    _jumpToMonth(_visibleYear, v);
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 8),

                          // カレンダーグリッド本体
                          AspectRatio(
                            aspectRatio: 7 / 7,
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFCED6E6),
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                children: [
                                  // 曜日ヘッダー
                                  _WeekdayRow(trans: _trans),

                                  // 日付部分 PageView
                                  Expanded(
                                    child: Listener(
                                      onPointerSignal: _handlePointerSignal,
                                      child: PageView.builder(
                                        controller: _pageController,
                                        scrollDirection: Axis.vertical,
                                        itemCount: totalMonths,
                                        onPageChanged: (index) {
                                          final m = _monthFromIndex(index);
                                          setState(() {
                                            _visibleYear = m.year;
                                            _visibleMonth = m.month;
                                            _pickedYear = m.year;
                                            _pickedMonth = m.month;
                                          });
                                        },
                                        itemBuilder: (context, index) {
                                          final month = _monthFromIndex(index);
                                          return _MonthGrid(
                                            month: month,
                                            selectedDate: _selectedDate,
                                            garbageTypesOf: _garbageTypesFor,
                                            onDateTap: (d) => _onDateTap(
                                              d,
                                              currentMonth: month,
                                            ),
                                            lang: _lang,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // 2. 選択された日の詳細情報カード
                    _SelectedInfoCard(
                      selectedDate: _selectedDate,
                      lang: _lang,
                      garbageTextOf: _garbageTextFor,
                    ),

                    const SizedBox(height: 10),

                    // 3. 詳細ガイドボタン
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () =>
                            setState(() => _showGuide = !_showGuide),
                        // ... (スタイル)
                        child: Text(
                          _showGuide
                              ? (_trans['hide_guide'] ?? '詳細情報を非表示') // ★JSON使用
                              : (_trans['show_guide'] ?? '詳細情報を表示'), // ★JSON使用
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                    // 4. ガイドパネル
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: _showGuide
                          ? Padding(
                              key: const ValueKey('guide'),
                              padding: const EdgeInsets.only(top: 10),
                              // ★修正: transを渡す
                              child: _GarbageGuidePanel(trans: _trans),
                            )
                          : const SizedBox.shrink(key: ValueKey('empty')),
                    ),

                    const SizedBox(height: 10),

                    // 5. 重要なお知らせカード
                    _ImportantNoticeCard(
                      trans: _trans, // ★追加: タイトル用
                      selectedArea: _selectedArea,
                      // ★JSONからリストを取得
                      items: List<String>.from(
                        _trans['important_notices'] ?? [],
                      ),
                    ),

                    const SizedBox(height: 10),

                    // 6. お問い合わせカード
                    _InquiryCard(
                      trans: _trans, // ★追加: タイトル用
                      selectedArea: _selectedArea,
                      // ★JSONからリストを取得
                      lines: List<String>.from(_trans['contact_info'] ?? []),
                    ),

                    const SizedBox(height: 10),

                    // 7. 週間スケジュールカード
                    _WeeklyScheduleCard(
                      trans: _trans,
                      selectedDate: _selectedDate ?? DateTime.now(),
                      garbageTypesOf: _garbageTypesFor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =========================== // セクション区切り
// 補助ウィジェット：AppBar用ドロップダウン
// =========================== // セクション区切り

class _HeaderDropdown<T> extends StatelessWidget {
  // AppBar内で使う装飾付きDropdown
  final String label; // 表示ラベル
  final T value; // 現在値
  final List<T> items; // 候補一覧
  final String Function(T) itemLabel; // 候補→表示文字変換
  final ValueChanged<T> onChanged; // 選択変更通知
  final double? width;

  const _HeaderDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 40, // 高さ固定
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE1E5EE)), // 枠線
        borderRadius: BorderRadius.circular(10), // 角丸
        color: const Color(0xFFE7EBF3), // 背景
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10), // 内側余白
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          isExpanded: true, // これにより幅いっぱいまで広がる
          icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
          items: items.map((v) {
            // 表示文字の変換（ラベルがある場合）
            // 親側で replaceFirst などをしている処理がここで反映されます
            return DropdownMenuItem<T>(
              value: v,
              child: Text(
                itemLabel(v),
                overflow: TextOverflow.ellipsis, // 長い時は省略
              ),
            );
          }).toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

// =========================== // セクション区切り
// 補助ウィジェット：年/月ドロップダウン // カレンダー操作用
// =========================== // セクション区切り

class _LabeledDropdown<T> extends StatelessWidget {
  // InputDecoratorを使って「ラベル付き入力欄」風に見せるドロップダウン
  final String label; // ラベル（例：'年', '月'）
  final T value; // 現在値
  final List<T> items; // 選択肢
  final String Function(T) itemLabel; // 表示用変換関数
  final ValueChanged<T> onChanged; // 変更通知

  const _LabeledDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      // テキストフィールドのような枠とラベルを表示するためのラッパー
      decoration: InputDecoration(
        labelText: label, // 左上のラベル
        isDense: true, // 縦幅を詰める
        border: const OutlineInputBorder(), // 囲み枠
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 8,
        ), // 内側の余白
      ),
      child: DropdownButtonHideUnderline(
        // ドロップダウン自体の下線を消す（InputDecoratorの枠を使うため）
        child: DropdownButton<T>(
          value: value, // 現在値
          isDense: true, // 縦幅詰め
          isExpanded: true, // 横幅最大
          items: items
              .map(
                (v) => DropdownMenuItem<T>(
                  value: v,
                  child: Text(itemLabel(v)), // 選択肢の文字
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v); // 変更通知
          },
        ),
      ),
    ); // InputDecorator終わり
  }
} // _LabeledDropdown終わり

// =========================== // セクション区切り
// 補助ウィジェット：曜日行 // カレンダー上部の「日 月 火...」
// =========================== // セクション区切り

class _WeekdayRow extends StatelessWidget {
  final Map<String, dynamic> trans;
  const _WeekdayRow({required this.trans});

  @override
  Widget build(BuildContext context) {
    // JSONから曜日リストを作成
    final days = [
      trans['sun'] ?? '日',
      trans['mon'] ?? '月',
      trans['tue'] ?? '火',
      trans['wed'] ?? '水',
      trans['thu'] ?? '木',
      trans['fri'] ?? '金',
      trans['sat'] ?? '土',
    ];

    return Container(
      height: 40, // 行の高さ固定
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE7EBF3)), // 下線のみ描画
        ),
      ),
      child: Row(
        // 7つの曜日を均等配置
        children: List.generate(
          7,
          (i) => Expanded(
            child: Center(
              child: Text(
                days[i], // 曜日文字
                style: TextStyle(
                  fontSize: 12, // フォントサイズ
                  fontWeight: FontWeight.bold, // 太字
                  // 色分けロジック：日曜(0)は赤、土曜(6)は青、平日は黒
                  color: i == 0
                      ? Colors.red
                      : i == 6
                      ? Colors.blue
                      : Colors.black,
                ),
              ),
            ),
          ),
        ), // List.generate終わり
      ), // Row終わり
    ); // Container終わり
  }
} // _WeekdayRow終わり

// =========================== // セクション区切り
// 補助ウィジェット：月グリッド（★複数色＋複数アイコン対応）
// =========================== // セクション区切り

// --- カレンダーの「月」ごとのグリッド表示クラス ---
class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final DateTime? selectedDate;
  final List<GarbageType> Function(DateTime) garbageTypesOf;
  final Function(DateTime) onDateTap;
  final UiLang lang;

  const _MonthGrid({
    required this.month,
    required this.selectedDate,
    required this.garbageTypesOf,
    required this.onDateTap,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    // 月の初日と末日を計算
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final daysInMonth = lastDay.day;

    // 1日が何曜日か（日曜=0, 月曜=1...となるように調整）
    // DateTime.weekdayは 月=1...日=7 なので、日曜始まりのグリッドにするなら調整が必要
    // ここでは日曜始まり(0)〜土曜(6)のインデックスに変換します
    final firstWeekdayIndex = (firstDay.weekday == 7) ? 0 : firstDay.weekday;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(), // 親のスクロールを使うため
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7, // 1週間は7日
        childAspectRatio: 0.85, // セルの縦横比
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      // マスの数 = 空白マス(1日の前) + 日数
      itemCount: firstWeekdayIndex + daysInMonth,
      itemBuilder: (context, index) {
        // 1日より前の空白セル
        if (index < firstWeekdayIndex) {
          return const SizedBox.shrink();
        }

        // 今日の日付を計算
        final day = index - firstWeekdayIndex + 1;
        final date = DateTime(month.year, month.month, day);

        // ゴミの種類を取得
        final types = garbageTypesOf(date);

        // 選択されているか
        final isSelected =
            selectedDate != null &&
            selectedDate!.year == date.year &&
            selectedDate!.month == date.month &&
            selectedDate!.day == date.day;

        // ★ここで個別のセルを描画
        return GestureDetector(
          onTap: () => onDateTap(date),
          child: _DayCell(date: date, types: types, isSelected: isSelected),
        );
      },
    );
  }
}

// --- ★ここが重要：1日ごとのセル描画（分割ロジック） ---
class _DayCell extends StatelessWidget {
  final DateTime date;
  final List<GarbageType> types;
  final bool isSelected;

  const _DayCell({
    required this.date,
    required this.types,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    // 枠線の色（選択時は青、通常は透明）
    final borderColor = isSelected ? Colors.blue : Colors.transparent;
    final borderWidth = isSelected ? 2.0 : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white, // ベース背景
        border: Border.all(color: borderColor, width: borderWidth),
        borderRadius: BorderRadius.circular(6),
        boxShadow: isSelected
            ? [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 4)]
            : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4), // 中身も角丸に
        child: Stack(
          children: [
            // -------------------------------------------
            // 1. 背景色（左右分割ロジック）
            // -------------------------------------------
            if (types.isNotEmpty)
              Row(
                children: types.map((type) {
                  // Expandedを使うことで、リストが1つなら全幅、2つなら50%ずつに自動分割される
                  return Expanded(
                    child: Container(color: garbageBgColor(type)),
                  );
                }).toList(),
              ),

            // -------------------------------------------
            // 2. 日付数字（左上）
            // -------------------------------------------
            Positioned(
              top: 3,
              left: 4,
              child: Text(
                '${date.day}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  // 日曜日は赤、その他は黒
                  color: date.weekday == 7 ? Colors.red : Colors.black87,
                ),
              ),
            ),

            // -------------------------------------------
            // 3. アイコン（中央）
            // -------------------------------------------
            if (types.isNotEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 14), // 日付と被らないように少し下げる
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: types.map((type) {
                      // 2つの時は少し小さく(18)、1つの時は大きく(26)
                      final size = types.length > 1 ? 18.0 : 26.0;
                      return Icon(
                        garbageIcon(type),
                        color: garbageIconColor(type),
                        size: size,
                      );
                    }).toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// =========================== // セクション区切り
// 補助ウィジェット：選択日情報カード // 選択日と「週×曜日：何ゴミ」を表示
// =========================== // セクション区切り

class _SelectedInfoCard extends StatelessWidget {
  // 選択日情報カード
  final DateTime? selectedDate; // 選択日（nullなら未選択）
  final UiLang lang; // 表示言語
  final String Function(DateTime date) garbageTextOf; // 日付→表示文言（週×曜日：何ゴミ）

  const _SelectedInfoCard({
    required this.selectedDate, // 選択日
    required this.lang, // 言語
    required this.garbageTextOf, // 文言生成関数
  }); // コンストラクタ終わり

  @override
  Widget build(BuildContext context) {
    if (selectedDate == null) {
      // 未選択なら
      return Container(
        width: double.infinity, // 横幅いっぱい
        padding: const EdgeInsets.all(12), // 余白
        decoration: BoxDecoration(
          color: Colors.white, // 背景白
          borderRadius: BorderRadius.circular(12), // 角丸
        ), // decoration終わり
        child: Text(
          lang == UiLang.ja ? '日付を選択してください' : 'Please select a date',
        ), // 案内文
      ); // Container終わり
    } // if終わり

    final info = garbageTextOf(selectedDate!); // 選択日の説明文を作る

    return Container(
      width: double.infinity, // 横幅いっぱい
      padding: const EdgeInsets.all(12), // 余白
      decoration: BoxDecoration(
        color: Colors.white, // 背景白
        borderRadius: BorderRadius.circular(12), // 角丸
      ), // decoration終わり
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // 左寄せ
        children: [
          Text(
            '${selectedDate!.year}/${selectedDate!.month}/${selectedDate!.day}', // 日付表示
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ), // 太字・大きめ
          ), // Text終わり
          const SizedBox(height: 6), // 間隔
          Text(info), // 「週×曜日：何ゴミ」または固定除外メッセージ
        ], // children終わり
      ), // Column終わり
    ); // Container終わり
  } // build終わり
} // _SelectedInfoCard終わり

// ===========================
// ★詳細情報パネル：ゴミ出しの注意点ガイド（JSONデータ対応版）
// ===========================
class _GarbageGuidePanel extends StatelessWidget {
  // ★変更: UiLangではなく翻訳データを受け取る
  final Map<String, dynamic> trans;

  const _GarbageGuidePanel({
    required this.trans, // ★変更
  });

  Widget _typeCard({
    required GarbageType type,
    required String title,
    required String note,
  }) {
    // (このメソッドの中身はデザインなので変更なし)
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1E5EE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(garbageIcon(type), color: garbageIconColor(type), size: 28),
              const SizedBox(height: 4),
              Container(
                width: 24,
                height: 4,
                decoration: BoxDecoration(
                  color: garbageBgColor(type),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  note,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF424242),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 表示する項目の定義（種類とJSONキーのマッピング）
    final items = [
      (type: GarbageType.burnable, key: 'burnable'),
      (type: GarbageType.spray, key: 'spray'),
      (type: GarbageType.nonBurnable, key: 'non_burnable'),
      (type: GarbageType.lighter, key: 'lighter'),
      (type: GarbageType.recyclable, key: 'recyclable'),
      (type: GarbageType.battery, key: 'battery'),
      (type: GarbageType.plastic, key: 'plastic'),
      (type: GarbageType.paper, key: 'paper'),
      (type: GarbageType.green, key: 'green'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1E5EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 20,
                color: Color(0xFF616161),
              ),
              const SizedBox(width: 8),
              Text(
                // ★JSONから取得。なければデフォルトで日本語
                trans['guide_title'] ?? 'ごみの出し方ガイド',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ループで各ゴミのカードを生成
          ...items.map((item) {
            // ★JSONからタイトルと説明文を取得
            // 例: "trash_burnable", "note_burnable"
            final title = trans['trash_${item.key}'] ?? '';
            final note = trans['note_${item.key}'] ?? '';

            return _typeCard(type: item.type, title: title, note: note);
          }),

          const SizedBox(height: 4),
          Text(
            trans['guide_disclaimer'] ?? '※ 詳しくは札幌市の公式ガイドブック等をご確認ください。',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

// ===========================
// 重要なお知らせカード
// ===========================
class _ImportantNoticeCard extends StatelessWidget {
  // ★langではなくtransを受け取る
  final Map<String, dynamic> trans;
  final String selectedArea;

  // itemsは親から渡さず、ここでtransから取り出す形でもOKですが、
  // 親で取り出して渡す形を維持するなら以下のようになります。
  // 今回は「親からリストをもらう」形を維持しつつ、
  // タイトル部分をJSON化するために trans も受け取れるようにします。
  final List<String> items;

  const _ImportantNoticeCard({
    required this.trans, // ★追加
    required this.selectedArea,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // (装飾部分は変更なし)
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.error_outline,
                color: Color(0xFFD32F2F),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  // ★JSONから取得
                  trans['ui_important_notice'] ?? '重要なお知らせ',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('・$t', style: const TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================
// お問い合わせカード
// ===========================
class _InquiryCard extends StatelessWidget {
  final Map<String, dynamic> trans; // ★追加
  final String selectedArea;
  final List<String> lines;

  const _InquiryCard({
    required this.trans, // ★追加
    required this.selectedArea,
    required this.lines,
  });

  // (_spansWithGrayBracketsメソッドは変更なし)
  List<TextSpan> _spansWithGrayBrackets(String text) {
    // ... (省略) ...
    // 元のコードのままでOK
    final spans = <TextSpan>[];
    final reg = RegExp(r'\[[^\]]*\]');
    int idx = 0;
    for (final m in reg.allMatches(text)) {
      if (m.start > idx)
        spans.add(TextSpan(text: text.substring(idx, m.start)));
      spans.add(
        TextSpan(
          text: text.substring(m.start, m.end),
          style: const TextStyle(color: Color(0xFF757575)),
        ),
      );
      idx = m.end;
    }
    if (idx < text.length) spans.add(TextSpan(text: text.substring(idx)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // (装飾部分は変更なし)
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBBDEFB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.phone_in_talk_outlined,
                color: Color(0xFF1565C0),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  // ★JSONから取得
                  trans['ui_contact'] ?? 'お問い合わせ',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 13, color: Colors.black),
                  children: _spansWithGrayBrackets(line),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===========================
// 補助ウィジェット：週間スケジュールカード（修正版）
// ===========================
class _WeeklyScheduleCard extends StatelessWidget {
  final Map<String, dynamic> trans; // ★変更: 言語フラグではなく翻訳データを受け取る
  final DateTime selectedDate;
  final List<GarbageType> Function(DateTime) garbageTypesOf;

  const _WeeklyScheduleCard({
    required this.trans, // ★変更
    required this.selectedDate,
    required this.garbageTypesOf,
  });

  // 曜日ラベル取得 (JSONキーに対応)
  String _weekdayLabel(int weekday) {
    // DateTime.weekday: 1=月, ..., 7=日
    switch (weekday) {
      case 1:
        return trans['mon'] ?? 'Mon';
      case 2:
        return trans['tue'] ?? 'Tue';
      case 3:
        return trans['wed'] ?? 'Wed';
      case 4:
        return trans['thu'] ?? 'Thu';
      case 5:
        return trans['fri'] ?? 'Fri';
      case 6:
        return trans['sat'] ?? 'Sat';
      case 7:
        return trans['sun'] ?? 'Sun';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    // 基準日が含まれる週の「日曜日」を計算
    final sunday = selectedDate.subtract(
      Duration(days: selectedDate.weekday % 7),
    );

    // 日〜土の7日間を生成
    final weekDays = List.generate(
      7,
      (index) => sunday.add(Duration(days: index)),
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1E5EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- ヘッダー ---
          Row(
            children: [
              const Icon(
                Icons.calendar_view_week,
                size: 20,
                color: Color(0xFF616161),
              ),
              const SizedBox(width: 8),
              Text(
                trans['ui_weekly_schedule'] ?? 'Weekly Schedule', // ★JSONキー使用
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              // 期間を表示
              Text(
                '${weekDays.first.month}/${weekDays.first.day} 〜 ${weekDays.last.month}/${weekDays.last.day}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // --- 7日間のリスト ---
          ...weekDays.map((date) {
            final types = garbageTypesOf(date);
            final isToday =
                (date.year == selectedDate.year &&
                date.month == selectedDate.month &&
                date.day == selectedDate.day);

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: isToday
                  ? BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    )
                  : null,
              child: Row(
                children: [
                  // 日付と曜日
                  SizedBox(
                    width: 70, // 少し幅を広げました
                    child: Text(
                      '${date.day} (${_weekdayLabel(date.weekday)})',
                      style: TextStyle(
                        fontWeight: isToday
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: date.weekday == 7
                            ? Colors.red
                            : date.weekday == 6
                            ? Colors.blue
                            : Colors.black,
                      ),
                    ),
                  ),
                  // ゴミの内容
                  Expanded(
                    child: types.isEmpty
                        ? Text(
                            '-',
                            style: TextStyle(color: Colors.grey.shade400),
                          )
                        : Text(
                            // ★修正: グローバルの garbageLabel 関数を使用
                            types
                                .map((t) => garbageLabel(t, trans))
                                .join(' / '),
                            style: TextStyle(
                              fontWeight: isToday
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: Colors.black87,
                            ),
                          ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
