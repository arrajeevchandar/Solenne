import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  static const int _futureDayCount = 30;
  static const int _pastDayCount = 120;
  static const double _navHeight = 62;
  static const double _navBottomMargin = 14;
  static const double _calendarToNavGap = 8;
  static const double _sectionGap = 14;
  static const double _horizontalPadding = 20;
  static const double _headerTop = 20;
  static const double _timelinePanelTop = 94;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _todayKey = GlobalKey();
  int _expandedIndex = _pastDayCount;
  bool _hasPositionedToday = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _positionTodayAtTop());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  List<_TimelineDay> _visibleDays() {
    final today = _dateOnly(DateTime.now());
    return List.generate(_futureDayCount + 1 + _pastDayCount, (index) {
      final date = today.add(Duration(days: index - _pastDayCount));
      return _TimelineDay.fromDate(date, index: index, today: today);
    });
  }

  void _positionTodayAtTop() {
    if (!mounted || _hasPositionedToday) return;
    final todayContext = _todayKey.currentContext;
    if (todayContext == null) return;
    _hasPositionedToday = true;
    Scrollable.ensureVisible(
      todayContext,
      alignment: 0,
      duration: Duration.zero,
      curve: Curves.linear,
    );
  }

  @override
  Widget build(BuildContext context) {
    final days = _visibleDays();
    final bottomPadding =
        _navHeight +
        _navBottomMargin +
        _calendarToNavGap +
        MediaQuery.paddingOf(context).bottom;
    return _CosmicPage(
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final calendarHeight = constraints.maxHeight < 720 ? 246.0 : 258.0;
            return Stack(
              children: [
                Positioned(
                  left: _horizontalPadding,
                  right: _horizontalPadding,
                  top: _headerTop,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Timeline',
                        style: AppTextStyles.display(fontSize: 36),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Look back without turning it into a report.',
                        style: AppTextStyles.body(
                          fontSize: 14,
                          color: AppColors.shellstone.withValues(alpha: 0.72),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: _horizontalPadding,
                  right: _horizontalPadding,
                  top: _timelinePanelTop,
                  bottom: bottomPadding + calendarHeight + _sectionGap,
                  child: _TimelineScrollPanel(
                    child: ScrollbarTheme(
                      data: ScrollbarThemeData(
                        thumbColor: WidgetStatePropertyAll(
                          AppColors.quicksand.withValues(alpha: 0.42),
                        ),
                        trackColor: WidgetStatePropertyAll(
                          AppColors.shellstone.withValues(alpha: 0.08),
                        ),
                        trackBorderColor: WidgetStatePropertyAll(
                          AppColors.shellstone.withValues(alpha: 0.04),
                        ),
                        thickness: const WidgetStatePropertyAll(3),
                        radius: const Radius.circular(999),
                      ),
                      child: Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        interactive: true,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
                          child: Column(
                            children: [
                              for (int i = 0; i < days.length; i++) ...[
                                KeyedSubtree(
                                  key: days[i].isToday
                                      ? _todayKey
                                      : ValueKey<DateTime>(days[i].date),
                                  child: _TimelineRow(
                                    day: days[i],
                                    expanded:
                                        _expandedIndex == i && days[i].hasEntry,
                                    onTap: () =>
                                        setState(() => _expandedIndex = i),
                                  ),
                                ),
                                if (i != days.length - 1)
                                  const SizedBox(height: 12),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: _horizontalPadding,
                  right: _horizontalPadding,
                  bottom: bottomPadding,
                  height: calendarHeight,
                  child: const _MonthCalendarPreview(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}

class _TimelineScrollPanel extends StatelessWidget {
  const _TimelineScrollPanel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SolenneGlass(
      padding: EdgeInsets.zero,
      borderRadius: 24,
      child: child,
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final _TimelineDay day;
  final bool expanded;
  final VoidCallback onTap;

  const _TimelineRow({
    required this.day,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: day.hasEntry ? onTap : null,
      child: AnimatedContainer(
        duration: AppDurations.transition,
        curve: Curves.easeOut,
        padding: EdgeInsets.fromLTRB(14, 12, 14, expanded ? 16 : 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: expanded
                ? day.tint.withValues(alpha: 0.36)
                : AppColors.shellstone.withValues(alpha: 0.14),
          ),
          color: AppColors.royalBlue.withValues(alpha: expanded ? 0.28 : 0.14),
        ),
        child: Column(
          children: [
            Row(
              children: [
                SizedBox(
                  width: 78,
                  child: Text(
                    day.dateLabel,
                    style: AppTextStyles.mono(
                      fontSize: 11,
                      color: day.isToday
                          ? AppColors.quicksand.withValues(alpha: 0.9)
                          : AppColors.shellstone.withValues(alpha: 0.78),
                    ),
                  ),
                ),
                Icon(
                  day.hasEntry ? Icons.circle : Icons.circle_outlined,
                  size: day.isToday ? 15 : 13,
                  color: day.hasEntry
                      ? day.tint.withValues(alpha: 0.92)
                      : AppColors.shellstone.withValues(alpha: 0.52),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 20,
                    child: CustomPaint(
                      painter: _FingerprintLinePainter(
                        length: day.length,
                        color: day.hasEntry ? day.tint : AppColors.shellstone,
                        hasEntry: day.hasEntry,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: 16),
              _ExpandedDay(day: day),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExpandedDay extends StatelessWidget {
  final _TimelineDay day;

  const _ExpandedDay({required this.day});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 76,
          height: 86,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: RadialGradient(
              center: const Alignment(-0.4, -0.5),
              colors: [
                day.tint.withValues(alpha: 0.44),
                AppColors.sapphire.withValues(alpha: 0.22),
                AppColors.royalBlue.withValues(alpha: 0.1),
              ],
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                day.observation,
                style: AppTextStyles.body(
                  fontSize: 14,
                  color: AppColors.swanWing.withValues(alpha: 0.9),
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: day.tags.map((tag) => _Tag(label: tag)).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.headphones_rounded,
                    size: 16,
                    color: AppColors.quicksand.withValues(alpha: 0.76),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Listen back later',
                    style: AppTextStyles.mono(
                      fontSize: 10,
                      color: AppColors.quicksand.withValues(alpha: 0.76),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;

  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AppColors.sapphire.withValues(alpha: 0.14),
        border: Border.all(color: AppColors.shellstone.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        style: AppTextStyles.mono(
          fontSize: 9,
          color: AppColors.shellstone.withValues(alpha: 0.76),
        ),
      ),
    );
  }
}

class _MonthCalendarPreview extends StatefulWidget {
  const _MonthCalendarPreview();

  @override
  State<_MonthCalendarPreview> createState() => _MonthCalendarPreviewState();
}

class _MonthCalendarPreviewState extends State<_MonthCalendarPreview> {
  _CalendarMode _mode = _CalendarMode.monthly;
  late DateTime _visibleMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );
  late DateTime _visibleWeekFocus = _dateOnly(DateTime.now());

  void _changePeriod(int delta) {
    setState(() {
      if (_mode == _CalendarMode.monthly) {
        _visibleMonth = DateTime(
          _visibleMonth.year,
          _visibleMonth.month + delta,
        );
        return;
      }
      _visibleWeekFocus = _visibleWeekFocus.add(Duration(days: delta * 7));
    });
  }

  @override
  Widget build(BuildContext context) {
    final focusDate = _mode == _CalendarMode.monthly
        ? _focusDateForMonth(_visibleMonth)
        : _visibleWeekFocus;
    final weeks = _mode == _CalendarMode.monthly
        ? _monthPreviewWeeks(focusDate)
        : [_weekDays(focusDate)];
    final days = weeks.first;
    final title = _mode == _CalendarMode.monthly
        ? _months[_visibleMonth.month - 1]
        : 'Week';
    final trailingLabel = _mode == _CalendarMode.monthly
        ? '${focusDate.day}'
        : _weekRangeLabel(days);
    final activeYear = _mode == _CalendarMode.monthly
        ? _visibleMonth.year
        : focusDate.year;
    final activeMonth = _mode == _CalendarMode.monthly
        ? _visibleMonth.month
        : focusDate.month;
    return _Glass(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CalendarModeToggle(
                mode: _mode,
                onChanged: (mode) => setState(() => _mode = mode),
              ),
              const Spacer(),
              _RoundIcon(
                icon: Icons.chevron_left_rounded,
                onTap: () => _changePeriod(-1),
              ),
              const SizedBox(width: 8),
              _RoundIcon(
                icon: Icons.chevron_right_rounded,
                onTap: () => _changePeriod(1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.display(
                    fontSize: 36,
                    color: AppColors.swanWing.withValues(alpha: 0.9),
                  ),
                ),
              ),
              Text(
                trailingLabel,
                style: AppTextStyles.display(
                  fontSize: _mode == _CalendarMode.monthly ? 36 : 30,
                  color: AppColors.swanWing.withValues(alpha: 0.92),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final label in _weekdayLabels)
                Expanded(child: _CalendarWeekdayLabel(label: label)),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            children: [
              for (
                int weekIndex = 0;
                weekIndex < weeks.length;
                weekIndex++
              ) ...[
                Row(
                  children: [
                    for (final date in weeks[weekIndex])
                      Expanded(
                        child: _CalendarDateTile(
                          date: date,
                          inMonth:
                              date.year == activeYear &&
                              date.month == activeMonth,
                          today: _isSameDay(date, DateTime.now()),
                          marked: _hasDummyEntry(date),
                        ),
                      ),
                  ],
                ),
                if (weekIndex != weeks.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static DateTime _focusDateForMonth(DateTime month) {
    final today = DateTime.now();
    if (today.year == month.year && today.month == month.month) {
      return DateTime(today.year, today.month, today.day);
    }
    return DateTime(month.year, month.month);
  }

  static List<DateTime> _weekDays(DateTime focusDate) {
    final start = focusDate.subtract(Duration(days: focusDate.weekday % 7));
    return List.generate(7, (index) => start.add(Duration(days: index)));
  }

  static List<List<DateTime>> _monthPreviewWeeks(DateTime focusDate) {
    final firstWeek = _weekDays(focusDate);
    return [firstWeek, _weekDays(firstWeek.first.add(const Duration(days: 7)))];
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static bool _hasDummyEntry(DateTime date) {
    return (date.day + date.month + date.year) % 5 != 2;
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _weekRangeLabel(List<DateTime> days) {
    final start = days.first;
    final end = days.last;
    if (start.month == end.month) return '${start.day}-${end.day}';
    return '${start.day} ${_shortMonths[start.month - 1]}-${end.day} ${_shortMonths[end.month - 1]}';
  }
}

enum _CalendarMode { weekly, monthly }

class _CalendarModeToggle extends StatelessWidget {
  const _CalendarModeToggle({required this.mode, required this.onChanged});

  final _CalendarMode mode;
  final ValueChanged<_CalendarMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      width: 166,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: AppColors.sapphire.withValues(alpha: 0.16),
        border: Border.all(color: AppColors.shellstone.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _CalendarModeSegment(
              label: 'Weekly',
              selected: mode == _CalendarMode.weekly,
              onTap: () => onChanged(_CalendarMode.weekly),
            ),
          ),
          Expanded(
            child: _CalendarModeSegment(
              label: 'Monthly',
              selected: mode == _CalendarMode.monthly,
              onTap: () => onChanged(_CalendarMode.monthly),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarModeSegment extends StatelessWidget {
  const _CalendarModeSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.transition,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(9),
          color: selected
              ? AppColors.swanWing.withValues(alpha: 0.94)
              : Colors.transparent,
        ),
        child: Text(
          label,
          style: AppTextStyles.body(
            fontSize: 12,
            color: selected
                ? AppColors.royalBlue
                : AppColors.shellstone.withValues(alpha: 0.46),
          ),
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.sapphire.withValues(alpha: 0.16),
          border: Border.all(
            color: AppColors.shellstone.withValues(alpha: 0.16),
          ),
        ),
        child: Icon(
          icon,
          size: 16,
          color: AppColors.shellstone.withValues(alpha: 0.78),
        ),
      ),
    );
  }
}

class _CalendarDateTile extends StatelessWidget {
  const _CalendarDateTile({
    required this.date,
    required this.inMonth,
    required this.today,
    required this.marked,
  });

  final DateTime date;
  final bool inMonth;
  final bool today;
  final bool marked;

  @override
  Widget build(BuildContext context) {
    final isRecordedDay = marked && inMonth;
    final tileColor = today
        ? AppColors.swanWing.withValues(alpha: 0.96)
        : isRecordedDay
        ? AppColors.sapphire.withValues(alpha: 0.24)
        : Colors.transparent;
    final borderColor = today
        ? AppColors.swanWing.withValues(alpha: 0.76)
        : isRecordedDay
        ? AppColors.sapphire.withValues(alpha: 0.42)
        : Colors.transparent;
    final numberColor = today
        ? AppColors.royalBlue
        : isRecordedDay
        ? AppColors.swanWing.withValues(alpha: 0.92)
        : AppColors.shellstone.withValues(alpha: inMonth ? 0.82 : 0.26);

    return Column(
      children: [
        AnimatedContainer(
          duration: AppDurations.transition,
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: tileColor,
            border: Border.all(color: borderColor),
            boxShadow: today
                ? [
                    BoxShadow(
                      color: AppColors.sapphire.withValues(alpha: 0.4),
                      blurRadius: 18,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Text(
            '${date.day}',
            style: AppTextStyles.body(fontSize: 17, color: numberColor),
          ),
        ),
        const SizedBox(height: 7),
        AnimatedContainer(
          duration: AppDurations.transition,
          width: 3.5,
          height: 3.5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isRecordedDay
                ? AppColors.sapphire.withValues(alpha: today ? 0.0 : 0.86)
                : Colors.transparent,
          ),
        ),
      ],
    );
  }
}

class _CalendarWeekdayLabel extends StatelessWidget {
  const _CalendarWeekdayLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        label,
        style: AppTextStyles.mono(
          fontSize: 10,
          color: AppColors.shellstone.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

const _weekdayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

class _FingerprintLinePainter extends CustomPainter {
  final double length;
  final Color color;
  final bool hasEntry;

  const _FingerprintLinePainter({
    required this.length,
    required this.color,
    required this.hasEntry,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final endX = size.width * (hasEntry ? length : 0.22);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = hasEntry
          ? color.withValues(alpha: 0.72)
          : AppColors.shellstone.withValues(alpha: 0.34);
    canvas.drawLine(
      Offset.zero.translate(0, size.height / 2),
      Offset(endX, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(_FingerprintLinePainter oldDelegate) =>
      oldDelegate.length != length ||
      oldDelegate.color != color ||
      oldDelegate.hasEntry != hasEntry;
}

class _TimelineDay {
  final DateTime date;
  final String dateLabel;
  final bool hasEntry;
  final bool isToday;
  final double length;
  final Color tint;
  final String observation;
  final List<String> tags;

  const _TimelineDay({
    required this.date,
    required this.dateLabel,
    required this.hasEntry,
    required this.isToday,
    required this.length,
    required this.tint,
    required this.observation,
    required this.tags,
  });

  factory _TimelineDay.fromDate(
    DateTime date, {
    required int index,
    required DateTime today,
  }) {
    final hasEntry = (date.day + date.month + date.year) % 5 != 2;
    final palette = [
      AppColors.quicksand,
      AppColors.shellstone,
      AppColors.sapphire,
    ];
    final observations = [
      'A small signal sits here, waiting for a future entry.',
      'This day has a softer shape in the pattern.',
      'A future reflection can live here when you return.',
      'There is room here for what the day becomes.',
    ];
    final tagSets = [
      ['sleep', 'work', 'uncertainty'],
      ['family', 'rest', 'something good'],
      ['plans', 'change', 'timing'],
      ['quiet', 'voice', 'noted'],
    ];
    return _TimelineDay(
      date: date,
      dateLabel: _dateLabel(date, today),
      hasEntry: hasEntry,
      isToday: _sameDay(date, today),
      length: 0.38 + ((date.day * 17 + date.month * 3) % 52) / 100,
      tint: palette[(date.day + index) % palette.length],
      observation: observations[(date.day + date.month) % observations.length],
      tags: tagSets[(date.day + index) % tagSets.length],
    );
  }

  static String _dateLabel(DateTime date, DateTime today) {
    if (_sameDay(date, today)) return 'Today';
    return '${date.day} ${_months[date.month - 1]}';
  }

  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const _shortMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

class _CosmicPage extends StatelessWidget {
  final Widget child;

  const _CosmicPage({required this.child});

  @override
  Widget build(BuildContext context) {
    return SolenneBackground(child: child);
  }
}

class _Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _Glass({required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return SolenneGlass(padding: padding, borderRadius: 22, child: child);
  }
}
