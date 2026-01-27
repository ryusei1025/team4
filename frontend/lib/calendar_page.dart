import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'drawer_menu.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
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

  final List<String> _areas = const ['中央区', '東区', '北区'];
  String _selectedArea = '中央区';
  UiLang _lang = UiLang.ja;

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

  int _monthIndexFrom(DateTime base, DateTime target) =>
      (target.year - base.year) * 12 + (target.month - base.month);
  DateTime _monthFromIndex(int index) =>
      DateTime(baseYear + (index ~/ 12), 1 + (index % 12), 1);

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

  void _goToPickedMonth() {
    final target = DateTime(_pickedYear, _pickedMonth, 1);
    final idx = _monthIndexFrom(baseMonth, target).clamp(0, totalMonths - 1);
    _pageController.animateToPage(
      idx,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  void _onDateTap(DateTime date, {required DateTime currentMonth}) {
    setState(() => _selectedDate = date);
    if (date.year != currentMonth.year || date.month != currentMonth.month) {
      setState(() {
        _pickedYear = date.year.clamp(baseYear, maxYear);
        _pickedMonth = date.month;
      });
      _goToPickedMonth();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 背景をグラデーションにするためScaffold自体の色は透明にする
      backgroundColor: Colors.transparent,
      drawer: LeftMenuDrawer(lang: _lang, selectedArea: _selectedArea),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: const Color.fromARGB(
          255,
          0,
          221,
          192,
        ).withOpacity(0.8), // 少し透けさせて馴染ませる
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: _HeaderDropdown<String>(
          label: _lang == UiLang.ja ? 'エリア' : 'Area',
          value: _selectedArea,
          items: _areas,
          itemLabel: (v) => v,
          onChanged: (v) => setState(() => _selectedArea = v),
          width: 160,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: LanguageSelector(
              currentLang: _lang,
              onChanged: (v) => setState(() => _lang = v),
            ),
          ),
        ],
      ),
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9), // 背景に合わせて少し透過
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color.fromARGB(255, 200, 188, 243),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _LabeledDropdown<int>(
                                label: '年',
                                value: _pickedYear,
                                items: List.generate(
                                  maxYear - baseYear + 1,
                                  (i) => baseYear + i,
                                ),
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
                                label: '月',
                                value: _pickedMonth,
                                items: List.generate(12, (i) => i + 1),
                                itemLabel: (v) => '$v',
                                onChanged: (v) {
                                  setState(() => _pickedMonth = v);
                                  _goToPickedMonth();
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
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
                                _WeekdayRow(lang: _lang),
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SelectedInfoCard(selectedDate: _selectedDate, lang: _lang),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- 補助ウィジェット ---

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
          border: Border.all(color: const Color(0xFFE1E5EE)),
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFFE7EBF3).withOpacity(0.9),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isDense: true,
              isExpanded: true,
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
        filled: true,
        fillColor: Colors.white,
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
        color: Color(0xFFF8F9FB),
        border: Border(bottom: BorderSide(color: Color(0xFFE7EBF3))),
      ),
      child: Row(
        children: List.generate(
          7,
          (i) => Expanded(
            child: Center(
              child: Text(
                labels[i],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: i == 0
                      ? Colors.red
                      : i == 6
                      ? Colors.blue
                      : Colors.black,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  final DateTime month;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDateTap;
  const _MonthGrid({
    required this.month,
    required this.selectedDate,
    required this.onDateTap,
  });
  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final offset = first.weekday % 7;
    final cells = List<DateTime>.generate(
      42,
      (i) => DateTime(month.year, month.month, 1 + (i - offset)),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellH = constraints.maxHeight / 6;
        final cellW = constraints.maxWidth / 7;
        return Column(
          children: List.generate(
            6,
            (row) => SizedBox(
              height: cellH,
              child: Row(
                children: List.generate(7, (col) {
                  final d = cells[row * 7 + col];
                  final isSelected =
                      selectedDate != null &&
                      d.year == selectedDate!.year &&
                      d.month == selectedDate!.month &&
                      d.day == selectedDate!.day;
                  return SizedBox(
                    width: cellW,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFF0F0F0)),
                        color: isSelected
                            ? Colors.green.withOpacity(0.2) // グラデーションに合わせて緑系に
                            : Colors.transparent,
                      ),
                      child: InkWell(
                        onTap: () => onDateTap(d),
                        child: Center(
                          child: Text(
                            '${d.day}',
                            style: TextStyle(
                              color: d.month == month.month
                                  ? Colors.black
                                  : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SelectedInfoCard extends StatelessWidget {
  final DateTime? selectedDate;
  final UiLang lang;
  const _SelectedInfoCard({required this.selectedDate, required this.lang});
  @override
  Widget build(BuildContext context) {
    String message = lang == UiLang.ja ? '日付を選択してください' : 'Please select a date';
    if (selectedDate != null) {
      // ここに実際のごみ収集ロジックを入れる想定
      message = 'この日は燃えるゴミの日です';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: selectedDate == null
          ? Text(message, style: const TextStyle(color: Colors.grey))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${selectedDate!.year}/${selectedDate!.month}/${selectedDate!.day}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 4),
                Text(message, style: const TextStyle(fontSize: 16)),
              ],
            ),
    );
  }
}
