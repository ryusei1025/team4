// import 'dart:convert'; // JSON変換などに使うが、今回は未使用なのでコメントアウト（将来JSON読み込みするなら復活）

import 'package:flutter/gestures.dart'; // RichTextのリンク風タップ等（TapGestureRecognizer）やホイール入力を扱うため
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

/// ★おすすめ修正：月日（Month-Day）を int キーにする（const Set<int> に入れられる）
/// 例：1/3 → 103、12/31 → 1231
int mdKey(DateTime date) =>
    date.month * 100 + date.day; // DateTime→「月*100+日」の整数キーへ変換

class GarbageRule {
  // 「第N週 × 曜日 → ゴミ種別」を表すルール
  final Set<int> weeks; // 対象週（例：{1,3}なら第1・第3週）
  final int weekday0to6; // 対象曜日（0=日,1=月,...6=土）
  final GarbageType type; // このルールのゴミ種別

  const GarbageRule({
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

// ===========================
// ★追加：表示用に「種別の並び順」を固定する（重複除去＋順序安定化）
// - 同じ日に複数収集が被った場合、アイコン/色の並びが毎回同じになるようにする
// ===========================

List<GarbageType> normalizeTypes(Iterable<GarbageType> types) {
  // 重複を除去し、一定の順番で返す（noneは除外）
  const order = <GarbageType>[
    GarbageType.burnable, // 1) 燃える
    GarbageType.recyclable, // 2) 資源
    GarbageType.plastic, // 3) プラ
    GarbageType.nonBurnable, // 4) 不燃
    GarbageType.bulky, // 5) 粗大
  ]; // 表示順
  final set = <GarbageType>{...types}..remove(GarbageType.none); // 重複除去＆noneを除外
  return order.where(set.contains).toList(); // orderに沿って並べ替え
} // normalizeTypes終わり

Color garbageColor(GarbageType type) {
  // ゴミ種別→セル背景色を返す
  switch (type) {
    case GarbageType.burnable:
      return Colors.orange.withOpacity(0.18); // 薄いオレンジ
    case GarbageType.recyclable:
      return Colors.blue.withOpacity(0.16); // 薄い青
    case GarbageType.plastic:
      return Colors.green.withOpacity(0.16); // 薄い緑
    case GarbageType.nonBurnable:
      return Colors.purple.withOpacity(0.16); // 薄い紫
    case GarbageType.bulky:
      return Colors.brown.withOpacity(0.16); // 薄い茶
    case GarbageType.none:
      return Colors.transparent; // 透明（色を表示しない）
  } // switch終わり
} // garbageColor終わり

String garbageLabel(GarbageType type, UiLang lang) {
  // ゴミ種別→表示ラベル（日本語/英語）を返す
  if (lang == UiLang.ja) {
    switch (type) {
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
    switch (type) {
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

  @override
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

  // ===========================
  // ★追加：土日収集を無効化する（重要なお知らせの「土日は収集しません」に合わせる）
  // ※もし将来「土曜も収集する区」が出たら false に変更する
  // ===========================

  static const bool _disableWeekendCollection = true; // trueなら土日(0,6)は常に収集なしにする

  // =========================== // セクション区切り
  // エリアごとの「週×曜日」収集ルール表（ここを書き換えると収集日を変更できる） // 設定の中心
  // =========================== // セクション区切り

  late final Map<String, List<GarbageRule>> _areaRules = {
    '中央区': const [
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
      ), // 第1・第3土：資源（※土日無効なら表示/判定で除外）
    ], // 中央区終わり
    '東区': const [
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
      ), // 第2・第4土：資源（※土日無効なら表示/判定で除外）
    ], // 東区終わり
    '北区': const [
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
      ), // 第4土：不燃（※土日無効なら表示/判定で除外）
    ], // 北区終わり
  }; // _areaRules終わり

  // =========================== // セクション区切り
  // 固定除外日：この日付は「収集なし」で色もアイコンも表示しない（例：年始） // 特例ルール
  // =========================== // セクション区切り

  static const Set<int> _noCollectionFixedDays = {
    101, // 1/1：年始で収集なし
    102, // 1/2：年始で収集なし
    103, // 1/3：年始で収集なし
  }; // 固定除外日終わり

  // ===========================
  // ★追加：[重要なお知らせ]（区ごとに変えられるようMap化）
  // ===========================

  final Map<String, List<String>> _importantNoticeByArea = {
    '中央区': const [
      '・ごみは収集日の朝8時30分までに出してください',
      '・指定袋以外での排出は収集されません',
      '・年末年始は収集日程が変更になります',
      '・台風等の悪天候時は収集を中止する場合があります',
      '・土日はごみ収集を行いません',
    ],
    '東区': const [
      '・ごみは収集日の朝8時30分までに出してください',
      '・指定袋以外での排出は収集されません',
      '・年末年始は収集日程が変更になります',
      '・台風等の悪天候時は収集を中止する場合があります',
      '・土日はごみ収集を行いません',
    ],
    '北区': const [
      '・ごみは収集日の朝8時30分までに出してください',
      '・指定袋以外での排出は収集されません',
      '・年末年始は収集日程が変更になります',
      '・台風等の悪天候時は収集を中止する場合があります',
      '・土日はごみ収集を行いません',
    ],
  }; // _importantNoticeByArea終わり

  // ===========================
  // ★追加：[お問い合わせ]（区ごとに変えられるようデータ化）
  // ===========================

  final Map<String, _InquiryInfo> _inquiryByArea = {
    '中央区': const _InquiryInfo(
      centerName: '札幌市コールセンター',
      phone: '011-222-4894',
      hoursWeekday: '平日 8:00〜21:00',
      hoursHoliday: '土日祝 : 9:00〜17:00',
      websiteLabel: '札幌市公式ウェブサイト',
      websiteUrlText: 'URL',
    ),
    '東区': const _InquiryInfo(
      centerName: '札幌市コールセンター',
      phone: '011-222-4894',
      hoursWeekday: '平日 8:00〜21:00',
      hoursHoliday: '土日祝 : 9:00〜17:00',
      websiteLabel: '札幌市公式ウェブサイト',
      websiteUrlText: 'URL',
    ),
    '北区': const _InquiryInfo(
      centerName: '札幌市コールセンター',
      phone: '011-222-4894',
      hoursWeekday: '平日 8:00〜21:00',
      hoursHoliday: '土日祝 : 9:00〜17:00',
      websiteLabel: '札幌市公式ウェブサイト',
      websiteUrlText: 'URL',
    ),
  }; // _inquiryByArea終わり

  // ===========================
  // ★追加：祝日の収集ポリシー（区ごとに設定できる） // 収集スケジュール表示用
  // ===========================

  final Map<String, HolidayPolicy> _holidayPolicyByArea = {
    '中央区': HolidayPolicy.collect, // 祝日も収集あり（例）
    '東区': HolidayPolicy.collect, // 祝日も収集あり（例）
    '北区': HolidayPolicy.collect, // 祝日も収集あり（例）
  }; // _holidayPolicyByArea終わり

  @override
  void initState() {
    super.initState(); // 親クラス初期化

    final now = DateTime.now(); // 現在日時
    final initial = (now.year < baseYear)
        ? DateTime(baseYear, 1, 1)
        : DateTime(now.year, now.month, 1); // 初期表示月

    _visibleYear = initial.year; // 表示中年の初期値
    _visibleMonth = initial.month; // 表示中月の初期値
    _pickedYear = _visibleYear; // ドロップダウン年を同期
    _pickedMonth = _visibleMonth; // ドロップダウン月を同期

    final initialIndex = _monthIndexFrom(
      baseMonth,
      DateTime(_visibleYear, _visibleMonth, 1),
    ); // 初期月をページIndexに変換
    _pageController = PageController(
      initialPage: initialIndex.clamp(0, totalMonths - 1),
    ); // PageView用コントローラ
  } // initState終わり

  @override
  void dispose() {
    _pageController.dispose(); // PageController破棄
    super.dispose(); // 親クラスdispose
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
      if (event.scrollDelta.dy > 18.0) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        ); // 次月へ
      } else if (event.scrollDelta.dy < -18.0) {
        _pageController.previousPage(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        ); // 前月へ
      } // if/else終わり
    } // 型チェック終わり
  } // _handlePointerSignal終わり

