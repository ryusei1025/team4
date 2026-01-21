// import 'dart:convert'; // JSON変換などに使うが、今回は未使用なのでコメントアウト（将来JSON読み込みするなら復活）

import 'package:flutter/gestures.dart'; // マウスホイール（PointerScrollEvent）などの入力を扱うため
import 'package:flutter/material.dart'; // Material UI（Scaffold/AppBar/Iconなど）を使うため
import 'drawer_menu.dart'; // LeftMenuDrawer / LanguageSelector / UiLang など（プロジェクト側定義）を使うため

// =========================== // セクション区切り（見やすさのため）
// ★共通定義：ゴミ種別／週×曜日ルール／色／アイコン／固定除外日 // カレンダー表示の基盤をここに集約
// =========================== // セクション区切り（見やすさのため）

enum GarbageType {
  // ゴミの種類（判定・表示・色・アイコンの基準）
  none, // 収集なし（固定除外日や該当ルール無しの日）
  burnable, // 燃えるゴミ
  recyclable, // 資源ゴミ
  plastic, // プラスチック
  nonBurnable, // 燃えないゴミ
  bulky, // 粗大ごみ（例）
} // enum終わり

/// ★追加：表示順（複数のゴミが被った時の並び順にも使う） // UIの見やすさを安定させる
const List<GarbageType> garbageTypeDisplayOrder = <GarbageType>[
  GarbageType.burnable, // 燃える
  GarbageType.recyclable, // 資源
  GarbageType.plastic, // プラ
  GarbageType.nonBurnable, // 不燃
  GarbageType.bulky, // 粗大
  GarbageType.none, // 収集なし（最後）
]; // 表示順終わり

/// ★おすすめ修正：月日（Month-Day）を int キーにする（const Set<int> に入れられる） // const Setで独自クラスが使えない問題の回避
/// 例：1/3 → 103、12/31 → 1231 // 変換例
int mdKey(DateTime date) =>
    date.month * 100 + date.day; // DateTime→「月*100+日」の整数キーへ変換

class GarbageRule {
  // 「第N週 × 曜日 → ゴミ種別」を表すルール
  final Set<int> weeks; // 対象週（例：{1,3}なら第1・第3週）
  final int weekday0to6; // 対象曜日（0=日,1=月,...6=土）
  final GarbageType type; // このルールのゴミ種別

  const GarbageRule({
    // constで定義できるようにconstコンストラクタ
    required this.weeks, // 対象週
    required this.weekday0to6, // 対象曜日
    required this.type, // ゴミ種別
  }); // コンストラクタ終わり

  bool matches(DateTime date) {
    // 与えられた日付がこのルールに一致するか判定
    final w = weekOfMonth(date); // 月内の第何週か（1〜）
    final wd = weekdayIndex0to6(date); // 曜日を0〜6に変換
    return weeks.contains(w) && wd == weekday0to6; // 週と曜日が一致すればtrue
  } // matches終わり

  static int weekOfMonth(DateTime date) =>
      ((date.day - 1) ~/ 7) + 1; // 1..7=第1週、8..14=第2週…の簡易計算
} // GarbageRule終わり

int weekdayIndex0to6(DateTime date) =>
    date.weekday % 7; // DateTime.weekday(月=1..日=7)を日=0..土=6へ変換

Color garbageColor(GarbageType type) {
  // ゴミ種別→セル背景色を返す
  switch (type) {
    // 種別で分岐
    case GarbageType.burnable: // 燃えるゴミ
      return Colors.orange.withOpacity(0.18); // 薄いオレンジ
    case GarbageType.recyclable: // 資源ゴミ
      return Colors.blue.withOpacity(0.16); // 薄い青
    case GarbageType.plastic: // プラ
      return Colors.green.withOpacity(0.16); // 薄い緑
    case GarbageType.nonBurnable: // 不燃
      return Colors.purple.withOpacity(0.16); // 薄い紫
    case GarbageType.bulky: // 粗大
      return Colors.brown.withOpacity(0.16); // 薄い茶
    case GarbageType.none: // 収集なし
      return Colors.transparent; // 透明（色を表示しない）
  } // switch終わり
} // garbageColor終わり

String garbageLabel(GarbageType type, UiLang lang) {
  // ゴミ種別→表示ラベル（日本語/英語）を返す
  if (lang == UiLang.ja) {
    // 日本語UIなら
    switch (type) {
      // 種別で分岐（日本語）
      case GarbageType.burnable:
        return '燃えるゴミ';
      case GarbageType.recyclable:
        return '資源ゴミ';
      case GarbageType.plastic:
        return 'プラスチック';
      case GarbageType.nonBurnable:
        return '燃えないゴミ';
      case GarbageType.bulky:
        return '粗大ごみ';
      case GarbageType.none:
        return '収集なし';
    } // switch終わり
  } else {
    // 英語UIなら
    switch (type) {
      // 種別で分岐（英語）
      case GarbageType.burnable:
        return 'Burnable';
      case GarbageType.recyclable:
        return 'Recyclable';
      case GarbageType.plastic:
        return 'Plastic';
      case GarbageType.nonBurnable:
        return 'Non-burnable';
      case GarbageType.bulky:
        return 'Bulky';
      case GarbageType.none:
        return 'No collection';
    } // switch終わり
  } // if/else終わり
} // garbageLabel終わり

String weekdayLabel0to6(int wd0to6, UiLang lang) {
  // 曜日(0..6)→ラベルへ変換
  final ja = const ['日', '月', '火', '水', '木', '金', '土']; // 日本語曜日
  final en = const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']; // 英語曜日
  return (lang == UiLang.ja ? ja : en)[wd0to6.clamp(0, 6)]; // 言語で配列を切替し、安全に取り出す
} // weekdayLabel0to6終わり

String weekLabel(int week, UiLang lang) {
  // 第N週の表示ラベルを作る
  if (lang == UiLang.ja) return '第$week'; // 日本語なら「第N」
  switch (week) {
    // 英語なら序数っぽい表記
    case 1:
      return '1st';
    case 2:
      return '2nd';
    case 3:
      return '3rd';
    default:
      return '${week}th';
  } // switch終わり
} // weekLabel終わり

IconData garbageIcon(GarbageType type) {
  // ゴミ種別→アイコン（セルの日付下に表示）
  switch (type) {
    // 種別で分岐
    case GarbageType.burnable:
      return Icons.local_fire_department; // 燃える：炎
    case GarbageType.recyclable:
      return Icons.autorenew; // 資源：循環
    case GarbageType.plastic:
      return Icons.shopping_bag; // プラ：袋
    case GarbageType.nonBurnable:
      return Icons.do_not_disturb_on; // 不燃：禁止
    case GarbageType.bulky:
      return Icons.weekend; // 粗大：家具（ソファ）
    case GarbageType.none:
      return Icons.remove; // 収集なし（保険）
  } // switch終わり
} // garbageIcon終わり

Color garbageIconColor(GarbageType type) {
  // ゴミ種別→アイコン色（背景より濃く）
  switch (type) {
    // 種別で分岐
    case GarbageType.burnable:
      return Colors.deepOrange; // 燃える：濃オレンジ
    case GarbageType.recyclable:
      return Colors.blue; // 資源：青
    case GarbageType.plastic:
      return Colors.green; // プラ：緑
    case GarbageType.nonBurnable:
      return Colors.purple; // 不燃：紫
    case GarbageType.bulky:
      return Colors.brown; // 粗大：茶
    case GarbageType.none:
      return Colors.transparent; // 収集なし：表示しない想定
  } // switch終わり
} // garbageIconColor終わり

// =========================== // セクション区切り
// CalendarScreen（本体） // ここから画面実装
// =========================== // セクション区切り

