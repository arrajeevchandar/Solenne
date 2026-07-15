import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/journals/journal_day.dart';
import '../../features/journals/journal_repository.dart';
import '../../theme/app_theme.dart';
import '../journals/journal_day_navigation.dart';

class TimelineScreen extends ConsumerStatefulWidget {
  const TimelineScreen({super.key});

  @override
  ConsumerState<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends ConsumerState<TimelineScreen> {
  static const int _pastDayCount = 120;

  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final today = _dateOnly(DateTime.now());
    final start = today.subtract(const Duration(days: _pastDayCount));
    final end = today.add(const Duration(days: 1));
    final state = ref.watch(
      journalRangeStreamProvider(JournalDateRange(start: start, end: end)),
    );

    return SolenneBackground(
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final calendarHeight = constraints.maxHeight < 720 ? 246.0 : 258.0;
            final timelineHeight = math.max(
              190.0,
              constraints.maxHeight - calendarHeight - 210,
            );
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 106),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Timeline', style: AppTextStyles.display(fontSize: 36)),
                  const SizedBox(height: 4),
                  Text(
                    'Look back without turning it into a report.',
                    style: AppTextStyles.body(
                      fontSize: 14,
                      color: AppColors.shellstone.withValues(alpha: 0.72),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: timelineHeight,
                    child: state.when(
                      loading: () => const _TimelineState(
                        loading: true,
                        message: 'Gathering your recorded days…',
                      ),
                      error: (_, _) => const _TimelineState(
                        message: 'Your timeline could not be reached.',
                      ),
                      data: (entries) {
                        final groups = groupJournalEntries(entries);
                        final byKey = {
                          for (final group in groups) group.key: group,
                        };
                        final days = List.generate(_pastDayCount + 1, (index) {
                          final date = today.subtract(Duration(days: index));
                          return _TimelineDay.fromDate(
                            date,
                            today: today,
                            journalDay: byKey[journalDateKey(date)],
                          );
                        });
                        return _TimelinePanel(
                          controller: _scrollController,
                          days: days,
                          onOpenDay: (day) => openJournalDay(context, day),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: calendarHeight,
                    child: state.when(
                      loading: () => const _TimelineState(
                        loading: true,
                        message: 'Preparing the calendar…',
                      ),
                      error: (_, _) => const _TimelineState(
                        message: 'The calendar could not be reached.',
                      ),
                      data: (entries) {
                        final byKey = {
                          for (final group in groupJournalEntries(entries))
                            group.key: group,
                        };
                        return _MonthCalendarPreview(
                          journalDays: byKey,
                          minimumDate: start,
                          maximumDate: today,
                          onOpenDay: (day) => openJournalDay(context, day),
                        );
                      },
                    ),
                  ),
                ],
              ),
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

class _TimelineState extends StatelessWidget {
  const _TimelineState({required this.message, this.loading = false});

  final String message;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SolenneGlass(
      padding: const EdgeInsets.all(20),
      borderRadius: 24,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 1.3,
                  color: AppColors.quicksand.withValues(alpha: 0.7),
                ),
              )
            else
              Icon(
                Icons.cloud_off_outlined,
                color: AppColors.quicksand.withValues(alpha: 0.68),
              ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(
                fontSize: 12,
                color: AppColors.shellstone.withValues(alpha: 0.68),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelinePanel extends StatelessWidget {
  const _TimelinePanel({
    required this.controller,
    required this.days,
    required this.onOpenDay,
  });

  final ScrollController controller;
  final List<_TimelineDay> days;
  final ValueChanged<JournalDay> onOpenDay;

  @override
  Widget build(BuildContext context) {
    return SolenneGlass(
      padding: EdgeInsets.zero,
      borderRadius: 24,
      child: ScrollbarTheme(
        data: ScrollbarThemeData(
          thumbColor: WidgetStatePropertyAll(
            AppColors.quicksand.withValues(alpha: 0.42),
          ),
          trackColor: WidgetStatePropertyAll(
            AppColors.shellstone.withValues(alpha: 0.08),
          ),
          thickness: const WidgetStatePropertyAll(3),
          radius: const Radius.circular(999),
        ),
        child: Scrollbar(
          controller: controller,
          thumbVisibility: true,
          interactive: true,
          child: ListView.separated(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(12, 12, 16, 12),
            itemCount: days.length,
            separatorBuilder: (_, _) => const SizedBox(height: 9),
            itemBuilder: (context, index) {
              final day = days[index];
              return KeyedSubtree(
                key: ValueKey(day.date),
                child: _TimelineRow(
                  day: day,
                  onTap: day.journalDay == null
                      ? null
                      : () => onOpenDay(day.journalDay!),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.day, required this.onTap});

  final _TimelineDay day;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.transition,
        padding: EdgeInsets.fromLTRB(14, 11, 14, day.hasEntry ? 13 : 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(19),
          border: Border.all(
            color: day.hasEntry
                ? day.tint.withValues(alpha: 0.3)
                : AppColors.shellstone.withValues(alpha: 0.09),
          ),
          color: AppColors.royalBlue.withValues(
            alpha: day.hasEntry ? 0.24 : 0.1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 78,
                  child: Text(
                    day.dateLabel,
                    style: AppTextStyles.mono(
                      fontSize: 10,
                      color: day.isToday
                          ? AppColors.quicksand.withValues(alpha: 0.92)
                          : AppColors.shellstone.withValues(alpha: 0.72),
                    ),
                  ),
                ),
                Icon(
                  day.hasEntry ? Icons.circle : Icons.circle_outlined,
                  size: day.isToday ? 14 : 12,
                  color: day.hasEntry
                      ? day.tint.withValues(alpha: 0.92)
                      : AppColors.shellstone.withValues(alpha: 0.34),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 18,
                    child: CustomPaint(
                      painter: _FingerprintLinePainter(
                        length: day.length,
                        color: day.tint,
                        hasEntry: day.hasEntry,
                      ),
                    ),
                  ),
                ),
                if (day.hasEntry) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 15,
                    color: AppColors.quicksand.withValues(alpha: 0.62),
                  ),
                ],
              ],
            ),
            if (day.hasEntry) ...[
              const SizedBox(height: 9),
              Padding(
                padding: const EdgeInsets.only(left: 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      day.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.body(
                        fontSize: 12,
                        color: AppColors.swanWing.withValues(alpha: 0.88),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      day.detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.mono(
                        fontSize: 7,
                        color: AppColors.shellstone.withValues(alpha: 0.48),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MonthCalendarPreview extends StatefulWidget {
  const _MonthCalendarPreview({
    required this.journalDays,
    required this.minimumDate,
    required this.maximumDate,
    required this.onOpenDay,
  });

  final Map<String, JournalDay> journalDays;
  final DateTime minimumDate;
  final DateTime maximumDate;
  final ValueChanged<JournalDay> onOpenDay;

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
        final candidate = DateTime(
          _visibleMonth.year,
          _visibleMonth.month + delta,
        );
        final minimumMonth = DateTime(
          widget.minimumDate.year,
          widget.minimumDate.month,
        );
        final maximumMonth = DateTime(
          widget.maximumDate.year,
          widget.maximumDate.month,
        );
        if (candidate.isBefore(minimumMonth) ||
            candidate.isAfter(maximumMonth)) {
          return;
        }
        _visibleMonth = candidate;
        return;
      }
      final candidate = _visibleWeekFocus.add(Duration(days: delta * 7));
      if (candidate.isBefore(widget.minimumDate) ||
          candidate.isAfter(widget.maximumDate)) {
        return;
      }
      _visibleWeekFocus = candidate;
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
    final trailing = _mode == _CalendarMode.monthly
        ? '${focusDate.day}'
        : _weekRangeLabel(days);

    return SolenneGlass(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      borderRadius: 22,
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
                trailing,
                style: AppTextStyles.display(
                  fontSize: _mode == _CalendarMode.monthly ? 36 : 29,
                  color: AppColors.swanWing.withValues(alpha: 0.92),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final label in _weekdayLabels)
                Expanded(child: _CalendarWeekdayLabel(label: label)),
            ],
          ),
          const SizedBox(height: 7),
          for (int weekIndex = 0; weekIndex < weeks.length; weekIndex++) ...[
            Row(
              children: [
                for (final date in weeks[weekIndex])
                  Expanded(
                    child: _CalendarDateTile(
                      date: date,
                      inMonth:
                          _mode == _CalendarMode.weekly ||
                          date.month == focusDate.month,
                      today: _sameDay(date, DateTime.now()),
                      journalDay: widget.journalDays[journalDateKey(date)],
                      onOpenDay: widget.onOpenDay,
                    ),
                  ),
              ],
            ),
            if (weekIndex != weeks.length - 1) const SizedBox(height: 7),
          ],
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

  static bool _sameDay(DateTime a, DateTime b) {
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
    required this.journalDay,
    required this.onOpenDay,
  });

  final DateTime date;
  final bool inMonth;
  final bool today;
  final JournalDay? journalDay;
  final ValueChanged<JournalDay> onOpenDay;

  @override
  Widget build(BuildContext context) {
    final recorded = journalDay != null && inMonth;
    final tileColor = today
        ? AppColors.swanWing.withValues(alpha: 0.96)
        : recorded
        ? AppColors.sapphire.withValues(alpha: 0.24)
        : Colors.transparent;
    final numberColor = today
        ? AppColors.royalBlue
        : recorded
        ? AppColors.swanWing.withValues(alpha: 0.92)
        : AppColors.shellstone.withValues(alpha: inMonth ? 0.82 : 0.26);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: recorded ? () => onOpenDay(journalDay!) : null,
      child: Column(
        children: [
          AnimatedContainer(
            duration: AppDurations.transition,
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: tileColor,
              border: Border.all(
                color: today
                    ? AppColors.swanWing.withValues(alpha: 0.76)
                    : recorded
                    ? AppColors.sapphire.withValues(alpha: 0.42)
                    : Colors.transparent,
              ),
            ),
            child: Text(
              '${date.day}',
              style: AppTextStyles.body(fontSize: 17, color: numberColor),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 3.5,
            height: 3.5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: recorded && !today
                  ? AppColors.quicksand.withValues(alpha: 0.84)
                  : Colors.transparent,
            ),
          ),
        ],
      ),
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

class _FingerprintLinePainter extends CustomPainter {
  const _FingerprintLinePainter({
    required this.length,
    required this.color,
    required this.hasEntry,
  });

  final double length;
  final Color color;
  final bool hasEntry;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = hasEntry
          ? color.withValues(alpha: 0.72)
          : AppColors.shellstone.withValues(alpha: 0.26);
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width * (hasEntry ? length : 0.22), size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(_FingerprintLinePainter oldDelegate) {
    return oldDelegate.length != length ||
        oldDelegate.color != color ||
        oldDelegate.hasEntry != hasEntry;
  }
}

class _TimelineDay {
  const _TimelineDay({
    required this.date,
    required this.dateLabel,
    required this.isToday,
    required this.journalDay,
    required this.length,
    required this.tint,
    required this.title,
    required this.detail,
  });

  final DateTime date;
  final String dateLabel;
  final bool isToday;
  final JournalDay? journalDay;
  final double length;
  final Color tint;
  final String title;
  final String detail;

  bool get hasEntry => journalDay != null;

  factory _TimelineDay.fromDate(
    DateTime date, {
    required DateTime today,
    required JournalDay? journalDay,
  }) {
    final entry = journalDay?.latestEntry;
    final insight = entry?.aiInsights.isNotEmpty == true
        ? entry!.aiInsights.first
        : null;
    final confidence = insight?.confidence.clamp(0.0, 1.0) ?? 0.0;
    final palette = [
      AppColors.quicksand,
      AppColors.shellstone,
      AppColors.sapphire,
    ];
    final details = <String>[
      if (journalDay != null && journalDay.entryCount > 1)
        '${journalDay.entryCount} entries',
      if (entry?.moodLabel?.trim().isNotEmpty == true)
        entry!.moodLabel!.trim()
      else if (insight?.moodLabel.trim().isNotEmpty == true)
        insight!.moodLabel.trim(),
      if (insight?.dayThemes.isNotEmpty == true) insight!.dayThemes.first,
    ];
    return _TimelineDay(
      date: date,
      dateLabel: _sameDay(date, today)
          ? 'Today'
          : '${date.day} ${_shortMonths[date.month - 1]}',
      isToday: _sameDay(date, today),
      journalDay: journalDay,
      length: journalDay == null
          ? 0.22
          : (0.46 + confidence * 0.44).clamp(0.46, 0.9),
      tint: palette[(date.day + date.month) % palette.length],
      title: insight?.title.trim().isNotEmpty == true
          ? insight!.title
          : entry?.displayTitle ?? '',
      detail: details.isEmpty ? 'Saved reflection' : details.join('  ·  '),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

const _weekdayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

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
