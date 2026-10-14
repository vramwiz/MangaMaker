unit MangaMakerMainForm;

// 責務：編集状態とオブジェクトの寿命を所有し、機能別Workspaceへイベントを委譲する。

interface

uses Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, Winapi.Imm,
  System.SysUtils, System.Classes, System.Types, System.UITypes,
  System.Math, System.IOUtils, System.Generics.Collections, System.JSON,
  System.Hash, System.DateUtils, Vcl.Controls, Vcl.Forms,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Menus,
  Vcl.Dialogs, Vcl.Graphics, Vcl.Imaging.pngimage, ComicModel,
  ComicRender, ComicAssetDialog, ComicLayouts, ComicExport,
  ComicEditing, ComicIconButton, ComicTextInput, ComicPagePresets,
  ComicPageDialog, ComicPanelTransform, ComicFontHistory, ComicGenerationPresets,
  ComicGenerationDialog, ComicBridge, ComicAssetEditing, ComicEffects,
  ComicRecentProjects, ComicExportDialog, ComicProjectDialog, ComicCodexTransport;

type
  TComicPaintBox = class(TPaintBox)
  public
    property MouseCapture;
    property ControlStyle;
  end;
  TComicView = class(TPanel)
  protected
    procedure WndProc(var Message: TMessage); override;
  public
    OnCaptureLost: TNotifyEvent;
    property ImeMode;
  end;
  TComicGenerationJob = class
  public
    RequestID,LibraryName,AssetID,AssetName,ProjectID,PageID,PanelID,ExpectedFileName,Fingerprint,Root,Prefix,Folder,DialogID: string;
    Worker: TComicCodexWorker;
    Adopted: Boolean;
    constructor Create;
    destructor Destroy; override;
  end;
  TMainForm = class(TForm)
  protected
    // 機能別ヘルパーと検証用派生フォームで同じ状態を参照する。publicへ公開したり複製したりしない。
    FBridge: TComicBridge;
    FAssetManager: TAssetDialog;
    FGenerationJobs: TObjectList<TComicGenerationJob>;
    FGenerationActive: TComicGenerationJob;
    FGenerationTimer: TTimer;
    FGenerationTimeoutMS: Cardinal;
    FEffectMaterials: TObjectList<TComicEffectMaterial>;
    FEffectLibraryWritable: Boolean;
    FEffectStartupError: string;
    FEffectPages: TPageControl;
    FEffectCategory: TComboBox;
    FEffectList: TListBox;
    FFilterKind,FFilterStrength,FFrameKind,FPanelBorderWidth: TComboBox;
    FPanelBorderColor: TColor;
    FEffectIndex: Integer;
    FRecent: TComicRecentProjects;
    FRecentWritable: Boolean;
    FRecentMenu,FRecentEmpty,FRecentClear: TMenuItem;
    FSaveMenu,FUndoMenu,FRedoMenu,FExportMenu,FImagesMenu: TMenuItem;
    FFitMenu,FNextModeMenu,FPreviousModeMenu: TMenuItem;
    FModeMenu: array[0..4] of TMenuItem;
    FRecentItems: array[0..19] of TMenuItem;
    FProject: TComicProject;
    FCharacters: TObjectList<TComicAsset>;
    FCharacterLibraryWritable: Boolean;
    FRenderer: TComicRenderer;
    FUndo,FRedo: TList<string>;
    FPages,FImages,FLayoutList: TListBox;
    FLayouts: TObjectList<TComicLayout>;
    FPagePresets: TObjectList<TComicPagePreset>;
    FGenerationPresets: TObjectList<TComicGenerationPreset>;
    FGenerationWritable: Boolean;
    FPagePresetWritable: Boolean;
    FLayoutLibraryWritable: Boolean;
    FPageDropIndex: Integer;
    FCanvas: TComicPaintBox;
    FView: TComicView;
    FTabs: TPageControl;
    FStatus: TStatusBar;
    FText: TMemo;
    FVertical,FTransparent,FOverflow: TCheckBox;
    FFont: TComboBox;
    FImagePopup: TPopupMenu;
    FDetachImageMenu: TMenuItem;
    FFontFamily: TComboBox;
    FFontHistory: TComicFontHistory;
    FFontHistoryWritable: Boolean;
    FFontBold,FFontItalic,FFontUnderline,FFontStrikeOut: TCheckBox;
    FTextColor: TColor;
    FPageIndex,FPanelIndex,FBalloonIndex,FTool,FNumber: Integer;
    FFirst,FDragging,FDirty,FRefreshing: Boolean;
    FStart,FLast: TPointF;
    FDragBounds: TRectF;
    FDragMouse: TPoint;
    FPageRect: TRect;
    FScale: Double;
    FViewZoom: Double;
    FViewPan,FViewPanStart: TPointF;
    FViewPanMouse: TPoint;
    FViewPanButton: TMouseButton;
    FViewPanning,FViewPanMoved: Boolean;
    FViewportPageID: string;
    FDragHandle: Integer;
    FDragSnapshot: string;
    FDragMoved: Boolean;
    FTesting: Boolean;
    FIconButtons: TList<TComicIconButton>;
    FModeButtons: array[0..4] of TComicIconButton;
    FModeTitle: TLabel;
    FDragZoom: Double;
    FTailIndex,FDragTailHandle: Integer;
    FDragTailState: TComicTailState;
    FDragBalloonTransform: TComicBalloonTransform;
    FBorderWidth,FContour: TComboBox;
    FBorderColor,FFillColor: TColor;
    FDragTextOffset: TPointF;
    FDragFontSize: Integer;
    FGeometryPoints: TList<TPointF>;
    FSnap: TCheckBox;
    FSplitStage: Integer;
    FSplitPanelID: string;
    FSplitA,FSplitB,FSplitC,FSplitD: TPointF;
    FDragVertices: TArray<TPointF>;
    FDragVertex: Integer;
    FDragImageBounds: TRectF;
    FSelectedPanels: TList<string>;
    FDragGroup: TArray<TComicPanelTransform>;
    function GenerationSnapshot(const LibraryName,ProjectID,AssetID: string; out References: TArray<string>): string;
    function GenerationTargetMatches(Job: TComicGenerationJob): Boolean;
    procedure GenerateAsset(Sender: TObject);
    procedure CancelGeneration(Sender: TObject);
    procedure GenerationTick(Sender: TObject);
    procedure BridgeRequest(const Request: string; out Reply: string);
    procedure FinishImageManagement(const Before: string);
    procedure EffectMaterials(Sender: TObject);
    procedure EffectLibraryChanged(Sender: TObject);
    procedure RefreshEffectMaterials;
    procedure EffectCategoryChanged(Sender: TObject);
    procedure DrawEffectItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
    procedure ApplyEffectMaterial(PanelIndex: Integer; Material: TComicEffectMaterial);
    procedure ApplyFilter(Sender: TObject);
    procedure ApplyFrame(Sender: TObject);
    procedure DeleteEffect(Sender: TObject);
    procedure ChoosePanelBorderColor(Sender: TObject);
    procedure LoadPanelEffectControls;
    function SelectedEffect: TComicOverlay;
    function HitEffect(Panel: TComicPanel; const P: TPointF): Integer;
    procedure OpenProjectFile(const FileName: string; DraftChoice: Integer=-1);
    procedure RememberProject(const FileName: string);
    procedure RefreshRecentMenu;
    procedure RecentClick(Sender: TObject);
    procedure ClearRecent(Sender: TObject);
    function CreateExportOptions: TComicExportDialog; virtual;
    procedure Notify(const Message: string);
    function InsideBalloonBody(Balloon: TComicBalloon; const P: TPointF): Boolean;
    procedure TailClick(const P: TPointF);
    procedure TailEditClick(const P: TPointF);
    procedure DeleteTail(Sender: TObject);
    function SelectedPanelIDs: TArray<string>;
    function SelectedPanelBounds: TRectF;
    procedure TogglePanelSelection(Index: Integer);
    procedure SelectSinglePanel(Index: Integer);
    function VertexHandles(Panel: TComicPanel): TArray<TPointF>;
    function HitVertex(Panel: TComicPanel; const P: TPointF): Integer;
    procedure EditVertexContext(const P: TPointF);
    procedure PreservePanelImage(Panel: TComicPanel; const Original: TRectF);
    procedure ResetGeometryInput;
    function SnapCreationPoint(const P: TPointF; const ExcludePanelID: string=''): TPointF;
    function SnapPanelDragBounds(const Bounds: TRectF): TRectF;
    procedure PolygonClick(const P: TPointF);
    procedure SplitClick(const P: TPointF);
    procedure CommitSplit(Index: Integer);
    procedure ModeClick(Sender: TObject);
    procedure ButtonHelp(Sender: TObject);
    procedure IconNavigate(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure UpdateIconState;
    procedure CancelDrag;
    procedure EditBalloonText(Sender: TObject);
    function GlobalShortcutsAllowed: Boolean;
    procedure MenuOpening(Sender: TObject);
    procedure FitView(Sender: TObject);
    procedure CycleMode(Sender: TObject);
    procedure BuildUI;
    function Page: TComicPage;
    function HasCharacter: Boolean;
    function NeedProject: Boolean;
    function ConfirmLeave: Boolean;
    procedure Checkpoint;
    procedure Changed(ContentChanged: Boolean=True);
    procedure RefreshUI;
    procedure ShowPageStatus;
    function PrepareImageContext(const MousePos: TPoint): Boolean;
    procedure ImageContextPopup(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
    procedure NewProject(Sender: TObject);
    procedure PageSettings(Sender: TObject);
    procedure GenerationPresets(Sender: TObject);
    procedure ApplyGenerationPreset(const ID,Name,Instructions: string);
    procedure ApplyPageBasis(const Basis: TComicPageBasis);
    procedure AdoptProject(Project: TComicProject; Dirty: Boolean);
    procedure OpenProject(Sender: TObject);
    procedure SaveProject(Sender: TObject);
    procedure Characters(Sender: TObject);
    procedure Images(Sender: TObject);
    procedure ExportPNG(Sender: TObject);
    procedure OpenOutput(Sender: TObject);
    procedure AddPage(Sender: TObject);
    procedure DeletePage(Sender: TObject);
    procedure RemoveSelectedPages(Ask: Boolean);
    procedure MovePage(Sender: TObject);
    procedure PageSelect(Sender: TObject);
    procedure TabChanged(Sender: TObject);
    procedure DrawPageItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
    procedure Undo(Sender: TObject);
    procedure Redo(Sender: TObject);
    procedure Template(Sender: TObject);
    procedure RegisterLayout(Sender: TObject);
    procedure RenameSelectedLayout(Sender: TObject);
    procedure DeleteSelectedLayout(Sender: TObject);
    procedure RefreshLayouts(Index: Integer);
    procedure LayoutSelectionChanged(Sender: TObject);
    procedure InsertLayout(Sender: TObject);
    procedure ApplyLayout(Layout: TComicLayout; InsertAt: Integer);
    procedure DrawLayoutItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
    procedure DrawImageItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
    procedure DetachImage(Sender: TObject);
    function PageDropIndex(Y: Integer): Integer;
    procedure PagesDragOver(Sender,Source: TObject; X,Y: Integer; State: TDragState; var Accept: Boolean);
    procedure PagesDragDrop(Sender,Source: TObject; X,Y: Integer);
    procedure PagesDragEnd(Sender,Target: TObject; X,Y: Integer);
    procedure Tool(Sender: TObject);
    procedure Paint(Sender: TObject); reintroduce;
    procedure MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X,Y: Integer); reintroduce;
    procedure MouseMove(Sender: TObject; Shift: TShiftState; X,Y: Integer); reintroduce;
    procedure MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X,Y: Integer); reintroduce;
    procedure UpdateViewport;
    procedure ResetViewport;
    procedure BeginViewPan(Button: TMouseButton; X,Y: Integer);
    procedure EndViewPan(Cancel: Boolean);
    procedure ViewCaptureLost(Sender: TObject);
    procedure ViewWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
    function EmptyViewPoint(const P: TPointF): Boolean;
    function ToPage(X,Y: Integer): TPointF;
    function HitPanel(const P: TPointF): Integer;
    function HitBalloon(const P: TPointF): Integer;
    procedure DeleteObject(Sender: TObject);
    procedure AssignImage(Sender: TObject);
    procedure DragOver(Sender,Source: TObject; X,Y: Integer; State: TDragState; var Accept: Boolean); reintroduce;
    procedure DragDrop(Sender,Source: TObject; X,Y: Integer); reintroduce;
    procedure ApplyText(Sender: TObject);
    procedure LoadBalloonControls(Balloon: TComicBalloon);
    procedure FontDropDown(Sender: TObject);
    procedure ChooseTextColor(Sender: TObject);
    procedure TextInputDialog(Sender: TObject);
    function CreateBalloonTextDialog: TComicTextDialog;
    procedure FinishTextDialog(Dialog: TComicTextDialog);
    procedure ImageSelectionChanged(Sender: TObject);
    procedure Tail(Sender: TObject);
    procedure CloseCheck(Sender: TObject; var CanClose: Boolean);
    procedure Key(Sender: TObject; var Key: Word; Shift: TShiftState);
  protected
    function CreateProjectDialog: TComicProjectOpenDialog; virtual;
    function CreateGenerationWorker(Job: TComicGenerationJob; const Prompt: string; const References: TArray<string>): TComicCodexWorker; virtual;
  public
    function IsShortCut(var Message: TWMKey): Boolean; override;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  MainForm: TMainForm;