class CalendarScreen extends StatefulWidget {
  // 状態を持つ画面（選択日・表示月など）
  const CalendarScreen({super.key}); // keyを受け取るコンストラクタ

  @override // Stateを返すメソッドをオーバーライド
  State<CalendarScreen> createState() => _CalendarScreenState(); // このWidgetのStateを生成
} // CalendarScreen終わり

class _CalendarScreenState extends State<CalendarScreen> {
  // 画面の状態（State）本体
  static const int baseYear = 2026; // 表示開始年（ページング下限）
  static const int maxYear = 2100; // 表示終了年（ページング上限）
  static final DateTime baseMonth = DateTime(baseYear, 1, 1); // 月インデックス計算の基準月
  static const int totalMonths = (maxYear - baseYear + 1) * 12; // 表示可能な総月数

  late final PageController _pageController; // 月ページ(PageView)制御
  late int _visibleYear; // PageViewで現在表示している年
  late int _visibleMonth; // PageViewで現在表示している月
  late int _pickedYear; // ドロップダウンで選択した年
  late int _pickedMonth; // ドロップダウンで選択した月
  DateTime? _selectedDate; // ユーザーが選択した日（未選択はnull）

  final List<String> _areas = const ['中央区', '東区', '北区']; // エリア候補（例）
  String _selectedArea = '中央区'; // 現在選択中のエリア
  UiLang _lang = UiLang.ja; // 表示言語（drawer_menu.dart側で定義されている想定）

  bool _showGuide = false; // 「詳細情報」パネルの表示/非表示フラグ

  // =========================== // セクション区切り
  // エリアごとの「週×曜日」収集ルール表（ここを書き換えると収集日を変更できる） // 設定の中心
  // =========================== // セクション区切り

  late final Map<String, List<GarbageRule>> _areaRules = {
    // エリア名→ルール一覧
    '中央区': const [
      // 中央区のルール
      GarbageRule(
        weeks: {1, 2, 3, 4, 5},
        weekday0to6: 1,
        type: GarbageType.burnable,
      ), // 毎週月：燃える
      GarbageRule(
        weeks: {1, 2, 3, 4, 5},
        weekday0to6: 4,
        type: GarbageType.burnable,
      ), // 毎週木：燃える
      GarbageRule(
        weeks: {2},
        weekday0to6: 3,
        type: GarbageType.nonBurnable,
      ), // 第2水：不燃
      GarbageRule(
        weeks: {1, 3},
        weekday0to6: 6,
        type: GarbageType.recyclable,
      ), // 第1・第3土：資源
    ], // 中央区終わり
    '東区': const [
      // 東区のルール
      GarbageRule(
        weeks: {1, 2, 3, 4, 5},
        weekday0to6: 2,
        type: GarbageType.burnable,
      ), // 毎週火：燃える
      GarbageRule(
        weeks: {1, 2, 3, 4, 5},
        weekday0to6: 5,
        type: GarbageType.burnable,
      ), // 毎週金：燃える
      GarbageRule(
        weeks: {1, 3},
        weekday0to6: 4,
        type: GarbageType.plastic,
      ), // 第1・第3木：プラ
      GarbageRule(
        weeks: {2, 4},
        weekday0to6: 6,
        type: GarbageType.recyclable,
      ), // 第2・第4土：資源
    ], // 東区終わり
    '北区': const [
      // 北区のルール
      GarbageRule(
        weeks: {1, 2, 3, 4, 5},
        weekday0to6: 1,
        type: GarbageType.burnable,
      ), // 毎週月：燃える
      GarbageRule(
        weeks: {1, 2, 3, 4, 5},
        weekday0to6: 3,
        type: GarbageType.burnable,
      ), // 毎週水：燃える
      GarbageRule(
        weeks: {1, 2, 3, 4, 5},
        weekday0to6: 5,
        type: GarbageType.burnable,
      ), // 毎週金：燃える
      GarbageRule(
        weeks: {2},
        weekday0to6: 4,
        type: GarbageType.recyclable,
      ), // 第2木：資源
      GarbageRule(
        weeks: {4},
        weekday0to6: 6,
        type: GarbageType.nonBurnable,
      ), // 第4土：不燃
    ], // 北区終わり
  }; // _areaRules終わり

  // =========================== // セクション区切り
  // 固定除外日：この日付は「収集なし」で色もアイコンも表示しない（例：年始） // 特例ルール
  // =========================== // セクション区切り

  static const Set<int> _noCollectionFixedDays = {
    // mdKey（月*100+日）で保持
    101, // 1/1：年始で収集なし
    102, // 1/2：年始で収集なし
    103, // 1/3：年始で収集なし
  }; // 固定除外日終わり

  // =========================== // セクション区切り
  // ★追加：重要なお知らせ（区ごとに差し替え可能） // 赤カードで表示
  // =========================== // セクション区切り

  late final List<String> _commonImportantNotice = <String>[
    'ごみは収集日の朝8時30分までに出してください', // 重要：時間厳守
    '指定袋以外での排出は収集されません', // 重要：指定袋
    '年末年始は収集日程が変更になります', // 重要：年末年始
    '台風等の悪天候時は収集を中止する場合があります', // 重要：悪天候
    '土日はごみ収集を行いません', // 重要：土日休み（※ルール設定と矛盾しないよう運用側で調整）
  ]; // 共通のお知らせ終わり

  late final Map<String, List<String>> _importantNoticeByArea = {
    // 区名→重要なお知らせ（区ごとに内容を変えたい場合はここを編集）
    '中央区': _commonImportantNotice, // 中央区（今は共通）
    '東区': _commonImportantNotice, // 東区（今は共通）
    '北区': _commonImportantNotice, // 北区（今は共通）
  }; // _importantNoticeByArea終わり

  // =========================== // セクション区切り
  // ★追加：お問い合わせ（区ごとに差し替え可能） // 青カードで表示
  // =========================== // セクション区切り

  late final List<String> _commonInquiry = <String>[
    '札幌市コールセンター : [011-222-4894]', // 電話番号（[]内をグレー表示）
    '受付時間 : [平日 8:00〜21:00]', // 平日受付（[]内をグレー表示）
    '土日祝 : [9:00〜17:00]', // 土日祝受付（[]内をグレー表示）
    '札幌市公式ウェブサイト : [URL]', // 公式サイト（[]内をグレー表示）
  ]; // 共通のお問い合わせ終わり

  late final Map<String, List<String>> _inquiryByArea = {
    // 区名→お問い合わせ（区ごとに内容を変えたい場合はここを編集）
    '中央区': _commonInquiry, // 中央区（今は共通）
    '東区': _commonInquiry, // 東区（今は共通）
    '北区': _commonInquiry, // 北区（今は共通）
  }; // _inquiryByArea終わり

  // =========================== // セクション区切り
  // ★追加：祝日は収集するか（区ごとに設定できる） // 収集スケジュールカードで表示
  // =========================== // セクション区切り

  late final Map<String, bool> _collectOnHolidaysByArea = {
    // 区名→祝日の収集有無（必要に応じて区ごとに変更）
    '中央区': true, // 中央区：祝日も収集する想定（例）
    '東区': true, // 東区：祝日も収集する想定（例）
    '北区': true, // 北区：祝日も収集する想定（例）
  }; // _collectOnHolidaysByArea終わり

