unit ComicWorkspaceProject;

// 責務：新規作品の設定確定と、作成後の初回台本貼付をワークスペースへ接続する。
interface
uses MangaMakerMainForm;
procedure NewWorkspaceProject(Form: TMainForm);
procedure ImportWorkspaceScript(Form: TMainForm);
implementation
uses System.SysUtils, System.IOUtils, System.UITypes, ComicModel, ComicNewProjectDialog,
  ComicScriptAssist, ComicProjectReferences;
type
  TWorkspaceProjectHelper = class helper for TMainForm
    procedure NewProjectSettings;
    procedure PasteScript;
  end;
procedure TWorkspaceProjectHelper.NewProjectSettings;
var Dialog: TComicNewProjectDialog; Project: TComicProject;
begin
  if not ConfirmLeave then Exit;
  Dialog:=TComicNewProjectDialog.CreateSettings(Self,FPagePresets);
  try
    Project:=nil;
    while Project=nil do begin
      if Dialog.ShowModal<>mrOK then Exit;
      try Project:=Dialog.CreateProject(FCharacters);
      except on E: Exception do Notify(E.Message); end;
    end;
    AdoptProject(Project,False);
    RememberProject(TPath.Combine(FProject.Folder,'Project.json'));
  finally Dialog.Free; end;
end;
procedure TWorkspaceProjectHelper.PasteScript;
var Text,Before: string; Imported: TScriptImportResult;
begin
  if not NeedProject then Exit;
  if FProject.ScriptSource<>'' then begin Notify('台本の追加・置換は現在保留中です。'); Exit; end;
  Text:=''; if not PasteComicScript(Self,Text) or (Trim(Text)='') then Exit;
  CloseImageWorkspace; Before:=FProject.Snapshot;
  try
    Imported:=ImportComicScript(FProject,FCharacters,Text);
    CaptureProjectReferences(FProject,FCharacters); FinishImageManagement(Before);
  except FProject.Restore(Before); RefreshUI; raise; end;
  Images(nil); FStatus.SimpleText:=Imported.Summary;
end;
procedure NewWorkspaceProject(Form: TMainForm);
begin Form.NewProjectSettings; end;
procedure ImportWorkspaceScript(Form: TMainForm);
begin Form.PasteScript; end;
end.