implementation
uses ComicWorkspaceUI, ComicWorkspaceBridge, ComicWorkspaceGeneration, ComicWorkspaceViewport, ComicWorkspaceGeometry, ComicWorkspaceInteraction, ComicWorkspaceBalloons, ComicWorkspaceEffects
  {$IFDEF DEBUG}, ComicPerformance{$ENDIF};

{$R *.dfm}

procedure TComicView.WndProc(var Message: TMessage);
begin
  if ((Message.Msg=WM_CAPTURECHANGED) or (Message.Msg=WM_CANCELMODE) or (Message.Msg=CM_CANCELMODE)) and
    Assigned(OnCaptureLost) then OnCaptureLost(Self);
  inherited;
end;
constructor TComicGenerationJob.Create;
begin inherited; end;
destructor TComicGenerationJob.Destroy;
begin if Worker<>nil then Worker.Cancel; Worker.Free; inherited; end;

function TMainForm.GenerationSnapshot(const LibraryName,ProjectID,AssetID: string; out References: TArray<string>): string;
begin Result:=RunWorkspaceGenerationSnapshot(Self,LibraryName,ProjectID,AssetID,References); end;
function TMainForm.CreateGenerationWorker(Job: TComicGenerationJob; const Prompt: string; const References: TArray<string>): TComicCodexWorker;
begin Result:=TComicCodexWorker.Create(Job.RequestID,Prompt,Job.Folder,Job.Root,Job.Prefix,References,FGenerationTimeoutMS); end;
procedure TMainForm.GenerateAsset(Sender: TObject);
begin RunWorkspaceGenerateAsset(Self,Sender); end;
function TMainForm.GenerationTargetMatches(Job: TComicGenerationJob): Boolean;
begin Result:=RunWorkspaceGenerationTargetMatches(Self,Job); end;
procedure TMainForm.CancelGeneration(Sender: TObject);
begin RunWorkspaceCancelGeneration(Self,Sender); end;
procedure TMainForm.GenerationTick(Sender: TObject);
begin RunWorkspaceGenerationTick(Self,Sender); end;
constructor TMainForm.Create(AOwner: TComponent);
begin
  inherited; FPageIndex:=-1; FPanelIndex:=-1; FBalloonIndex:=-1; FTailIndex:=-1; FDragVertex:=-1; FScale:=1; FViewZoom:=1; FFillColor:=clWhite; FEffectIndex:=-1;
  FTesting:=(ParamCount>0) and (ParamStr(1)='--self-test');
  {$IFDEF DEBUG}StartComicPerformance(DataRoot);{$ENDIF}
  FGenerationJobs:=TObjectList<TComicGenerationJob>.Create(True); FGenerationTimeoutMS:=600000;
  FGenerationTimer:=TTimer.Create(Self); FGenerationTimer.Interval:=200; FGenerationTimer.OnTimer:=GenerationTick;
  FCharacters:=TObjectList<TComicAsset>.Create; FRenderer:=TComicRenderer.Create;
  FUndo:=TList<string>.Create; FRedo:=TList<string>.Create;
  FIconButtons:=TList<TComicIconButton>.Create;
  FGeometryPoints:=TList<TPointF>.Create;
  FSelectedPanels:=TList<string>.Create;
  FLayouts:=TObjectList<TComicLayout>.Create; FLayoutLibraryWritable:=True; FPageDropIndex:=-1;
  SeedLayouts(FLayouts);
  try LoadLayouts(FLayouts,TPath.Combine(DataRoot,'Presets\Layouts.json'));
  except on E: Exception do begin FLayoutLibraryWritable:=False; if not FTesting then Notify('コマ割りライブラリを読み込めません。元ファイルは保持します。'+sLineBreak+E.Message); end; end;
  FPagePresets:=TObjectList<TComicPagePreset>.Create; SeedPagePresets(FPagePresets); FPagePresetWritable:=True;
  try LoadPagePresets(FPagePresets,TPath.Combine(DataRoot,'Presets\PageBases.json'));
  except on E: Exception do begin FPagePresetWritable:=False; if not FTesting then Notify('ページ基準を読み込めません。元ファイルは保持します。'+sLineBreak+E.Message); end; end;
  FFontHistory:=TComicFontHistory.Create; FFontHistoryWritable:=True;
  try FFontHistory.Load(TPath.Combine(DataRoot,'Presets\FontHistory.json'));
  except FFontHistoryWritable:=False; end;
  FGenerationPresets:=TObjectList<TComicGenerationPreset>.Create; FGenerationWritable:=True;
  try LoadGenerationPresets(FGenerationPresets,TPath.Combine(DataRoot,'Presets\Generation.json'));
  except on E: Exception do begin FGenerationWritable:=False; if not FTesting then Notify('画像生成プリセットを読み込めません。元ファイルは保持します。'+sLineBreak+E.Message); end; end;
  FEffectMaterials:=TObjectList<TComicEffectMaterial>.Create; SeedEffectMaterials(FEffectMaterials); FEffectLibraryWritable:=True;
  try LoadEffectMaterials(FEffectMaterials,TPath.Combine(DataRoot,'Effects\Library.json'));
  except on E: Exception do begin FEffectLibraryWritable:=False; if not FTesting then Notify('効果素材を読み込めません。元のライブラリは保持します。'+E.Message); end; end;
  try EnsureBuiltInMaterialFiles(FEffectMaterials); except on E: Exception do FEffectStartupError:=E.Message; end;
  FRecent:=TComicRecentProjects.Create; FRecentWritable:=True;
  try FRecent.Load(TPath.Combine(DataRoot,'Presets\RecentProjects.json')); except FRecentWritable:=False; end;
  BuildUI;
  FCharacterLibraryWritable:=True;
  try ReadAssets(FCharacters,TPath.Combine(DataRoot,'Characters\Library.json')); NormalizeCharacters(FCharacters);
  except on E: Exception do begin FCharacterLibraryWritable:=False; if not FTesting then Notify(E.Message); end; end;
  RefreshUI;
  if FEffectStartupError<>'' then FStatus.SimpleText:='組込効果素材を用意できません：'+FEffectStartupError;
  if not FTesting then
    try FBridge:=TComicBridge.Create(TPath.Combine(DataRoot,'Runtime'),BridgeRequest);
    except on E: Exception do FStatus.SimpleText:='ローカル連携を開始できません：'+E.Message; end;
end;
destructor TMainForm.Destroy;
// タイマーと所有する生成要求を先に止め、遅延コールバックが解放済みのUI・作品へ触れないようにする。
begin if FGenerationTimer<>nil then FGenerationTimer.Enabled:=False; CancelGeneration(nil); FGenerationJobs.Free; FGenerationJobs:=nil; if FView<>nil then FView.OnCaptureLost:=nil; EndViewPan(False); FBridge.Free; FProject.Free; FCharacters.Free; FRenderer.Free; FUndo.Free; FRedo.Free; FLayouts.Free; FPagePresets.Free; FFontHistory.Free; FGenerationPresets.Free; FEffectMaterials.Free; FRecent.Free; FIconButtons.Free; FGeometryPoints.Free; FSelectedPanels.Free; inherited; end;
procedure TMainForm.BridgeRequest(const Request: string; out Reply: string);
begin HandleWorkspaceBridge(Self,Request,Reply); end;
procedure TMainForm.RefreshEffectMaterials;
begin RunWorkspaceRefreshEffectMaterials(Self); end;
procedure TMainForm.EffectMaterials(Sender: TObject);
begin RunWorkspaceEffectMaterials(Self,Sender); end;
procedure TMainForm.EffectLibraryChanged(Sender: TObject);
begin RunWorkspaceEffectLibraryChanged(Self,Sender); end;
procedure TMainForm.EffectCategoryChanged(Sender: TObject);
begin RunWorkspaceEffectCategoryChanged(Self,Sender); end;
procedure TMainForm.DrawEffectItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
begin RunWorkspaceDrawEffectItem(Self,Control,Index,Rect,State); end;
function TMainForm.SelectedEffect: TComicOverlay;
begin Result:=RunWorkspaceSelectedEffect(Self); end;
function TMainForm.HitEffect(Panel: TComicPanel; const P: TPointF): Integer;
begin Result:=RunWorkspaceHitEffect(Self,Panel,P); end;
procedure TMainForm.ApplyEffectMaterial(PanelIndex: Integer; Material: TComicEffectMaterial);
begin RunWorkspaceApplyEffectMaterial(Self,PanelIndex,Material); end;
procedure TMainForm.LoadPanelEffectControls;
begin RunWorkspaceLoadPanelEffectControls(Self); end;
procedure TMainForm.ApplyFilter(Sender: TObject);
begin RunWorkspaceApplyFilter(Self,Sender); end;
procedure TMainForm.ApplyFrame(Sender: TObject);
begin RunWorkspaceApplyFrame(Self,Sender); end;
procedure TMainForm.ChoosePanelBorderColor(Sender: TObject);
begin RunWorkspaceChoosePanelBorderColor(Self,Sender); end;
procedure TMainForm.DeleteEffect(Sender: TObject);
begin RunWorkspaceDeleteEffect(Self,Sender); end;
function TMainForm.GlobalShortcutsAllowed: Boolean;
var Control: TWinControl; Window: HWND; Context: HIMC;
begin
  Result:=False;
  if not Enabled or (HandleAllocated and not IsWindowEnabled(Handle)) or
    (Application.ModalLevel>0) then Exit;
  if (Screen.ActiveCustomForm<>nil) and (Screen.ActiveCustomForm<>Self) then Exit;
  Control:=ActiveControl;
  if Control is TCustomEdit then Exit;
  if (Control is TCustomComboBox) and (TComboBox(Control).Style<>csDropDownList) then Exit;
  Window:=Winapi.Windows.GetFocus;
  if (Window<>0) and ((Window=Handle) or IsChild(Handle,Window)) then begin
    Context:=ImmGetContext(Window);
    if Context<>0 then
      try if ImmGetCompositionStringW(Context,GCS_COMPSTR,nil,0)>0 then Exit;
      finally ImmReleaseContext(Window,Context); end;
  end;
  Result:=True;