  @override // initStateをオーバーライド
  void initState() {
    // 最初の1回だけ呼ばれる初期化
    super.initState(); // 親クラスの初期化

    final now = DateTime.now(); // 現在日時（初期表示を決めるため）
    final initial =
        (now.year < baseYear) // baseYearより前なら
        ? DateTime(baseYear, 1, 1) // 2026/1を初期表示
        : DateTime(now.year, now.month, 1); // それ以外は今月を初期表示（1日固定）

    _visibleYear = initial.year; // 表示中年の初期値
    _visibleMonth = initial.month; // 表示中月の初期値
    _pickedYear = _visibleYear; // ドロップダウン年を同期
    _pickedMonth = _visibleMonth; // ドロップダウン月を同期

    final initialIndex = _monthIndexFrom(
      // 初期月をページIndexに変換
      baseMonth, // 基準月（2026/1）
      DateTime(_visibleYear, _visibleMonth, 1), // 初期表示月
    ); // 変換終わり

    _pageController = PageController(
      // PageView用コントローラ作成
      initialPage: initialIndex.clamp(0, totalMonths - 1), // 範囲外を防ぐ
    ); // controller終わり
  } // initState終わり

  @override // disposeをオーバーライド
  void dispose() {
    // 破棄時に呼ばれる
    _pageController.dispose(); // PageController破棄（メモリリーク防止）
    super.dispose(); // 親クラスの破棄
  } // dispose終わり

  int _monthIndexFrom(DateTime base, DateTime target) =>
      (target.year - base.year) * 12 +
      (target.month - base.month); // base→targetの月差をIndex化

  DateTime _monthFromIndex(int index) => DateTime(
    baseYear + (index ~/ 12),
    1 + (index % 12),
    1,
  ); // Index→対象月(1日)を復元

  void _handlePointerSignal(PointerSignalEvent event) {
    // ホイールで月送りするため
    if (event is PointerScrollEvent) {
      // スクロールイベントだけ対象
      if (event.scrollDelta.dy > 18.0) {
        // 下方向スクロールが一定以上なら
        _pageController.nextPage(
          // 次月へ
          duration: const Duration(milliseconds: 180), // アニメ時間
          curve: Curves.easeOut, // カーブ
        ); // nextPage終わり
      } else if (event.scrollDelta.dy < -18.0) {
        // 上方向スクロールが一定以上なら
        _pageController.previousPage(
          // 前月へ
          duration: const Duration(milliseconds: 180), // アニメ時間
          curve: Curves.easeOut, // カーブ
        ); // previousPage終わり
      } // if/else終わり
    } // 型チェック終わり
  } // _handlePointerSignal終わり

  void _goToPickedMonth() {
    // ドロップダウン選択の年月へジャンプする
    final target = DateTime(_pickedYear, _pickedMonth, 1); // 選択年月（1日固定）
    final idx = _monthIndexFrom(
      baseMonth,
      target,
    ).clamp(0, totalMonths - 1); // Index化して範囲内へ
    _pageController.animateToPage(
      // アニメ移動
      idx, // 目的ページ
      duration: const Duration(milliseconds: 220), // アニメ時間
      curve: Curves.easeOut, // カーブ
    ); // animateToPage終わり
  } // _goToPickedMonth終わり

  void _onDateTap(DateTime date, {required DateTime currentMonth}) {
    // 日付セルをタップしたとき
    setState(() => _selectedDate = date); // 選択日を更新

    if (date.year != currentMonth.year || date.month != currentMonth.month) {
      // 前月/翌月のはみ出しセルなら
      setState(() {
        _pickedYear = date.year.clamp(baseYear, maxYear); // 年を範囲内に制限
        _pickedMonth = date.month; // 月を更新
      }); // setState終わり
      _goToPickedMonth(); // 押した日付の月へ移動
    } // if終わり
  } // _onDateTap終わり

  // =========================== // セクション区切り
  // ★何ゴミか判定（固定除外日を最優先） // 「複数被り」に対応するためListで返す
  // =========================== // セクション区切り

  List<GarbageType> _garbageTypesFor(DateTime date) {
    // 指定日→該当するゴミ種別をすべて返す（複数被り対応）
    if (_noCollectionFixedDays.contains(mdKey(date))) {
      // 固定除外日なら
      return const <GarbageType>[]; // 収集なし（色/アイコン表示なし）
    } // 固定除外チェック終わり

    final rules =
        _areaRules[_selectedArea] ?? const <GarbageRule>[]; // 選択区のルール一覧（なければ空）
    final set = <GarbageType>{}; // 重複排除用のSet

    for (final r in rules) {
      // ルールを全件評価（★被りを拾うためbreakしない）
      if (r.matches(date)) set.add(r.type); // 一致したら種別を追加
    } // for終わり

    final list = set.toList(); // Set→Listへ変換
    list.sort((a, b) {
      // 表示順でソートして安定化
      final ia = garbageTypeDisplayOrder.indexOf(a); // aの順位
      final ib = garbageTypeDisplayOrder.indexOf(b); // bの順位
      return ia.compareTo(ib); // 昇順
    }); // sort終わり

    return list; // 該当種別の一覧（空なら収集なし）
  } // _garbageTypesFor終わり

  String _garbageTextFor(DateTime date) {
    // 選択日カード用「週×曜日：何ゴミ」文字列（複数被り対応）
    if (_noCollectionFixedDays.contains(mdKey(date))) {
      // 固定除外日なら
      return _lang == UiLang.ja
          ? '年明けのため収集なし'
          : 'No collection (New Year holidays)'; // 特別メッセージ
    } // 固定除外チェック終わり

    final w = GarbageRule.weekOfMonth(date); // 第何週
    final wd = weekdayIndex0to6(date); // 曜日0..6
    final types = _garbageTypesFor(date); // ★複数種別（空なら収集なし）

    final wText = weekLabel(w, _lang); // 第N / 1st等
    final wdText = weekdayLabel0to6(wd, _lang); // 日/月/... or Sun/Mon...

    final gText = types.isEmpty
        ? garbageLabel(GarbageType.none, _lang) // 収集なし
        : types
              .map((t) => garbageLabel(t, _lang))
              .join(_lang == UiLang.ja ? '・' : ' / '); // 複数は区切って表示

    return (_lang == UiLang.ja)
        ? '$wText$wdText曜日：$gText'
        : '$wText $wdText: $gText'; // 言語で表記切替
  } // _garbageTextFor終わり

