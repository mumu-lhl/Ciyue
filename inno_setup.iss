[Setup]
AppName=Ciyue
AppVersion=2.0.0
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