end;
function TMainForm.IsShortCut(var Message: TWMKey): Boolean;
begin
  // メニューへ渡す前に入力範囲を確認し、文字欄のUndo・選択・IME確定取消をアプリ操作で奪わない。
  Result:=False;
  if not GlobalShortcutsAllowed then Exit;
  UpdateIconState;
  Result:=inherited IsShortCut(Message);
end;
procedure TMainForm.MenuOpening(Sender: TObject);
begin UpdateIconState; end;
procedure TMainForm.FitView(Sender: TObject);
begin if FProject=nil then Exit; CancelDrag; ResetViewport; end;
procedure TMainForm.CycleMode(Sender: TObject);
var Index: Integer;
begin
  if not FTabs.Enabled then Exit;
  Index:=(FTabs.ActivePageIndex+TComponent(Sender).Tag+Length(FModeButtons)) mod Length(FModeButtons);
  FModeMenu[Index].Click;
end;


procedure TMainForm.BuildUI;
begin BuildWorkspaceUI(Self); end;
function TMainForm.Page: TComicPage;
begin Result:=nil; if (FProject<>nil) and (FPageIndex>=0) and (FPageIndex<FProject.Pages.Count) then Result:=FProject.Pages[FPageIndex]; end;
function TMainForm.HasCharacter: Boolean;
var A: TComicAsset;
begin
  Result:=False; for A in FCharacters do if (A.ParentID='') and (Trim(A.Name)<>'') and (A.FileName<>'') and
    FileExists(SafeChild(TPath.Combine(DataRoot,'Characters'),A.FileName)) then Exit(True);
end;
function TMainForm.NeedProject: Boolean;
begin Result:=FProject<>nil; if not Result then Notify('作品を作成または開いてください。'); end;
function TMainForm.ConfirmLeave: Boolean;
var R: Integer;
begin
  CancelDrag;
  Result:=True; if not FDirty then Exit;
  R:=MessageDlg('作品に未保存の変更があります。保存しますか？',mtConfirmation,[mbYes,mbNo,mbCancel],0);
  if R=mrCancel then Exit(False); if R=mrYes then SaveProject(nil);
end;
procedure TMainForm.Checkpoint;
begin
  CancelDrag;
  if FProject=nil then Exit; FUndo.Add(FProject.Snapshot); FRedo.Clear;
  if FUndo.Count>40 then FUndo.Delete(0);
end;
procedure TMainForm.Changed(ContentChanged: Boolean);
{$IFDEF DEBUG}var PerfScope: TComicPerfScope;{$ENDIF}
begin
  {$IFDEF DEBUG}PerfScope.Start(cpChanged);{$ENDIF}
  FDirty:=True; if ContentChanged and (Page<>nil) then Inc(Page.Revision);
  FProject.SaveDraft; RefreshUI;
end;
procedure TMainForm.RefreshUI;
{$IFDEF DEBUG}var PerfScope: TComicPerfScope;{$ENDIF}
var I,SelectedImage: Integer; A: TComicAsset; SelectedPages: TList<string>;
begin
  {$IFDEF DEBUG}PerfScope.Start(cpRefreshUI);{$ENDIF}
  FRefreshing:=True; SelectedPages:=TList<string>.Create;
  try
    for I:=0 to FPages.Count-1 do if FPages.Selected[I] then SelectedPages.Add(FPages.Items[I]);
    FPages.Items.BeginUpdate; FImages.Items.BeginUpdate;
    try
      SelectedImage:=FImages.ItemIndex; FPages.Clear; FImages.Clear;
      if FProject<>nil then begin
        for I:=0 to FProject.Pages.Count-1 do FPages.Items.Add(FProject.Pages[I].ID);
        FPageIndex:=Min(FPageIndex,FProject.Pages.Count-1); FPages.ItemIndex:=FPageIndex;
        for I:=0 to FPages.Count-1 do FPages.Selected[I]:=SelectedPages.Contains(FPages.Items[I]);
        if (FPages.SelCount=0) and (FPageIndex>=0) then FPages.Selected[FPageIndex]:=True;
        for A in FProject.Assets do if A.FileName<>'' then FImages.Items.AddObject(A.Name,A);
        if SelectedImage<FImages.Count then FImages.ItemIndex:=SelectedImage;
        Caption:=FProject.Title+'  /  '+FProject.Episode+' — MangaMaker'; if FDirty then Caption:='* '+Caption;
      end else Caption:='MangaMaker — AI漫画スタジオ';
    finally FImages.Items.EndUpdate; FPages.Items.EndUpdate; end;
    FTabs.Enabled:=FProject<>nil;
    if (FProject=nil) and not HasCharacter then FStatus.SimpleText:='はじめに［キャラ管理］で人物名と参照画像を登録してください。'
    else if FProject=nil then FStatus.SimpleText:='［新規作品］で作品タイトルと話数を入力してください。'
    else if FImages.Count=0 then FStatus.SimpleText:='［画像管理］で場面を追加し、画像を登録してください。'
    else ShowPageStatus;
    UpdateIconState;
    FCanvas.Invalidate;
  finally SelectedPages.Free; FRefreshing:=False; end;
end;
procedure TMainForm.ModeClick(Sender: TObject);
begin
  if not FTabs.Enabled then Exit;
  FTabs.ActivePageIndex:=TComponent(Sender).Tag; TabChanged(nil);
  if Sender is TWinControl then ActiveControl:=TWinControl(Sender) else ActiveControl:=FView;
  FStatus.SimpleText:=FTabs.ActivePage.Caption+'：右側のアイコンや一覧から操作を選択してください。';
end;
procedure TMainForm.ButtonHelp(Sender: TObject);
begin
  if (Sender is TComicIconButton) and TComicIconButton(Sender).Available then
    FStatus.SimpleText:=TComicIconButton(Sender).Hint;
end;
procedure TMainForm.ImageSelectionChanged(Sender: TObject);
begin UpdateIconState; end;
procedure TMainForm.IconNavigate(Sender: TObject; var Key: Word; Shift: TShiftState);
var Button,Next: TComicIconButton; Candidates: TList<TComicIconButton>; Index,Step,I: Integer;
begin
  if not (Key in [VK_LEFT,VK_RIGHT,VK_UP,VK_DOWN]) then Exit; Button:=TComicIconButton(Sender);
  Candidates:=TList<TComicIconButton>.Create;
  try
    for Next in FIconButtons do
      if Next.Available and (Next.Parent=Button.Parent) and
        (((Button.Role=brMode) and (Next.Role=brMode)) or
        ((Button.Role in [brTool,brTail,brTextPlacement]) and (Next.Role in [brTool,brTail,brTextPlacement]))) then Candidates.Add(Next);
    Index:=Candidates.IndexOf(Button); if (Index<0) or (Candidates.Count<2) then Exit;
    if Key in [VK_LEFT,VK_UP] then Step:=-1 else Step:=1;
    I:=(Index+Step+Candidates.Count) mod Candidates.Count; Next:=Candidates[I];
    ActiveControl:=Next; Next.Click; Key:=0;
  finally Candidates.Free; end;
end;
procedure TMainForm.UpdateIconState;
var Button: TComicIconButton; CanEdit,HasPage,HasPanel,HasBalloon: Boolean; I: Integer;
begin
  if FTabs=nil then Exit; CanEdit:=FProject<>nil; HasPage:=CanEdit and (Page<>nil);
  HasPanel:=HasPage and (FPanelIndex>=0) and (FPanelIndex<Page.Panels.Count);
  HasBalloon:=HasPage and (FBalloonIndex>=0) and (FBalloonIndex<Page.Balloons.Count);
  for Button in FIconButtons do begin
    case Button.Role of
      brAlways: Button.Enabled:=True;
      brProject,brSave,brExport,brAddPage,brMode: Button.Enabled:=CanEdit;
      brUndo: Button.Enabled:=CanEdit and (FUndo.Count>0);
      brRedo: Button.Enabled:=CanEdit and (FRedo.Count>0);
      brDeletePage: Button.Enabled:=HasPage;
      brPageUp: Button.Enabled:=HasPage and (FPageIndex>0);
      brPageDown: Button.Enabled:=HasPage and (FPageIndex<FProject.Pages.Count-1);
      brRegister: Button.Enabled:=HasPage and (Page.Panels.Count>0) and FLayoutLibraryWritable;
      brApplyLayout: Button.Enabled:=HasPage and (FImages.Count>0) and (FLayoutList.ItemIndex>=0);
      brInsertLayout: Button.Enabled:=CanEdit and (FImages.Count>0) and (FLayoutList.ItemIndex>=0);
      brManageLayout: Button.Enabled:=FLayoutLibraryWritable and (FLayoutList.ItemIndex>=0) and
        not TComicLayout(FLayoutList.Items.Objects[FLayoutList.ItemIndex]).BuiltIn;
      brTool: Button.Enabled:=HasPage and ((Button.Tag=0) or (FImages.Count>0));
      brDeletePanel: Button.Enabled:=HasPanel;
      brTail,brApplyText,brDeleteBalloon: Button.Enabled:=HasBalloon;
      brDeleteTail: Button.Enabled:=HasBalloon and (FTailIndex>=0) and (FTailIndex<Page.Balloons[FBalloonIndex].Tails.Count);
      brTextPlacement: Button.Enabled:=HasBalloon and (Page.Balloons[FBalloonIndex].Text<>'');
      brApplyFilter,brApplyFrame: Button.Enabled:=HasPanel;
      brDeleteEffect: begin Button.Enabled:=False;
        if HasPanel then case Button.Tag of
          0: Button.Enabled:=SelectedEffect<>nil;
          1: Button.Enabled:=Page.Panels[FPanelIndex].FilterKind<>0;
          2: Button.Enabled:=(Page.Panels[FPanelIndex].FrameKind<>0) or (Page.Panels[FPanelIndex].BorderWidth<>4) or (Page.Panels[FPanelIndex].BorderColor<>0);
        end;
      end;
    end;
    if (Button.Role=brTool) and (Button.Tag=9) then
      Button.Enabled:=HasPage and (Page.Panels.Count>0) and ((not HasPanel) or Page.Panels[FPanelIndex].CanSplit);
    if (Button.Role=brTail) and (Button.Tag=12) then Button.Enabled:=HasBalloon and Page.Balloons[FBalloonIndex].HasTail;
    Button.Selected:=((Button.Role=brMode) and (Button.Tag=FTabs.ActivePageIndex)) or
      ((Button.Role in [brTool,brTail,brTextPlacement]) and (Button.Context=FTabs.ActivePageIndex) and (Button.Tag=FTool));
  end;
  FSaveMenu.Enabled:=CanEdit; FExportMenu.Enabled:=CanEdit; FImagesMenu.Enabled:=CanEdit;
  FUndoMenu.Enabled:=CanEdit and (FUndo.Count>0); FRedoMenu.Enabled:=CanEdit and (FRedo.Count>0);
  FFitMenu.Enabled:=CanEdit; FNextModeMenu.Enabled:=CanEdit; FPreviousModeMenu.Enabled:=CanEdit;
  for I:=0 to High(FModeMenu) do begin FModeMenu[I].Enabled:=CanEdit; FModeMenu[I].Checked:=FTabs.ActivePageIndex=I; end;
  FModeTitle.Caption:=FTabs.ActivePage.Caption;
  FDetachImageMenu.Enabled:=HasPanel and (FTabs.ActivePageIndex=2) and (Page.Panels[FPanelIndex].ImageID<>'');
