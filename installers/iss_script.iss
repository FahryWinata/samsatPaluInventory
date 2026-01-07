[Setup]
AppId={{8B8A0427-0C7D-484E-9180-2E2404097475}}
AppName=Samsat Palu Inventory
AppVersion=1.0.0
;AppVerName=Samsat Palu Inventory 1.0.0
AppPublisher=Samsat Palu
DefaultDirName={autopf}\SamsatPaluInventory
DisableProgramGroupPage=yes
; Remove the following line to run in administrative install mode (install for all users.)
PrivilegesRequired=lowest
OutputDir=.
OutputBaseFilename=SamsatPaluSetup
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"
; Name: "indonesian"; MessagesFile: "compiler:Languages\Indonesian.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; IMPORTANT: Update this path to your actual build output path
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; NOTE: Don't use "Flags: ignoreversion" on any shared system files
Source: "..\Inventarisku\msvcp140.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\Inventarisku\vcruntime140.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\Inventarisku\vcruntime140_1.dll"; DestDir: "{app}"; Flags: ignoreversion


[Icons]
Name: "{autoprograms}\Samsat Palu Inventory"; Filename: "{app}\inventarisku.exe"
Name: "{autodesktop}\Samsat Palu Inventory"; Filename: "{app}\inventarisku.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\inventarisku.exe"; Description: "{cm:LaunchProgram,Samsat Palu Inventory}"; Flags: nowait postinstall skipifsilent
