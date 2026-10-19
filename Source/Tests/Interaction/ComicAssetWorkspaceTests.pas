unit ComicAssetWorkspaceTests;

// 責務：常設の画像管理、保存失敗時の保持、DPI往復と非入力操作のIME終了を検証する。
interface
uses ComicTestSupport;
procedure RunAssetWorkspaceChecks(Host: TComicTestForm);
implementation
uses Winapi.Windows, Winapi.Messages, Winapi.Imm, System.SysUtils, System.Classes,
  System.Types, System.IOUtils, System.JSON, Vcl.Forms, Vcl.Controls, Vcl.StdCtrls, Vcl.Graphics, Vcl.ExtCtrls,
  Vcl.Imaging.pngimage, ComicModel, ComicAssetDialog, ComicTextInput;
type
  TAssetWorkspaceTests = class helper for TComicTestForm
    procedure WorkspaceChecks;
    procedure DpiChecks(const ID: string);
    procedure SaveChecks(const ID: string);
    procedure SaveFailureChecks(const ID: string);
    procedure FocusImeChecks;
  end;
procedure TAssetWorkspaceTests.FocusImeChecks;
var Context,Previous: HIMC; Control: TWinControl; Editor: TEdit; I: Integer; TextDialog: TComicTextDialog;
  procedure FocusMessage(Target: TWinControl; ExpectedOpen: Boolean; Receiver: TWinControl=nil);
  begin
    ImmSetOpenStatus(Context,True);
    if Receiver=nil then Receiver:=Self; Receiver.Perform(CM_FOCUSCHANGED,0,LPARAM(Target));
    Check(ImmGetOpenStatus(Context)=ExpectedOpen,'focus route closes IME only outside text: '+Target.ClassName);
  end;
begin
  Context:=ImmCreateContext;
  Check(Context<>0,'isolated focus IME context is created');
  try
    for I:=0 to 2 do begin
      case I of 0: Control:=FView; 1: Control:=FModeButtons[0]; else Control:=FPages; end;
      Previous:=ImmAssociateContext(Control.Handle,Context);
      try FocusMessage(Control,False);
      finally ImmAssociateContext(Control.Handle,Previous); end;
    end;
    Editor:=TEdit.Create(Self);
    try
      Editor.Parent:=FView; Previous:=ImmAssociateContext(Editor.Handle,Context);
      try FocusMessage(Editor,True);
      finally ImmAssociateContext(Editor.Handle,Previous); end;
    finally Editor.Free; end;
    Images(nil); Control:=FImageWorkspace.AssetTree; Previous:=ImmAssociateContext(Control.Handle,Context);
    try FocusMessage(Control,False,FImageWorkspace);
    finally ImmAssociateContext(Control.Handle,Previous); CloseImageWorkspace; end;
    TextDialog:=TComicTextDialog.CreateEditor(Self,'IME route',False,True);
    try
      for I:=0 to TextDialog.ComponentCount-1 do if TextDialog.Components[I] is TButton then begin
        Control:=TButton(TextDialog.Components[I]); Previous:=ImmAssociateContext(Control.Handle,Context);
        try FocusMessage(Control,False,TextDialog);
        finally ImmAssociateContext(Control.Handle,Previous); end;
      end;
    finally TextDialog.Free; end;
  finally ImmDestroyContext(Context); end;
end;
procedure TAssetWorkspaceTests.DpiChecks(const ID: string);
var Before: string; PPI,ModalCount: Integer; Manager: TAssetDialog; PNG: TPngImage; PointValue: TPointF;
begin
  Before:=FProject.Snapshot; ModalCount:=Application.ModalLevel; PNG:=TPngImage.Create;
  try
    for PPI in [96,144,192,96] do begin
      Scaled:=True; ScaleForPPI(PPI); Scaled:=False; Realign;
      Check((CurrentPPI=PPI) and (FPages.ItemHeight=MulDiv(158,PPI,96)) and
        (FImages.ItemHeight=MulDiv(104,PPI,96)),Format('DPI changes update fixed list rows %d [form=%d rows=%d,%d]',
          [PPI,CurrentPPI,FPages.ItemHeight,FImages.ItemHeight]));
      FModeButtons[5].Click; Manager:=FImageWorkspace; Realign;
      Check((Manager<>nil) and (Manager=FAssetManager) and (Manager.Parent=FWorkspaceHost) and
        (Manager.BorderStyle=bsNone) and (Application.ModalLevel=ModalCount),
        'image management is an embedded nonmodal workspace '+IntToStr(PPI));
      Check((Manager.CurrentPPI=PPI) and (Manager.AssetTree.Parent.Width=MulDiv(250,PPI,96)) and
        (Manager.AssetTree.Width=Manager.AssetTree.Parent.Width-2*TPanel(Manager.AssetTree.Parent).BevelWidth),
        Format('embedded manager uses owner monitor PPI exactly once %d [form=%d tree=%d treePPI=%d]',
          [PPI,Manager.CurrentPPI,Manager.AssetTree.Width,Manager.AssetTree.CurrentPPI]));
      Check((FModeButtons[5].Left<FModeButtons[0].Left) and FModeButtons[5].Selected and
        not FView.Visible and not FToolsPanel.Visible,'leftmost image management icon controls workspace');
      Manager.SelectAsset(ID);
      if PPI=144 then begin
        HandleNeeded; B.SetSize(ClientWidth,ClientHeight); PaintTo(B.Canvas,0,0); PNG.Assign(B);
        PNG.SaveToFile(TPath.Combine(TestFolder,'asset-workspace-144.png'));
      end;
      FModeButtons[3].Click;
      Check((FImageWorkspace=nil) and (FAssetManager=nil) and FView.Visible and FToolsPanel.Visible and
        (FProject.Snapshot=Before),'workspace switching preserves project and restores editor');
      UpdateViewport; PointValue:=ToPage(FPageRect.Left,FPageRect.Top);
      Check((Abs(PointValue.X)<0.01) and (Abs(PointValue.Y)<0.01),
        'DPI viewport inverse mapping keeps the page origin '+IntToStr(PPI));
    end;
  finally PNG.Free; end;
