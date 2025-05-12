#define MyAppName "ServiceLauncher"
#define MyAppExeName "ServiceLauncher.exe"
#define MyAppPublisher "haiyewei"
#define MyAppURL "https://github.com/haiyewei"

[Setup]
AppId={{D0A976CD-A8E1-48FF-BA59-B5BB684D7D09}}
AppName={#MyAppName}
AppVersion={{APP_VERSION}}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={code:GetInstallModeDir}
DefaultGroupName={code:GetInstallModeGroupName}
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
SetupIconFile=..\assets\icons\app_icon.ico
OutputBaseFilename={#MyAppName}-Setup-{{APP_VERSION}}
OutputDir=..\output_installer
PrivilegesRequired=admin
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "quicklaunchicon"; Description: "{cm:CreateQuickLaunchIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked; OnlyBelowVersion: 0,6.1

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; Check: IsAdminInstallMode
Name: "{userdesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon; Check: not IsAdminInstallMode
Name: "{userappdata}\Microsoft\Internet Explorer\Quick Launch\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: quicklaunchicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent
[Code]
function GetInstallModeDir(Param: string): string;
begin
  if IsAdminInstallMode then
    Result := ExpandConstant('{autopf}\{#MyAppName}') // 管理员安装路径
  else
    Result := ExpandConstant('{userappdata}\{#MyAppName}'); // 当前用户安装路径
end;

function GetInstallModeGroupName(Param: string): string;
begin
  if IsAdminInstallMode then
    Result := '{#MyAppName}' // 管理员开始菜单组
  else
    Result := '{userprograms}\{#MyAppName}'; // 当前用户开始菜单组
end;