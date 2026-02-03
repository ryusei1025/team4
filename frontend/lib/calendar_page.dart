// import 'dart:convert'; // 将来JSON読み込みが必要になったら復活させる

import 'package:flutter/gestures.dart'; // マウスホイール操作用
import 'package:flutter/material.dart'; // UI部品用
import 'drawer_menu.dart'; // ドロワーメニューや言語設定
import 'package:csv/csv.dart'; // CSV解析用
import 'package:flutter/services.dart' show rootBundle; // アセット読み込み用

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
String garbageLabel(GarbageType type, UiLang lang) {
  if (lang == UiLang.ja) {
    switch (type) {
      case GarbageType.burnable:
        return '燃やせるごみ（有料）';
      case GarbageType.spray:
        return 'スプレー缶類（別袋無料）';
      case GarbageType.nonBurnable:
        return '燃やせないごみ（有料）';
      case GarbageType.lighter:
        return '加熱式たばこ・ライター・筒型乾電池（別袋無料）';
      case GarbageType.recyclable:
        return 'びん・缶・ペットボトル（無料）';
      case GarbageType.battery:
        return '乾電池（無料）';
      case GarbageType.plastic:
        return '容器包装プラスチック（無料）';
      case GarbageType.paper:
        return '雑がみ（無料）';
      case GarbageType.green:
        return '枝・葉・草（無料）';
    }
  } else {
    switch (type) {
      case GarbageType.burnable:
        return 'Burnable (Paid)';
      case GarbageType.spray:
        return 'Spray cans (Free)';
      case GarbageType.nonBurnable:
        return 'Non-burnable (Paid)';
      case GarbageType.lighter:
        return 'Lighters/Batteries (Free)';
      case GarbageType.recyclable:
        return 'Bottles/Cans/PET (Free)';
      case GarbageType.battery:
        return 'Batteries (Free)';
      case GarbageType.plastic:
        return 'Plastic containers (Free)';
      case GarbageType.paper:
        return 'Mixed Paper (Free)';
      case GarbageType.green:
        return 'Leaves/Grass (Free)';
    }
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

  // 区のリスト（中央区, 豊平区...）を取得するゲッター
  List<String> get _wardList => _areaData.keys.toList();

  // 現在選択されている地域（初期値）
  String _selectedArea = '中央区1';

  // 現在選択されている「区」（初期値は仮置き、initStateで確定させる）
  String _selectedWard = '中央区';

  UiLang _lang = UiLang.ja;
  bool _showGuide = false; // ガイド表示フラグ

  // ==========================================
  // 5. データ：お知らせ・お問い合わせ・祝日設定
  // ==========================================

  // 重要なお知らせ（共通）
  late final List<String> _commonImportantNotice = <String>[
    'ごみは収集日の朝8時30分までに出してください',
    '指定袋以外での排出は収集されません',
    '年末年始は収集日程が変更になります',
    '台風等の悪天候時は収集を中止する場合があります',
    '土日はごみ収集を行いません',
  ];

  // 全10区に対応させました（内容は共通のものをセット）
  late final Map<String, List<String>> _importantNoticeByArea = {
    '中央区': _commonImportantNotice,
    '北区': _commonImportantNotice,
    '東区': _commonImportantNotice,
    '白石区': _commonImportantNotice,
    '厚別区': _commonImportantNotice,
    '豊平区': _commonImportantNotice,
    '清田区': _commonImportantNotice,
    '南区': _commonImportantNotice,
    '西区': _commonImportantNotice,
    '手稲区': _commonImportantNotice,
  };

  // お問い合わせ情報（共通）
  late final List<String> _commonInquiry = <String>[
    '札幌市コールセンター : [011-222-4894]',
    '受付時間 : [平日 8:00〜21:00]',
    '土日祝 : [9:00〜17:00]',
    '札幌市公式ウェブサイト : https://www.city.sapporo.jp/seiso/kaisyu/index.html',
  ];

  // 全10区に対応させました
  late final Map<String, List<String>> _inquiryByArea = {
    '中央区': _commonInquiry,
    '北区': _commonInquiry,
    '東区': _commonInquiry,
    '白石区': _commonInquiry,
    '厚別区': _commonInquiry,
    '豊平区': _commonInquiry,
    '清田区': _commonInquiry,
    '南区': _commonInquiry,
    '西区': _commonInquiry,
    '手稲区': _commonInquiry,
  };

  // ★【追加】読み込んだスケジュールデータ（日付 -> ゴミ種別リスト）
  Map<DateTime, List<GarbageType>> _scheduleCache = {};

  // ==========================================
  // 6. 初期化とロジックメソッド
  // ==========================================

  @override
  void initState() {
    super.initState();

    _updateWardFromArea();

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
      return _lang == UiLang.ja ? '収集なし' : 'No collection';
    }

    // 3. ゴミ種別を文字に変換して連結（例：「燃やせるごみ・プラスチック」）
    // garbageLabelメソッドは元のコードにあるはずなので、そのまま使います
    final gText = types
        .map((t) => garbageLabel(t, _lang))
        .join(_lang == UiLang.ja ? '・' : ' / ');

    // 4. シンプルにゴミの内容だけを返す
    // （日付や曜日は画面の他の場所に表示されるため、ここでは不要です）
    return gText;
  }

  /// 選択中の地域名から、対応する地図画像のパスを返す
  String _getAreaMapAssetPath(String areaName) {
    // プレフィックス（前方一致）で判定します
    if (areaName.startsWith('中央区')) return 'assets/images/map_chuo.png';
    if (areaName.startsWith('北区')) return 'assets/images/map_kita.png';
    if (areaName.startsWith('東区')) return 'assets/images/map_higashi.png';
    if (areaName.startsWith('白石区')) return 'assets/images/map_shiroishi.png';
    if (areaName.startsWith('厚別区')) return 'assets/images/map_atsubetsu.png';
    if (areaName.startsWith('豊平区')) return 'assets/images/map_toyohira.png';
    if (areaName.startsWith('清田区')) return 'assets/images/map_kiyota.png';
    if (areaName.startsWith('南区')) return 'assets/images/map_minami.png';
    if (areaName.startsWith('西区')) return 'assets/images/map_nishi.png';
    if (areaName.startsWith('手稲区')) return 'assets/images/map_teine.png';

    return ''; // 画像がない場合
  }

  /// 地図画像をポップアップで表示する
  void _showAreaMapDialog() {
    final path = _getAreaMapAssetPath(_selectedArea);
    if (path.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // 内容に合わせて高さを調整
            children: [
              // ヘッダー（タイトルと閉じるボタン）
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Text(
                        '$_selectedArea のエリア',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // 画像表示エリア
              Flexible(
                child: SingleChildScrollView(
                  child: Image.asset(
                    path,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      // 画像が見つからない場合のエラー表示
                      return const Padding(
                        padding: EdgeInsets.all(20.0),
                        child: Text(
                          '画像が見つかりませんでした。\n(assets/images/を確認してください)',
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
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

  @override // buildメソッドをオーバーライドしてUIを描画
  Widget build(BuildContext context) {
    // 画面UI構築（状態変化、setStateなどで再ビルドされる）
    return Scaffold(
      // 画面の基本構造（土台）
      backgroundColor: const Color(0xFFF6F7FB), // 背景色（薄いグレー）
      // 左側のドロワーメニュー（外部ファイルで定義されたWidget）
      drawer: LeftMenuDrawer(
        lang: _lang,
        selectedArea: _selectedArea,
        onLangChanged: (newLang) => setState(() => _lang = newLang),
      ),

      // 上部のヘッダーバー（固定表示）
      appBar: AppBar(
        centerTitle: true, // タイトルを中央寄せ

        titleSpacing: 0,
        backgroundColor: const Color.fromARGB(
          255,
          0,
          221,
          192,
        ).withValues(alpha: 0.8), // 少し透けさせて馴染ませる
        // 左側のハンバーガーメニューボタン
        leading: Builder(
          // Scaffold.of(context)を正しく動作させるためにBuilderで新しいcontextを作成
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(), // ドロワーを開く
          ),
        ),

        title: Container(
          padding: EdgeInsets.zero, // 余計な余白を消して広く使う
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center, // 中央寄せ
            mainAxisSize: MainAxisSize.min,
            children: [
              // ① 区を選ぶドロップダウン（例：中央区）
              Flexible(
                flex: 5, // 幅の比率（少し広め）
                child: _HeaderDropdown<String>(
                  label: _lang == UiLang.ja ? '区' : 'Ward',
                  value: _selectedWard,
                  items: _wardList, // 区のリスト
                  itemLabel: (v) => v,
                  width: null, // ★重要：nullにしてFlexibleに幅調整を任せる
                  onChanged: (newWard) {
                    setState(() {
                      _selectedWard = newWard;
                      // 区が変わったら、その区の「1番目」を自動選択する
                      _selectedArea = _areaData[newWard]!.first;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8), // 間隔
              // ---------------------------------------------
              // ② 番号を選ぶドロップダウン（幅の比率 4）
              // ---------------------------------------------
              Expanded(
                flex: 4, // 4割の幅を使う
                child: _HeaderDropdown<String>(
                  label: 'No.',
                  value: _selectedArea,
                  items: _areaData[_selectedWard]!, // 「中央区1」→「1」と表示
                  itemLabel: (v) => v.replaceFirst(_selectedWard, ''),
                  width: null, // 自動幅
                  onChanged: (newArea) {
                    setState(() {
                      _selectedArea = newArea;
                    });
                    // 番号が変わったら再読み込み
                    _loadScheduleData();
                  },
                ),
              ),
              const SizedBox(width: 8), // 間隔
              // ③ マップ確認ボタン（サイズ固定だがFlexible内にあるので安全）
              Container(
                width: 36, // 少し小さく
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

        // ★右側の言語切り替えボタンがあった場所（修正箇所）
        actions: const [
          // 言語ボタンがあった場所に、同じくらいの幅の「透明な箱」を置く
          // これでタイトルの位置ずれを防げます
          SizedBox(width: 50),
        ],
      ),

      // メインコンテンツ部分（スクロール可能）
      body: Container(
        // ★ グラデーション背景の適用
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromARGB(255, 247, 247, 209), // #ffffe0
              Color.fromARGB(255, 199, 228, 199), // #f0fff0
            ],
          ),
        ),
        child: Scrollbar(
          // スクロールバーを表示（PC/Webでの操作性向上）
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16), // 画面端からの余白
            child: Center(
              // 大画面でもコンテンツが広がりすぎないように中央寄せ
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 520,
                ), // 最大幅を520pxに制限
                child: Column(
                  // 要素を縦方向に並べる
                  children: [
                    // 1. カレンダーカード（年月選択 + カレンダー本体）
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFE1E5EE),
                        ), // 薄い枠線
                      ),
                      child: Column(
                        children: [
                          // --- 年月操作 ---
                          Row(
                            children: [
                              // 年の操作
                              Row(
                                children: [
                                  // 「前の年」ボタン
                                  IconButton(
                                    icon: const Icon(
                                      Icons.arrow_back_ios,
                                      size: 16,
                                    ),
                                    // ★修正: _visibleYear を使用して判定
                                    onPressed: _visibleYear > baseYear
                                        ? () => _jumpToMonth(
                                            _visibleYear - 1,
                                            _visibleMonth,
                                          )
                                        : null,
                                  ),
                                  // 「年」のテキスト表示
                                  Text(
                                    // ★修正: ここで _visibleYear を表示に使用
                                    ' $_visibleYear年 ',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  // 「次の年」ボタン
                                  IconButton(
                                    icon: const Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                    ),
                                    // ★修正: _visibleYear を使用して判定
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
                                  label: '月',
                                  value: _visibleMonth,
                                  items: List.generate(12, (i) => i + 1),
                                  itemLabel: (v) => '$v',
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
                            aspectRatio: 7 / 7, // 正方形に近い比率で固定
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
                                  // 曜日ヘッダー（日〜土）
                                  _WeekdayRow(lang: _lang),

                                  // 日付部分（スワイプ/スクロール可能なPageView）
                                  Expanded(
                                    child: Listener(
                                      // マウスホイールでの操作を検知
                                      onPointerSignal: _handlePointerSignal,
                                      child: PageView.builder(
                                        controller: _pageController,
                                        scrollDirection:
                                            Axis.vertical, // 縦スクロール
                                        itemCount: totalMonths,
                                        onPageChanged: (index) {
                                          // ページ切り替え時に年月表示を同期
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
                                            garbageTypesOf:
                                                _garbageTypesFor, // 日付ごとのゴミ種別判定
                                            onDateTap: (d) => _onDateTap(
                                              d,
                                              currentMonth: month,
                                            ), // タップ処理
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

                    // 3. 詳細ガイドの表示/非表示ボタン
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () =>
                            setState(() => _showGuide = !_showGuide),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.all(12),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          _showGuide
                              ? (_lang == UiLang.ja ? '詳細情報を非表示' : 'Hide guide')
                              : (_lang == UiLang.ja ? '詳細情報を表示' : 'Show guide'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                    // 4. ガイドパネル（アニメーション付き開閉）
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeOut,
                      child: _showGuide
                          ? Padding(
                              key: const ValueKey('guide'),
                              padding: const EdgeInsets.only(top: 10),
                              child: _GarbageGuidePanel(lang: _lang),
                            )
                          : const SizedBox.shrink(key: ValueKey('empty')),
                    ),

                    const SizedBox(height: 10),

                    // 5. 重要なお知らせカード
                    _ImportantNoticeCard(
                      lang: _lang,
                      selectedArea: _selectedArea,
                      items:
                          _importantNoticeByArea[_selectedArea] ??
                          _commonImportantNotice,
                    ),

                    const SizedBox(height: 10),

                    // 6. お問い合わせカード
                    _InquiryCard(
                      lang: _lang,
                      selectedArea: _selectedArea,
                      lines: _inquiryByArea[_selectedArea] ?? _commonInquiry,
                    ),

                    const SizedBox(height: 10),

                    // 7. 週間スケジュールカード（選択中の日付の週を表示）
                    _WeeklyScheduleCard(
                      lang: _lang,
                      // selectedDateがnullの場合は現在日時を渡す安全策
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
  // 曜日ラベルを表示する行
  final UiLang lang; // 言語設定（日/英切り替え用）

  const _WeekdayRow({required this.lang});

  @override
  Widget build(BuildContext context) {
    // 言語に応じた曜日ラベルリスト
    final labels = (lang == UiLang.ja)
        ? const ['日', '月', '火', '水', '木', '金', '土']
        : const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

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
                labels[i], // 曜日文字
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
// ★詳細情報パネル：ゴミ出しの注意点ガイド（CSV解析とは無関係に固定情報を表示）
// ===========================

class _GarbageGuidePanel extends StatelessWidget {
  final UiLang lang;

  const _GarbageGuidePanel({
    required this.lang,
    // selectedArea や rules は不要になったので削除
  });

  Widget _typeCard({
    required GarbageType type,
    required String title,
    required String note,
  }) {
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
          // 左側：アイコンと色
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
          // 右側：タイトルと説明
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
    // 表示するガイドデータの定義
    // ★修正：新しいGarbageTypeに合わせて8種類すべてを定義
    final items = [
      (
        type: GarbageType.burnable,
        titleJa: '燃やせるごみ',
        titleEn: 'Burnable',
        noteJa: '・生ごみは水をよく切る\n・食用油は紙や布に染み込ませる\n・汚れた紙やおむつもこちら\n・指定袋を使用',
        noteEn:
            'Drain food waste. Soak up oil. Dirty paper/diapers are also burnable. Use designated bags.',
      ),
      (
        type: GarbageType.spray, // ★追加
        titleJa: 'スプレー缶類',
        titleEn: 'Spray Cans',
        noteJa: '・穴を開けずに中身を使い切る\n・透明・半透明の袋に入れる\n・「燃やせるごみ」の日に別袋にして出す',
        noteEn:
            'Use up completely. Do NOT puncture. Put in a separate transparent bag on Burnable days.',
      ),
      (
        type: GarbageType.nonBurnable,
        titleJa: '燃やせないごみ',
        titleEn: 'Non-burnable',
        noteJa: '・ガラス、陶磁器、小型家電など\n・刃物は紙に包んで「キケン」と書く\n・指定袋を使用',
        noteEn:
            'Glass, ceramics, small appliances. Wrap blades and label "Danger". Use designated bags.',
      ),
      (
        type: GarbageType.lighter, // ★追加
        titleJa: 'ライター・加熱式たばこ',
        titleEn: 'Lighters / Heated Tobacco',
        noteJa: '・中身を使い切る\n・水に浸してから透明・半透明の袋に入れる\n・「燃やせないごみ」の日に別袋にして出す',
        noteEn:
            'Use up completely. Soak in water. Put in a separate transparent bag on Non-burnable days.',
      ),
      (
        type: GarbageType.recyclable,
        titleJa: 'びん・缶・ペットボトル',
        titleEn: 'Bottles / Cans / PET',
        noteJa: '・中をすすぐ\n・ペットボトルのキャップとラベルは外して「プラ」へ\n・透明・半透明の袋に入れる',
        noteEn:
            'Rinse inside. Remove caps/labels from PET bottles (put in Plastic). Use transparent bags.',
      ),
      (
        type: GarbageType.battery, // ★追加
        titleJa: '筒型乾電池',
        titleEn: 'Batteries (Cylindrical)',
        noteJa: '・アルカリ、マンガン乾電池が対象\n・透明・半透明の袋に入れる\n・「びん・缶・ペット」の日に別袋にして出す',
        noteEn:
            'Alkaline/Manganese only. Put in a separate transparent bag on Recyclable days.',
      ),
      (
        type: GarbageType.plastic,
        titleJa: '容器包装プラスチック',
        titleEn: 'Plastic Containers',
        noteJa: '・プラマークがあるもの\n・汚れを洗い流す（落ちない場合は燃やせるごみへ）\n・二重袋にしない',
        noteEn: 'Items with Plastic mark. Rinse off dirt. Do not double bag.',
      ),
      (
        type: GarbageType.paper, // ★追加
        titleJa: '雑がみ',
        titleEn: 'Mixed Paper',
        noteJa: '・お菓子などの紙箱、封筒、はがき、トイレットペーパーの芯など\n・紙袋に入れるか、ひもで束ねて出す',
        noteEn:
            'Paper boxes, envelopes, cores. Put in paper bags or tie with string.',
      ),
      (
        type: GarbageType.green, // ★追加
        titleJa: '枝・葉・草',
        titleEn: 'Branches / Grass',
        noteJa: '・枝は長さ50cmくらいに束ねる\n・草や葉は透明・半透明の袋に入れる\n・生ごみと混ぜない',
        noteEn:
            'Bundle branches (approx 50cm). Put grass/leaves in transparent bags. Do not mix with food waste.',
      ),
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
                lang == UiLang.ja ? 'ごみの出し方ガイド' : 'Sorting Guide',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          ...items.map((item) {
            return _typeCard(
              type: item.type,
              title: lang == UiLang.ja ? item.titleJa : item.titleEn,
              note: lang == UiLang.ja ? item.noteJa : item.noteEn,
            );
          }),

          const SizedBox(height: 4),
          Text(
            lang == UiLang.ja
                ? '※ 詳しくは札幌市の公式ガイドブック等をご確認ください。'
                : '* Please refer to the official Sapporo City guide for details.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

// =========================== // セクション区切り
// ★追加：赤いカード「重要なお知らせ」 // 区ごとに内容が変わる想定
// =========================== // セクション区切り

class _ImportantNoticeCard extends StatelessWidget {
  final UiLang lang; // 表示言語（今回は日本語中心だが将来拡張用）
  final String selectedArea; // 選択中の区（見出し用）
  final List<String> items; // 表示する箇条書き

  const _ImportantNoticeCard({
    required this.lang, // 言語
    required this.selectedArea, // 区名
    required this.items, // 内容
  }); // コンストラクタ終わり

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, // 横幅いっぱい
      padding: const EdgeInsets.all(12), // 余白
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE), // ★薄い赤（重要を強調）
        borderRadius: BorderRadius.circular(12), // 角丸
        border: Border.all(color: const Color(0xFFFFCDD2)), // 赤系の枠線
      ), // decoration終わり
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // 左寄せ
        children: [
          Row(
            children: [
              const Icon(
                Icons.error_outline,
                color: Color(0xFFD32F2F),
                size: 20,
              ), // 注意アイコン
              const SizedBox(width: 8), // 間隔
              Expanded(
                child: Text(
                  lang == UiLang.ja
                      ? '重要なお知らせ（$selectedArea）'
                      : 'Important notice ($selectedArea)', // 見出し
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ), // 太字
                ), // Text終わり
              ), // Expanded終わり
            ], // children終わり
          ), // Row終わり
          const SizedBox(height: 8), // 間隔
          ...items.map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 6), // 行間
              child: Text('・$t', style: const TextStyle(fontSize: 13)), // 箇条書き
            ), // Padding終わり
          ), // map展開終わり
        ], // children終わり
      ), // Column終わり
    ); // Container終わり
  } // build終わり
} // _ImportantNoticeCard終わり

// =========================== // セクション区切り
// ★追加：青いカード「お問い合わせ」 // []内をグレー表示（RichText）
// =========================== // セクション区切り

class _InquiryCard extends StatelessWidget {
  final UiLang lang; // 表示言語（今回は日本語中心だが将来拡張用）
  final String selectedArea; // 選択中の区（見出し用）
  final List<String> lines; // 表示する行（[]を含める）

  const _InquiryCard({
    required this.lang, // 言語
    required this.selectedArea, // 区名
    required this.lines, // 内容
  }); // コンストラクタ終わり

  List<TextSpan> _spansWithGrayBrackets(String text) {
    // ★[]で囲まれた部分（ブラケット含む）をグレーにするTextSpan生成
    final spans = <TextSpan>[]; // 出力Spanリスト
    final reg = RegExp(r'\[[^\]]*\]'); // []部分を丸ごと抜き出す正規表現
    int idx = 0; // 現在位置

    for (final m in reg.allMatches(text)) {
      if (m.start > idx) {
        spans.add(TextSpan(text: text.substring(idx, m.start))); // 通常部分（デフォルト色）
      } // if終わり
      spans.add(
        TextSpan(
          text: text.substring(m.start, m.end), // []部分（ブラケット含む）
          style: const TextStyle(color: Color(0xFF757575)), // ★グレー
        ), // TextSpan終わり
      ); // add終わり
      idx = m.end; // 次の開始位置へ
    } // for終わり

    if (idx < text.length) {
      spans.add(TextSpan(text: text.substring(idx))); // 末尾の通常部分
    } // if終わり

    return spans; // Span一覧を返す
  } // _spansWithGrayBrackets終わり

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, // 横幅いっぱい
      padding: const EdgeInsets.all(12), // 余白
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD), // ★薄い青（問い合わせ）
        borderRadius: BorderRadius.circular(12), // 角丸
        border: Border.all(color: const Color(0xFFBBDEFB)), // 青系の枠線
      ), // decoration終わり
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // 左寄せ
        children: [
          Row(
            children: [
              const Icon(
                Icons.phone_in_talk_outlined,
                color: Color(0xFF1565C0),
                size: 20,
              ), // 電話アイコン
              const SizedBox(width: 8), // 間隔
              Expanded(
                child: Text(
                  lang == UiLang.ja
                      ? 'お問い合わせ（$selectedArea）'
                      : 'Contact ($selectedArea)', // 見出し
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ), // 太字
                ), // Text終わり
              ), // Expanded終わり
            ], // children終わり
          ), // Row終わり
          const SizedBox(height: 8), // 間隔

          ...lines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 6), // 行間
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black,
                  ), // デフォルト（黒）
                  children: _spansWithGrayBrackets(line), // ★[]だけグレーSpan
                ), // TextSpan終わり
              ), // RichText終わり
            ), // Padding終わり
          ), // map展開終わり
        ], // children終わり
      ), // Column終わり
    ); // Container終わり
  } // build終わり
} // _InquiryCard終わり

// ===========================
// ★修正：「今週（選択中の週）のスケジュール」を表示するカード
// ===========================
class _WeeklyScheduleCard extends StatelessWidget {
  final UiLang lang;
  final DateTime selectedDate; // 選択中の日付（基準日）
  final List<GarbageType> Function(DateTime) garbageTypesOf;

  const _WeeklyScheduleCard({
    required this.lang,
    required this.selectedDate, // 年(year)ではなく日付を受け取る
    required this.garbageTypesOf,
  });

  // 曜日ラベル取得
  String _weekdayLabel(int weekday) {
    const ja = ['', '月', '火', '水', '木', '金', '土', '日'];
    const en = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return lang == UiLang.ja ? ja[weekday] : en[weekday];
  }

  // ゴミの表示名
  String _garbageLabel(GarbageType type) {
    if (lang == UiLang.ja) {
      switch (type) {
        case GarbageType.burnable:
          return '燃やせるごみ';
        case GarbageType.spray:
          return 'スプレー缶';
        case GarbageType.nonBurnable:
          return '燃やせないごみ';
        case GarbageType.lighter:
          return 'ライター・電池';
        case GarbageType.recyclable:
          return 'びん・缶・ペット';
        case GarbageType.battery:
          return '乾電池';
        case GarbageType.plastic:
          return 'プラ';
        case GarbageType.paper:
          return '雑がみ';
        case GarbageType.green:
          return '枝・葉';
      }
    } else {
      switch (type) {
        case GarbageType.burnable:
          return 'Burnable';
        case GarbageType.spray:
          return 'Spray cans';
        case GarbageType.nonBurnable:
          return 'Non-burnable';
        case GarbageType.lighter:
          return 'Lighter';
        case GarbageType.recyclable:
          return 'Bottles/Cans';
        case GarbageType.battery:
          return 'Batteries';
        case GarbageType.plastic:
          return 'Plastic';
        case GarbageType.paper:
          return 'Paper';
        case GarbageType.green:
          return 'Green';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 基準日が含まれる週の「日曜日」を計算
    // DateTime.weekdayは 月=1...日=7 なので、% 7 すると 日=0, 月=1...土=6 となる
    // その日数分引けば、直前の日曜日になる
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
                lang == UiLang.ja ? '今週のスケジュール' : 'Weekly Schedule',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              // 期間を表示（例: 1/1 - 1/7）
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
            // 今日かどうか判定
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
                    width: 60,
                    child: Text(
                      '${date.day} (${_weekdayLabel(date.weekday)})',
                      style: TextStyle(
                        fontWeight: isToday
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: date.weekday == 7
                            ? Colors
                                  .red // 日曜
                            : date.weekday == 6
                            ? Colors
                                  .blue // 土曜
                            : Colors.black,
                      ),
                    ),
                  ),
                  // ゴミの内容
                  Expanded(
                    child: types.isEmpty
                        ? Text(
                            lang == UiLang.ja ? '-' : '-',
                            style: TextStyle(color: Colors.grey.shade400),
                          )
                        : Text(
                            types.map((t) => _garbageLabel(t)).join(' / '),
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