  void _goToPickedMonth() {
    // ドロップダウン選択の年月へジャンプする
    final target = DateTime(_pickedYear, _pickedMonth, 1); // 選択年月
    final idx = _monthIndexFrom(
      baseMonth,
      target,
    ).clamp(0, totalMonths - 1); // Index化して範囲内へ
    _pageController.animateToPage(
      idx,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    ); // アニメ移動
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
  // ★複数収集に対応：指定日→ゴミ種別リスト（固定除外日・土日除外を最優先）
  // - 収集日が被ったら、その数に応じて複数の色＆アイコンを表示できる
  // =========================== // セクション区切り

  List<GarbageType> _garbageTypesFor(DateTime date) {
    // 指定日→その日に該当するゴミ種別を全て返す（0件なら収集なし）
    if (_noCollectionFixedDays.contains(mdKey(date))) {
      return const <GarbageType>[]; // 年始固定除外日は収集なし（色もアイコンも出さない）
    } // 固定除外チェック終わり

    final wd = weekdayIndex0to6(date); // 曜日(0..6)
    if (_disableWeekendCollection && (wd == 0 || wd == 6)) {
      return const <GarbageType>[]; // 土日を収集なしとして扱う（重要なお知らせに合わせる）
    } // 土日除外終わり

    final rules =
        _areaRules[_selectedArea] ?? const <GarbageRule>[]; // 選択区のルール一覧（なければ空）
    final matched = <GarbageType>[]; // 一致した種別を溜める
    for (final r in rules) {
      if (r.matches(date)) matched.add(r.type); // 一致したら追加（被ったら複数入る）
    } // for終わり

    return normalizeTypes(matched); // 重複除去＆表示順を安定化して返す
  } // _garbageTypesFor終わり

  String _garbageTextFor(DateTime date) {
    // 選択日カード用「週×曜日：何ゴミ」文字列（複数対応）
    if (_noCollectionFixedDays.contains(mdKey(date))) {
      return _lang == UiLang.ja
          ? '年明けのため収集なし'
          : 'No collection (New Year holidays)'; // 固定除外メッセージ
    } // 固定除外チェック終わり

    final wd = weekdayIndex0to6(date); // 曜日
    if (_disableWeekendCollection && (wd == 0 || wd == 6)) {
      return _lang == UiLang.ja
          ? '土日のため収集なし'
          : 'No collection (weekend)'; // 土日メッセージ
    } // 土日除外終わり

    final w = GarbageRule.weekOfMonth(date); // 第何週
    final wText = weekLabel(w, _lang); // 第N / 1st等
    final wdText = weekdayLabel0to6(wd, _lang); // 日/月/... or Sun/Mon...

    final types = _garbageTypesFor(date); // 種別リスト（0件なら収集なし）
    final gText = types.isEmpty
        ? garbageLabel(GarbageType.none, _lang)
        : types
              .map((t) => garbageLabel(t, _lang))
              .join(_lang == UiLang.ja ? '／' : ' / '); // 種別表示（複数は区切り）

    return (_lang == UiLang.ja)
        ? '$wText$wdText曜日：$gText'
        : '$wText $wdText: $gText'; // 日本語/英語で整形
  } // _garbageTextFor終わり

  @override
  Widget build(BuildContext context) {
    // 画面UI構築（状態変化で再ビルド）
    final noticeLines =
        _importantNoticeByArea[_selectedArea] ??
        const <String>[]; // 選択区の重要お知らせ行
    final inquiry =
        _inquiryByArea[_selectedArea] ??
        const _InquiryInfo(
          centerName: '',
          phone: '',
          hoursWeekday: '',
          hoursHoliday: '',
          websiteLabel: '',
          websiteUrlText: '',
        ); // 選択区の問い合わせ情報
    final holidayPolicy =
        _holidayPolicyByArea[_selectedArea] ??
        HolidayPolicy.collect; // 選択区の祝日ポリシー
    final selectedRules =
        _areaRules[_selectedArea] ?? const <GarbageRule>[]; // 選択区のルール

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB), // 背景色
      drawer: LeftMenuDrawer(
        lang: _lang,
        selectedArea: _selectedArea,
      ), // 左ドロワー（外部定義）
      appBar: AppBar(
        centerTitle: true, // タイトル中央寄せ
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu), // メニューアイコン
            onPressed: () => Scaffold.of(ctx).openDrawer(), // Drawerを開く
          ), // IconButton終わり
        ), // Builder終わり
        title: _HeaderDropdown<String>(
          label: _lang == UiLang.ja ? 'エリア' : 'Area', // ラベル（言語で切替）
          value: _selectedArea, // 現在選択値
          items: _areas, // 候補
          itemLabel: (v) => v, // 表示
          onChanged: (v) => setState(() => _selectedArea = v), // 区変更→全表示更新
          width: 160, // 幅
        ), // _HeaderDropdown終わり
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12), // 右余白
            child: LanguageSelector(
              currentLang: _lang, // 現在言語
              onChanged: (v) => setState(() => _lang = v), // 言語変更→全表示更新
            ), // LanguageSelector終わり
          ), // Padding終わり
        ], // actions終わり
      ), // AppBar終わり
      // ★変更：AppBarより下を全体スクロールできるようにする
      body: Scrollbar(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16), // 画面内余白
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520), // 最大幅を制限
              child: Column(
                children: [
                  // ===========================
                  // 上段：年月選択＋カレンダー本体
                  // ===========================
                  Container(
                    padding: const EdgeInsets.all(12), // 内側余白
                    decoration: BoxDecoration(
                      color: Colors.white, // 背景白
                      borderRadius: BorderRadius.circular(14), // 角丸
                      border: Border.all(color: const Color(0xFFE1E5EE)), // 枠線
                    ), // decoration終わり
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _LabeledDropdown<int>(
                                label: '年', // ラベル
                                value: _pickedYear, // 選択年
                                items: List.generate(
                                  maxYear - baseYear + 1,
                                  (i) => baseYear + i,
                                ), // 年候補
                                itemLabel: (v) => '$v', // 表示文字
                                onChanged: (v) {
                                  setState(() => _pickedYear = v); // 状態更新
                                  _goToPickedMonth(); // その年月へ移動
                                }, // onChanged終わり
                              ), // 年ドロップダウン終わり
                            ), // Expanded終わり
                            const SizedBox(width: 10), // 間隔
                            Expanded(
                              child: _LabeledDropdown<int>(
                                label: '月', // ラベル
                                value: _pickedMonth, // 選択月
                                items: List.generate(12, (i) => i + 1), // 1〜12
                                itemLabel: (v) => '$v', // 表示文字
                                onChanged: (v) {
                                  setState(() => _pickedMonth = v); // 状態更新
                                  _goToPickedMonth(); // その年月へ移動
                                }, // onChanged終わり
                              ), // 月ドロップダウン終わり
                            ), // Expanded終わり
                          ], // children終わり
                        ), // Row終わり
                        const SizedBox(height: 8), // 間隔
                        AspectRatio(
                          aspectRatio: 7 / 7, // ほぼ正方形
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12), // 角丸
                              border: Border.all(
                                color: const Color(0xFFCED6E6),
                              ), // 枠線
                            ), // decoration終わり
                            clipBehavior: Clip.antiAlias, // 角丸外をクリップ
                            child: Column(
                              children: [
                                _WeekdayRow(lang: _lang), // 曜日ラベル行
                                Expanded(
                                  child: Listener(
                                    onPointerSignal:
                                        _handlePointerSignal, // ホイール処理
                                    child: PageView.builder(
                                      controller: _pageController, // コントローラ
                                      scrollDirection: Axis.vertical, // 縦スワイプ
                                      itemCount: totalMonths, // ページ数
                                      onPageChanged: (index) {
                                        final m = _monthFromIndex(
                                          index,
                                        ); // index→年月
                                        setState(() {
                                          _visibleYear = m.year; // 表示年更新
                                          _visibleMonth = m.month; // 表示月更新
                                          _pickedYear = m.year; // ドロップダウン同期
                                          _pickedMonth = m.month; // ドロップダウン同期
                                        }); // setState終わり
                                      }, // onPageChanged終わり
                                      itemBuilder: (context, index) {
                                        final month = _monthFromIndex(
                                          index,
                                        ); // 対象月
                                        return _MonthGrid(
                                          month: month, // 表示月
                                          selectedDate: _selectedDate, // 選択日
                                          garbageTypesOf:
                                              _garbageTypesFor, // ★日付→複数種別（色/アイコン複数表示用）
                                          onDateTap: (d) => _onDateTap(
                                            d,
                                            currentMonth: month,
                                          ), // タップ処理
                                          lang: _lang, // 言語
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
                  // ===========================
                  // 選択日情報カード
                  // ===========================
                  _SelectedInfoCard(
                    selectedDate: _selectedDate, // 選択日
                    lang: _lang, // 言語
                    garbageTextOf: _garbageTextFor, // 日付→「週×曜日：何ゴミ」文
                    garbageTypesOf: _garbageTypesFor, // ★日付→複数種別（アイコン表示用）
                  ), // _SelectedInfoCard終わり

                  const SizedBox(height: 10), // 間隔
                  // ===========================
                  // 詳細情報の表示/非表示ボタン
                  // ===========================
                  SizedBox(
                    width: double.infinity, // カード幅と同じ
                    child: ElevatedButton(
                      onPressed: () =>
                          setState(() => _showGuide = !_showGuide), // 押すたびに切替
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue, // 青
                        foregroundColor: Colors.white, // 白文字
                        padding: const EdgeInsets.all(12), // 余白
                        minimumSize: const Size.fromHeight(48), // 高さ
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ), // 角丸
                      ), // style終わり
                      child: Text(
                        _showGuide
                            ? (_lang == UiLang.ja ? '詳細情報を非表示' : 'Hide guide')
                            : (_lang == UiLang.ja
                                  ? '詳細情報を表示'
                                  : 'Show guide'), // 文言切替
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ), // 太字
                      ), // Text終わり
                    ), // ElevatedButton終わり
                  ), // SizedBox終わり
                  // ===========================
                  // 詳細情報パネル（区ごとに切替＋種別カード縦並び）
                  // ===========================
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220), // 切替時間
                    switchInCurve: Curves.easeOut, // 表示カーブ
                    switchOutCurve: Curves.easeOut, // 非表示カーブ
                    child: _showGuide
                        ? Padding(
                            key: const ValueKey('guide'), // キー
                            padding: const EdgeInsets.only(top: 10), // 余白
                            child: _GarbageGuidePanel(
                              lang: _lang, // 言語
                              selectedArea: _selectedArea, // 区
                              rules: selectedRules, // ルール
                              disableWeekendCollection:
                                  _disableWeekendCollection, // 土日無効設定
                            ), // _GarbageGuidePanel終わり
                          ) // Padding終わり
                        : const SizedBox.shrink(
                            key: ValueKey('empty'),
                          ), // 非表示は高さ0
                  ), // AnimatedSwitcher終わり

                  const SizedBox(height: 10), // 間隔（ボタン/パネルの下）
                  // ===========================
                  // ★追加：重要なお知らせ（赤いカード・区ごとに内容切替）
                  // ===========================
                  _ImportantNoticeCard(
                    lang: _lang, // 言語（将来英語化する場合に使用）
                    selectedArea: _selectedArea, // 区（見出し用）
                    lines: noticeLines, // 表示する行
                  ), // _ImportantNoticeCard終わり

                  const SizedBox(height: 10), // 間隔
                  // ===========================
                  // ★追加：お問い合わせ（青いカード・区ごとに内容切替／[]内はグレー）
                  // ===========================
                  _InquiryCard(
                    lang: _lang, // 言語（将来英語化する場合に使用）
                    selectedArea: _selectedArea, // 区（見出し用）
                    info: inquiry, // 問い合わせ情報
                  ), // _InquiryCard終わり

                  const SizedBox(height: 10), // 間隔
                  // ===========================
                  // ★追加：収集スケジュール（グレーのカード・お問い合わせの下）
                  // ===========================
                  _CollectionScheduleCard(
                    lang: _lang, // 言語
                    selectedArea: _selectedArea, // 区
                    rules: selectedRules, // ルール
                    holidayPolicy: holidayPolicy, // 祝日ポリシー
                    disableWeekendCollection:
                        _disableWeekendCollection, // 土日無効設定
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
  final String label; // 表示ラベル（例：エリア）
  final T value; // 現在値
  final List<T> items; // 候補一覧
  final String Function(T) itemLabel; // 候補→表示文字変換
  final ValueChanged<T> onChanged; // 選択変更通知
  final double width; // 幅

  const _HeaderDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    required this.width,
  }); // コンストラクタ終わり

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width, // 指定幅
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE1E5EE)), // 枠線
          borderRadius: BorderRadius.circular(10), // 角丸
          color: const Color(0xFFE7EBF3), // 背景
        ), // decoration終わり
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10), // 左右余白
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value, // 現在値
              isDense: true, // 高さ詰め
              isExpanded: true, // 横幅いっぱい
              items: items
                  .map(
                    (v) => DropdownMenuItem<T>(
                      value: v,
                      child: Text(
                        '$label: ${itemLabel(v)}',
                        overflow: TextOverflow.ellipsis,
                      ), // 「ラベル: 値」
                    ),
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
  final String label; // ラベル（年/月）
  final T value; // 現在値
  final List<T> items; // 候補一覧
  final String Function(T) itemLabel; // 表示変換
  final ValueChanged<T> onChanged; // 変更通知

  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
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
                (v) => DropdownMenuItem<T>(value: v, child: Text(itemLabel(v))),
              )
              .toList(), // 候補をMenuItemへ
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
  final UiLang lang; // 表示言語
  const _WeekdayRow({required this.lang}); // コンストラクタ

  @override
  Widget build(BuildContext context) {
    final labels = (lang == UiLang.ja)
        ? const ['日', '月', '火', '水', '木', '金', '土']
        : const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']; // 曜日ラベル

    return Container(
      height: 40, // 高さ固定
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE7EBF3))),
      ), // 下線
      child: Row(
        children: List.generate(
          7,
          (i) => Expanded(
            child: Center(
              child: Text(
                labels[i], // 曜日文字
                style: TextStyle(
                  fontSize: 12, // サイズ
                  fontWeight: FontWeight.bold, // 太字
                  color: i == 0
                      ? Colors.red
                      : (i == 6 ? Colors.blue : Colors.black), // 日=赤、土=青
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
// 補助ウィジェット：月グリッド（背景色複数＋日付下アイコン複数）
// =========================== // セクション区切り

class _MonthGrid extends StatelessWidget {
  final DateTime month; // 表示月（1日固定想定）
  final DateTime? selectedDate; // 選択日
  final ValueChanged<DateTime> onDateTap; // 日付タップ通知
  final List<GarbageType> Function(DateTime date)
  garbageTypesOf; // ★日付→複数種別（被り対応）
  final UiLang lang; // 言語

  const _MonthGrid({
    required this.month,
    required this.selectedDate,
    required this.onDateTap,
    required this.garbageTypesOf,
    required this.lang,
  }); // コンストラクタ終わり

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1); // 表示月の1日
    final offset = first.weekday % 7; // 日曜始まりのオフセット（日=0）
    final cells = List<DateTime>.generate(
      42,
      (i) => DateTime(month.year, month.month, 1 + (i - offset)),
    ); // 42セル（前後月含む）

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellH = constraints.maxHeight / 6; // 行高さ
        final cellW = constraints.maxWidth / 7; // 列幅

        return Column(
          children: List.generate(
            6,
            (row) => SizedBox(
              height: cellH,
              child: Row(
                children: List.generate(
                  7,
                  (col) {
                    final d = cells[row * 7 + col]; // このセルの日付
                    final isInThisMonth = d.month == month.month; // 当月かどうか

                    final isSelected =
                        selectedDate != null &&
                        d.year == selectedDate!.year &&
                        d.month == selectedDate!.month &&
                        d.day == selectedDate!.day; // 選択判定

                    final types = isInThisMonth
                        ? garbageTypesOf(d)
                        : const <GarbageType>[]; // 当月のみ判定（はみ出しは空）
                    final selectedBorderColor = isSelected
                        ? const Color(0xFF5B8DEF)
                        : const Color(0xFFF0F0F0); // 枠線色
                    final selectedBorderWidth = isSelected ? 1.2 : 1.0; // 枠線太さ

                    return SizedBox(
                      width: cellW,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: selectedBorderColor,
                            width: selectedBorderWidth,
                          ), // 枠線
                        ), // decoration終わり
                        child: Material(
                          color: Colors.transparent, // 背景はStack側で描くので透明
                          child: InkWell(
                            onTap: () => onDateTap(d), // タップで日付選択
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: _MultiTypeBackground(
                                    types: types,
                                  ), // ★複数色の背景（0件なら透明）
                                ), // 背景終わり
                                if (isSelected)
                                  Positioned.fill(
                                    child: Container(
                                      color: Colors.blue.withOpacity(0.10),
                                    ), // 選択時の薄青オーバーレイ
                                  ), // 選択オーバーレイ終わり
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
                                      if (isInThisMonth &&
                                          types.isNotEmpty) ...[
                                        const SizedBox(height: 2), // 間隔
                                        Wrap(
                                          spacing: 2, // アイコン間隔
                                          runSpacing: 2, // 折返し間隔
                                          alignment:
                                              WrapAlignment.center, // 中央寄せ
                                          children: types
                                              .take(4) // 表示数を抑えて見やすく（最大4）
                                              .map(
                                                (t) => Icon(
                                                  garbageIcon(t), // 種別→アイコン
                                                  size: 14, // 小さめ
                                                  color: garbageIconColor(
                                                    t,
                                                  ), // 種別→アイコン色
                                                ),
                                              )
                                              .toList(), // List化
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

class _MultiTypeBackground extends StatelessWidget {
  // ★複数色を1セル内に表示する背景（被った数に応じて色が増える）
  final List<GarbageType> types; // 表示する種別リスト（0件なら透明）
  const _MultiTypeBackground({required this.types}); // コンストラクタ

  @override
  Widget build(BuildContext context) {
    if (types.isEmpty) {
      return const SizedBox.expand(); // 何もなければ透明（何も描かない）
    } // if終わり

    if (types.length == 1) {
      return Container(color: garbageColor(types.first)); // 1種類なら単色
    } // if終わり

    return Row(
      children: types
          .map(
            (t) => Expanded(
              child: Container(color: garbageColor(t)), // 複数なら等分ストライプで表示
            ),
          )
          .toList(), // List化
    ); // Row終わり
  } // build終わり
} // _MultiTypeBackground終わり

// =========================== // セクション区切り
// 補助ウィジェット：選択日情報カード（複数種別対応）
// =========================== // セクション区切り

class _SelectedInfoCard extends StatelessWidget {
  final DateTime? selectedDate; // 選択日
  final UiLang lang; // 表示言語
  final String Function(DateTime date) garbageTextOf; // 日付→表示文言
  final List<GarbageType> Function(DateTime date)
  garbageTypesOf; // ★日付→複数種別（アイコン表示）

  const _SelectedInfoCard({
    required this.selectedDate,
    required this.lang,
    required this.garbageTextOf,
    required this.garbageTypesOf,
  }); // コンストラクタ終わり

  @override
  Widget build(BuildContext context) {
    if (selectedDate == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(lang == UiLang.ja ? '日付を選択してください' : 'Please select a date'),
      ); // 未選択カード
    } // if終わり

    final info = garbageTextOf(selectedDate!); // 選択日の説明文
    final types = garbageTypesOf(selectedDate!); // 選択日の種別（複数）

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${selectedDate!.year}/${selectedDate!.month}/${selectedDate!.day}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(info),
          if (types.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: types
                  .map(
                    (t) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          garbageIcon(t),
                          size: 18,
                          color: garbageIconColor(t),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          garbageLabel(t, lang),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    ); // Container終わり
  } // build終わり
} // _SelectedInfoCard終わり

// ===========================
// ★詳細情報パネル：区ごとに内容を切替／ゴミ種別ごとにカードを縦に並べて表示
// ===========================

class _GarbageGuidePanel extends StatelessWidget {
  final UiLang lang; // 表示言語
  final String selectedArea; // 区
  final List<GarbageRule> rules; // ルール
  final bool disableWeekendCollection; // 土日無効設定

  const _GarbageGuidePanel({
    required this.lang,
    required this.selectedArea,
    required this.rules,
    required this.disableWeekendCollection,
  }); // コンストラクタ終わり

  Map<GarbageType, List<GarbageRule>> _groupRulesByType(
    List<GarbageRule> rules,
  ) {
    final map = <GarbageType, List<GarbageRule>>{}; // 種別→ルール一覧
    for (final r in rules) {
      if (disableWeekendCollection &&
          (r.weekday0to6 == 0 || r.weekday0to6 == 6)) {
        continue; // 土日無効なら土日ルールを表示から除外（見た目と判定を一致させる）
      }
      map.putIfAbsent(r.type, () => <GarbageRule>[]).add(r); // 種別配列に追加
    }
    return map;
  } // _groupRulesByType終わり

  String _weeksText(Set<int> weeks) {
    final list = weeks.toList()..sort(); // ソート
    final isEveryWeek =
        list.length >= 5 &&
        list.contains(1) &&
        list.contains(2) &&
        list.contains(3) &&
        list.contains(4) &&
        list.contains(5); // 1〜5が揃えば毎週扱い
    if (isEveryWeek) return (lang == UiLang.ja) ? '毎週' : 'Every week'; // 毎週表記
    if (lang == UiLang.ja)
      return list.map((w) => weekLabel(w, lang)).join('・'); // 例：第1・第3
    return list.map((w) => weekLabel(w, lang)).join(' & '); // 例：1st & 3rd
  } // _weeksText終わり

  String _ruleLine(GarbageRule r) {
    final wd = weekdayLabel0to6(r.weekday0to6, lang); // 曜日文字
    final w = _weeksText(r.weeks); // 週文字
    if (lang == UiLang.ja) return '$w${wd}曜日'; // 例：毎週月曜日
    return '$w $wd'; // 例：Every week Mon
  } // _ruleLine終わり

  Widget _typeCard({
    required GarbageType type,
    required String title,
    required String note,
    required List<GarbageRule> typeRules,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1E5EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(garbageIcon(type), color: garbageIconColor(type), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: garbageColor(type),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: const Color(0xFFCED6E6)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            lang == UiLang.ja ? '収集日' : 'Collection days',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 4),
          if (typeRules.isEmpty)
            Text(
              lang == UiLang.ja ? 'この区では設定がありません' : 'No rule set for this area',
            )
          else
            ...typeRules.map((r) => Text('• ${_ruleLine(r)}')),
          const SizedBox(height: 10),
          Text(
            lang == UiLang.ja ? '注意点' : 'Tips',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(note),
        ],
      ),
    );
  } // _typeCard終わり

  @override
  Widget build(BuildContext context) {
    final grouped = _groupRulesByType(rules); // 種別ごとにまとめる（土日無効なら土日も除外）

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
    ];

    final order = <GarbageType>[
      GarbageType.burnable,
      GarbageType.recyclable,
      GarbageType.plastic,
      GarbageType.nonBurnable,
      GarbageType.bulky,
    ]; // 表示順
    final itemMap = {for (final it in items) it.type: it}; // type→item のMap

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE1E5EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang == UiLang.ja
                ? '$selectedArea の 詳細情報'
                : 'Details: $selectedArea',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            lang == UiLang.ja
                ? '※ 1/1〜1/3 は 収集がありません（色・アイコンも表示しません）'
                : '* No collection on Jan 1–3 (no color/icon).',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          if (disableWeekendCollection) ...[
            const SizedBox(height: 4),
            Text(
              lang == UiLang.ja
                  ? '※ 土日は収集なしとして扱います'
                  : '* Weekends are treated as no-collection.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ],
          const SizedBox(height: 12),

          ...order.map((type) {
            final it = itemMap[type]!;
            final title = (lang == UiLang.ja) ? it.titleJa : it.titleEn;
            final note = (lang == UiLang.ja) ? it.noteJa : it.noteEn;
            final typeRules = grouped[type] ?? const <GarbageRule>[];
            return _typeCard(
              type: type,
              title: title,
              note: note,
              typeRules: typeRules,
            );
          }),

          Text(
            lang == UiLang.ja
                ? '※実際の分別・出し方は自治体の案内が最優先です。'
                : '*Local municipality rules take precedence.*',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  } // build終わり
} // _GarbageGuidePanel終わり

class _GarbageGuideItem {
  final GarbageType type;
  final String titleJa;
  final String titleEn;
  final String noteJa;
  final String noteEn;

  const _GarbageGuideItem({
    required this.type,
    required this.titleJa,
    required this.titleEn,
    required this.noteJa,
    required this.noteEn,
  });
} // _GarbageGuideItem終わり

// ===========================
// ★追加：重要なお知らせ（赤いカード）
// ===========================

class _ImportantNoticeCard extends StatelessWidget {
  final UiLang lang; // 言語（将来拡張用）
  final String selectedArea; // 区（見出し用）
  final List<String> lines; // 表示行

  const _ImportantNoticeCard({
    required this.lang,
    required this.selectedArea,
    required this.lines,
  }); // コンストラクタ終わり

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, // 横幅いっぱい
      padding: const EdgeInsets.all(12), // 余白
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE), // 薄い赤背景
        borderRadius: BorderRadius.circular(12), // 角丸
        border: Border.all(color: const Color(0xFFFFCDD2)), // 赤系枠線
      ), // decoration終わり
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang == UiLang.ja
                ? '重要なお知らせ（$selectedArea）'
                : 'Important Notice ($selectedArea)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ...lines.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(s),
            ),
          ), // 行を縦に表示
        ],
      ),
    );
  } // build終わり
} // _ImportantNoticeCard終わり

// ===========================
// ★追加：お問い合わせ（青いカード）— []内をグレー表示
// ===========================

class _InquiryInfo {
  final String centerName; // センター名
  final String phone; // 電話番号
  final String hoursWeekday; // 平日時間
  final String hoursHoliday; // 土日祝時間
  final String websiteLabel; // サイトラベル
  final String websiteUrlText; // URL文字（実URLが無い場合の表示）

  const _InquiryInfo({
    required this.centerName,
    required this.phone,
    required this.hoursWeekday,
    required this.hoursHoliday,
    required this.websiteLabel,
    required this.websiteUrlText,
  }); // コンストラクタ終わり
} // _InquiryInfo終わり

class _InquiryCard extends StatelessWidget {
  final UiLang lang; // 言語（将来拡張用）
  final String selectedArea; // 区（見出し用）
  final _InquiryInfo info; // 問い合わせ情報

  const _InquiryCard({
    required this.lang,
    required this.selectedArea,
    required this.info,
  }); // コンストラクタ終わり

  TextSpan _line(String left, String bracketText, {TextStyle? leftStyle}) {
    // 1行分のRichText（[]内のみグレー）
    final grey = TextStyle(
      color: Colors.grey.shade700,
      fontWeight: FontWeight.bold,
    ); // []内のグレー
    return TextSpan(
      children: [
        TextSpan(text: left, style: leftStyle), // 左側テキスト
        TextSpan(text: ' [', style: leftStyle), // 開き括弧
        TextSpan(text: bracketText, style: grey), // []内（グレー）
        TextSpan(text: ']', style: leftStyle), // 閉じ括弧
      ],
    );
  } // _line終わり

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontSize: 13,
      color: Colors.blue.shade900,
    ); // 基本文字色（青系）
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F2FD), // 薄い青背景
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBBDEFB)), // 青系枠線
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang == UiLang.ja
                ? 'お問い合わせ（$selectedArea）'
                : 'Inquiry ($selectedArea)',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          RichText(
            text: _line(
              '${info.centerName} :',
              info.phone,
              leftStyle: baseStyle,
            ),
          ), // 電話
          const SizedBox(height: 4),
          RichText(
            text: _line('受付時間 :', info.hoursWeekday, leftStyle: baseStyle),
          ), // 平日
          const SizedBox(height: 4),
          RichText(
            text: _line('', info.hoursHoliday, leftStyle: baseStyle),
          ), // 土日祝
          const SizedBox(height: 4),
          RichText(
            text: _line(
              '${info.websiteLabel}',
              info.websiteUrlText,
              leftStyle: baseStyle,
            ),
          ), // 公式サイト
        ],
      ),
    );
  } // build終わり
} // _InquiryCard終わり

