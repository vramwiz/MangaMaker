unit ComicWorkspaceAssets;

// 責務：ページ編集・画像管理・共通キャラ管理の切替と、管理中の保存・寿命を揃える。
interface
uses MangaMakerMainForm, Vcl.Controls;
procedure OpenWorkspaceAssets(Form: TMainForm);
procedure CommitWorkspaceAssets(Form: TMainForm);
procedure CloseWorkspaceAssets(Form: TMainForm);
procedure SwitchPrimaryWorkspace(Form: TMainForm; Index: Integer);
procedure RefreshPrimaryWorkspace(Form: TMainForm);
procedure WorkspaceDpiChanged(Form: TMainForm);
implementation
uses System.SysUtils, System.Classes, System.IOUtils, Winapi.Windows, Vcl.Forms, Vcl.StdCtrls,
  ComicAssetDialog, ComicModel, ComicAssetEditing, ComicProjectReferences;
type
  TWorkspaceAssetsHelper = class helper for TMainForm
    procedure OpenAssets;
    procedure CommitAssets;
    procedure CloseAssets;
    procedure OpenCharacters;
    procedure SwitchPrimary(Index: Integer);
    procedure RefreshPrimary;
    procedure UpdateDpi;
  end;
procedure TWorkspaceAssetsHelper.RefreshPrimary;
begin
  if FPrimaryBar=nil then Exit;
  FPrimaryBar.Visible:=(FProject<>nil) or (FCharacterWorkspace<>nil);
  FWorkspaceHost.Visible:=FPrimaryBar.Visible;
  FPages.Parent.Visible:=(FProject<>nil) and (FPrimaryIndex=0);
  FView.Visible:=FPrimaryIndex=0; FToolsPanel.Visible:=FPrimaryIndex=0;
  FStatus.Visible:=FProject<>nil;
  for var I:=0 to 2 do begin
    FPrimaryButtons[I].Enabled:=(I=2) or (FProject<>nil);
    FPrimaryButtons[I].Selected:=I=FPrimaryIndex;
  end;
  FModeMenu[5].Checked:=FPrimaryIndex=1;
end;
procedure TWorkspaceAssetsHelper.OpenAssets;
var Manager: TAssetDialog;
begin
  if (FImageWorkspace<>nil) or (FProject=nil) then Exit;
  Manager:=TAssetDialog.CreateManager(Self,FProject.Assets,FProject,False,True,
    GenerationPresets,FCharacters,GenerateAsset,CancelGeneration,GenerateScript,FWorkspaceHost);
  try
    FImageWorkspaceBefore:=FProject.Snapshot;
    FImageWorkspace:=Manager; FAssetManager:=Manager;
    if FLastAssetID<>'' then Manager.SelectAsset(FLastAssetID);
    FPrimaryIndex:=1; RefreshPrimary; Manager.Show;
  except FImageWorkspace:=nil; FAssetManager:=nil; Manager.Free; raise; end;
end;
procedure TWorkspaceAssetsHelper.OpenCharacters;
begin
  if FCharacterWorkspace<>nil then Exit;
  if not FCharacterLibraryWritable then begin
    try
      ReadAssets(FCharacters,TPath.Combine(DataRoot,'Characters\Library.json'));
      NormalizeCharacters(FCharacters); FCharacterLibraryWritable:=True;
    except on E: Exception do if not FTesting then Notify(E.Message); end;
  end;
  FCharacterWorkspace:=TAssetDialog.CreateManager(Self,FCharacters,nil,True,FCharacterLibraryWritable,
    nil,nil,GenerateAsset,CancelGeneration,nil,FWorkspaceHost);
  FAssetManager:=FCharacterWorkspace;
  if FLastCharacterID<>'' then FCharacterWorkspace.SelectAsset(FLastCharacterID);
  FPrimaryIndex:=2; RefreshPrimary; FCharacterWorkspace.Show;
end;
procedure TWorkspaceAssetsHelper.CommitAssets;
begin
  if FCharacterWorkspace<>nil then begin
    if FCharacterLibraryWritable then FCharacterWorkspace.SaveWorkspace;
    Exit;
  end;
  if FImageWorkspace=nil then Exit;
  // 保存失敗では画面・選択・入力を保持し、作品切替やUndoへ進ませない。
  FImageWorkspace.FlushDraft; CaptureProjectReferences(FProject,FCharacters);
  FImageWorkspace.SaveWorkspace;
  FinishImageManagement(FImageWorkspaceBefore,True);
  FImageWorkspaceBefore:=FProject.Snapshot;
end;
procedure TWorkspaceAssetsHelper.CloseAssets;
var Manager: TAssetDialog;
begin
  CommitAssets;
  if FCharacterWorkspace<>nil then begin
    Manager:=FCharacterWorkspace;
    if Manager.CurrentAsset<>nil then FLastCharacterID:=Manager.CurrentAsset.ID;
    CancelGeneration(Manager); FAssetManager:=nil; FCharacterWorkspace:=nil; Manager.Free;
  end;
  if FImageWorkspace<>nil then begin
    Manager:=FImageWorkspace;
    if Manager.CurrentAsset<>nil then FLastAssetID:=Manager.CurrentAsset.ID;
    CancelGeneration(Manager); FAssetManager:=nil; FImageWorkspace:=nil;
    Manager.Free; FImageWorkspaceBefore:='';
  end;
  FPrimaryIndex:=0;
  if FTabs.ActivePageIndex=5 then FTabs.ActivePageIndex:=0;
  RefreshPrimary;
end;
procedure TWorkspaceAssetsHelper.SwitchPrimary(Index: Integer);
begin
  if not (Index in [0..2]) then Exit;
  if (Index<>2) and (FProject=nil) then Exit;
  if (Index=FPrimaryIndex) and (((Index=1) and (FImageWorkspace<>nil)) or
    ((Index=2) and (FCharacterWorkspace<>nil)) or (Index=0)) then Exit;
  CancelDrag; CloseAssets;
  try
    case Index of 1: OpenAssets; 2: OpenCharacters; end;
  finally RefreshPrimary; UpdateIconState; end;
end;
procedure OpenWorkspaceAssets(Form: TMainForm);
begin Form.SwitchPrimary(1); end;
procedure CommitWorkspaceAssets(Form: TMainForm);
begin Form.CommitAssets; end;
procedure CloseWorkspaceAssets(Form: TMainForm);
begin Form.CloseAssets; end;
procedure SwitchPrimaryWorkspace(Form: TMainForm; Index: Integer);
begin Form.SwitchPrimary(Index); end;
procedure RefreshPrimaryWorkspace(Form: TMainForm);
begin Form.RefreshPrimary; end;
procedure TWorkspaceAssetsHelper.UpdateDpi;
begin if FCanvas<>nil then begin UpdateViewport; FCanvas.Invalidate; end; end;
procedure WorkspaceDpiChanged(Form: TMainForm);
begin Form.UpdateDpi; end;
end.
