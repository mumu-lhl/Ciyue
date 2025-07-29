import "package:ciyue/services/translation.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:flutter/material.dart";

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
          .where((entry) =>
              entry.value.toLowerCase().contains(query.toLowerCase()))
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            onChanged: _filterLanguages,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.searchLanguage,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _filteredLanguages.length,
            itemBuilder: (context, index) {
              final entry = _filteredLanguages[index];
              final isSelected = entry.key == widget.selectedLanguage;
              return ListTile(
                title: Text(getLanguageName(entry.key) == "Auto Detect"
                    ? AppLocalizations.of(context)!.autoDetect
                    : getLanguageName(entry.key)),
                trailing: isSelected ? const Icon(Icons.check) : null,
                onTap: () => widget.onLanguageSelected(entry.key),
              );
            },
          ),
        ),
      ],
    );
  }
}
