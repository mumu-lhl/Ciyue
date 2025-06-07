build_runner:
    flutter pub run build_runner build

make-migrations:
    flutter pub run drift_dev make-migrations

icon:
    flutter pub run flutter_launcher_icons:main

count-codes:
    tokei lib/ -e "*.g.dart" -e "*.steps.dart" -e "app_localizations*.dart"