  @override // buildをオーバーライド
  Widget build(BuildContext context) {
    // 画面UI構築（状態変化で再ビルド）
    return Scaffold(
      // 画面の土台
      backgroundColor: const Color(0xFFF6F7FB), // 背景色
      drawer: LeftMenuDrawer(
        lang: _lang,
        selectedArea: _selectedArea,
      ), // 左ドロワー（外部定義）
      appBar: AppBar(
        // ヘッダー（固定でスクロールしない）
        centerTitle: true, // タイトル中央寄せ
        leading: Builder(
          // Scaffold.of を使うためBuilderで別contextを作る
          builder: (ctx) => IconButton(
            // メニューボタン
            icon: const Icon(Icons.menu), // ハンバーガーアイコン
            onPressed: () => Scaffold.of(ctx).openDrawer(), // Drawerを開く
          ), // IconButton終わり
        ), // Builder終わり
        title: _HeaderDropdown<String>(
          // AppBar中央のエリア選択
          label: _lang == UiLang.ja ? 'エリア' : 'Area', // ラベル（言語で切替）
          value: _selectedArea, // 現在選択値
          items: _areas, // 候補
          itemLabel: (v) => v, // 表示
          onChanged: (v) =>
              setState(() => _selectedArea = v), // 選択区更新→色/アイコン/詳細も変わる
          width: 160, // 幅
        ), // _HeaderDropdown終わり
        actions: [
          // AppBar右側
          Padding(
            // 右余白
            padding: const EdgeInsets.only(right: 12), // 右に12
            child: LanguageSelector(
              // 言語切替（外部定義）
              currentLang: _lang, // 現在言語
              onChanged: (v) => setState(() => _lang = v), // 言語変更→全表示の言語が変わる
            ), // LanguageSelector終わり
          ), // Padding終わり
        ], // actions終わり
      ), // AppBar終わり
      // ★変更：AppBarより下を全体スクロールできるようにする // 画面下部が長くなっても見やすい
      body: Scrollbar(
        // スクロールバー表示（Web/デスクトップで位置が分かる）
        child: SingleChildScrollView(
          // ヘッダー下の全内容を縦スクロール可能にする
          padding: const EdgeInsets.all(16), // 画面内余白
          child: Center(
            // 横方向は中央寄せ
            child: ConstrainedBox(
              // 幅を制限して読みやすく
              constraints: const BoxConstraints(maxWidth: 520), // 最大幅520
              child: Column(
                // 中身を縦に並べる
                children: [
                  Container(
                    // 年月選択＋カレンダー本体のカード
                    padding: const EdgeInsets.all(12), // 内側余白
                    decoration: BoxDecoration(
                      // 見た目
                      color: Colors.white, // 背景白
                      borderRadius: BorderRadius.circular(14), // 角丸
                      border: Border.all(color: const Color(0xFFE1E5EE)), // 枠線
                    ), // decoration終わり
                    child: Column(
                      // カード内を縦に配置
                      children: [
                        Row(
                          // 年/月ドロップダウンを横並び
                          children: [
                            Expanded(
                              // 年側を伸ばす
                              child: _LabeledDropdown<int>(
                                // 年ドロップダウン
                                label: '年', // ラベル
                                value: _pickedYear, // 選択年
                                items: List.generate(
                                  maxYear - baseYear + 1,
                                  (i) => baseYear + i,
                                ), // 年候補
                                itemLabel: (v) => '$v', // 表示文字
                                onChanged: (v) {
                                  // 変更時
                                  setState(() => _pickedYear = v); // 状態更新
                                  _goToPickedMonth(); // その年月へ移動
                                }, // onChanged終わり
                              ), // 年ドロップダウン終わり
                            ), // Expanded終わり
                            const SizedBox(width: 10), // 年と月の間隔
                            Expanded(
                              // 月側を伸ばす
                              child: _LabeledDropdown<int>(
                                // 月ドロップダウン
                                label: '月', // ラベル
                                value: _pickedMonth, // 選択月
                                items: List.generate(12, (i) => i + 1), // 1〜12
                                itemLabel: (v) => '$v', // 表示文字
                                onChanged: (v) {
                                  // 変更時
                                  setState(() => _pickedMonth = v); // 状態更新
                                  _goToPickedMonth(); // その年月へ移動
                                }, // onChanged終わり
                              ), // 月ドロップダウン終わり
                            ), // Expanded終わり
                          ], // Row children終わり
                        ), // Row終わり
                        const SizedBox(height: 8), // 年月とカレンダーの間隔
                        AspectRatio(
                          // カレンダー枠の縦横比を固定（スクロール内で高さを安定）
                          aspectRatio: 7 / 7, // ほぼ正方形
                          child: Container(
                            // カレンダー枠
                            decoration: BoxDecoration(
                              // 枠の見た目
                              borderRadius: BorderRadius.circular(12), // 角丸
                              border: Border.all(
                                color: const Color(0xFFCED6E6),
                              ), // 枠線
                            ), // decoration終わり
                            clipBehavior: Clip.antiAlias, // 角丸の外をクリップ
                            child: Column(
                              // 曜日行＋月グリッド
                              children: [
                                _WeekdayRow(lang: _lang), // 曜日ラベル行
                                Expanded(
                                  // 残り領域をPageViewへ
                                  child: Listener(
                                    // ホイールで月移動できるようにする
                                    onPointerSignal:
                                        _handlePointerSignal, // ホイール処理
                                    child: PageView.builder(
                                      // 月ページを縦方向に切替
                                      controller: _pageController, // コントローラ
                                      scrollDirection:
                                          Axis.vertical, // 縦スワイプで月移動
                                      itemCount: totalMonths, // ページ数
                                      onPageChanged: (index) {
                                        // ページが変わったら
                                        final m = _monthFromIndex(
                                          index,
                                        ); // index→年月を復元
                                        setState(() {
                                          // 状態更新
                                          _visibleYear = m.year; // 表示年
                                          _visibleMonth = m.month; // 表示月
                                          _pickedYear = m.year; // ドロップダウン年も同期
                                          _pickedMonth = m.month; // ドロップダウン月も同期
                                        }); // setState終わり
                                      }, // onPageChanged終わり
                                      itemBuilder: (context, index) {
                                        // 月ページの描画
                                        final month = _monthFromIndex(
                                          index,
                                        ); // 対象月
                                        return _MonthGrid(
                                          // 月グリッド（★複数色＋複数アイコン対応）
                                          month: month, // 表示月
                                          selectedDate: _selectedDate, // 選択日
                                          garbageTypesOf:
                                              _garbageTypesFor, // ★日付→複数種別（セル色/アイコン用）
                                          onDateTap: (d) => _onDateTap(
                                            d,
                                            currentMonth: month,
                                          ), // タップ処理
                                          lang: _lang, // 言語（拡張用）
                                        ); // _MonthGrid終わり
                                      }, // itemBuilder終わり
                                    ), // PageView.builder終わり
                                  ), // Listener終わり
                                ), // Expanded終わり
                              ], // children終わり
                            ), // Column終わり
                          ), // Container終わり
                        ), // AspectRatio終わり
                      ], // children終わり
                    ), // Column終わり
                  ), // カレンダーカード終わり

                  const SizedBox(height: 12), // 間隔

                  _SelectedInfoCard(
                    // 選択日情報カード
                    selectedDate: _selectedDate, // 選択日
                    lang: _lang, // 言語
                    garbageTextOf: _garbageTextFor, // 日付→「週×曜日：何ゴミ」文
                  ), // _SelectedInfoCard終わり

                  const SizedBox(height: 10), // 間隔

                  SizedBox(
                    // ボタン幅をカードに合わせる箱
                    width: double.infinity, // ConstrainedBox内なのでカードと同じ幅
                    child: ElevatedButton(
                      // 「詳細情報」表示/非表示ボタン
                      onPressed: () =>
                          setState(() => _showGuide = !_showGuide), // 押すたびに切替
                      style: ElevatedButton.styleFrom(
                        // ボタン見た目
                        backgroundColor: Colors.blue, // 青
                        foregroundColor: Colors.white, // 白文字
                        padding: const EdgeInsets.all(12), // 余白
                        minimumSize: const Size.fromHeight(48), // 高さ確保
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ), // 角丸
                      ), // style終わり
                      child: Text(
                        // ボタン文字
                        _showGuide
                            ? (_lang == UiLang.ja ? '詳細情報を非表示' : 'Hide guide')
                            : (_lang == UiLang.ja ? '詳細情報を表示' : 'Show guide'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ), // 太字
                      ), // Text終わり
                    ), // ElevatedButton終わり
                  ), // SizedBox終わり
                  // ★詳細情報（区ごと切替＋種別カード縦並び）はAnimatedSwitcherで表示/非表示
                  AnimatedSwitcher(
                    // 表示/非表示を滑らかに切替
                    duration: const Duration(milliseconds: 220), // 切替時間
                    switchInCurve: Curves.easeOut, // 表示カーブ
                    switchOutCurve: Curves.easeOut, // 非表示カーブ
                    child: _showGuide
                        ? Padding(
                            // 表示時の上余白
                            key: const ValueKey('guide'), // AnimatedSwitcher用キー
                            padding: const EdgeInsets.only(top: 10), // ボタンとの間隔
                            child: _GarbageGuidePanel(
                              // 詳細情報パネル
                              lang: _lang, // 言語
                              selectedArea: _selectedArea, // 区名（見出し）
                              rules:
                                  _areaRules[_selectedArea] ??
                                  const <GarbageRule>[], // 選択区のルール
                            ), // _GarbageGuidePanel終わり
                          )
                        : const SizedBox.shrink(
                            key: ValueKey('empty'),
                          ), // 非表示時は高さ0
                  ), // AnimatedSwitcher終わり

                  const SizedBox(height: 10), // 間隔（ボタン/詳細情報の下）

                  _ImportantNoticeCard(
                    // ★追加：赤い「重要なお知らせ」カード
                    lang: _lang, // 言語（将来拡張用）
                    selectedArea: _selectedArea, // 区名（見出しに表示）
                    items:
                        _importantNoticeByArea[_selectedArea] ??
                        _commonImportantNotice, // 区ごとのお知らせ
                  ), // _ImportantNoticeCard終わり

                  const SizedBox(height: 10), // 間隔

                  _InquiryCard(
                    // ★追加：青い「お問い合わせ」カード
                    lang: _lang, // 言語（将来拡張用）
                    selectedArea: _selectedArea, // 区名（見出しに表示）
                    lines:
                        _inquiryByArea[_selectedArea] ??
                        _commonInquiry, // 区ごとの問い合わせ
                  ), // _InquiryCard終わり

                  const SizedBox(height: 10), // 間隔

                  _CollectionScheduleCard(
                    // ★追加：グレーの「収集スケジュール」カード（お問い合わせの下）
                    lang: _lang, // 言語（将来拡張用）
                    selectedArea: _selectedArea, // 区名（見出しに表示）
                    rules:
                        _areaRules[_selectedArea] ??
                        const <GarbageRule>[], // 区のルール（週×曜日）
                    collectOnHolidays:
                        _collectOnHolidaysByArea[_selectedArea] ??
                        true, // 祝日収集するか
                  ), // _CollectionScheduleCard終わり
                ], // children終わり
              ), // Column終わり
            ), // ConstrainedBox終わり
          ), // Center終わり
        ), // SingleChildScrollView終わり
      ), // Scrollbar終わり
    ); // Scaffold終わり
  } // build終わり
} // _CalendarScreenState終わり

