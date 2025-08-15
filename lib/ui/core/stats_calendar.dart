import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/viewModels/stats_view_model.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "package:table_calendar/table_calendar.dart";

class StatsCalendar<T extends StatsViewModel> extends StatelessWidget {
  const StatsCalendar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<T>(
      builder: (context, viewModel, child) {
        if (viewModel.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        Widget? dayBuilder(context, day, focusedDay) {
          final wordCount = viewModel.getEventsForDay(day).first;
          if (wordCount > 0) {
            final color = Theme.of(context).colorScheme.primary;
            final opacity =
                (wordCount / viewModel.maxItemsInFocusedMonth).clamp(0.1, 1.0);
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              decoration: BoxDecoration(
                color: color.withAlpha((255 * opacity).toInt()),
                shape: BoxShape.circle,
              ),
              margin: const EdgeInsets.all(6.0),
              child: Center(
                child: Text(
                  "${day.day}",
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                ),
              ),
            );
          }
          return null;
        }

        return TableCalendar(
          firstDay: DateTime.utc(2024, 8, 15),
          lastDay: DateTime.utc(2077, 12, 31),
          focusedDay: viewModel.focusedDay,
          eventLoader: (day) {
            final events = viewModel.getEventsForDay(day);
            return events.where((event) => event > 0).toList();
          },
          onPageChanged: viewModel.onPageChanged,
          availableCalendarFormats: {
            CalendarFormat.month: AppLocalizations.of(context)!.month
          },
          calendarStyle: const CalendarStyle(
            todayDecoration: BoxDecoration(),
            defaultTextStyle: TextStyle(fontWeight: FontWeight.bold),
            weekendTextStyle: TextStyle(fontWeight: FontWeight.bold),
          ),
          calendarBuilders: CalendarBuilders(
            todayBuilder: dayBuilder,
            defaultBuilder: dayBuilder,
            markerBuilder: (context, day, events) {
              if (events.isEmpty) return null;

              return Positioned(
                right: 1,
                bottom: 1,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.secondary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 12,
                    minHeight: 12,
                  ),
                  child: Text(
                    "${events.first}",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSecondary,
                      fontSize: 11,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            },
            headerTitleBuilder: (context, day) {
              return GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: day,
                    firstDate: DateTime.utc(2024, 8, 15),
                    lastDate: DateTime.utc(2077, 12, 31),
                    initialDatePickerMode: DatePickerMode.year,
                  );
                  viewModel.onDatePicked(picked);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "${day.year} - ${day.month}",
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "${viewModel.itemsInFocusedMonth}",
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSecondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
