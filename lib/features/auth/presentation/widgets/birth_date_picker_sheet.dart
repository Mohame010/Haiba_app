import 'package:material_ui/material_ui.dart';

const _primaryColor = Color(0xFF7C3AED);
const _textColor = Color(0xFF1E1B4B);
const _arabicMonths = <String>[
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

Future<DateTime?> showBirthDatePickerBottomSheet({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  assert(!firstDate.isAfter(lastDate));
  assert(!initialDate.isBefore(firstDate));
  assert(!initialDate.isAfter(lastDate));

  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x990F102A),
    builder: (_) => BirthDatePickerSheet(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    ),
  );
}

class BirthDatePickerSheet extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const BirthDatePickerSheet({
    super.key,
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<BirthDatePickerSheet> createState() => _BirthDatePickerSheetState();
}

class _BirthDatePickerSheetState extends State<BirthDatePickerSheet> {
  static const _itemExtent = 48.0;

  late int _selectedYear;
  late int _selectedMonth;
  late int _selectedDay;

  late final FixedExtentScrollController _yearController;
  late final FixedExtentScrollController _monthController;
  late final FixedExtentScrollController _dayController;

  int get _firstYear => widget.firstDate.year;
  int get _yearCount => widget.lastDate.year - widget.firstDate.year + 1;

  int get _firstMonth =>
      _selectedYear == widget.firstDate.year ? widget.firstDate.month : 1;

  int get _lastMonth =>
      _selectedYear == widget.lastDate.year ? widget.lastDate.month : 12;

  int get _monthCount => _lastMonth - _firstMonth + 1;

  int get _firstDay =>
      _selectedYear == widget.firstDate.year &&
          _selectedMonth == widget.firstDate.month
      ? widget.firstDate.day
      : 1;

  int get _lastDay {
    final daysInMonth = DateTime(_selectedYear, _selectedMonth + 1, 0).day;
    if (_selectedYear == widget.lastDate.year &&
        _selectedMonth == widget.lastDate.month) {
      return widget.lastDate.day;
    }
    return daysInMonth;
  }

  int get _dayCount => _lastDay - _firstDay + 1;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialDate.year;
    _selectedMonth = widget.initialDate.month;
    _selectedDay = widget.initialDate.day;
    _yearController = FixedExtentScrollController(
      initialItem: _selectedYear - _firstYear,
    );
    _monthController = FixedExtentScrollController(
      initialItem: _selectedMonth - _firstMonth,
    );
    _dayController = FixedExtentScrollController(
      initialItem: _selectedDay - _firstDay,
    );
  }

  @override
  void dispose() {
    _yearController.dispose();
    _monthController.dispose();
    _dayController.dispose();
    super.dispose();
  }

  void _selectYear(int index) {
    final year = _firstYear + index;
    if (year == _selectedYear) return;

    setState(() {
      _selectedYear = year;
      _selectedMonth = _selectedMonth.clamp(_firstMonth, _lastMonth);
      _selectedDay = _selectedDay.clamp(_firstDay, _lastDay);
    });
    _syncDependentWheels(syncMonth: true);
  }

  void _selectMonth(int index) {
    final month = _firstMonth + index;
    if (month == _selectedMonth) return;

    setState(() {
      _selectedMonth = month;
      _selectedDay = _selectedDay.clamp(_firstDay, _lastDay);
    });
    _syncDependentWheels();
  }

  void _syncDependentWheels({bool syncMonth = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (syncMonth && _monthController.hasClients) {
        _monthController.jumpToItem(_selectedMonth - _firstMonth);
      }
      if (_dayController.hasClients) {
        _dayController.jumpToItem(_selectedDay - _firstDay);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + bottomPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFB5B6C8),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 28),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  color: _primaryColor,
                  size: 30,
                ),
                SizedBox(width: 12),
                Text(
                  'اختر تاريخ الميلاد',
                  style: TextStyle(
                    color: _textColor,
                    fontFamily: 'IBM',
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 26),
            const Row(
              children: [
                Expanded(child: _ColumnHeader(label: 'اليوم')),
                SizedBox(width: 12),
                Expanded(child: _ColumnHeader(label: 'الشهر')),
                SizedBox(width: 12),
                Expanded(child: _ColumnHeader(label: 'السنة')),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: _itemExtent * 5,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    height: _itemExtent,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8E1FF),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: _buildWheel(
                          key: const ValueKey('birth-day-wheel'),
                          controller: _dayController,
                          itemCount: _dayCount,
                          labelBuilder: (index) => '${_firstDay + index}',
                          onSelectedItemChanged: (index) {
                            setState(() => _selectedDay = _firstDay + index);
                          },
                        ),
                      ),
                      const VerticalDivider(
                        width: 1,
                        indent: 28,
                        endIndent: 28,
                        color: Color(0xFFE1E2EE),
                      ),
                      Expanded(
                        child: _buildWheel(
                          key: ValueKey('birth-month-wheel-$_selectedYear'),
                          controller: _monthController,
                          itemCount: _monthCount,
                          labelBuilder: (index) =>
                              '${_firstMonth + index} - ${_arabicMonths[_firstMonth + index - 1]}',
                          onSelectedItemChanged: _selectMonth,
                        ),
                      ),
                      const VerticalDivider(
                        width: 1,
                        indent: 28,
                        endIndent: 28,
                        color: Color(0xFFE1E2EE),
                      ),
                      Expanded(
                        child: _buildWheel(
                          key: const ValueKey('birth-year-wheel'),
                          controller: _yearController,
                          itemCount: _yearCount,
                          labelBuilder: (index) => '${_firstYear + index}',
                          onSelectedItemChanged: _selectYear,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                key: const ValueKey('confirm-birth-date'),
                onPressed: () => Navigator.of(
                  context,
                ).pop(DateTime(_selectedYear, _selectedMonth, _selectedDay)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'تأكيد',
                  style: TextStyle(
                    fontFamily: 'IBM',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWheel({
    required Key key,
    required FixedExtentScrollController controller,
    required int itemCount,
    required String Function(int index) labelBuilder,
    required ValueChanged<int> onSelectedItemChanged,
  }) {
    return ListWheelScrollView.useDelegate(
      key: key,
      controller: controller,
      itemExtent: _itemExtent,
      physics: const FixedExtentScrollPhysics(),
      diameterRatio: 1.5,
      perspective: 0.003,
      useMagnifier: true,
      magnification: 1.08,
      overAndUnderCenterOpacity: 0.55,
      onSelectedItemChanged: onSelectedItemChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: itemCount,
        builder: (context, index) => Center(
          child: Text(
            labelBuilder(index),
            maxLines: 1,
            style: const TextStyle(
              color: _textColor,
              fontFamily: 'IBM',
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _ColumnHeader extends StatelessWidget {
  final String label;

  const _ColumnHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F8),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: _textColor,
          fontFamily: 'IBM',
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