// =========================== // セクション区切り
// 補助ウィジェット：AppBar用ドロップダウン // タイトル部分のエリア選択
// =========================== // セクション区切り

class _HeaderDropdown<T> extends StatelessWidget {
  // AppBar内で使う装飾付きDropdown
  final String label; // 表示ラベル（例：エリア）
  final T value; // 現在値
  final List<T> items; // 候補一覧
  final String Function(T) itemLabel; // 候補→表示文字変換
  final ValueChanged<T> onChanged; // 選択変更通知
  final double width; // 幅

  const _HeaderDropdown({
    // コンストラクタ
    required this.label, // ラベル
    required this.value, // 現在値
    required this.items, // 候補
    required this.itemLabel, // 表示変換
    required this.onChanged, // 変更処理
    required this.width, // 幅
  }); // コンストラクタ終わり

  @override // buildオーバーライド
  Widget build(BuildContext context) {
    // UI構築
    return SizedBox(
      // 幅固定
      width: width, // 指定幅
      child: DecoratedBox(
        // 背景と枠線
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE1E5EE)), // 枠線
          borderRadius: BorderRadius.circular(10), // 角丸
          color: const Color(0xFFE7EBF3), // 背景
        ), // decoration終わり
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10), // 内側余白
          child: DropdownButtonHideUnderline(
            // 下線を消す
            child: DropdownButton<T>(
              value: value, // 現在値
              isDense: true, // 高さ詰め
              isExpanded: true, // 横幅いっぱい
              items: items
                  .map(
                    (v) => DropdownMenuItem<T>(
                      value: v, // 値
                      child: Text(
                        '$label: ${itemLabel(v)}', // 表示
                        overflow: TextOverflow.ellipsis, // 長い時省略
                      ), // Text終わり
                    ), // DropdownMenuItem終わり
                  )
                  .toList(), // List化
              onChanged: (v) {
                if (v != null) onChanged(v); // nullでなければ通知
              }, // onChanged終わり
            ), // DropdownButton終わり
          ), // DropdownButtonHideUnderline終わり
        ), // Padding終わり
      ), // DecoratedBox終わり
    ); // SizedBox終わり
  } // build終わり
} // _HeaderDropdown終わり

// =========================== // セクション区切り
// 補助ウィジェット：年/月ドロップダウン // 年月選択UI
// =========================== // セクション区切り

class _LabeledDropdown<T> extends StatelessWidget {
  // InputDecorator風Dropdown
  final String label; // ラベル（年/月）
  final T value; // 現在値
  final List<T> items; // 候補一覧
  final String Function(T) itemLabel; // 表示変換
  final ValueChanged<T> onChanged; // 変更通知

  const _LabeledDropdown({
    required this.label, // ラベル
    required this.value, // 値
    required this.items, // 候補
    required this.itemLabel, // 表示変換
    required this.onChanged, // 変更処理
  }); // コンストラクタ終わり

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label, // ラベル表示
        isDense: true, // 高さ詰め
        border: const OutlineInputBorder(), // 枠線
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 8,
        ), // 内側余白
      ), // decoration終わり
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value, // 現在値
          isDense: true, // 高さ詰め
          isExpanded: true, // 横幅いっぱい
          items: items
              .map(
                (v) => DropdownMenuItem<T>(
                  value: v, // 値
                  child: Text(itemLabel(v)), // 表示
                ), // DropdownMenuItem終わり
              )
              .toList(), // List化
          onChanged: (v) {
            if (v != null) onChanged(v); // nullでなければ通知
          }, // onChanged終わり
        ), // DropdownButton終わり
      ), // DropdownButtonHideUnderline終わり
    ); // InputDecorator終わり
  } // build終わり
} // _LabeledDropdown終わり

// =========================== // セクション区切り
// 補助ウィジェット：曜日行 // 日〜土の見出し
// =========================== // セクション区切り

class _WeekdayRow extends StatelessWidget {
  // 曜日ラベル行（日〜土 / Sun〜Sat）
  final UiLang lang; // 表示言語
  const _WeekdayRow({required this.lang}); // コンストラクタ

  @override
  Widget build(BuildContext context) {
    final labels = (lang == UiLang.ja)
        ? const ['日', '月', '火', '水', '木', '金', '土'] // 日本語
        : const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']; // 英語

    return Container(
      height: 40, // 高さ固定
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE7EBF3))), // 下線
      ), // decoration終わり
      child: Row(
        children: List.generate(
          7, // 7曜日
          (i) => Expanded(
            child: Center(
              child: Text(
                labels[i], // 曜日文字
                style: TextStyle(
                  fontSize: 12, // サイズ
                  fontWeight: FontWeight.bold, // 太字
                  color: i == 0
                      ? Colors.red
                      : i == 6
                      ? Colors.blue
                      : Colors.black, // 日=赤、土=青、平日=黒
                ), // style終わり
              ), // Text終わり
            ), // Center終わり
          ), // Expanded終わり
        ), // generate終わり
      ), // Row終わり
    ); // Container終わり
  } // build終わり
} // _WeekdayRow終わり

// =========================== // セクション区切り
// 補助ウィジェット：月グリッド（★複数色＋複数アイコン対応）
// =========================== // セクション区切り

class _MonthGrid extends StatelessWidget {
  // 1か月分を描画
  final DateTime month; // 表示月（1日固定想定）
  final DateTime? selectedDate; // 選択日
  final ValueChanged<DateTime> onDateTap; // 日付タップ通知
  final List<GarbageType> Function(DateTime date)
  garbageTypesOf; // ★日付→複数種別（セル色/アイコン用）
  final UiLang lang; // 言語（拡張用）

