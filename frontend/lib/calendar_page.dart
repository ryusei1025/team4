import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 6行×7列の月カレンダー（2026年以降）
/// - 曜日表示あり
/// - 月切り替えは「縦スクロール」
/// - 前月/次月の日付も薄く表示して自然につながる
/// - 枠上部に年/月ドロップダウン（即移動）
/// - 日付クリックで、下に「年月日・曜日・例文1・例文2」を表示
/// - ヘッダー：左にエリア選択（中央より左寄り）、右端に言語選択
/// - ★追加：ヘッダー最左に「三点リーダ」→ 左から Drawer（メニューバー）表示
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

bool _drawerOpen = false;

enum UiLang { ja, en }

class _CalendarPageState extends State<CalendarPage> {
  static const int baseYear = 2026;
  static const int maxYear = 2100;
  static final DateTime baseMonth = DateTime(baseYear, 1, 1);
  static const int totalMonths = (maxYear - baseYear + 1) * 12;

  late final PageController _pageController;

  late int _visibleYear;
  late int _visibleMonth;

  late int _pickedYear;
  late int _pickedMonth;

  DateTime? _selectedDate;

  // ヘッダー：エリア選択
  final List<String> _areas = const ['中央区', '東区', '北区'];
  String _selectedArea = '中央区';

  // ヘッダー：言語
  UiLang _lang = UiLang.ja;

  static const _weekdayEn = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  static const _weekdayJa = ['日', '月', '火', '水', '木', '金', '土'];

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    final initial = (now.year < baseYear)
        ? DateTime(baseYear, 1, 1)
        : DateTime(now.year, now.month, 1);

    _visibleYear = initial.year;
    _visibleMonth = initial.month;

    _pickedYear = _visibleYear;
    _pickedMonth = _visibleMonth;