end;
procedure TMainForm.ShowPageStatus;
var P: TComicPanel; IDs: TDictionary<string,Boolean>; Missing,Duplicate,Outside: Integer; Frame: TRectF;
begin
  if FProject=nil then Exit; Missing:=0; Duplicate:=0; Outside:=0; Frame:=FProject.PageBasis.Frame;
  IDs:=TDictionary<string,Boolean>.Create;
  try
    if Page<>nil then for P in Page.Panels do begin
      if (P.ImageID='') or not FileExists(FProject.ImagePath(P.ImageID)) then Inc(Missing);
      if P.ImageID<>'' then begin
        if IDs.ContainsKey(P.ImageID) then Inc(Duplicate) else IDs.Add(P.ImageID,True);
      end;
      if (P.Bounds.Left<Frame.Left) or (P.Bounds.Top<Frame.Top) or (P.Bounds.Right>Frame.Right) or
        (P.Bounds.Bottom>Frame.Bottom) then Inc(Outside);
    end;
    FStatus.SimpleText:=Format('%d ページ / %d 画像  |  選択ページ：未配置・参照切れ %d / 重複 %d / 外枠超過 %d  |  %s',
      [FProject.Pages.Count,FImages.Count,Missing,Duplicate,Outside,FProject.Folder]);
  finally IDs.Free; end;
end;
function TMainForm.PrepareImageContext(const MousePos: TPoint): Boolean;
var Index: Integer;
begin
  Result:=False;
  if (FTabs.ActivePageIndex<>2) or (Page=nil) then Exit;
  CancelDrag;
  if MousePos.X>=0 then begin
    if not FPageRect.Contains(MousePos) then Exit;
    Index:=HitPanel(ToPage(MousePos.X,MousePos.Y));
    if Index<0 then Exit;
    SelectSinglePanel(Index);
  end;
  ActiveControl:=FView; UpdateIconState; FCanvas.Invalidate;
  Result:=(FPanelIndex>=0) and (FPanelIndex<Page.Panels.Count);
end;
procedure TMainForm.ImageContextPopup(Sender: TObject; MousePos: TPoint; var Handled: Boolean);
var Position: TPoint; Bounds: TRectF;
begin
  if FTabs.ActivePageIndex<>2 then Exit;
  Handled:=True;
  if not PrepareImageContext(MousePos) then Exit;
  Position:=MousePos;
  if Position.X<0 then begin
    Bounds:=Page.Panels[FPanelIndex].Bounds;
    Position:=Point(FPageRect.Left+Round((Bounds.Left+Bounds.Right)*0.5*FScale),
      FPageRect.Top+Round((Bounds.Top+Bounds.Bottom)*0.5*FScale));
  end;
  Position:=FCanvas.ClientToScreen(Position);
  FImagePopup.Popup(Position.X,Position.Y);
end;
procedure TMainForm.NewProject(Sender: TObject);
var Title,Episode: string; P: TComicProject;
begin
  if not HasCharacter then begin Characters(nil); if not HasCharacter then Exit; end;
  if not ConfirmLeave then Exit;
  Title:=''; Episode:='第1話'; if not InputQuery('新規作品','作品タイトル',Title) or (Trim(Title)='') then Exit;
  if not InputQuery('新規作品','話数',Episode) then Exit;
  P:=TComicProject.Create; try P.Initialize(Trim(Title),Trim(Episode)); except P.Free; raise; end;
  AdoptProject(P,False); Images(nil);
end;
procedure TMainForm.PageSettings(Sender: TObject);
var Dialog: TComicPageDialog;
begin
  if not NeedProject then Exit;
  Dialog:=TComicPageDialog.CreateSettings(Self,FProject.PageBasis,FPagePresets,
    TPath.Combine(DataRoot,'Presets\PageBases.json'),FPagePresetWritable);
  try if Dialog.ShowModal=mrOK then ApplyPageBasis(Dialog.ResultBasis); finally Dialog.Free; end;
end;
procedure TMainForm.ApplyPageBasis(const Basis: TComicPageBasis);
begin
  if not Basis.Valid then raise Exception.Create('出力解像度またはページ外枠の余白が不正です。');
  if (FProject=nil) or FProject.PageBasis.Same(Basis) then Exit;
  Checkpoint; ResetGeometryInput; FFirst:=False; FTool:=0;
  FProject.SetPageBasis(Basis); Changed(False);
end;
procedure TMainForm.GenerationPresets(Sender: TObject);
var Dialog: TComicGenerationDialog;
begin
  Dialog:=TComicGenerationDialog.CreateManager(Self,FGenerationPresets,TPath.Combine(DataRoot,'Presets\Generation.json'),FGenerationWritable,FProject<>nil);
  try if Dialog.ShowModal=mrOK then ApplyGenerationPreset(Dialog.SelectedID,Dialog.SelectedName,Dialog.SelectedInstructions); finally Dialog.Free; end;
end;
procedure TMainForm.ApplyGenerationPreset(const ID,Name,Instructions: string);
begin
  if FProject=nil then Exit;
  if (Trim(Name)='') or (Length(Trim(Name))>200) or (Length(Instructions)>65536) then raise Exception.Create('生成指示の名前または本文が不正です。');
  if (FProject.GenerationPresetID=ID) and (FProject.GenerationPresetName=Trim(Name)) and (FProject.GenerationInstructions=Instructions) then Exit;
  if (FAssetManager=nil) or FAssetManager.IsCharacters then Checkpoint;
  FProject.GenerationPresetID:=ID; FProject.GenerationPresetName:=Trim(Name); FProject.GenerationInstructions:=Instructions; Changed(False);
  if FAssetManager<>nil then FAssetManager.SetGenerationSummary(FProject.GenerationPresetName,FProject.GenerationInstructions);
end;
procedure TMainForm.AdoptProject(Project: TComicProject; Dirty: Boolean);
begin
  CancelGeneration(nil); CancelDrag; ResetGeometryInput;
  FFirst:=False; FTool:=0; FNumber:=1; FDragVertex:=-1;
  FSelectedPanels.Clear; FDragGroup:=nil; FEffectIndex:=-1;
  FDragVertices:=nil; FDragSnapshot:=''; FPageDropIndex:=-1;
  FreeAndNil(FProject); FProject:=Project;
  FPageIndex:=Min(0,FProject.Pages.Count-1); FPanelIndex:=-1; FBalloonIndex:=-1; FDirty:=Dirty;
  FUndo.Clear; FRedo.Clear; FRenderer.ClearCache; ResetViewport; RefreshUI;
end;
function TMainForm.CreateProjectDialog: TComicProjectOpenDialog;
var Folder: string;
begin
  Folder:=''; if FProject<>nil then Folder:=FProject.Folder;
  Result:=TComicProjectOpenDialog.Create(Self);
  ConfigureProjectOpenDialog(Result,DataRoot,Folder,Application.ExeName);
end;
procedure TMainForm.OpenProject(Sender: TObject);
var D: TComicProjectOpenDialog;
begin
  CancelDrag;
  // 既存作品は人物登録へ迂回させず読めるようにし、新規制作や共有人物を使う管理操作の前提は別に確認する。
  if not ConfirmLeave then Exit; D:=CreateProjectDialog;
  try
    if not D.Execute then Exit;
    OpenProjectFile(D.FileName);
  finally D.Free; end;
end;
procedure TMainForm.SaveProject(Sender: TObject);
{$IFDEF DEBUG}var PerfScope: TComicPerfScope;{$ENDIF}
begin
  {$IFDEF DEBUG}PerfScope.Start(cpSave);{$ENDIF} CancelDrag; if FProject=nil then Exit; FProject.Save; FDirty:=False; RefreshUI; FStatus.SimpleText:='保存しました：'+FProject.Folder;
  RememberProject(TPath.Combine(FProject.Folder,'Project.json')); end;
procedure TMainForm.OpenProjectFile(const FileName: string; DraftChoice: Integer);
{$IFDEF DEBUG}var PerfScope: TComicPerfScope;{$ENDIF}
var Project,Candidate: TComicProject; Saved,Draft,HistoryFile,SavedID: string; Restore,Dirty: Boolean;
begin
  {$IFDEF DEBUG}PerfScope.Start(cpOpen);{$ENDIF}
  Project:=TComicProject.Create;
  try
    Saved:=TFile.ReadAllText(FileName,TEncoding.UTF8); Project.Load(FileName); SavedID:=Project.ID; Draft:=TPath.Combine(Project.Folder,'Draft.json');
    Restore:=DraftChoice=1;
    if (DraftChoice<0) and not FTesting and FileExists(Draft) and (TFile.ReadAllText(Draft,TEncoding.UTF8)<>Project.Snapshot) then
      Restore:=MessageDlg('前回の作業データを復元しますか？',mtConfirmation,[mbYes,mbNo],0)=mrYes;
    if Restore and FileExists(Draft) then begin Project.Load(Draft); if Project.ID<>SavedID then raise Exception.Create('作業データの作品IDが一致しません。'); end;
    HistoryFile:=TPath.Combine(Project.Folder,'Project.json'); if not FileExists(HistoryFile) then HistoryFile:=TPath.GetFullPath(FileName);
    Dirty:=Project.Snapshot<>Saved; Candidate:=Project; Project:=nil; AdoptProject(Candidate,Dirty); RememberProject(HistoryFile);
  finally Project.Free; end;
