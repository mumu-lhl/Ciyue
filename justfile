build_runner:
    dart run build_runner build --delete-conflicting-outputs

make-migrations:
    dart run drift_dev make-migrations

icon:
    dart run flutter_launcher_icons:main

count-codes:
    tokei lib/ -e "*.g.dart" -e "*.steps.dart" -e "app_localizations*.dart"

update-flutter-version version:
    dart run tools/update_flutter_version.dart {{version}}

build-appimage:
    ./tools/build_appimage.sh

build-rpm:
    ./tools/build_rpm.sh

build-deb:
    ./tools/build_deb.sh

generate-changelog version:
    git cliff --tag {{version}} --ignore-tags ".*-.*" -o
