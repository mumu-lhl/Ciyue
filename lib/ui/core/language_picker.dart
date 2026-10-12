import "package:ciyue/services/translation.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:material_ui/material_ui.dart";

class LanguagePicker extends StatefulWidget {
  const LanguagePicker({
    super.key,
    required this.selectedLanguage,
    required this.onLanguageSelected,
    required this.isSource,
  });

  final String selectedLanguage;
  final ValueChanged<String> onLanguageSelected;
  final bool isSource;

  @override
  State<LanguagePicker> createState() => _LanguagePickerState();
}

class _LanguagePickerState extends State<LanguagePicker> {
  late final TextEditingController _searchController;
  late List<MapEntry<String, String>> _filteredLanguages;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _filteredLanguages = languageMap.entries.toList();
    if (!widget.isSource) {
      _filteredLanguages.removeWhere((entry) => entry.key == "auto");
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterLanguages(String query) {
    setState(() {
      _filteredLanguages = languageMap.entries
          .where(
            (entry) => entry.value.toLowerCase().contains(query.toLowerCase()),
          )
          .toList();
      if (!widget.isSource) {
        _filteredLanguages.removeWhere((entry) => entry.key == "auto");
      }
    });
  }

  String getLanguageName(String code) {
    return languageMap[code] ?? code;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            children: [
              Text(
                l10n.searchLanguage,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: TextField(
            controller: _searchController,
            onChanged: _filterLanguages,
            decoration: InputDecoration(
              hintText: l10n.search,
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            itemCount: _filteredLanguages.length,
            separatorBuilder: (context, index) => const SizedBox(height: 2),
            itemBuilder: (context, index) {
              final entry = _filteredLanguages[index];
              final isSelected = entry.key == widget.selectedLanguage;
              final displayName = getLanguageName(entry.key) == "Auto Detect"
                  ? l10n.autoDetect
                  : getLanguageName(entry.key);

              return ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                selected: isSelected,
                selectedTileColor: theme.colorScheme.primaryContainer
                    .withValues(alpha: 0.4),
                title: Text(
                  displayName,
                  style: TextStyle(
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isSelected ? theme.colorScheme.primary : null,
                  ),
                ),
                trailing: isSelected
                    ? Icon(
                        Icons.check_circle_rounded,
                        color: theme.colorScheme.primary,
                        size: 20,
                      )
                    : null,
                onTap: () => widget.onLanguageSelected(entry.key),
              );
            },
          ),
        ),
      ],
    );
  }
}
