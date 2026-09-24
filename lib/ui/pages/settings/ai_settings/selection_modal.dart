import "package:material_ui/material_ui.dart";

void showSelectionModal<T>({
  required BuildContext context,
  required String title,
  required List<T> items,
  required T? currentItem,
  required String Function(T) itemText,
  required void Function(T) onItemSelected,
  String? searchHint,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.8,
      widthFactor: 0.9,
      child: SafeArea(
        child: _SelectionModalContent<T>(
          title: title,
          items: items,
          currentItem: currentItem,
          itemText: itemText,
          onItemSelected: onItemSelected,
          searchHint: searchHint,
        ),
      ),
    ),
  );
}

class _SelectionModalContent<T> extends StatefulWidget {
  final String title;
  final List<T> items;
  final T? currentItem;
  final String Function(T) itemText;
  final void Function(T) onItemSelected;
  final String? searchHint;

  const _SelectionModalContent({
    required this.title,
    required this.items,
    required this.currentItem,
    required this.itemText,
    required this.onItemSelected,
    this.searchHint,
  });

  @override
  State<_SelectionModalContent<T>> createState() =>
      _SelectionModalContentState<T>();
}

class _SelectionModalContentState<T> extends State<_SelectionModalContent<T>> {
  String _searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final query = _searchQuery.trim().toLowerCase();
    final filteredItems = query.isEmpty
        ? widget.items
        : widget.items.where((item) {
            return widget.itemText(item).toLowerCase().contains(query);
          }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
          child: Text(
            widget.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (widget.items.length > 5)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: widget.searchHint ?? "Search",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                isDense: true,
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
            ),
          ),
        const Divider(height: 1),
        Expanded(
          child: filteredItems.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      "No matching items",
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    return ListTile(
                      title: Text(widget.itemText(item)),
                      trailing: item == widget.currentItem
                          ? const Icon(Icons.check)
                          : null,
                      onTap: () {
                        widget.onItemSelected(item);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