// ===========================
// ★追加：祝日の収集ポリシー（表示用）
// ===========================

enum HolidayPolicy {
  collect, // 祝日も収集する
  noCollect, // 祝日は収集しない
  check, // 要確認（自治体情報確認）
} // HolidayPolicy終わり

String holidayPolicyText(HolidayPolicy p, UiLang lang) {
  if (lang == UiLang.ja) {
    switch (p) {
      case HolidayPolicy.collect:
        return '祝日：収集あり（通常どおり）';
      case HolidayPolicy.noCollect:
        return '祝日：収集なし';
      case HolidayPolicy.check:
        return '祝日：要確認（自治体の案内をご確認ください）';
    }
  } else {
    switch (p) {
      case HolidayPolicy.collect:
        return 'Holidays: Collected (as usual)';
      case HolidayPolicy.noCollect:
        return 'Holidays: No collection';
      case HolidayPolicy.check:
        return 'Holidays: Please check local rules';
    }
  }
} // holidayPolicyText終わり

// ===========================
// ★追加：グレーのカード「収集スケジュール」
// - 平日収集：月〜金の曜日ごとの収集物（ルールから自動集計）
// - 休収集日：収集が無い曜日（ルールから自動抽出）
// - 祝日：収集があるか（区ごとの設定で表示）
// ===========================

