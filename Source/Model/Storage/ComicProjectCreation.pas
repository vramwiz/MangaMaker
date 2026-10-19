unit ComicProjectCreation;

// 責務：新規作品の入力を検証し、指定先へ空ページと任意の台本を保存する。
interface
uses System.Generics.Collections, ComicModel;
function CreateProjectAt(const Folder,Title,Episode,ScriptText: string; const Basis: TComicPageBasis;
  Characters: TObjectList<TComicAsset>): TComicProject;
implementation
uses System.SysUtils, System.IOUtils, ComicScript, ComicScriptAssist, ComicProjectReferences;
function CreateProjectAt(const Folder,Title,Episode,ScriptText: string; const Basis: TComicPageBasis;
  Characters: TObjectList<TComicAsset>): TComicProject;
var Script: TComicScript;
begin
  if Trim(Folder)='' then raise Exception.Create('保存先フォルダを指定してください。');
  if not TPath.IsPathRooted(Trim(Folder)) then raise Exception.Create('保存先は絶対パスで指定してください。');
  if Trim(Title)='' then raise Exception.Create('作品名を入力してください。');
  if not Basis.Valid then raise Exception.Create('用紙の幅・高さ・余白を確認してください。');
  if Length(ScriptText)>1024*1024 then raise Exception.Create('台本は100万文字以内にしてください。');
  Script:=TComicScript.Create;
  try
    if Trim(ScriptText)<>'' then begin Script.Read(ScriptText);
      if Script.FatalErrors.Count>0 then raise Exception.Create(Script.FatalErrors.Text); end;
  finally Script.Free; end;
  Result:=TComicProject.Create;
  try
    Result.ID:=NewUID; Result.Folder:=TPath.GetFullPath(Trim(Folder));
    Result.Title:=Trim(Title); Result.Episode:=Trim(Episode); Result.SetPageBasis(Basis);
    Result.Pages.Add(TComicPage.Create);
    // 解析の成否が分かるまではProject.jsonを置換しない。上書き先の選択は利用者が行う。
    if Trim(ScriptText)<>'' then ImportComicScript(Result,Characters,ScriptText);
    ForceDirectories(Result.Folder); CaptureProjectReferences(Result,Characters); Result.Save;
  except Result.Free; raise; end;
end;
end.