end;
procedure TMainForm.RememberProject(const FileName: string);
begin
  if not FRecentWritable or (FProject=nil) then Exit;
  try FRecent.Remember(FileName,FProject.Title,FProject.Episode,TPath.Combine(DataRoot,'Presets\RecentProjects.json')); RefreshRecentMenu;
  except on E: Exception do FStatus.SimpleText:='作品は開いています。履歴を記録できません：'+E.Message; end;
end;
procedure TMainForm.RefreshRecentMenu;
var I: Integer;
begin
  if FRecentMenu=nil then Exit;
  for I:=0 to High(FRecentItems) do begin
    FRecentItems[I].Visible:=I<FRecent.Items.Count;
    if I<FRecent.Items.Count then begin
      FRecentItems[I].Caption:=StringReplace(FRecent.Items[I].Title+' '+FRecent.Items[I].Episode,'&','&&',[rfReplaceAll]);
      FRecentItems[I].Hint:=FRecent.Items[I].FileName; FRecentItems[I].Enabled:=FileExists(FRecent.Items[I].FileName);
      if not FRecentItems[I].Enabled then FRecentItems[I].Caption:=FRecentItems[I].Caption+'（見つかりません）';
    end;
  end;
  FRecentEmpty.Visible:=FRecent.Items.Count=0; FRecentClear.Enabled:=FRecentWritable and (FRecent.Items.Count>0);
end;
procedure TMainForm.RecentClick(Sender: TObject);
var Path: string; Index: Integer;
begin
  Index:=TMenuItem(Sender).Tag; if (Index<0) or (Index>=FRecent.Items.Count) then Exit; Path:=FRecent.Items[Index].FileName;
  CancelDrag;
  if not ConfirmLeave then Exit; OpenProjectFile(Path);
end;
procedure TMainForm.ClearRecent(Sender: TObject);
begin if not FRecentWritable then Exit; FRecent.Clear(TPath.Combine(DataRoot,'Presets\RecentProjects.json')); RefreshRecentMenu; end;
procedure TMainForm.Characters(Sender: TObject);
var D: TAssetDialog;
begin
  if not FCharacterLibraryWritable then
    try ReadAssets(FCharacters,TPath.Combine(DataRoot,'Characters\Library.json')); NormalizeCharacters(FCharacters); FCharacterLibraryWritable:=True;
    except on E: Exception do if not FTesting then Notify(E.Message); end;
  D:=TAssetDialog.CreateManager(Self,FCharacters,nil,True,FCharacterLibraryWritable,nil,nil,GenerateAsset,CancelGeneration);
  FAssetManager:=D;
  try D.ShowModal; finally CancelGeneration(D); FAssetManager:=nil; D.Free; end; RefreshUI;
end;
procedure TMainForm.Images(Sender: TObject);
var D: TAssetDialog; Before: string;
begin
  CancelDrag;
  if not NeedProject then Exit;
  if not HasCharacter then begin Notify('参照画像付きのキャラを先に登録してください。'); Exit; end;
  Before:=FProject.Snapshot;
  D:=TAssetDialog.CreateManager(Self,FProject.Assets,FProject,False,True,GenerationPresets,FCharacters,GenerateAsset,CancelGeneration);
  FAssetManager:=D;
  try D.ShowModal; finally CancelGeneration(D); FAssetManager:=nil; D.Free; end;
  FinishImageManagement(Before);
end;
procedure TMainForm.FinishImageManagement(const Before: string);
begin
  if FProject.Snapshot=Before then Exit;
  FUndo.Add(Before); FRedo.Clear; if FUndo.Count>40 then FUndo.Delete(0);
  FRenderer.ClearCache; Changed(False);
end;
procedure TMainForm.AddPage(Sender: TObject);
begin
  if not NeedProject then Exit; Checkpoint;
  if FPageIndex<0 then FPageIndex:=FProject.Pages.Count else Inc(FPageIndex);
  FProject.Pages.Insert(FPageIndex,TComicPage.Create); FPages.Clear; FPanelIndex:=-1; FBalloonIndex:=-1; Changed(False);
end;
procedure TMainForm.DeletePage(Sender: TObject);
begin RemoveSelectedPages(True); end;
procedure TMainForm.RemoveSelectedPages(Ask: Boolean);
var Indices: TList<Integer>; I: Integer;
begin
  if (Page=nil) or not HasCharacter then Exit;
  Indices:=TList<Integer>.Create;
  try
    for I:=0 to FPages.Count-1 do if FPages.Selected[I] then Indices.Add(I);
    if Indices.Count=0 then Indices.Add(FPageIndex);
    if Ask and (MessageDlg(Format('選択した %d ページを削除しますか？ 元に戻す操作で内容と順序を復元できます。',
      [Indices.Count]),mtConfirmation,[mbYes,mbNo],0)<>mrYes) then Exit;
    Checkpoint;
    for I:=Indices.Count-1 downto 0 do FProject.Pages.Delete(Indices[I]);
    FPageIndex:=Min(Indices[0],FProject.Pages.Count-1); FPages.Clear;
    FPanelIndex:=-1; FBalloonIndex:=-1; Changed(False);
  finally Indices.Free; end;
end;
procedure TMainForm.MovePage(Sender: TObject);
var Dest: Integer;
begin
  if Page=nil then Exit; Dest:=FPageIndex+TControl(Sender).Tag;
  if (Dest<0) or (Dest>=FProject.Pages.Count) then Exit;
  Checkpoint; FProject.Pages.Move(FPageIndex,Dest); FPageIndex:=Dest; Changed(False);
end;
procedure TMainForm.PageSelect(Sender: TObject);
begin if FRefreshing then Exit; CancelGeneration(nil); CancelDrag; ResetGeometryInput; FSelectedPanels.Clear; FPageIndex:=FPages.ItemIndex; ResetViewport; FPanelIndex:=-1; FBalloonIndex:=-1; FFirst:=False; ShowPageStatus; UpdateIconState; FCanvas.Invalidate; end;
procedure TMainForm.TabChanged(Sender: TObject);
begin CancelDrag; ResetGeometryInput; FSelectedPanels.Clear; FEffectIndex:=-1; FTool:=0; FFirst:=False; if FTabs.ActivePageIndex<>3 then FBalloonIndex:=-1; UpdateIconState; FCanvas.Invalidate; end;
procedure TMainForm.DrawPageItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
{$IFDEF DEBUG}var PerfScope: TComicPerfScope;{$ENDIF}
var R: TRect; B: TBitmap; I: Integer;
  function D(Value: Integer): Integer; begin Result:=MulDiv(Value,CurrentPPI,96); end;
begin
  {$IFDEF DEBUG}PerfScope.Start(cpThumbnail);{$ENDIF}
  FPages.Canvas.FillRect(Rect); if (FProject=nil) or (Index>=FProject.Pages.Count) then Exit;
  R:=System.Types.Rect(Rect.Left+D(40),Rect.Top+D(8),Rect.Left+D(136),Rect.Top+D(144));
  B:=TBitmap.Create; try B.SetSize(D(96),D(136)); FRenderer.Draw(B.Canvas,FProject,FProject.Pages[Index],System.Types.Rect(0,0,B.Width,B.Height),False);
    FPages.Canvas.Draw(R.Left,R.Top,B); finally B.Free; end;
  FPages.Canvas.TextOut(Rect.Left+D(8),Rect.Top+D(10),IntToStr(Index+1));
  if (FPageDropIndex=Index) or ((Index=FPages.Count-1) and (FPageDropIndex=FPages.Count)) then begin
    FPages.Canvas.Pen.Color:=$E5B45B; FPages.Canvas.Pen.Width:=3;
    if FPageDropIndex=Index then I:=Rect.Top+1 else I:=Rect.Bottom-2;
    FPages.Canvas.MoveTo(Rect.Left,I); FPages.Canvas.LineTo(Rect.Right,I); FPages.Canvas.Pen.Width:=1;
  end;
end;
procedure TMainForm.Undo(Sender: TObject);
{$IFDEF DEBUG}var PerfScope: TComicPerfScope;{$ENDIF}
var P: TComicPage;
begin
  {$IFDEF DEBUG}PerfScope.Start(cpUndo);{$ENDIF}
  CancelDrag;
  ResetGeometryInput;
  if (FProject=nil) or (FUndo.Count=0) then Exit;
  FRedo.Add(FProject.Snapshot); FProject.Restore(FUndo.Last); FUndo.Delete(FUndo.Count-1);
  FSelectedPanels.Clear;
  for P in FProject.Pages do P.OutputRevision:=-1;
  FPageIndex:=Min(FPageIndex,FProject.Pages.Count-1); FPanelIndex:=-1; FBalloonIndex:=-1; FFirst:=False;
  FDirty:=True; FProject.SaveDraft; RefreshUI;
end;
procedure TMainForm.Redo(Sender: TObject);
{$IFDEF DEBUG}var PerfScope: TComicPerfScope;{$ENDIF}
var P: TComicPage;
begin
  {$IFDEF DEBUG}PerfScope.Start(cpRedo);{$ENDIF}
  CancelDrag;
  ResetGeometryInput;
  if (FProject=nil) or (FRedo.Count=0) then Exit;
  FUndo.Add(FProject.Snapshot); FProject.Restore(FRedo.Last); FRedo.Delete(FRedo.Count-1);
  FSelectedPanels.Clear;
  for P in FProject.Pages do P.OutputRevision:=-1;
  FPanelIndex:=-1; FBalloonIndex:=-1; FDirty:=True; FProject.SaveDraft; RefreshUI;
end;
procedure TMainForm.Template(Sender: TObject);
begin
  if FLayoutList.ItemIndex>=0 then ApplyLayout(TComicLayout(FLayoutList.Items.Objects[FLayoutList.ItemIndex]),-1);
end;
procedure TMainForm.InsertLayout(Sender: TObject);
var At: Integer;
begin
  if (FProject=nil) or (FLayoutList.ItemIndex<0) then Exit;
  if FPageIndex<0 then At:=FProject.Pages.Count else At:=FPageIndex+1;
  ApplyLayout(TComicLayout(FLayoutList.Items.Objects[FLayoutList.ItemIndex]),At);
end;
procedure TMainForm.ApplyLayout(Layout: TComicLayout; InsertAt: Integer);
var NewPage: TComicPage;
begin
  if not NeedProject or (Layout=nil) then Exit;
  if FImages.Count=0 then begin Notify('先に画像管理で使用する画像を登録してください。'); Exit; end;
  if InsertAt<0 then begin
    if Page=nil then Exit; Checkpoint; Layout.Apply(Page,FProject.Width,FProject.Height);
  end else begin
    NewPage:=TComicPage.Create;
    try Layout.Apply(NewPage,FProject.Width,FProject.Height);
    except NewPage.Free; raise; end;
    Checkpoint; FPageIndex:=EnsureRange(InsertAt,0,FProject.Pages.Count);
    FProject.Pages.Insert(FPageIndex,NewPage); FPages.Clear;
  end;
  FFirst:=False; FDragging:=False; FPanelIndex:=-1; FBalloonIndex:=-1; Changed;