  const _MonthGrid({
    required this.month, // 月
    required this.selectedDate, // 選択日
    required this.onDateTap, // タップ処理
    required this.garbageTypesOf, // 種別判定（複数）
    required this.lang, // 言語
  }); // コンストラクタ終わり

  List<GarbageType> _sortedTypes(List<GarbageType> types) {
    // 種別を表示順で整列する（UIを安定させる）
    final list = [...types]; // 破壊しないようコピー
    list.sort(
      (a, b) => garbageTypeDisplayOrder
          .indexOf(a)
          .compareTo(garbageTypeDisplayOrder.indexOf(b)),
    ); // 順位比較
    return list; // ソート済みリスト
  } // _sortedTypes終わり

  Widget _multiTypeBackground(List<GarbageType> types) {
    // ★複数種別の背景を「横分割」で表示する（色が複数見える）
    if (types.isEmpty) {
      // 収集なしなら
      return const SizedBox.expand(); // 何も描かない
    } // if終わり

    final t = _sortedTypes(types); // 表示順で整列

    return Row(
      // 横に分割して複数色を見せる
      children: [
        for (final type in t)
          Expanded(
            child: Container(
              color: garbageColor(type), // 種別→背景色（薄い色）
            ), // Container終わり
          ), // Expanded終わり
      ], // children終わり
    ); // Row終わり
  } // _multiTypeBackground終わり

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1); // 表示月の1日
    final offset = first.weekday % 7; // 日曜始まりのオフセット（日=0）
    final cells = List<DateTime>.generate(
      42, // 6週×7日
      (i) => DateTime(month.year, month.month, 1 + (i - offset)), // 前後月含め連続日付
    ); // cells終わり

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellH = constraints.maxHeight / 6; // 行高さ
        final cellW = constraints.maxWidth / 7; // 列幅

        return Column(
          children: List.generate(
            6, // 6行
            (row) => SizedBox(
              height: cellH, // 行高さ
              child: Row(
                children: List.generate(
                  7, // 7列
                  (col) {
                    final d = cells[row * 7 + col]; // セル日付
                    final isInThisMonth = d.month == month.month; // 当月セルか

                    final isSelected =
                        selectedDate != null && // 選択日が存在し
                        d.year == selectedDate!.year && // 年一致
                        d.month == selectedDate!.month && // 月一致
                        d.day == selectedDate!.day; // 日一致

                    final types = isInThisMonth
                        ? garbageTypesOf(d)
                        : const <GarbageType>[]; // ★当月だけ判定（はみ出しは空）
                    final selectedOverlay = Colors.blue.withOpacity(
                      0.10,
                    ); // 選択時の薄青

                    final typesSorted = _sortedTypes(
                      types,
                    ); // ★表示順に整列（アイコンも背景も同順）

                    return SizedBox(
                      width: cellW, // セル幅
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF5B8DEF)
                                : const Color(0xFFF0F0F0), // 選択枠は濃い
                            width: isSelected ? 1.2 : 1.0, // 選択枠は少し太い
                          ), // border終わり
                          color: Colors.transparent, // 背景はStack側で描くので透明
                        ), // decoration終わり
                        child: Material(
                          color:
                              Colors.transparent, // InkWellのためにMaterialを置く（透明）
                          child: InkWell(
                            onTap: () => onDateTap(d), // タップで日付選択
                            child: Stack(
                              fit: StackFit.expand, // セル全体に広げる
                              children: [
                                Positioned.fill(
                                  child: _multiTypeBackground(
                                    typesSorted,
                                  ), // ★複数色背景を描画
                                ), // Positioned.fill終わり

                                if (isSelected)
                                  Positioned.fill(
                                    child: Container(
                                      color: selectedOverlay,
                                    ), // ★選択中は青を上から薄く重ねる
                                  ), // Positioned.fill終わり

                                Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min, // 中身を最小化
                                    mainAxisAlignment:
                                        MainAxisAlignment.center, // 中央寄せ
                                    children: [
                                      Text(
                                        '${d.day}', // 日付数字
                                        style: TextStyle(
                                          color: isInThisMonth
                                              ? Colors.black
                                              : Colors.grey, // 当月=黒、はみ出し=灰
                                          fontWeight: FontWeight.bold, // 太字
                                        ), // style終わり
                                      ), // Text終わり
                                      // ★当月セルかつ「収集あり（typesが空でない）」なら複数アイコンを表示
                                      if (isInThisMonth &&
                                          typesSorted.isNotEmpty) ...[
                                        const SizedBox(height: 2), // 間隔
                                        Wrap(
                                          // ★複数アイコンを横に並べ、入りきらなければ折り返す
                                          spacing: 2, // 横間隔
                                          runSpacing: 0, // 縦間隔
                                          alignment:
                                              WrapAlignment.center, // 中央寄せ
                                          children: [
                                            for (final t in typesSorted)
                                              Icon(
                                                garbageIcon(t), // 種別→アイコン
                                                size: 14, // 小さめ
                                                color: garbageIconColor(
                                                  t,
                                                ), // 種別→アイコン色
                                              ), // Icon終わり
                                          ], // children終わり
                                        ), // Wrap終わり
                                      ], // if終わり
                                    ], // children終わり
                                  ), // Column終わり
                                ), // Center終わり
                              ], // children終わり
                            ), // Stack終わり
                          ), // InkWell終わり
                        ), // Material終わり
                      ), // Container終わり
                    ); // SizedBox終わり
                  }, // col builder終わり
                ), // generate列終わり
              ), // Row終わり
            ), // SizedBox行終わり
          ), // generate行終わり
        ); // Column終わり
      }, // builder終わり
    ); // LayoutBuilder終わり
  } // build終わり
} // _MonthGrid終わり

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

// =========================== // セクション区切り
// ★詳細情報パネル：区ごとに内容を切替／ゴミ種別ごとにカードを縦に並べて表示
// =========================== // セクション区切り

class _GarbageGuidePanel extends StatelessWidget {
  final UiLang lang; // 表示言語
  final String selectedArea; // 選択中の区（区ごとに見出しや内容を切替）
  final List<GarbageRule> rules; // 選択中の区のルール（週×曜日）

  const _GarbageGuidePanel({
    required this.lang, // 言語
    required this.selectedArea, // 区名
    required this.rules, // ルール一覧
  }); // コンストラクタ終わり

  Map<GarbageType, List<GarbageRule>> _groupRulesByType(
    List<GarbageRule> rules,
  ) {
    final map = <GarbageType, List<GarbageRule>>{}; // 種別→ルール一覧のMap
    for (final r in rules) {
      map.putIfAbsent(r.type, () => <GarbageRule>[]).add(r); // 種別の配列に追加（なければ作る）
    } // for終わり
    return map; // まとめたMapを返す
  } // _groupRulesByType終わり

  String _weeksText(Set<int> weeks) {
    final list = weeks.toList()..sort(); // ソートしたリストへ変換

    final isEveryWeek =
        list.length >= 5 &&
        list.contains(1) &&
        list.contains(2) &&
        list.contains(3) &&
        list.contains(4) &&
        list.contains(5); // 1〜5週が揃っていれば毎週

    if (isEveryWeek) return (lang == UiLang.ja) ? '毎週' : 'Every week'; // 毎週表記

    if (lang == UiLang.ja)
      return list.map((w) => weekLabel(w, lang)).join('・'); // 日本語：第1・第3
    return list.map((w) => weekLabel(w, lang)).join(' & '); // 英語：1st & 3rd
  } // _weeksText終わり