    final initialIndex = _monthIndexFrom(
      baseMonth,
      DateTime(_visibleYear, _visibleMonth, 1),
    );
    _pageController = PageController(
      initialPage: initialIndex.clamp(0, totalMonths - 1),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  int _monthIndexFrom(DateTime base, DateTime target) {
    return (target.year - base.year) * 12 + (target.month - base.month);
  }

  DateTime _monthFromIndex(int index) {
    final y = baseYear + (index ~/ 12);
    final m = 1 + (index % 12);
    return DateTime(y, m, 1);
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final dy = event.scrollDelta.dy;
      const threshold = 18.0;

      if (dy > threshold) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      } else if (dy < -threshold) {
        _pageController.previousPage(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    }
  }

  void _goToPickedMonth() {
    if (_pickedYear == _visibleYear && _pickedMonth == _visibleMonth) return;

    final target = DateTime(_pickedYear, _pickedMonth, 1);
    final idx = _monthIndexFrom(baseMonth, target).clamp(0, totalMonths - 1);

    _pageController.animateToPage(
      idx,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _onDateTap(DateTime date, {required DateTime currentMonth}) {
    setState(() {
      _selectedDate = date;
    });

    final inThisMonth =
        (date.year == currentMonth.year && date.month == currentMonth.month);
    if (!inThisMonth) {
      setState(() {
        _pickedYear = date.year.clamp(baseYear, maxYear);
        _pickedMonth = date.month;
      });
      _goToPickedMonth();
    }
  }

  String _weekdayText(DateTime d) {
    final idx = d.weekday % 7;
    return _lang == UiLang.ja ? _weekdayJa[idx] : _weekdayEn[idx];
  }

  String _selectedInfoTitle(DateTime d) {
    final w = _weekdayText(d);
    if (_lang == UiLang.ja) return '${d.year}年${d.month}月${d.day}日（$w）';
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd ($w)';
  }

  String _labelYear() => _lang == UiLang.ja ? '年' : 'Year';
  String _labelMonth() => _lang == UiLang.ja ? '月' : 'Month';
  String _labelArea() => _lang == UiLang.ja ? 'エリア' : 'Area';
  String _labelLang() => _lang == UiLang.ja ? '言語' : 'Lang';

  String _placeholderText() {
    return _lang == UiLang.ja
        ? '日付をクリックすると、ここに「年月日・曜日・例文1・例文2」を表示します。'
        : 'Click a date to show “date, weekday, example 1, example 2” here.';
  }

  @override
  Widget build(BuildContext context) {
    final years = List<int>.generate(
      maxYear - baseYear + 1,
      (i) => baseYear + i,
    );
    final months = List<int>.generate(12, (i) => i + 1);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      // ★追加：Drawer の開閉状態を受け取る
      onDrawerChanged: (isOpen) {
        setState(() => _drawerOpen = isOpen);
      },
      // ★ Drawer（左から出るメニューバー）
      drawer: _LeftMenuDrawer(
        lang: _lang,
        selectedArea: _selectedArea,
        onTapMenu: (key) {
          // ここにメニューの処理を後から足せます（例：画面遷移・設定）
          // 今は例として Drawer を閉じるだけにしています。
          Navigator.of(context).pop();
        },
      ),

      // ★ ヘッダー（AppBar）
      appBar: AppBar(
        centerTitle: true,

        // ★最左：三点リーダ（Drawer を開く）
        leading: Builder(
          // AppBarのleadingは別contextになるのでBuilderでScaffoldを取る
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.more_vert), // 三点リーダ（縦）
            tooltip: 'Menu',
            onPressed: () {
              if (_drawerOpen) {
                // すでに開いている → 閉じる
                Navigator.of(context).pop();
              } else {
                // 閉じている → 開く
                Scaffold.of(ctx).openDrawer();
              }
            },
          ),
        ),

        // タイトル文字列は不要なので、代わりに「エリア選択」を配置
        title: Transform.translate(
          // leadingがあるので、少しだけ左寄せにする（必要なら数値調整）
          offset: const Offset(-10, 0),
          child: _HeaderDropdown<String>(
            label: _labelArea(),
            value: _selectedArea,
            items: _areas,
            itemLabel: (v) => v,
            onChanged: (v) {
              setState(() => _selectedArea = v);
            },
            width: 160,
          ),
        ),

        // 右端：言語選択
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: _HeaderDropdown<UiLang>(
                label: _labelLang(),
                value: _lang,
                items: const [UiLang.ja, UiLang.en],
                itemLabel: (v) => v == UiLang.ja ? '日本語' : 'English',
                onChanged: (v) => setState(() => _lang = v),
                width: 140,
              ),
            ),
          ),
        ],
      ),

      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 外枠
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFE1E5EE),
                      width: 1,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        blurRadius: 16,
                        offset: Offset(0, 8),
                        color: Color(0x14000000),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 枠上部：年/月ドロップダウン（即移動）
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: _LabeledDropdown<int>(
                                label: _labelYear(),
                                value: _pickedYear,
                                items: years,
                                itemLabel: (v) => '$v',
                                onChanged: (v) {
                                  setState(() => _pickedYear = v);
                                  _goToPickedMonth();
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _LabeledDropdown<int>(
                                label: _labelMonth(),
                                value: _pickedMonth,
                                items: months,
                                itemLabel: (v) => '$v',
                                onChanged: (v) {
                                  setState(() => _pickedMonth = v);
                                  _goToPickedMonth();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // グリッド枠（6x7 + 曜日行）
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: AspectRatio(
                          aspectRatio: 7 / 7,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFCED6E6),
                                width: 1,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Column(
                              children: [
                                _WeekdayRow(lang: _lang),

                                // 縦スクロール PageView
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
                                          onDateTap: (d) => _onDateTap(
                                            d,
                                            currentMonth: month,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                _SelectedInfoCard(
                  selectedDate: _selectedDate,
                  titleBuilder: _selectedInfoTitle,
                  placeholder: _placeholderText(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ★ 左から出る Drawer（メニューバー）
/// 今は雛形なので、好きなメニュー項目を追加してください。
class _LeftMenuDrawer extends StatelessWidget {
  final UiLang lang;
  final String selectedArea;
  final void Function(String key) onTapMenu;

  const _LeftMenuDrawer({
    required this.lang,
    required this.selectedArea,
    required this.onTapMenu,
  });
  // サイドバーメニュー項目
  @override
  Widget build(BuildContext context) {
    final item1 = (lang == UiLang.ja) ? 'ホーム画面' : 'Menu home';
    final item2 = (lang == UiLang.ja) ? 'ゴミ分別辞書' : 'Garbage Sorting Dictionary';
    final item3 = (lang == UiLang.ja) ? 'ゴミ箱マップ' : 'trash can map';
    final item4 = (lang == UiLang.ja)
        ? 'AIカメラ(ゴミ種類)'
        : 'AI camera (garbage type)';

    return Drawer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 36), // ←ここを増やすと「下がる」
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.home_outlined),
                title: Text(item1),
                onTap: () => onTapMenu('item1'),
              ),
              ListTile(
                leading: const Icon(Icons.book_outlined),
                title: Text(item2),
                onTap: () => onTapMenu('item2'),
              ),
              ListTile(
                leading: const Icon(Icons.map_outlined),
                title: Text(item3),
                onTap: () => onTapMenu('item3'),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: Text(item4),
                onTap: () => onTapMenu('item4'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// AppBar内用の小さめドロップダウン
class _HeaderDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T> onChanged;
  final double width;

  const _HeaderDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Color(0xFFE7EBF3),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isDense: true,
              isExpanded: true,
              icon: const Icon(Icons.expand_more, size: 18),
              items: items
                  .map(
                    (v) => DropdownMenuItem<T>(
                      value: v,
                      child: Text(
                        '$label: ${itemLabel(v)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// 枠上部（年/月）用ドロップダウン
class _LabeledDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final String Function(T) itemLabel;
  final ValueChanged<T> onChanged;

  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          isExpanded: true,
          items: items
              .map(
                (v) => DropdownMenuItem<T>(value: v, child: Text(itemLabel(v))),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

/// 曜日行（言語で切り替え）
class _WeekdayRow extends StatelessWidget {
  final UiLang lang;
  const _WeekdayRow({required this.lang});

  @override
  Widget build(BuildContext context) {
    final labels = (lang == UiLang.ja)
        ? const ['日', '月', '火', '水', '木', '金', '土']
        : const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Container(
      height: 40,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE7EBF3), width: 1)),
      ),
      child: Row(
        children: List.generate(7, (i) {
          final isSun = i == 0;
          final isSat = i == 6;

          return Expanded(
            child: Center(
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isSun
                      ? const Color(0xFFCF3B3B)
                      : isSat
                      ? const Color(0xFF2E5AAC)
                      : const Color(0xFF2C3441),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// 1か月分の「6×7」日付グリッド（前月/次月も含めて42セル）
class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateTap;

  const _MonthGrid({
    required this.month,
    required this.selectedDate,
    required this.onDateTap,
  });

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final offset = first.weekday % 7;

    final cells = List<DateTime>.generate(42, (i) {
      return DateTime(month.year, month.month, 1 + (i - offset));
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellW = constraints.maxWidth / 7;
        final cellH = constraints.maxHeight / 6;
        final now = DateTime.now();

        return Column(
          children: List.generate(6, (row) {
            return SizedBox(
              height: cellH,
              child: Row(
                children: List.generate(7, (col) {
                  final idx = row * 7 + col;
                  final d = cells[idx];

                  final inThisMonth =
                      (d.month == month.month) && (d.year == month.year);
                  final isSun = col == 0;
                  final isSat = col == 6;

                  final textColor = !inThisMonth
                      ? const Color(0xFFB4BCCB)
                      : isSun
                      ? const Color(0xFFCF3B3B)
                      : isSat
                      ? const Color(0xFF2E5AAC)
                      : const Color(0xFF2C3441);

                  final isToday =
                      (d.year == now.year &&
                      d.month == now.month &&
                      d.day == now.day);
                  final isSelected =
                      selectedDate != null && _sameDate(d, selectedDate!);

                  Color bg = Colors.transparent;
                  if (isToday) bg = const Color(0x1A4B7BE5);
                  if (isSelected) bg = const Color(0x264B7BE5);

                  return SizedBox(
                    width: cellW,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(
                          right: BorderSide(
                            color: col == 6
                                ? Colors.transparent
                                : const Color(0xFFE7EBF3),
                            width: 1,
                          ),
                          bottom: BorderSide(
                            color: row == 5
                                ? Colors.transparent
                                : const Color(0xFFE7EBF3),
                            width: 1,
                          ),
                        ),
                        color: bg,
                      ),
                      child: InkWell(
                        onTap: () => onDateTap(d),
                        child: Center(
                          child: Text(
                            '${d.day}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: inThisMonth
                                  ? FontWeight.w700
                                  : FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        );
      },
    );
  }
}

/// カレンダー下に出す「選択情報」カード
class _SelectedInfoCard extends StatelessWidget {
  final DateTime? selectedDate;
  final String Function(DateTime) titleBuilder;
  final String placeholder;

  const _SelectedInfoCard({
    required this.selectedDate,
    required this.titleBuilder,
    required this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    final d = selectedDate;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1E5EE), width: 1),
      ),
      child: d == null
          ? Text(
              placeholder,
              style: const TextStyle(fontSize: 13, color: Color(0xFF5B6475)),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titleBuilder(d),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('例文1', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 4),
                const Text('例文2', style: TextStyle(fontSize: 13)),
              ],
            ),
    );
  }
}
