import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:ciyue/ui/core/changelog_dialog.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";

const _sample = """
---
## [2.0.0-beta.1](https://github.com/mumu-lhl/Ciyue/compare/v1.23.2..v2.0.0-beta.1) - 2026-10-17

### Features

- **Multi-source translation** - many sources at once

---
## [1.23.2](https://github.com/mumu-lhl/Ciyue/compare/v1.23.1..1.23.2) - 2026-09-19

### Bug Fixes

- **(android)** stabilize floating window - ([48dd2f4](https://github.com/mumu-lhl/Ciyue/commit/48dd2f43f2ffc1de0318808b367bc1868b1b2319)) - Mumulhl
""";

Future<void> _pumpDialog(WidgetTester tester, {required bool latestOnly}) {
  return tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ChangelogDialog(
            changelogContent: _sample,
            latestOnly: latestOnly,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets("popup shows only the newest version, with its date", (
    tester,
  ) async {
    await _pumpDialog(tester, latestOnly: true);
    await tester.pumpAndSettle();

    expect(
      find.textContaining("2.0.0-beta.1 · 2026-10-17", findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining("Multi-source translation", findRichText: true),
      findsWidgets,
    );
    expect(
      find.textContaining("stabilize floating window", findRichText: true),
      findsNothing,
    );
  });

  testWidgets("full view groups by version and cleans commit tails", (
    tester,
  ) async {
    await _pumpDialog(tester, latestOnly: false);
    await tester.pumpAndSettle();

    expect(find.text("2.0.0-beta.1"), findsOneWidget);
    expect(find.text("1.23.2"), findsOneWidget);
    expect(
      find.textContaining("Multi-source translation", findRichText: true),
      findsWidgets,
    );
    // The old version is collapsed by default; expand it and the entry
    // shows without its commit hash / author tail.
    await tester.tap(find.text("1.23.2"));
    await tester.pumpAndSettle();
    expect(
      find.textContaining("stabilize floating window", findRichText: true),
      findsWidgets,
    );
    expect(find.textContaining("48dd2f4", findRichText: true), findsNothing);
    expect(find.textContaining("Mumulhl", findRichText: true), findsNothing);
  });
}