  String _ruleLine(GarbageRule r) {
    final wd = weekdayLabel0to6(r.weekday0to6, lang); // 曜日文字（例：月 / Mon）
    final w = _weeksText(r.weeks); // 週文字（例：毎週 / 第1・第3）
    return (lang == UiLang.ja) ? '$w${wd}曜日' : '$w $wd'; // 言語で表記切替
  } // _ruleLine終わり

  Widget _typeCard({
    required GarbageType type, // 対象種別
    required String title, // 種別タイトル
    required String note, // 注意点
    required List<GarbageRule> typeRules, // その種別のルール
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10), // カード同士の縦間隔
      padding: const EdgeInsets.all(12), // 内側余白
      decoration: BoxDecoration(
        color: Colors.white, // 背景白
        borderRadius: BorderRadius.circular(12), // 角丸
        border: Border.all(color: const Color(0xFFE1E5EE)), // 枠線
      ), // decoration終わり
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // 左寄せ
        children: [
          Row(
            children: [
              Icon(
                garbageIcon(type),
                color: garbageIconColor(type),
                size: 20,
              ), // アイコン
              const SizedBox(width: 8), // 間隔
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ), // タイトル
              ), // Expanded終わり
              Container(
                width: 18, // 幅
                height: 18, // 高さ
                decoration: BoxDecoration(
                  color: garbageColor(type), // 背景色チップ
                  borderRadius: BorderRadius.circular(5), // 角丸
                  border: Border.all(color: const Color(0xFFCED6E6)), // 枠線
                ), // decoration終わり
              ), // Container終わり
            ], // children終わり
          ), // Row終わり
          const SizedBox(height: 8), // 間隔
          Text(
            lang == UiLang.ja ? '収集日' : 'Collection days',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ), // 見出し
          const SizedBox(height: 4), // 間隔
          if (typeRules.isEmpty)
            Text(
              lang == UiLang.ja ? 'この区では設定がありません' : 'No rule set for this area',
            ) // なし表示
          else
            ...typeRules.map((r) => Text('• ${_ruleLine(r)}')), // ルール表示
          const SizedBox(height: 10), // 間隔
          Text(
            lang == UiLang.ja ? '注意点' : 'Tips',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ), // 見出し
          const SizedBox(height: 4), // 間隔
          Text(note), // 注意点本文
        ], // children終わり
      ), // Column終わり
    ); // Container終わり
  } // _typeCard終わり

  @override
  Widget build(BuildContext context) {
    final grouped = _groupRulesByType(rules); // ルールを種別ごとにまとめる

    final items = <_GarbageGuideItem>[
      _GarbageGuideItem(
        type: GarbageType.burnable,
        titleJa: '燃えるゴミ',
        titleEn: 'Burnable',
        noteJa: '水気を切る／生ごみはよく絞る。自治体指定の袋がある場合は従う。',
        noteEn: 'Drain liquids well. Follow local bag rules if required.',
      ),
      _GarbageGuideItem(
        type: GarbageType.recyclable,
        titleJa: '資源ゴミ',
        titleEn: 'Recyclable',
        noteJa: '缶・びん等は軽くすすいで乾かす。紙は汚れが強いと可燃になることがある。',
        noteEn:
            'Rinse and dry cans/bottles. Heavily soiled paper may not be recyclable.',
      ),
      _GarbageGuideItem(
        type: GarbageType.plastic,
        titleJa: 'プラスチック',
        titleEn: 'Plastic',
        noteJa: '汚れは落とす（難しい場合は可燃へ）。自治体の「容器包装プラ」区分に注意。',
        noteEn:
            'Clean residue. If too dirty, treat as burnable depending on local rules.',
      ),
      _GarbageGuideItem(
        type: GarbageType.nonBurnable,
        titleJa: '燃えないゴミ',
        titleEn: 'Non-burnable',
        noteJa: '割れ物は新聞紙等で包み「キケン」表示。電池・スプレー缶は別区分のことが多い。',
        noteEn:
            'Wrap sharp items and label. Batteries/aerosols often have separate rules.',
      ),
      _GarbageGuideItem(
        type: GarbageType.bulky,
        titleJa: '粗大ごみ',
        titleEn: 'Bulky',
        noteJa: '予約制・シール購入が必要な場合が多い。サイズ条件や出し方は自治体の案内に従う。',
        noteEn:
            'Often requires reservation/sticker. Follow local size and set-out rules.',
      ),
    ]; // items終わり

    final order = <GarbageType>[
      GarbageType.burnable,
      GarbageType.recyclable,
      GarbageType.plastic,
      GarbageType.nonBurnable,
      GarbageType.bulky,
    ]; // 表示順

    final itemMap = {for (final it in items) it.type: it}; // type→item のMap化

    return Container(
      width: double.infinity, // 横幅いっぱい
      padding: const EdgeInsets.all(12), // 余白
      decoration: BoxDecoration(
        color: Colors.white, // 背景白
        borderRadius: BorderRadius.circular(12), // 角丸
        border: Border.all(color: const Color(0xFFE1E5EE)), // 枠線
      ), // decoration終わり
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // 左寄せ
        children: [
          Text(
            lang == UiLang.ja
                ? '$selectedArea の 詳細情報'
                : 'Details: $selectedArea', // 区ごとに見出しを変える
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ), // 太字
          ), // Text終わり
          const SizedBox(height: 6), // 間隔
          Text(
            lang == UiLang.ja
                ? '※ 1/1〜1/3 は 収集がありません'
                : '* No collection on Jan 1–3 (no color/icon).', // 固定除外日の説明
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700), // 小さめ
          ), // Text終わり
          const SizedBox(height: 12), // 間隔
          ...order.map((type) {
            final it = itemMap[type]!; // 種別に対応する説明データ
            final title = (lang == UiLang.ja) ? it.titleJa : it.titleEn; // タイトル
            final note = (lang == UiLang.ja) ? it.noteJa : it.noteEn; // 注意点
            final typeRules =
                grouped[type] ?? const <GarbageRule>[]; // この種別のルール
            return _typeCard(
              type: type,
              title: title,
              note: note,
              typeRules: typeRules,
            ); // 種別カード
          }),
          Text(
            lang == UiLang.ja
                ? '※実際の分別・出し方は自治体の案内が最優先です。'
                : '*Local municipality rules take precedence.*', // 注意書き
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700), // 小さめ
          ), // Text終わり
        ], // children終わり
      ), // Column終わり
    ); // Container終わり
  } // build終わり
} // _GarbageGuidePanel終わり

class _GarbageGuideItem {
  // 種別ごとの説明データ（カード本文に使う）
  final GarbageType type; // 種別
  final String titleJa; // 日本語タイトル
  final String titleEn; // 英語タイトル
  final String noteJa; // 日本語注意点
  final String noteEn; // 英語注意点

  const _GarbageGuideItem({
    required this.type, // 種別
    required this.titleJa, // 日本語
    required this.titleEn, // 英語
    required this.noteJa, // 日本語注意点
    required this.noteEn, // 英語注意点
  }); // コンストラクタ終わり
} // _GarbageGuideItem終わり

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

// =========================== // セクション区切り
// ★追加：グレーのカード「収集スケジュール」 // お問い合わせカードの下に表示
// =========================== // セクション区切り

class _CollectionScheduleCard extends StatelessWidget {
  // 区ごとの収集スケジュールを「曜日別」と「休収集日」「祝日対応」で表示するカード
  final UiLang lang; // 表示言語（今回は日本語中心だが将来拡張用）
  final String selectedArea; // 選択中の区（見出し用）
  final List<GarbageRule> rules; // この区の収集ルール（週×曜日→種別）
  final bool collectOnHolidays; // 祝日は収集するか（区ごとに設定）