end;
procedure TAssetWorkspaceTests.SaveChecks(const ID: string);
var Manager: TAssetDialog; Count: Integer;
begin
    FUndo.Clear; FRedo.Clear; Images(nil); Manager:=FImageWorkspace; Manager.SelectAsset(ID);
    Check(Manager.AssetTree.Items.Count=FProject.Assets.Count,Format('embedded tree retains nodes [%d/%d]',
      [Manager.AssetTree.Items.Count,FProject.Assets.Count]));
    Check(Manager.CurrentAsset<>nil,'embedded tree selection activates an asset '+ID);
    Check(Manager.CurrentAsset.ID=ID,'embedded tree selection activates the intended asset');
    Manager.DraftNotes.Text:='画面に埋め込んだ説明'; Count:=FUndo.Count;
    FModeButtons[0].Click;
    Check((FProject.Asset(ID).Notes='画面に埋め込んだ説明') and (FUndo.Count=Count+1) and FDirty,
      Format('leaving image workspace saves input as one project undo [notes=%s undo=%d/%d dirty=%s]',
        [FProject.Asset(ID).Notes,FUndo.Count,Count,BoolToStr(FDirty,True)]));
    Undo(nil); Check(FProject.Asset(ID).Notes<>'画面に埋め込んだ説明','workspace edit undo restores original asset');
    Redo(nil); Check(FProject.Asset(ID).Notes='画面に埋め込んだ説明','workspace edit redo restores changed asset');
    Images(nil); FImageWorkspace.SelectAsset(ID);
    FImageWorkspace.DraftNotes.Text:='ページ切替でも保存'; FPages.ItemIndex:=1; PageSelect(nil);
    Check((FPageIndex=1) and (FImageWorkspace=nil) and (FProject.Asset(ID).Notes='ページ切替でも保存'),
      'page click commits image workspace without reverting the clicked page selection');
  SaveFailureChecks(ID);
end;
procedure TAssetWorkspaceTests.SaveFailureChecks(const ID: string);
var Before,Path,Reply: string; Response: TJSONObject; Manager: TAssetDialog;
  Lock: THandle; Failed: Boolean; Restored: TComicProject;
begin
    Images(nil); Manager:=FImageWorkspace; Manager.SelectAsset(ID); Manager.DraftNotes.Text:='保存失敗でも保持';
    Before:=FProject.Snapshot; EnableWindow(Handle,False);
    try
      BridgeRequest('{"version":1,"action":"create_asset","library":"images","projectId":"'+FProject.ID+'","name":"blocked"}',Reply);
      Response:=TJSONObject.ParseJSONValue(Reply) as TJSONObject;
      try Check((JStr(Response,'ok','')='false') and (FProject.Snapshot=Before),
        'embedded workspace rejects bridge writes while the main window owns a native modal dialog');
      finally Response.Free; end;
    finally EnableWindow(Handle,True); end;
    Path:=TPath.Combine(FProject.Folder,'Draft.json'); Lock:=CreateFile(PChar(Path),GENERIC_READ,0,nil,OPEN_EXISTING,0,0);
    Check(Lock<>INVALID_HANDLE_VALUE,'workspace save failure fixture locks the draft');
    try
      Failed:=False; try FModeButtons[0].Click; except Failed:=True; end;
      Check(Failed and (FImageWorkspace=Manager) and (FTabs.ActivePageIndex=5) and Manager.Visible and
        (Manager.DraftNotes.Text='保存失敗でも保持'),'failed workspace save prevents switching and retains input');
    finally CloseHandle(Lock); end;
    SaveProject(nil);
    Check((FImageWorkspace=Manager) and not FDirty,'formal save commits workspace without closing it');
    Restored:=TComicProject.Create;
    try Restored.Load(TPath.Combine(FProject.Folder,'Project.json'));
      Check(Restored.Asset(ID).Notes='保存失敗でも保持','retry formal save includes embedded manager draft');
    finally Restored.Free; end;
  FModeButtons[0].Click;
end;
procedure TAssetWorkspaceTests.WorkspaceChecks;
var Project: TComicProject; Asset: TComicAsset; ID: string;
  OriginalPPI,OriginalW,OriginalH: Integer; OriginalScaled: Boolean;
begin
  HandleNeeded; Project:=FProject; OriginalPPI:=CurrentPPI; OriginalScaled:=Scaled;
  OriginalW:=Width; OriginalH:=Height;
  FProject:=CreateFixtureProject; FProject.Initialize('常設画像管理 fixture','1'); FPageIndex:=0;
  FProject.Pages.Add(TComicPage.Create);
  Asset:=FProject.ImportImage(TPath.Combine(TestFolder,'reference.bmp'),''); ID:=Asset.ID; RefreshUI;
  try
    DpiChecks(ID); SaveChecks(ID); FocusImeChecks;
  finally
    CloseImageWorkspace; FreeAndNil(FProject); FProject:=Project; FPageIndex:=-1;
    FUndo.Clear; FRedo.Clear; FDirty:=False;
    Scaled:=True; ScaleForPPI(OriginalPPI); Scaled:=OriginalScaled;
    Width:=OriginalW; Height:=OriginalH; Realign; RefreshUI;
  end;
end;
procedure RunAssetWorkspaceChecks(Host: TComicTestForm);
begin Host.WorkspaceChecks; end;
end.
