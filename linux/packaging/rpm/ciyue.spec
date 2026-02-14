Name:           ciyue
Version:        @VERSION@
Release:        @RELEASE@
Summary:        A simple mdict dictionary
License:        MIT
URL:            https://github.com/mumu-lhl/Ciyue

%description
A simple mdict dictionary with Android/Windows/Linux support.
Multi-dictionary support, AI integration, and Material You design.

%install
mkdir -p %{buildroot}/usr/bin
mkdir -p %{buildroot}/opt/%{name}
cp -r @BUNDLE_DIR@/* %{buildroot}/opt/%{name}/
ln -s /opt/%{name}/%{name} %{buildroot}/usr/bin/%{name}

# Desktop file
mkdir -p %{buildroot}/usr/share/applications
cp @DESKTOP_FILE@ %{buildroot}/usr/share/applications/

# Icon
mkdir -p %{buildroot}/usr/share/icons/hicolor/256x256/apps
cp @ICON_PATH@ %{buildroot}/usr/share/icons/hicolor/256x256/apps/%{name}.png

# Metainfo
mkdir -p %{buildroot}/usr/share/metainfo
cp @METAINFO_FILE@ %{buildroot}/usr/share/metainfo/org.eu.mumulhl.ciyue.appdata.xml

%files
/opt/%{name}/
/usr/bin/%{name}
/usr/share/applications/org.eu.mumulhl.ciyue.desktop
/usr/share/icons/hicolor/256x256/apps/%{name}.png
/usr/share/metainfo/org.eu.mumulhl.ciyue.appdata.xml

%changelog
* @DATE@ Ciyue Maintainers - @VERSION@-@RELEASE@
- Automated RPM build
