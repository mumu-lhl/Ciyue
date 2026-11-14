; The installer version is injected by the build from pubspec.yaml (see
; .github/workflows/windows-build.yml). Never hard-code it here: a stale
; AppVersion ends up in the uninstall registry and in upgrade checks.
; For a manual build, parse the version from pubspec.yaml and pass it with
; ISCC.exe /DMyAppVersion=<version>.
#ifndef MyAppVersion
  #error MyAppVersion is undefined. Pass the app version from pubspec.yaml via ISCC.exe /DMyAppVersion=<version>
#endif

[Setup]
AppName=Ciyue
AppVersion={#MyAppVersion}
AppPublisher=Mumulhl
DefaultDirName={autopf}\Ciyue
DefaultGroupName=Ciyue
OutputDir=.
OutputBaseFilename=ciyue-installer
Compression=lzma
SolidCompression=yes
LicenseFile=LICENSE

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Ciyue"; Filename: "{app}\Ciyue.exe"
Name: "{commondesktop}\Ciyue"; Filename: "{app}\Ciyue.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop icon"; GroupDescription: "Additional icons:"

[Registry]
Root: HKA; Subkey: "Software\Classes\ciyue"; ValueType: string; ValueName: ""; ValueData: "URL:Ciyue Protocol"; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\ciyue"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""; Flags: uninsdeletekey
Root: HKA; Subkey: "Software\Classes\ciyue\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: "{app}\Ciyue.exe,0"
Root: HKA; Subkey: "Software\Classes\ciyue\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\Ciyue.exe"" ""%1"""

[Run]
Filename: "{app}\Ciyue.exe"; Description: "{cm:LaunchProgram,Ciyue}"; Flags: nowait postinstall skipifsilent
