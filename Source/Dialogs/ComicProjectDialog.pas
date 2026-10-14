unit ComicProjectDialog;

// 責務：作品読込に標準Windowsダイアログを使い、初期位置とスタイル設定を局所的に管理する。

interface

uses System.Classes, Vcl.Dialogs, Winapi.Windows, Winapi.ShlObj;

type
  TComicProjectOpenDialog = class(TOpenDialog)
  protected
    procedure DoExecuteDialog(Dialog: IFileDialog); override;
  public
    function Execute(ParentWnd: HWND): Boolean; override;
  end;

procedure ConfigureProjectOpenDialog(Dialog: TOpenDialog; const DataFolder,CurrentFolder,Executable: string);

implementation

uses System.SysUtils, System.IOUtils, Vcl.Themes;

function TComicProjectOpenDialog.Execute(ParentWnd: HWND): Boolean;
var Hooks: TStyleManager.TSystemHooks;
begin
  Hooks:=TStyleManager.SystemHooks;
  try
    TStyleManager.SystemHooks:=Hooks-[shDialogs];
    Result:=inherited Execute(ParentWnd);
  finally TStyleManager.SystemHooks:=Hooks; end;
end;
procedure ConfigureProjectOpenDialog(Dialog: TOpenDialog; const DataFolder,CurrentFolder,Executable: string);
var Folder,Bundle,Sample: string;
begin
  Folder:=CurrentFolder;
  if not DirectoryExists(Folder) then begin
    Bundle:=TPath.GetDirectoryName(TPath.GetDirectoryName(Executable));
    Sample:=TPath.Combine(Bundle,'Project\Project.json');
    if FileExists(Sample) and FileExists(TPath.Combine(Bundle,'Start-Sample.ps1')) then Folder:=ExtractFileDir(Sample)
    else begin
      Folder:=TPath.Combine(DataFolder,'Projects');
      if not DirectoryExists(Folder) then Folder:=DataFolder;
      if not DirectoryExists(Folder) then Folder:=TPath.GetDocumentsPath;
    end;
  end;
  Dialog.Title:='作品を開く（Project.jsonファイルを選択）';
  Dialog.Filter:='作品ファイル (Project.json)|Project.json|JSON (*.json)|*.json';
  Dialog.FilterIndex:=1; Dialog.DefaultExt:='json'; Dialog.FileName:='Project.json'; Dialog.InitialDir:=Folder;
  Dialog.Options:=[ofFileMustExist,ofPathMustExist,ofEnableSizing,ofNoChangeDir];
end;

procedure TComicProjectOpenDialog.DoExecuteDialog(Dialog: IFileDialog);
var Folder: IShellItem;
begin
  inherited;
  // 前回の閲覧場所に引きずられないようSetFolderを使い、要求した作品フォルダーを実際に開く。
  if DirectoryExists(InitialDir) and Succeeded(SHCreateItemFromParsingName(PChar(InitialDir),nil,IShellItem,Folder)) then
    Dialog.SetFolder(Folder);
  Dialog.SetOkButtonLabel('作品を開く');
  Dialog.SetFileNameLabel('作品ファイル');
end;

end.