end;
procedure TMainForm.RegisterLayout(Sender: TObject);
var Name: string; L: TComicLayout;
begin
  CancelDrag;
  if (Page=nil) or (Page.Panels.Count=0) then begin Notify('コマを作成してから登録してください。'); Exit; end;
  if not FLayoutLibraryWritable then begin Notify('既存ライブラリの読み込みエラーを解決してから登録してください。'); Exit; end;
  Name:='自作コマ割り'; if not InputQuery('コマ割りを共通登録','テンプレート名',Name) or (Trim(Name)='') then Exit;
  L:=TComicLayout.Create; L.Name:=Trim(Name); L.Capture(FProject,Page); FLayouts.Add(L);
  try SaveLayouts(FLayouts,TPath.Combine(DataRoot,'Presets\Layouts.json'));
  except FLayouts.Remove(L); raise; end;
  FLayoutList.Items.AddObject(L.Name,L); FLayoutList.ItemIndex:=FLayoutList.Count-1;
  UpdateIconState;
  FStatus.SimpleText:='コマ割りを登録しました。他の作品でも利用できます。画像と吹き出しは含みません。';
end;
procedure TMainForm.LayoutSelectionChanged(Sender: TObject);
begin UpdateIconState; end;
procedure TMainForm.RefreshLayouts(Index: Integer);
var Layout: TComicLayout;
begin
  FLayoutList.Items.BeginUpdate;
  try FLayoutList.Clear; for Layout in FLayouts do FLayoutList.Items.AddObject(Layout.Name,Layout);
    FLayoutList.ItemIndex:=Min(Index,FLayoutList.Count-1);
  finally FLayoutList.Items.EndUpdate; end;
  UpdateIconState;
end;
procedure TMainForm.RenameSelectedLayout(Sender: TObject);
var Layout: TComicLayout; Name: string; Index: Integer;
begin
  if not FLayoutLibraryWritable then Exit; Index:=FLayoutList.ItemIndex; if Index<0 then Exit;
  Layout:=TComicLayout(FLayoutList.Items.Objects[Index]); if Layout.BuiltIn then Exit;
  Name:=Layout.Name; if not InputQuery('テンプレート名の変更','名前',Name) then Exit;
  RenameLayout(FLayouts,Layout,Name,TPath.Combine(DataRoot,'Presets\Layouts.json')); RefreshLayouts(Index);
end;
procedure TMainForm.DeleteSelectedLayout(Sender: TObject);
var Layout: TComicLayout; Index: Integer;
begin
  if not FLayoutLibraryWritable then Exit; Index:=FLayoutList.ItemIndex; if Index<0 then Exit;
  Layout:=TComicLayout(FLayoutList.Items.Objects[Index]); if Layout.BuiltIn then Exit;
  if MessageDlg('共通テンプレート「'+Layout.Name+'」を削除しますか？適用済みページは保持されます。',mtConfirmation,[mbYes,mbNo],0)<>mrYes then Exit;
  RemoveLayout(FLayouts,Layout,TPath.Combine(DataRoot,'Presets\Layouts.json')); RefreshLayouts(Index);
end;
procedure TMainForm.DrawLayoutItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
var L: TComicLayout; Preview: TComicProject; B: TBitmap; R: TRect;
  function D(Value: Integer): Integer; begin Result:=MulDiv(Value,CurrentPPI,96); end;
begin
  FLayoutList.Canvas.FillRect(Rect); L:=TComicLayout(FLayoutList.Items.Objects[Index]);
  Preview:=TComicProject.Create; B:=TBitmap.Create;
  try
    Preview.Width:=L.Width; Preview.Height:=L.Height; Preview.Pages.Add(TComicPage.Create);
    L.Apply(Preview.Pages[0],L.Width,L.Height); B.SetSize(D(66),D(94));
    FRenderer.Draw(B.Canvas,Preview,Preview.Pages[0],System.Types.Rect(0,0,B.Width,B.Height),False);
    FLayoutList.Canvas.Draw(Rect.Left+D(8),Rect.Top+D(8),B);
    R:=System.Types.Rect(Rect.Left+D(84),Rect.Top+D(18),Rect.Right-D(8),Rect.Bottom-D(8));
    FLayoutList.Canvas.Brush.Style:=bsClear;
    DrawText(FLayoutList.Canvas.Handle,PChar(L.Name),Length(L.Name),R,DT_WORDBREAK or DT_NOPREFIX);
    FLayoutList.Canvas.Brush.Style:=bsSolid;
  finally B.Free; Preview.Free; end;
end;
procedure TMainForm.DrawImageItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
var A: TComicAsset; R: TRect;
  function D(Value: Integer): Integer; begin Result:=MulDiv(Value,CurrentPPI,96); end;
begin
  FImages.Canvas.FillRect(Rect); if FProject=nil then Exit;
  A:=TComicAsset(FImages.Items.Objects[Index]);
  R:=System.Types.Rect(Rect.Left+D(8),Rect.Top+D(8),Rect.Left+D(114),Rect.Top+D(88));
  FRenderer.DrawImage(FImages.Canvas,FProject.ImagePath(A.ID),R);
  R:=System.Types.Rect(Rect.Left+D(124),Rect.Top+D(18),Rect.Right-D(8),Rect.Bottom-D(6));
  FImages.Canvas.Brush.Style:=bsClear;
  DrawText(FImages.Canvas.Handle,PChar(A.Name),Length(A.Name),R,DT_WORDBREAK or DT_NOPREFIX);
  FImages.Canvas.Brush.Style:=bsSolid;
end;
procedure TMainForm.DetachImage(Sender: TObject);
var P: TComicPanel;
begin
  // ドラッグ取消でモデルが復元されるため、コマ参照を取得する前に取消を終える。
  CancelDrag;
  if (Page=nil) or (FPanelIndex<0) then Exit; P:=Page.Panels[FPanelIndex]; if P.ImageID='' then Exit;
  Checkpoint; P.ImageID:=''; P.Zoom:=1; P.PanX:=0; P.PanY:=0; Changed;
end;
function TMainForm.PageDropIndex(Y: Integer): Integer;
var Index: Integer; R: TRect;
begin
  Result:=FPages.Count;
  Index:=FPages.ItemAtPos(Point(8,Max(0,Y)),True);
  if Index>=0 then begin
    R:=FPages.ItemRect(Index); Result:=Index; if Y>=(R.Top+R.Bottom) div 2 then Inc(Result);
  end;
end;
procedure TMainForm.PagesDragOver(Sender,Source: TObject; X,Y: Integer; State: TDragState; var Accept: Boolean);
begin
  Accept:=(FProject<>nil) and HasCharacter and (((Source=FPages) and (FPages.SelCount>0)) or
    ((Source=FLayoutList) and (FLayoutList.ItemIndex>=0) and (FImages.Count>0)));
  if Accept and (State<>dsDragLeave) then begin FPageDropIndex:=PageDropIndex(Y);
    FStatus.SimpleText:=Format('%d ページ目の前に挿入します。',[FPageDropIndex+1]); end
  else FPageDropIndex:=-1;
  FPages.Invalidate;
end;
procedure TMainForm.PagesDragEnd(Sender,Target: TObject; X,Y: Integer);
begin FPageDropIndex:=-1; FPages.Invalidate; end;
procedure TMainForm.PagesDragDrop(Sender,Source: TObject; X,Y: Integer);
var At,I,Before: Integer; Ordered,Moved: TList<TComicPage>; Current: TComicPage; Same: Boolean;
begin
  CancelDrag;
  if (FProject=nil) or not HasCharacter then Exit; At:=PageDropIndex(Y); FPageDropIndex:=-1;
  if Source=FLayoutList then begin
    if FLayoutList.ItemIndex>=0 then ApplyLayout(TComicLayout(FLayoutList.Items.Objects[FLayoutList.ItemIndex]),At); Exit;
  end;
  if (Source<>FPages) or (FPages.SelCount=0) then Exit;
  Ordered:=TList<TComicPage>.Create; Moved:=TList<TComicPage>.Create;
  try
    Current:=Page; Before:=0;
    for I:=0 to FProject.Pages.Count-1 do
      if FPages.Selected[I] then begin Moved.Add(FProject.Pages[I]); if I<At then Inc(Before); end
      else Ordered.Add(FProject.Pages[I]);
    At:=At-Before; Ordered.InsertRange(At,Moved); Same:=True;
    for I:=0 to Ordered.Count-1 do if Ordered[I]<>FProject.Pages[I] then Same:=False;
    if Same then Exit; Checkpoint;
    for I:=0 to Ordered.Count-1 do FProject.Pages.Move(FProject.Pages.IndexOf(Ordered[I]),I);
    FPageIndex:=FProject.Pages.IndexOf(Current); Changed(False);
  finally Moved.Free; Ordered.Free; FPages.Invalidate; end;
end;
procedure TMainForm.PreservePanelImage(Panel: TComicPanel; const Original: TRectF);
begin RunWorkspacePreservePanelImage(Self,Panel,Original); end;
function TMainForm.VertexHandles(Panel: TComicPanel): TArray<TPointF>;
begin Result:=RunWorkspaceVertexHandles(Self,Panel); end;
function TMainForm.HitVertex(Panel: TComicPanel; const P: TPointF): Integer;
begin Result:=RunWorkspaceHitVertex(Self,Panel,P); end;
procedure TMainForm.EditVertexContext(const P: TPointF);
begin RunWorkspaceEditVertexContext(Self,P); end;
procedure TMainForm.ResetGeometryInput;
begin RunWorkspaceResetGeometryInput(Self); end;
function TMainForm.SnapCreationPoint(const P: TPointF; const ExcludePanelID: string): TPointF;
begin Result:=RunWorkspaceSnapCreationPoint(Self,P,ExcludePanelID); end;
function TMainForm.SnapPanelDragBounds(const Bounds: TRectF): TRectF;
begin Result:=RunWorkspaceSnapPanelDragBounds(Self,Bounds); end;
procedure TMainForm.PolygonClick(const P: TPointF);
begin RunWorkspacePolygonClick(Self,P); end;
procedure TMainForm.SplitClick(const P: TPointF);
begin RunWorkspaceSplitClick(Self,P); end;
procedure TMainForm.CommitSplit(Index: Integer);
begin RunWorkspaceCommitSplit(Self,Index); end;
procedure TMainForm.Tool(Sender: TObject);
begin
  CancelDrag;
  ResetGeometryInput;
  FTool:=TControl(Sender).Tag; FFirst:=False; FNumber:=1;
  if FTool=8 then FStatus.SimpleText:='頂点をクリック。最初の点で閉じる。右クリックで最後の点を戻す。Escで中止。'
  else if FTool=9 then FStatus.SimpleText:='分割する四角・凸多角形の外周の1点目をクリック。Escで中止。'
  else if FTool in [1,2,3,5,6,10] then FStatus.SimpleText:='対角の1点目、2点目をクリックしてください。Escで中止。'
  else if FTool=4 then FStatus.SimpleText:='読む順番にコマをクリックしてください。'
  else if FTool=13 then FStatus.SimpleText:='文字の内部をドラッグして移動。青8点で文字全体を比率維持で拡縮。'
  else FStatus.SimpleText:='対象を選択。ドラッグで移動、青8点で拡縮、黄色で頂点移動。頂点／辺を右クリックで削除／追加。';
  UpdateIconState;
