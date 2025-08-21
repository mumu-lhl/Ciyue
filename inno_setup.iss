[Setup]
AppName=Ciyue
AppVersion=1.20.0
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

[Run]
Filename: "{app}\Ciyue.exe"; Description: "{cm:LaunchProgram,Ciyue}"; Flags: nowait postinstall skipifsilent
