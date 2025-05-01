import "package:flutter/material.dart";

class SardinianlLocalizationDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const SardinianlLocalizationDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == "sc";

  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    return const DefaultMaterialLocalizations();
  }

  @override
  bool shouldReload(SardinianlLocalizationDelegate old) => false;
}
