import "package:ciyue/viewModels/wordbook.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "dialogs.dart";

class WordbookFloatingActionButtons extends StatelessWidget {
  const WordbookFloatingActionButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final wordbookModel = context.watch<WordbookModel>();

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton(
          heroTag: "search",
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) {
                return const SearchWordDialog();
              },
            );
          },
          child: const Icon(Icons.search),
        ),
        const SizedBox(height: 8),
        if (wordbookModel.selectedDate != null)
          FloatingActionButton(
            heroTag: "clear_date",
            onPressed: () {
              wordbookModel.selectedDate = null;
              wordbookModel.updateWordList();
            },
            child: const Icon(Icons.clear),
          ),
        const SizedBox(height: 8),
        FloatingActionButton(
          heroTag: "calendar",
          onPressed: () async {
            final DateTime? picked = await showDialog(
              context: context,
              builder: (BuildContext context) {
                return const MonthPickerDialog();
              },
            );
            if (picked != null) {
              if (context.mounted) {
                wordbookModel.selectedDate = picked;
                wordbookModel.updateWordList();
              }
            }
          },
          child: const Icon(Icons.calendar_month),
        ),
      ],
    );
  }
}