class _CollectionScheduleCard extends StatelessWidget {
  final UiLang lang; // 表示言語
  final String selectedArea; // 区
  final List<GarbageRule> rules; // ルール
  final HolidayPolicy holidayPolicy; // 祝日ポリシー
  final bool disableWeekendCollection; // 土日無効

  const _CollectionScheduleCard({
    required this.lang,
    required this.selectedArea,
    required this.rules,
    required this.holidayPolicy,
    required this.disableWeekendCollection,
  }); // コンストラクタ終わり

  Map<int, List<GarbageType>> _typesByWeekday(List<GarbageRule> rules) {
    final map = <int, List<GarbageType>>{}; // weekday0to6 → types
    for (final r in rules) {
      if (disableWeekendCollection &&
          (r.weekday0to6 == 0 || r.weekday0to6 == 6)) {
        continue; // 土日無効なら土日ルールは集計から除外
      }
      map
          .putIfAbsent(r.weekday0to6, () => <GarbageType>[])
          .add(r.type); // 曜日キーに追加
    }
    return map;
  } // _typesByWeekday終わり

  String _weekdayText(int wd0to6) {
    final wd = weekdayLabel0to6(wd0to6, lang); // 0..6→文字
    return (lang == UiLang.ja) ? '${wd}曜日' : wd; // 日本語は「曜日」付き
  } // _weekdayText終わり

