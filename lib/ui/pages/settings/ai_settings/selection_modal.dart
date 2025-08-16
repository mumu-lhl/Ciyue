import "package:flutter/material.dart";

void showSelectionModal<T>({
  required BuildContext context,
  required String title,
  required List<T> items,
  required T currentItem,
  required String Function(T) itemText,
  required void Function(T) onItemSelected,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.8,
      widthFactor: 0.9,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  return ListTile(
                    title: Text(itemText(item)),
                    trailing:
                        item == currentItem ? const Icon(Icons.check) : null,
                    onTap: () {
                      onItemSelected(item);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
