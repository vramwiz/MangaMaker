unit ComicWorkspaceAssets;

// 責務：画像管理を通常の編集画面へ埋め込み、保存と画面・モデルの寿命を揃える。
interface
uses MangaMakerMainForm, Vcl.Controls;
procedure OpenWorkspaceAssets(Form: TMainForm);
procedure CommitWorkspaceAssets(Form: TMainForm);
procedure CloseWorkspaceAssets(Form: TMainForm);
procedure WorkspaceDpiChanged(Form: TMainForm);
implementation
uses System.SysUtils, System.Classes, Winapi.Windows, Vcl.Forms, Vcl.StdCtrls,
  ComicAssetDialog;
type
  TWorkspaceAssetsHelper = class helper for TMainForm
    procedure OpenAssets;
    procedure CommitAssets;
    procedure CloseAssets;
    procedure UpdateDpi;
  end;
procedure TWorkspaceAssetsHelper.OpenAssets;
var Manager: TAssetDialog;
begin
  if (FImageWorkspace<>nil) or (FProject=nil) then Exit;
  Manager:=TAssetDialog.CreateManager(Self,FProject.Assets,FProject,False,True,
    GenerationPresets,FCharacters,GenerateAsset,CancelGeneration,GenerateScript,FWorkspaceHost);
  try
    Manager.ScaleForPPI(CurrentPPI);
    FImageWorkspaceBefore:=FProject.Snapshot;
    FImageWorkspace:=Manager; FAssetManager:=Manager;
    FModeTitle.Parent.Parent:=FWorkspaceHost;
    FView.Visible:=False; FToolsPanel.Visible:=False; Manager.Show;
  except
    FImageWorkspace:=nil; FAssetManager:=nil; Manager.Free;
    FModeTitle.Parent.Parent:=FToolsPanel;
    FView.Visible:=True; FToolsPanel.Visible:=True; raise;
  end;
end;
procedure TWorkspaceAssetsHelper.CommitAssets;
begin
  if FImageWorkspace=nil then Exit;
  // 保存失敗では画面・選択・入力を保持し、作品切替やUndoへ進ませない。
  FImageWorkspace.SaveWorkspace;
  FinishImageManagement(FImageWorkspaceBefore,True);
  FImageWorkspaceBefore:=FProject.Snapshot;
end;
procedure TWorkspaceAssetsHelper.CloseAssets;
var Manager: TAssetDialog;
begin
  if FImageWorkspace=nil then Exit;
  CommitAssets; Manager:=FImageWorkspace;
  CancelGeneration(Manager); FAssetManager:=nil; FImageWorkspace:=nil;
  // 一覧の旧ポインターを更新した後で、削除済み素材を所有する管理画面を解放する。
  Manager.Free; FImageWorkspaceBefore:='';
  FModeTitle.Parent.Parent:=FToolsPanel;
  FView.Visible:=True; FToolsPanel.Visible:=True;
  if FTabs.ActivePageIndex=5 then FTabs.ActivePageIndex:=0;
  UpdateIconState;
end;
procedure TWorkspaceAssetsHelper.UpdateDpi;
begin
  if FCanvas=nil then Exit;
  // 行高やコントロールはVCLが拡縮する。HWND再作成を伴う行高の二重設定は避ける。
  UpdateViewport; FCanvas.Invalidate;
end;
procedure OpenWorkspaceAssets(Form: TMainForm);
begin Form.OpenAssets; end;
procedure CommitWorkspaceAssets(Form: TMainForm);
begin Form.CommitAssets; end;
procedure CloseWorkspaceAssets(Form: TMainForm);
begin Form.CloseAssets; end;
procedure WorkspaceDpiChanged(Form: TMainForm);
begin Form.UpdateDpi; end;
end.
