build_runner:
    dart run build_runner build --delete-conflicting-outputs

make-migrations:
    dart run drift_dev make-migrations

icon:
    dart run flutter_launcher_icons:main

count-codes:
    tokei lib/ -e "*.g.dart" -e "*.steps.dart" -e "app_localizations*.dart"

build-appimage:
    ./tools/build_appimage.sh