  String _typesText(List<GarbageType> types) {
    if (types.isEmpty) return (lang == UiLang.ja) ? 'なし' : 'None'; // なし表示
    return types
        .map((t) => garbageLabel(t, lang))
        .join(lang == UiLang.ja ? '／' : ' / '); // 種別名を連結
  } // _typesText終わり

  @override
  Widget build(BuildContext context) {
    final byWd = _typesByWeekday(rules); // 曜日→種別（未正規化）

    List<GarbageType> typesForWeekday(int wd0to6) {
      if (disableWeekendCollection && (wd0to6 == 0 || wd0to6 == 6)) {
        return const <GarbageType>[]; // 土日は収集なし表示
      }
      final raw = byWd[wd0to6] ?? const <GarbageType>[]; // 無ければ空
      return normalizeTypes(raw); // 重複除去＆順序安定化
    } // typesForWeekday終わり

    final weekdayList = <int>[1, 2, 3, 4, 5]; // 平日：月(1)〜金(5)
    final allDays = <int>[0, 1, 2, 3, 4, 5, 6]; // 全曜日：日(0)〜土(6)

    final restDays = <int>[
      for (final wd in allDays)
        if (typesForWeekday(wd).isEmpty) wd, // その曜日が空なら休収集日
    ]; // restDays終わり

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2), // 薄いグレー
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_month,
                color: Color(0xFF616161),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '収集スケジュール',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF616161).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  selectedArea,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF616161),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            lang == UiLang.ja ? '平日収集' : 'Weekday collections',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 6),

          ...weekdayList.map((wd) {
            final types = typesForWeekday(wd); // その曜日の種別（複数可）
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(
                      _weekdayText(wd),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _typesText(types),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 10),

          Text(
            lang == UiLang.ja ? '休収集日' : 'No collection days',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 6),

          if (restDays.isEmpty)
            Text(
              lang == UiLang.ja
                  ? 'なし（毎日いずれかの収集あり）'
                  : 'None (collections exist every day)',
              style: const TextStyle(fontSize: 13),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final wd in restDays)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFDDDDDD)),
                    ),
                    child: Text(
                      _weekdayText(wd),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF616161),
                      ),
                    ),
                  ),
              ],
            ),

          const SizedBox(height: 10),

          Text(
            lang == UiLang.ja ? '祝日の収集' : 'Holiday collections',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            holidayPolicyText(holidayPolicy, lang),
            style: const TextStyle(fontSize: 13),
          ),

          const SizedBox(height: 8),

          Text(
            lang == UiLang.ja
                ? '※この表示は「週×曜日ルール」から曜日ごとに集計した結果です（第2水なども含みます）。'
                : '*This view aggregates weekday types from rules (includes 2nd Wed etc.).',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  } // build終わり
} // _CollectionScheduleCard終わり