end;
procedure TMainForm.Paint(Sender: TObject);
{$IFDEF DEBUG}var PerfScope: TComicPerfScope;{$ENDIF}
var C: TCanvas; R: TRect; B: TRectF; HandlePoint: TPointF; HX,HY,I: Integer; IDs: TArray<string>; Panel: TComicPanel; ID: string;
  function ScreenPoint(const P: TPointF): TPoint;
  begin Result:=Point(FPageRect.Left+Round(P.X*FScale),FPageRect.Top+Round(P.Y*FScale)); end;
  procedure GuideLine(const A,B: TPointF);
  var P,Q: TPoint;
  begin P:=ScreenPoint(A); Q:=ScreenPoint(B); C.MoveTo(P.X,P.Y); C.LineTo(Q.X,Q.Y); end;
begin
  {$IFDEF DEBUG}PerfScope.Start(cpPaint);{$ENDIF}
  C:=FCanvas.Canvas; C.Brush.Color:=$302B28; C.FillRect(FCanvas.ClientRect);
  if Page=nil then begin
    C.Font.Name:='Yu Gothic UI'; C.Font.Size:=15; C.Font.Color:=$D9D9D9; C.Brush.Style:=bsClear;
    if not HasCharacter then C.TextOut(36,80,'1. キャラ管理で人物と参照画像を登録')
    else C.TextOut(36,80,'2. 新規作品を作成、または作品を開く');
    C.Brush.Style:=bsSolid; Exit;
  end;
  UpdateViewport;
  FRenderer.Draw(C,FProject,Page,FPageRect,True);
  B:=TRectF.Empty;
  if (FPanelIndex>=0) and (FPanelIndex<Page.Panels.Count) then begin
    B:=Page.Panels[FPanelIndex].Bounds;
    if FTabs.ActivePageIndex=1 then B:=SelectedPanelBounds;
    if FTabs.ActivePageIndex=2 then B:=FRenderer.ImageBounds(FProject,Page.Panels[FPanelIndex]);
  end;
  if (FBalloonIndex>=0) and (FBalloonIndex<Page.Balloons.Count) then B:=Page.Balloons[FBalloonIndex].Bounds;
  if (FTool=13) and (FBalloonIndex>=0) then B:=FRenderer.BalloonTextBounds(Page.Balloons[FBalloonIndex]);
  if FTabs.ActivePageIndex=4 then begin
    B:=TRectF.Empty;
    if (FEffectCategory.ItemIndex=0) and (SelectedEffect<>nil) then B:=OverlayBounds(Page.Panels[FPanelIndex],SelectedEffect);
    if (B.IsEmpty) and (FPanelIndex>=0) and (FPanelIndex<Page.Panels.Count) then begin
      R.TopLeft:=ScreenPoint(Page.Panels[FPanelIndex].Bounds.TopLeft); R.BottomRight:=ScreenPoint(Page.Panels[FPanelIndex].Bounds.BottomRight);
      C.Pen.Color:=$E5B45B; C.Pen.Width:=2; C.Brush.Style:=bsClear; C.Rectangle(R); C.Brush.Style:=bsSolid;
    end;
  end;
  if not B.IsEmpty and not ((FTabs.ActivePageIndex=3) and (FTool=12)) then begin
    R:=Rect(FPageRect.Left+Round(B.Left*FScale),FPageRect.Top+Round(B.Top*FScale),FPageRect.Left+Round(B.Right*FScale),FPageRect.Top+Round(B.Bottom*FScale));
    C.Brush.Style:=bsClear; C.Pen.Color:=$E5B45B; C.Pen.Width:=2; C.Rectangle(R);
    C.Brush.Style:=bsSolid; C.Brush.Color:=$E5B45B;
    for HandlePoint in EditHandles(B) do begin
      HX:=FPageRect.Left+Round(HandlePoint.X*FScale); HY:=FPageRect.Top+Round(HandlePoint.Y*FScale);
      C.FillRect(Rect(HX-4,HY-4,HX+5,HY+5));
    end;
    C.Pen.Width:=1;
  end;
  if (FTabs.ActivePageIndex=1) and (FTool=0) and (FPanelIndex>=0) and (FPanelIndex<Page.Panels.Count) and (Length(SelectedPanelIDs)<=1) then begin
    C.Brush.Color:=$60D6FF; C.Pen.Color:=$202020; C.Brush.Style:=bsSolid;
    for HandlePoint in VertexHandles(Page.Panels[FPanelIndex]) do begin
      HX:=ScreenPoint(HandlePoint).X; HY:=ScreenPoint(HandlePoint).Y;
      C.Rectangle(HX-4,HY-4,HX+5,HY+5);
    end;
  end;
  if (FTabs.ActivePageIndex=3) and (FTool=12) and (FBalloonIndex>=0) and (FTailIndex>=0) and
    (FTailIndex<Page.Balloons[FBalloonIndex].Tails.Count) then begin
    C.Brush.Color:=$60D6FF;
    for HandlePoint in Page.Balloons[FBalloonIndex].Tails[FTailIndex].Handles do begin
      HX:=ScreenPoint(HandlePoint).X; HY:=ScreenPoint(HandlePoint).Y; C.FillRect(Rect(HX-4,HY-4,HX+5,HY+5));
    end;
  end;
  IDs:=SelectedPanelIDs;
  if (FTabs.ActivePageIndex=1) and (Length(IDs)>1) then begin
    C.Pen.Color:=$E5B45B; C.Pen.Width:=1; C.Brush.Style:=bsClear;
    for Panel in Page.Panels do for ID in IDs do if Panel.ID=ID then begin
      R:=Rect(ScreenPoint(Panel.Bounds.TopLeft).X,ScreenPoint(Panel.Bounds.TopLeft).Y,
        ScreenPoint(Panel.Bounds.BottomRight).X,ScreenPoint(Panel.Bounds.BottomRight).Y); C.Rectangle(R); Break;
    end;
    C.Brush.Style:=bsSolid;
  end;
  if FFirst then begin C.Pen.Color:=clRed; C.MoveTo(FPageRect.Left+Round(FStart.X*FScale)-6,FPageRect.Top+Round(FStart.Y*FScale));
    C.LineTo(FPageRect.Left+Round(FStart.X*FScale)+6,FPageRect.Top+Round(FStart.Y*FScale));
    if FTool in [7,11] then begin C.Pen.Style:=psDot; GuideLine(FStart,FLast); C.Pen.Style:=psSolid; end;
  end;
  if FGeometryPoints.Count>0 then begin
    C.Pen.Color:=$E5B45B; C.Pen.Width:=2;
    for I:=1 to FGeometryPoints.Count-1 do GuideLine(FGeometryPoints[I-1],FGeometryPoints[I]);
    C.Pen.Style:=psDot; GuideLine(FGeometryPoints.Last,FLast); C.Pen.Style:=psSolid;
    for HandlePoint in FGeometryPoints do begin
      HX:=ScreenPoint(HandlePoint).X; HY:=ScreenPoint(HandlePoint).Y;
      C.Brush.Color:=$E5B45B; C.FillRect(Rect(HX-3,HY-3,HX+4,HY+4));
    end;
    C.Pen.Width:=1;
  end;
  if FSplitStage>0 then begin
    C.Pen.Color:=$4040FF; C.Pen.Width:=2;
    if FSplitStage=1 then GuideLine(FSplitA,FLast) else GuideLine(FSplitA,FSplitB);
    if FSplitStage>=3 then begin
      C.Pen.Color:=$E5B45B; GuideLine(FSplitC,FSplitD);
      HX:=ScreenPoint(FSplitD).X; HY:=ScreenPoint(FSplitD).Y;
      C.Brush.Color:=$E5B45B; C.FillRect(Rect(HX-5,HY-5,HX+6,HY+6));
    end;
    C.Pen.Width:=1;
  end;
end;
procedure TMainForm.UpdateViewport;
begin RunWorkspaceUpdateViewport(Self); end;
procedure TMainForm.ResetViewport;
begin RunWorkspaceResetViewport(Self); end;
procedure TMainForm.BeginViewPan(Button: TMouseButton; X,Y: Integer);
begin RunWorkspaceBeginViewPan(Self,Button,X,Y); end;
procedure TMainForm.EndViewPan(Cancel: Boolean);
begin RunWorkspaceEndViewPan(Self,Cancel); end;
procedure TMainForm.ViewCaptureLost(Sender: TObject);
begin RunWorkspaceViewCaptureLost(Self,Sender); end;
procedure TMainForm.ViewWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
begin RunWorkspaceViewWheel(Self,Sender,Shift,WheelDelta,MousePos,Handled); end;
function TMainForm.EmptyViewPoint(const P: TPointF): Boolean;
begin Result:=RunWorkspaceEmptyViewPoint(Self,P); end;
function TMainForm.ToPage(X,Y: Integer): TPointF;
begin Result:=RunWorkspaceToPage(Self,X,Y); end;
function TMainForm.HitPanel(const P: TPointF): Integer;
{$IFDEF DEBUG}var PerfScope: TComicPerfScope;{$ENDIF}
var I: Integer; G: HRGN; R: TRectF;
begin
  {$IFDEF DEBUG}PerfScope.Start(cpPanelHit);{$ENDIF}
  Result:=-1; if Page=nil then Exit;
  for I:=Page.Panels.Count-1 downto 0 do begin
    R:=Page.Panels[I].Bounds; if not R.Contains(P) then Continue;
    G:=PanelRegion(Page.Panels[I],Point(0,0),1);
    try if PtInRegion(G,Round(P.X),Round(P.Y)) then Exit(I); finally Winapi.Windows.DeleteObject(G); end;
  end;
end;
function TMainForm.HitBalloon(const P: TPointF): Integer;
{$IFDEF DEBUG}var PerfScope: TComicPerfScope;{$ENDIF}
var I: Integer; G: HRGN; R: TRectF;
begin
  {$IFDEF DEBUG}PerfScope.Start(cpBalloonHit);{$ENDIF}
  Result:=-1; if Page=nil then Exit;
  for I:=Page.Balloons.Count-1 downto 0 do begin
    R:=Page.Balloons[I].Bounds; if not R.Contains(P) then Continue;
    if Page.Balloons[I].Transparent then Exit(I);
    G:=BalloonBodyRegion(Page.Balloons[I],Point(0,0),1);
    try if PtInRegion(G,Round(P.X),Round(P.Y)) then Exit(I); finally Winapi.Windows.DeleteObject(G); end;
  end;
end;
procedure TMainForm.CancelDrag;
begin RunWorkspaceCancelDrag(Self); end;
function TMainForm.SelectedPanelIDs: TArray<string>;
var Panel: TComicPanel; List: TList<string>;
begin
  Result:=nil; if (Page=nil) or (FPanelIndex<0) or (FPanelIndex>=Page.Panels.Count) then Exit;
  if (FTabs.ActivePageIndex<>1) or not FSelectedPanels.Contains(Page.Panels[FPanelIndex].ID) then begin
    Result:=[Page.Panels[FPanelIndex].ID]; Exit;
  end;
  List:=TList<string>.Create;
  try
    for Panel in Page.Panels do if FSelectedPanels.Contains(Panel.ID) then List.Add(Panel.ID);
    Result:=List.ToArray;
  finally List.Free; end;
