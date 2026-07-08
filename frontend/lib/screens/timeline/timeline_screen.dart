import 'dart:math' as math;
import 'dart:ui' as ui;

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
  static const double _sectionGap = 4;
  static const double _horizontalPadding = 20;
  static const double _headerTop = 20;
  static const double _timelinePanelTop = 102;

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
            const calendarHeight = 190.0;
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.shellstone.withValues(alpha: 0.16),
            ),
            color: AppColors.royalBlue.withValues(alpha: 0.15),
          ),
          child: child,
        ),
      ),
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
        color: AppColors.quicksand.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.quicksand.withValues(alpha: 0.18)),
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
  late DateTime _visibleMonth = DateTime(
    DateTime.now().year,
    DateTime.now().month,
  );

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final days = _calendarDays(_visibleMonth);
    return _Glass(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _monthLabel(_visibleMonth),
                  style: AppTextStyles.body(
                    fontSize: 14.5,
                    color: AppColors.swanWing.withValues(alpha: 0.9),
                  ),
                ),
              ),
              _RoundIcon(
                icon: Icons.chevron_left_rounded,
                onTap: () => _changeMonth(-1),
              ),
              const SizedBox(width: 8),
              _RoundIcon(
                icon: Icons.chevron_right_rounded,
                onTap: () => _changeMonth(1),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: const [
              'M',
              'T',
              'W',
              'T',
              'F',
              'S',
              'S',
            ].map((label) => Expanded(child: _Weekday(label))).toList(),
          ),
          const SizedBox(height: 4),
          Column(
            children: [
              for (int week = 0; week < 6; week++) ...[
                Row(
                  children: [
                    for (int weekday = 0; weekday < 7; weekday++)
                      Expanded(
                        child: SizedBox(
                          height: 18,
                          child: _CalendarCell(
                            date: days[(week * 7) + weekday],
                            inMonth:
                                days[(week * 7) + weekday].month ==
                                _visibleMonth.month,
                            today: _isSameDay(
                              days[(week * 7) + weekday],
                              DateTime.now(),
                            ),
                            marked: _hasDummyEntry(days[(week * 7) + weekday]),
                          ),
                        ),
                      ),
                  ],
                ),
                if (week != 5) const SizedBox(height: 3),
              ],
            ],
          ),
        ],
      ),
    );
  }

  static List<DateTime> _calendarDays(DateTime month) {
    final first = DateTime(month.year, month.month);
    final start = first.subtract(Duration(days: first.weekday - 1));
    return List.generate(42, (index) => start.add(Duration(days: index)));
  }

  static bool _hasDummyEntry(DateTime date) {
    return (date.day + date.month + date.year) % 5 != 2;
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _monthLabel(DateTime date) {
    return '${_months[date.month - 1]} ${date.year}';
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

class _Weekday extends StatelessWidget {
  const _Weekday(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: TextAlign.center,
      style: AppTextStyles.mono(
        fontSize: 8,
        color: AppColors.shellstone.withValues(alpha: 0.46),
      ),
    );
  }
}

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({
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
    final tint = Color.lerp(
      AppColors.sapphire,
      AppColors.quicksand,
      (date.day % 7) / 7,
    )!;
    return Center(
      child: SizedBox.square(
        dimension: 18,
        child: AnimatedContainer(
          duration: AppDurations.transition,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: today
                ? AppColors.quicksand.withValues(alpha: 0.24)
                : marked && inMonth
                ? tint.withValues(alpha: 0.17)
                : Colors.transparent,
            border: Border.all(
              color: today
                  ? AppColors.quicksand.withValues(alpha: 0.58)
                  : marked && inMonth
                  ? tint.withValues(alpha: 0.24)
                  : AppColors.shellstone.withValues(
                      alpha: inMonth ? 0.12 : 0.05,
                    ),
            ),
          ),
          child: Text(
            '${date.day}',
            style: AppTextStyles.mono(
              fontSize: 8,
              color: today
                  ? AppColors.quicksand.withValues(alpha: 0.95)
                  : inMonth
                  ? AppColors.shellstone.withValues(alpha: 0.72)
                  : AppColors.shellstone.withValues(alpha: 0.22),
            ),
          ),
        ),
      ),
    );
  }
}

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

class _CosmicPage extends StatelessWidget {
  final Widget child;

  const _CosmicPage({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF071127), Color(0xFF0D2147), Color(0xFF143765)],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _SkyDustPainter())),
          child,
        ],
      ),
    );
  }
}

class _Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _Glass({required this.child, this.padding = const EdgeInsets.all(16)});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.shellstone.withValues(alpha: 0.18),
            ),
            color: AppColors.royalBlue.withValues(alpha: 0.2),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _SkyDustPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(17);
    for (int i = 0; i < 120; i++) {
      canvas.drawCircle(
        Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        ),
        0.25 + random.nextDouble() * 0.7,
        Paint()
          ..color = AppColors.shellstone.withValues(
            alpha: 0.06 + random.nextDouble() * 0.15,
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
