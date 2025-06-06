import "package:flutter/material.dart";
import "package:intl/intl.dart";

class DateDivider extends StatelessWidget {
  final DateTime date;

  const DateDivider({super.key, required this.date});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat("yyyy-MM-dd").format(date),
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context)
                      .colorScheme
                      .secondary
                      .withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: Divider(
              color: Theme.of(context)
                  .colorScheme
                  .secondary
                  .withValues(alpha: 0.5),
              thickness: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
