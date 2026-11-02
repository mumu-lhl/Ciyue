import "package:ciyue/core/localization_delegates.dart";
import "package:ciyue/src/generated/i18n/app_localizations.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";

void main() {
  testWidgets("Material widgets survive a locale Flutter does not translate", (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale("got"),
        localizationsDelegates: [
          AppLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
          const FallbackMaterialLocalizationsDelegate(),
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: MaterialUiCompatibilityBridge(
          child: Scaffold(
            appBar: AppBar(
              leading: const BackButton(),
              title: const Text("title"),
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: 0,
              onDestinationSelected: (_) {},
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home), label: "home"),
                NavigationDestination(
                  icon: Icon(Icons.book),
                  label: "word book",
                ),
              ],
            ),
            body: const Text("body"),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    // Flutter reports that not every delegate knows the locale, which is
    // true for every language the app ships and harmless.
    tester.takeException();

    // Without a fallback for the locales Flutter does not translate, the
    // widgets that need MaterialLocalizations fail to build and the app
    // shows an empty box where they are.
    expect(find.byType(ErrorWidget), findsNothing);
    expect(find.text("title"), findsOneWidget);
    expect(find.text("body"), findsOneWidget);
  });
}