  const _CollectionScheduleCard({
    required this.lang, // 言語
    required this.selectedArea, // 区名
    required this.rules, // ルール一覧
    required this.collectOnHolidays, // 祝日収集フラグ
  }); // コンストラクタ終わり

  List<int> _weekdayOrderMonToSun() {
    // ★月→日で表示したいので順番を固定する（内部は日=0..土=6だが表示は月始まり）
    return const <int>[1, 2, 3, 4, 5, 6, 0]; // 月火水木金土日
  } // _weekdayOrderMonToSun終わり

  bool _isEveryWeek(Set<int> weeks) {
    // 1〜5週が揃っていれば「毎週」扱いにする
    return weeks.contains(1) &&
        weeks.contains(2) &&
        weeks.contains(3) &&
        weeks.contains(4) &&
        weeks.contains(5);
  } // _isEveryWeek終わり

  String _weeksText(Set<int> weeks) {
    // 週セットを文字列化する（例：{1,3}→第1・第3 / 1st & 3rd）
    final list = weeks.toList()..sort(); // ソートして順序安定化
    if (_isEveryWeek(weeks))
      return (lang == UiLang.ja) ? '毎週' : 'Every week'; // 毎週なら短く
    if (lang == UiLang.ja)
      return list.map((w) => weekLabel(w, lang)).join('・'); // 日本語
    return list.map((w) => weekLabel(w, lang)).join(' & '); // 英語
  } // _weeksText終わり

  Map<GarbageType, Set<int>> _mergedTypeWeeksForWeekday(int weekday0to6) {
    // ★同じ曜日に複数ルールがある場合、種別ごとに「週」を結合してまとめる
    final map = <GarbageType, Set<int>>{}; // 種別→週セット
    for (final r in rules) {
      if (r.weekday0to6 != weekday0to6) continue; // 対象曜日だけ
      map.putIfAbsent(r.type, () => <int>{}).addAll(r.weeks); // 種別ごとに週を結合
    } // for終わり
    return map; // まとめたMap
  } // _mergedTypeWeeksForWeekday終わり

  List<String> _weekdayLineItems(int weekday0to6) {
    // ★「曜日の横に表示する収集物」を文字列リストで返す（複数対応）
    final merged = _mergedTypeWeeksForWeekday(weekday0to6); // 種別→週セット
    final wdText = weekdayLabel0to6(weekday0to6, lang); // 曜日ラベル（例：月）
    final types = merged.keys.toList(); // 種別一覧

    types.sort((a, b) {
      final ia = garbageTypeDisplayOrder.indexOf(a); // aの順位
      final ib = garbageTypeDisplayOrder.indexOf(b); // bの順位
      return ia.compareTo(ib); // 順位比較
    }); // sort終わり

    final out = <String>[]; // 出力
    for (final t in types) {
      final label = garbageLabel(t, lang); // 種別名
      final weeks = merged[t] ?? <int>{}; // 週セット
      if (_isEveryWeek(weeks)) {
        out.add(label); // 毎週なら「燃えるゴミ」だけ
      } else {
        final wText = _weeksText(weeks); // 例：第2 / 第1・第3
        out.add(
          lang == UiLang.ja
              ? '$label($wText$wdText)'
              : '$label($wText $wdText)',
        ); // ★()内に「どの週の何曜日」
      } // if/else終わり
    } // for終わり

    return out; // 空ならその曜日は収集なし
  } // _weekdayLineItems終わり

  List<int> _noCollectionWeekdays() {
    // ★ルールが1件も無い曜日を「休収集日」として抽出する
    final noDays = <int>[]; // 休収集日の曜日
    for (final wd in const <int>[0, 1, 2, 3, 4, 5, 6]) {
      final items = _weekdayLineItems(wd); // 曜日ごとの収集物
      if (items.isEmpty) noDays.add(wd); // 何も無ければ休収集日
    } // for終わり
    return noDays; // 休収集日一覧
  } // _noCollectionWeekdays終わり

  Widget _sectionTitle(String text) {
    // セクション見出しの見た目を統一する
    return Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
    ); // 太字小さめ
  } // _sectionTitle終わり

  @override
  Widget build(BuildContext context) {
    final order = _weekdayOrderMonToSun(); // 月→日の表示順
    final restDays = _noCollectionWeekdays(); // 休収集日の曜日一覧
    final grayText = TextStyle(
      fontSize: 12,
      color: Colors.grey.shade700,
    ); // 注釈用

    return Container(
      width: double.infinity, // 横幅いっぱい
      padding: const EdgeInsets.all(12), // 余白
      decoration: BoxDecoration(
        color: const Color(0xFFF2F3F5), // ★薄いグレー背景
        borderRadius: BorderRadius.circular(12), // 角丸
        border: Border.all(color: const Color(0xFFE1E5EE)), // 枠線
      ), // decoration終わり
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, // 左寄せ
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_month,
                size: 20,
                color: Color(0xFF616161),
              ), // カレンダーアイコン
              const SizedBox(width: 8), // 間隔
              const Expanded(
                child: Text(
                  '収集スケジュール',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ), // 見出し
              ), // Expanded終わり
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ), // 余白
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.06), // 薄いグレー
                  borderRadius: BorderRadius.circular(999), // 丸チップ
                ), // decoration終わり
                child: Text(
                  selectedArea, // 区名
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF424242),
                  ), // 濃グレー
                ), // Text終わり
              ), // Container終わり
            ], // children終わり
          ), // Row終わり

          const SizedBox(height: 6), // 間隔
          Text('※ 1/1〜1/3 は収集なし（色/アイコン表示なし）', style: grayText), // 固定除外日の注釈
          const SizedBox(height: 12), // 間隔

          _sectionTitle('平日収集'), // 見出し
          const SizedBox(height: 6), // 間隔

          ...order.map((wd) {
            final wdLabel = weekdayLabel0to6(wd, lang); // 曜日ラベル
            final items = _weekdayLineItems(wd); // 収集物
            final rightText = items.isEmpty
                ? '—'
                : items.join(' / '); // 複数は区切り表示
            return Padding(
              padding: const EdgeInsets.only(bottom: 6), // 行間
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start, // 上寄せ
                children: [
                  SizedBox(
                    width: 56, // 左の曜日欄幅
                    child: Text(
                      '$wdLabel曜日',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ), // 曜日
                  ), // SizedBox終わり
                  const SizedBox(width: 8), // 間隔
                  Expanded(
                    child: Text(
                      rightText,
                      style: const TextStyle(fontSize: 13),
                    ), // 収集物
                  ), // Expanded終わり
                ], // children終わり
              ), // Row終わり
            ); // Padding終わり
          }),

          const SizedBox(height: 10), // 間隔

          _sectionTitle('休収集日'), // 見出し
          const SizedBox(height: 6), // 間隔

          if (restDays.isEmpty)
            const Text('なし', style: TextStyle(fontSize: 13)) // 休収集日なし
          else
            Text(
              restDays
                  .map((wd) => '${weekdayLabel0to6(wd, lang)}曜日')
                  .join('・'), // 曜日列挙
              style: const TextStyle(fontSize: 13), // 標準
            ), // Text終わり

          const SizedBox(height: 10), // 間隔

          _sectionTitle('祝日の収集'), // 見出し
          const SizedBox(height: 6), // 間隔

          Text(
            collectOnHolidays
                ? '祝日も通常どおり収集します（※年末年始など一部例外あり）'
                : '祝日は収集しません', // フラグで切替
            style: const TextStyle(fontSize: 13), // 標準
          ), // Text終わり
        ], // children終わり
      ), // Column終わり
    ); // Container終わり
  } // build終わり
} // _CollectionScheduleCard終わり