end;
function TMainForm.SelectedPanelBounds: TRectF;
begin Result:=PanelGroupBounds(CapturePanelTransforms(Page,SelectedPanelIDs)); end;
procedure TMainForm.TogglePanelSelection(Index: Integer);
var I: Integer; ID: string;
begin
  if (Page=nil) or (Index<0) then Exit;
  if (FPanelIndex<0) or ((FPanelIndex<Page.Panels.Count) and not FSelectedPanels.Contains(Page.Panels[FPanelIndex].ID)) then
    SelectSinglePanel(FPanelIndex);
  if (FSelectedPanels.Count=0) and (FPanelIndex>=0) and (FPanelIndex<Page.Panels.Count) then
    FSelectedPanels.Add(Page.Panels[FPanelIndex].ID);
  ID:=Page.Panels[Index].ID;
  if FSelectedPanels.Contains(ID) then FSelectedPanels.Remove(ID) else FSelectedPanels.Add(ID);
  FPanelIndex:=-1; FBalloonIndex:=-1;
  for I:=0 to Page.Panels.Count-1 do if FSelectedPanels.Contains(Page.Panels[I].ID) then FPanelIndex:=I;
  UpdateIconState; FCanvas.Invalidate;
  FStatus.SimpleText:=Format('%d コマを選択。青8点で全体を拡縮、選択範囲の内部をドラッグして移動します。',[FSelectedPanels.Count]);
end;
// 主選択とUIDの選択集合を揃え、新規作成後のCtrl操作で古い複数選択が復活しないようにする。
procedure TMainForm.SelectSinglePanel(Index: Integer);
begin
  FSelectedPanels.Clear; FPanelIndex:=Index; FBalloonIndex:=-1;
  if (Page<>nil) and (Index>=0) and (Index<Page.Panels.Count) then FSelectedPanels.Add(Page.Panels[Index].ID);
end;
procedure TMainForm.EditBalloonText(Sender: TObject);
begin
  if (FTabs.ActivePageIndex<>3) or (FBalloonIndex<0) or (FTool<>0) then Exit;
  CancelDrag; LoadBalloonControls(Page.Balloons[FBalloonIndex]);
  ActiveControl:=FText;
  FText.SelectAll;
end;
procedure TMainForm.MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X,Y: Integer);
begin RunWorkspaceMouseDown(Self,Sender,Button,Shift,X,Y); end;
procedure TMainForm.MouseMove(Sender: TObject; Shift: TShiftState; X,Y: Integer);
begin RunWorkspaceMouseMove(Self,Sender,Shift,X,Y); end;
procedure TMainForm.MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X,Y: Integer);
begin RunWorkspaceMouseUp(Self,Sender,Button,Shift,X,Y); end;
procedure TMainForm.DeleteObject(Sender: TObject);
begin RunWorkspaceDeleteObject(Self,Sender); end;
procedure TMainForm.AssignImage(Sender: TObject);
begin RunWorkspaceAssignImage(Self,Sender); end;
procedure TMainForm.DragOver(Sender,Source: TObject; X,Y: Integer; State: TDragState; var Accept: Boolean);
begin RunWorkspaceDragOver(Self,Sender,Source,X,Y,State,Accept); end;
procedure TMainForm.DragDrop(Sender,Source: TObject; X,Y: Integer);
begin RunWorkspaceDragDrop(Self,Sender,Source,X,Y); end;
procedure TMainForm.ApplyText(Sender: TObject);
begin RunWorkspaceApplyText(Self,Sender); end;
procedure TMainForm.LoadBalloonControls(Balloon: TComicBalloon);
begin RunWorkspaceLoadBalloonControls(Self,Balloon); end;
procedure TMainForm.FontDropDown(Sender: TObject);
begin RunWorkspaceFontDropDown(Self,Sender); end;
procedure TMainForm.ChooseTextColor(Sender: TObject);
begin RunWorkspaceChooseTextColor(Self,Sender); end;
procedure TMainForm.TextInputDialog(Sender: TObject);
begin RunWorkspaceTextInputDialog(Self,Sender); end;
function TMainForm.CreateBalloonTextDialog: TComicTextDialog;
var Dialog: TComicTextDialog;
begin
  Dialog:=TComicTextDialog.CreateEditor(Self,FText.Text,FVertical.Checked,FTesting);
  Dialog.Editor.Font.Name:=FFontFamily.Text; Dialog.Editor.Font.Height:=-MulDiv(StrToIntDef(FFont.Text,40),Dialog.CurrentPPI,96);
  Dialog.Editor.Font.Color:=FTextColor; Dialog.Editor.Font.Style:=[];
  if FFontBold.Checked then Dialog.Editor.Font.Style:=Dialog.Editor.Font.Style+[fsBold];
  if FFontItalic.Checked then Dialog.Editor.Font.Style:=Dialog.Editor.Font.Style+[fsItalic];
  if FFontUnderline.Checked then Dialog.Editor.Font.Style:=Dialog.Editor.Font.Style+[fsUnderline];
  if FFontStrikeOut.Checked then Dialog.Editor.Font.Style:=Dialog.Editor.Font.Style+[fsStrikeOut];
  Result:=Dialog;
end;
procedure TMainForm.FinishTextDialog(Dialog: TComicTextDialog);
begin RunWorkspaceFinishTextDialog(Self,Dialog); end;
procedure TMainForm.Tail(Sender: TObject);
begin RunWorkspaceTail(Self,Sender); end;
function TMainForm.InsideBalloonBody(Balloon: TComicBalloon; const P: TPointF): Boolean;
begin Result:=RunWorkspaceInsideBalloonBody(Self,Balloon,P); end;
procedure TMainForm.TailClick(const P: TPointF);
begin RunWorkspaceTailClick(Self,P); end;
procedure TMainForm.TailEditClick(const P: TPointF);
begin RunWorkspaceTailEditClick(Self,P); end;
procedure TMainForm.DeleteTail(Sender: TObject);
begin RunWorkspaceDeleteTail(Self,Sender); end;
function TMainForm.CreateExportOptions: TComicExportDialog;
var Page: TComicPage; Panel: TComicPanel; IDs: TDictionary<string,Boolean>; Missing,Duplicate: Integer; Warnings: string;
begin
  CancelDrag; Missing:=0; Duplicate:=0; Warnings:=''; IDs:=TDictionary<string,Boolean>.Create;
  try
    for Page in FProject.Pages do for Panel in Page.Panels do begin
      if (Panel.ImageID='') or not FileExists(FProject.ImagePath(Panel.ImageID)) then Inc(Missing);
      if Panel.ImageID<>'' then
        if IDs.ContainsKey(Panel.ImageID) then Inc(Duplicate) else IDs.Add(Panel.ImageID,True);
    end;
  finally IDs.Free; end;
  if Missing>0 then Warnings:=Format('画像未配置・参照切れ：%d コマ。画像のない部分も含めて出力します。',[Missing]);
  if Duplicate>0 then begin
    if Warnings<>'' then Warnings:=Warnings+sLineBreak;
    Warnings:=Warnings+Format('同じ画像の重複配置：%d コマ。重複したまま出力します。',[Duplicate]);
  end;
  Result:=TComicExportDialog.CreateOptions(Self,TPath.Combine(FProject.Folder,'Output'),OpenOutput,Warnings);
end;
procedure TMainForm.Notify(const Message: string);
begin if FTesting then raise Exception.Create(Message) else ShowMessage(Message); end;
procedure TMainForm.ExportPNG(Sender: TObject);
var All: Boolean; N: Integer; Output: string; D: TComicExportDialog;
begin
  CancelDrag;
  if not NeedProject then Exit;
  Output:=TPath.Combine(FProject.Folder,'Output'); ForceDirectories(Output);
  D:=CreateExportOptions;
  try
    D.ShowModal; if not D.Accepted(All) then Exit;
  finally D.Free; end;
  Screen.Cursor:=crHourGlass;
  try
    N:=ExportSequence(FProject,FRenderer,All); FDirty:=True; RefreshUI;
    Notify(Format('%d ページを出力しました（再描画 %d ページ）。',[FProject.Pages.Count,N])+sLineBreak+Output);
  finally Screen.Cursor:=crDefault; end;
end;
procedure TMainForm.CloseCheck(Sender: TObject; var CanClose: Boolean);
begin CancelDrag; CanClose:=ConfirmLeave; end;
procedure TMainForm.OpenOutput(Sender: TObject);
begin if FProject<>nil then ShellExecute(Handle,'open',PChar(TPath.Combine(FProject.Folder,'Output')),nil,nil,SW_SHOWNORMAL); end;
procedure TMainForm.Key(Sender: TObject; var Key: Word; Shift: TShiftState);
var Panel: TComicPanel;
begin
  if not GlobalShortcutsAllowed then Exit;
  if FTabs.Enabled then begin
    if (Key=VK_TAB) and ((Shift=[ssCtrl]) or (Shift=[ssCtrl,ssShift])) then begin
      if ssShift in Shift then FPreviousModeMenu.Click else FNextModeMenu.Click;
      Key:=0; Exit;
    end;
    if (Shift=[ssCtrl]) and (Key>=Ord('1')) and (Key<=Ord('1')+High(FModeMenu)) then begin
      FModeMenu[Key-Ord('1')].Click; Key:=0; Exit;
    end;
    if (Shift=[ssCtrl]) and (Key=Ord('A')) and (ActiveControl=FView) and (FTabs.ActivePageIndex=1) and (Page<>nil) then begin
      CancelDrag; FSelectedPanels.Clear; for Panel in Page.Panels do FSelectedPanels.Add(Panel.ID);
      FPanelIndex:=Page.Panels.Count-1; FBalloonIndex:=-1; FTool:=0; FFirst:=False; ResetGeometryInput;
      UpdateIconState; FCanvas.Invalidate; Key:=0; Exit;
    end;
  end;
  if (Shift=[ssCtrl]) and (Key in [Ord('0'),VK_NUMPAD0]) and (FProject<>nil) then begin FitView(nil); Key:=0; Exit; end;
  if (Shift=[]) and (Key=VK_DELETE) and (ActiveControl=FView) and (FTabs.ActivePageIndex=1) then begin DeleteObject(nil); Key:=0; Exit; end;
  if (Shift=[]) and (Key=VK_DELETE) and (ActiveControl=FView) and (FTabs.ActivePageIndex=2) then begin DetachImage(nil); Key:=0; Exit; end;
  if (Shift=[]) and (Key=VK_DELETE) and (ActiveControl=FView) and (FTabs.ActivePageIndex=4) then begin DeleteEffect(nil); Key:=0; Exit; end;
  if (Shift=[]) and (Key=VK_ESCAPE) then begin CancelDrag; ResetGeometryInput; FFirst:=False; FTool:=0; UpdateIconState; FCanvas.Invalidate; Key:=0; end;
end;

end.
