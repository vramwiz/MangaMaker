unit MangaMakerMainForm;

interface

uses Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, Winapi.Imm, System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math,
  System.IOUtils, System.Generics.Collections, System.JSON, System.Hash, Vcl.Controls, Vcl.Forms,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Menus, Vcl.Dialogs,
  Vcl.Graphics, Vcl.Imaging.pngimage, ComicModel, ComicRender, ComicAssetDialog, ComicLayouts, ComicExport, ComicEditing, ComicIconButton, ComicGeometry, ComicTextInput, ComicTextLayout, WindowsImeController, ComicPagePresets, ComicPageDialog, ComicPanelTransform, ComicFontHistory, ComicGenerationPresets, ComicGenerationDialog, ComicBridge, ComicAssetEditing, ComicCharacterRefs, ComicEffects, ComicEffectDialog, ComicFilters, ComicRecentProjects, ComicGapSnap, ComicExportDialog, ComicProjectDialog;

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
  TMainForm = class(TForm)
  private
    FBridge: TComicBridge;
    FAssetManager: TAssetDialog;
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
    FFont,FZoom: TComboBox;
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
    FIconTestClicks: Integer;
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
    procedure IconTestClick(Sender: TObject);
    procedure ModeClick(Sender: TObject);
    procedure ButtonHelp(Sender: TObject);
    procedure IconNavigate(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure UpdateIconState;
    procedure CancelDrag;
    procedure EditBalloonText(Sender: TObject);
    procedure BuildUI;
    function Page: TComicPage;
    function HasCharacter: Boolean;
    function NeedProject: Boolean;
    function ConfirmLeave: Boolean;
    procedure Checkpoint;
    procedure Changed(ContentChanged: Boolean=True);
    procedure RefreshUI;
    procedure ShowPageStatus;
    procedure SyncZoom;
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
    procedure ImageZoom(Sender: TObject);
    procedure ImageSelectionChanged(Sender: TObject);
    procedure Tail(Sender: TObject);
    procedure CloseCheck(Sender: TObject; var CanClose: Boolean);
    procedure Key(Sender: TObject; var Key: Word; Shift: TShiftState);
  protected
    function CreateProjectDialog: TComicProjectOpenDialog; virtual;
  public
    procedure SmokeTest(const Folder: string);
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  MainForm: TMainForm;

implementation

{$R *.dfm}

function PrintWindow(hWnd: HWND; hdcBlt: HDC; nFlags: UINT): BOOL; stdcall; external 'user32.dll';

procedure TComicView.WndProc(var Message: TMessage);
begin
  if ((Message.Msg=WM_CAPTURECHANGED) or (Message.Msg=WM_CANCELMODE) or (Message.Msg=CM_CANCELMODE)) and
    Assigned(OnCaptureLost) then OnCaptureLost(Self);
  inherited;
end;
constructor TMainForm.Create(AOwner: TComponent);
begin
  inherited; FPageIndex:=-1; FPanelIndex:=-1; FBalloonIndex:=-1; FTailIndex:=-1; FDragVertex:=-1; FScale:=1; FViewZoom:=1; FFillColor:=clWhite; FEffectIndex:=-1;
  FTesting:=(ParamCount>0) and (ParamStr(1)='--self-test');
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
begin if FView<>nil then FView.OnCaptureLost:=nil; EndViewPan(False); FBridge.Free; FProject.Free; FCharacters.Free; FRenderer.Free; FUndo.Free; FRedo.Free; FLayouts.Free; FPagePresets.Free; FFontHistory.Free; FGenerationPresets.Free; FEffectMaterials.Free; FRecent.Free; FIconButtons.Free; FGeometryPoints.Free; FSelectedPanels.Free; inherited; end;
procedure TMainForm.BridgeRequest(const Request: string; out Reply: string);
var Value: TJSONValue; Input,Output,Data,Info: TJSONObject; Items: TJSONArray;
  Action,Scope,ID,ParentID,Root,Path,Relative,Before,OldFile,Ext,RequestID,Mode,SourceID,RefID: string;
  Assets: TObjectList<TComicAsset>; Asset,Parent,Created,Source,Ref,RefProbe: TComicAsset; Preset: TComicGenerationPreset;
  ParsedRefs: TArray<string>; RefData,RefParent: TJSONObject;
  Picture: TPicture; Characters,Mutating: Boolean; Pair: TJSONPair; Keys: TDictionary<string,Boolean>; WriteTarget: TWinControl;
  function Text(const Name: string; Required: Boolean=False; Limit: Integer=65536): string;
  var Item: TJSONValue;
  begin
    Item:=Input.GetValue(Name); Result:='';
    if Item=nil then begin if Required then raise Exception.Create('必須項目がありません：'+Name); Exit; end;
    if not (Item is TJSONString) then raise Exception.Create('文字列で指定してください：'+Name);
    Result:=Item.Value;
    if (Length(Result)>Limit) or (Pos(#0,Result)>0) or (Required and (Result='')) then raise Exception.Create('値が不正です：'+Name);
  end;
  procedure RequireProject;
  begin
    if FProject=nil then raise Exception.Create('作品が開かれていません。');
    if Text('projectId',True,200)<>FProject.ID then raise Exception.Create('対象作品が切り替わりました。状態を取得し直してください。');
  end;
  procedure SelectLibrary;
  begin
    Scope:=Text('library',True,20); Characters:=Scope='characters';
    if Characters then begin Assets:=FCharacters; Root:=TPath.Combine(DataRoot,'Characters'); end
    else if Scope='images' then begin RequireProject; Assets:=FProject.Assets; Root:=FProject.Folder; end
    else raise Exception.Create('libraryはcharactersまたはimagesで指定してください。');
    if Mutating then begin
      if Characters and not FCharacterLibraryWritable then raise Exception.Create('共通キャラは読み取りのみです。');
      if not Characters and not HasCharacter then raise Exception.Create('有効なキャラクターを先に登録してください。');
    end;
  end;
  function FindAsset(const UID: string): TComicAsset;
  var Item: TComicAsset;
  begin Result:=nil; for Item in Assets do if Item.ID=UID then Exit(Item); end;
  function AssetData(Item: TComicAsset): TJSONObject;
  begin
    Result:=Item.Json; if Item.FileName<>'' then Result.AddPair('referencePath',SafeChild(Root,Item.FileName)) else Result.AddPair('referencePath','');
    if Characters then Result.AddPair('storageFolder',Root) else Result.AddPair('storageFolder',TPath.Combine(Root,'Images'));
    if (FAssetManager<>nil) and (FAssetManager.CurrentAsset=Item) then begin
      Result.AddPair('draftName',FAssetManager.DraftName.Text); Result.AddPair('draftNotes',FAssetManager.DraftNotes.Text);
      if FAssetManager.IsCharacters then begin
        Result.AddPair('draftCharacterName',FAssetManager.CommonName.Text); Result.AddPair('draftCharacterNotes',FAssetManager.CommonNotes.Text);
      end;
    end;
  end;
  function CharacterData(Item: TComicAsset): TJSONObject;
  begin
    Result:=Item.Json;
    if Item.FileName<>'' then Result.AddPair('referencePath',SafeChild(TPath.Combine(DataRoot,'Characters'),Item.FileName))
    else Result.AddPair('referencePath','');
    if (FAssetManager<>nil) and FAssetManager.IsCharacters and (FAssetManager.CurrentAsset<>nil) and
      (FAssetManager.CurrentAsset.CharacterID=Item.CharacterID) then begin
      Result.AddPair('draftCharacterName',FAssetManager.CommonName.Text); Result.AddPair('draftCharacterNotes',FAssetManager.CommonNotes.Text);
    end;
  end;
  procedure Persist;
  begin
    if Characters then WriteAssets(Assets,TPath.Combine(Root,'Library.json'))
    else AtomicWrite(TPath.Combine(Root,'Draft.json'),FProject.Snapshot);
  end;
  procedure Published;
  var Warnings: TJSONArray;
    procedure Warn(const Message: string);
    begin if Warnings=nil then begin Warnings:=TJSONArray.Create; Data.AddPair('warnings',Warnings); end; Warnings.Add(Message); end;
  begin
    Warnings:=nil;
    if not Characters then begin
      if (FAssetManager=nil) or FAssetManager.IsCharacters then begin FUndo.Add(Before); FRedo.Clear; if FUndo.Count>40 then FUndo.Delete(0); end;
      FDirty:=True; FRenderer.ClearCache;
    end;
    if FAssetManager<>nil then
      try FAssetManager.RefreshFromExternal; if FAssetManager.PreviewError<>'' then Warn('参照画像の表示: '+FAssetManager.PreviewError);
      except on E: Exception do Warn('管理画面の更新: '+E.Message); end;
    try RefreshUI; except on E: Exception do Warn('ページ画面の更新: '+E.Message); end;
  end;
begin
  Value:=TJSONObject.ParseJSONValue(Request); Output:=TJSONObject.Create; Keys:=TDictionary<string,Boolean>.Create;
  try
    try
      if not (Value is TJSONObject) then raise Exception.Create('要求はJSONオブジェクトで指定してください。');
      Input:=TJSONObject(Value);
      for Pair in Input do begin if Keys.ContainsKey(Pair.JsonString.Value) then raise Exception.Create('同じ項目を重複指定できません。'); Keys.Add(Pair.JsonString.Value,True); end;
      if JNum(Input,'version',0)<>1 then raise Exception.Create('version:1を指定してください。');
      RequestID:=Text('requestId',False,128); if RequestID<>'' then Output.AddPair('requestId',RequestID);
      Action:=Text('action',True,40); Data:=TJSONObject.Create; Output.AddPair('data',Data);
      Mutating:=(Action='create_asset') or (Action='register_image');
      if Mutating and (FDragging or FFirst or (FGeometryPoints.Count>0) or (FSplitStage>0)) then raise Exception.Create('編集操作の確定または取消後に登録してください。');
      WriteTarget:=Self; if FAssetManager<>nil then WriteTarget:=FAssetManager;
      // Native common dialogs do not become Screen.ActiveCustomForm. Their
      // disabled owner window is still a reliable boundary for bridge writes.
      if Mutating and WriteTarget.HandleAllocated and not IsWindowEnabled(WriteTarget.Handle) then
        raise Exception.Create('開いているダイアログを閉じてから登録してください。');
      if Mutating and not FTesting and (Screen.ActiveCustomForm<>nil) and (Screen.ActiveCustomForm<>Self) and
        (Screen.ActiveCustomForm<>FAssetManager) then raise Exception.Create('別の編集画面を閉じてから登録してください。');
      if Action='status' then begin
        Data.AddPair('version',TJSONNumber.Create(1)); Data.AddPair('characterLibraryWritable',TJSONBool.Create(FCharacterLibraryWritable));
        Data.AddPair('canProduce',TJSONBool.Create(HasCharacter));
        if FProject<>nil then begin
          Info:=TJSONObject.Create; Data.AddPair('project',Info); Info.AddPair('id',FProject.ID); Info.AddPair('title',FProject.Title);
          Info.AddPair('episode',FProject.Episode); Info.AddPair('folder',FProject.Folder); Info.AddPair('pageId','');
          if Page<>nil then begin Pair:=Info.RemovePair('pageId'); Pair.Free; Info.AddPair('pageId',Page.ID); end;
          Info.AddPair('generationPresetId',FProject.GenerationPresetID); Info.AddPair('generationPresetName',FProject.GenerationPresetName);
          Info.AddPair('generationInstructions',FProject.GenerationInstructions);
        end;
        if (FAssetManager<>nil) and (FAssetManager.CurrentAsset<>nil) then begin
          Characters:=FAssetManager.IsCharacters;
          if Characters then begin Root:=TPath.Combine(DataRoot,'Characters'); Scope:='characters'; end
          else begin Root:=FProject.Folder; Scope:='images'; end;
          Info:=AssetData(FAssetManager.CurrentAsset); Info.AddPair('library',Scope); Data.AddPair('selection',Info);
        end else if (FProject<>nil) and (FImages.ItemIndex>=0) then begin
          Characters:=False; Root:=FProject.Folder; Info:=AssetData(TComicAsset(FImages.Items.Objects[FImages.ItemIndex]));
          Info.AddPair('library','images'); Data.AddPair('selection',Info);
        end;
      end else if Action='list_presets' then begin
        Items:=TJSONArray.Create; Data.AddPair('presets',Items); for Preset in FGenerationPresets do Items.AddElement(Preset.Json);
        Data.AddPair('writable',TJSONBool.Create(FGenerationWritable));
      end else if (Action='list_assets') or (Action='read_asset') then begin
        SelectLibrary;
        if Action='list_assets' then begin Items:=TJSONArray.Create; Data.AddPair('assets',Items); for Asset in Assets do Items.AddElement(AssetData(Asset)); end
        else begin
          Asset:=FindAsset(Text('assetId',True,200)); if Asset=nil then raise Exception.Create('対象IDが見つかりません。');
          Data.AddPair('asset',AssetData(Asset)); Parent:=FindAsset(Asset.ParentID); if Parent<>nil then Data.AddPair('parent',AssetData(Parent));
          if not Characters then begin
            Source:=FindAsset(Asset.SourceID);
            if (Source<>nil) and (Source<>Parent) then Data.AddPair('source',AssetData(Source));
            if (Asset.SourceID<>'') and (Source=nil) then Data.AddPair('sourceMissing',TJSONBool.Create(True));
            Items:=TJSONArray.Create; Data.AddPair('references',Items);
            for RefID in Asset.CharacterRefs do begin
              Ref:=AssetByID(FCharacters,RefID); RefData:=TJSONObject.Create; Items.AddElement(RefData);
              RefData.AddPair('id',RefID);
              if Ref=nil then RefData.AddPair('missing',TJSONBool.Create(True))
              else begin
                RefData.AddPair('asset',CharacterData(Ref)); Parent:=CharacterRoot(FCharacters,Ref);
                if Parent<>Ref then begin RefParent:=CharacterData(Parent); RefData.AddPair('parent',RefParent); end;
              end;
            end;
          end;
        end;
      end else if Action='create_asset' then begin
        SelectLibrary; ParentID:=Text('parentId',False,200); Parent:=FindAsset(ParentID);
        if (ParentID<>'') and ((Parent=nil) or (Parent.ParentID<>'')) then raise Exception.Create('子は既存の親を指定してください。');
        ID:=Trim(Text('name',True,200)); if ID='' then raise Exception.Create('名前を指定してください。'); Path:=Text('notes');
        Mode:=Text('mode',False,40); SourceID:=Text('sourceId',False,200); Source:=nil;
        if not Characters then begin
          if SourceID<>'' then Source:=FindAsset(SourceID) else Source:=Parent;
          if (SourceID<>'') and (Source=nil) then raise Exception.Create('参照元の画像が見つかりません。');
          if Mode='' then begin if Source<>nil then Mode:='child' else Mode:='scene'; end;
          if (Mode='scene') and ((ParentID<>'') or (SourceID<>'')) then raise Exception.Create('新規場面には参照元を指定しません。');
          if (Mode='alternate_scene') and (ParentID<>'') then raise Exception.Create('別位置の背景は親階層へ追加します。');
          RefProbe:=TComicAsset.Create;
          try RefProbe.Read(Input); ParsedRefs:=Copy(RefProbe.CharacterRefs); finally RefProbe.Free; end;
          for RefID in ParsedRefs do if AssetByID(FCharacters,RefID)=nil then raise Exception.Create('参照人物IDが見つかりません：'+RefID);
          if ((Mode='scene') or (Mode='alternate_scene')) and (Length(ParsedRefs)>0) then raise Exception.Create('背景の親は人物を参照しません。');
        end else if (Mode<>'') or (SourceID<>'') or (Input.GetValue('characterIds')<>nil) then raise Exception.Create('人物登録には画像用の追加方式を指定できません。');
        if FAssetManager<>nil then FAssetManager.FlushDraft;
        if not Characters then Before:=FProject.Snapshot;
        if Characters then begin Created:=TComicAsset.Create; Created.Name:=ID; Created.Notes:=Path; Created.ParentID:=ParentID; end
        else begin
          Created:=NewSceneAsset(Assets,Source,Mode,ID,Path,FProject.Title,FProject.Episode);
          if Input.GetValue('characterIds')<>nil then Created.CharacterRefs:=Copy(ParsedRefs);
        end;
        Assets.Add(Created);
        if Characters then NormalizeCharacters(Assets);
        try Persist; except Assets.Remove(Created); raise; end;
        Data.AddPair('asset',AssetData(Created)); Published;
      end else if Action='register_image' then begin
        SelectLibrary; Asset:=FindAsset(Text('assetId',True,200)); if Asset=nil then raise Exception.Create('対象IDが見つかりません。');
        if (Input.GetValue('expectedFileName')<>nil) and (Text('expectedFileName',False,1024)<>Asset.FileName) then
          raise Exception.Create('対象画像が更新されています。状態を取得し直してください。');
        Path:=Text('sourcePath',True,4096);
        if not TPath.IsPathRooted(Path) or Path.StartsWith('\\') then raise Exception.Create('画像はローカルの絶対パスで指定してください。');
        Path:=TPath.GetFullPath(Path); Ext:=LowerCase(ExtractFileExt(Path));
        if (Ext<>'.png') and (Ext<>'.jpg') and (Ext<>'.jpeg') and (Ext<>'.bmp') then raise Exception.Create('PNG/JPEG/BMP画像を指定してください。');
        if not FileExists(Path) then raise Exception.Create('画像ファイルがありません。');
        Picture:=TPicture.Create;
        try Picture.LoadFromFile(Path); if (Picture.Width<1) or (Picture.Height<1) or
          (Int64(Picture.Width)*Picture.Height>64000000) then raise Exception.Create('画像のサイズが不正です。');
        finally Picture.Free; end;
        if FAssetManager<>nil then FAssetManager.FlushDraft;
        if not Characters then Before:=FProject.Snapshot;
        Relative:=NewUID+Ext; if not Characters then Relative:='Images\'+Relative;
        OldFile:=Asset.FileName; ID:=SafeChild(Root,Relative); ForceDirectories(ExtractFilePath(ID)); TFile.Copy(Path,ID,False);
        try Asset.FileName:=Relative; Persist;
        except Asset.FileName:=OldFile; try TFile.Delete(ID); except end; raise; end;
        Data.AddPair('asset',AssetData(Asset)); Published;
      end else raise Exception.Create('未対応の操作です：'+Action);
      Output.AddPair('ok',TJSONBool.Create(True));
    except on E: Exception do begin Pair:=Output.RemovePair('data'); Pair.Free;
      Output.AddPair('ok',TJSONBool.Create(False)); Output.AddPair('error',E.Message); end; end;
    Reply:=Output.ToJSON;
  finally Keys.Free; Output.Free; Value.Free; end;
end;
procedure TMainForm.RefreshEffectMaterials;
var Material: TComicEffectMaterial; At: Integer;
begin
  At:=FEffectList.ItemIndex; FEffectList.Items.BeginUpdate;
  try FEffectList.Clear; for Material in FEffectMaterials do FEffectList.Items.AddObject(Material.Name,Material);
    FEffectList.ItemIndex:=Max(0,Min(At,FEffectList.Count-1));
  finally FEffectList.Items.EndUpdate; end;
end;
procedure TMainForm.EffectMaterials(Sender: TObject);
var Dialog: TComicEffectDialog; Prepared,Previous: TObjectList<TComicEffectMaterial>;
begin
  if not FEffectLibraryWritable then begin
    Prepared:=TObjectList<TComicEffectMaterial>.Create; SeedEffectMaterials(Prepared);
    try
      try
        LoadEffectMaterials(Prepared,TPath.Combine(DataRoot,'Effects\Library.json'));
        FEffectList.Items.Clear; Previous:=FEffectMaterials; FEffectMaterials:=Prepared; Prepared:=nil; Previous.Free; FEffectLibraryWritable:=True;
        RefreshEffectMaterials;
      except on E: Exception do FStatus.SimpleText:='効果素材ライブラリは読み取りのみです：'+E.Message; end;
    finally Prepared.Free; end;
  end;
  Dialog:=TComicEffectDialog.CreateManager(Self,FEffectMaterials,FEffectLibraryWritable,TPath.Combine(DataRoot,'Effects\Library.json'),EffectLibraryChanged);
  try Dialog.ShowModal; finally Dialog.Free; end;
  RefreshEffectMaterials; FRenderer.ClearCache; FCanvas.Invalidate;
end;
procedure TMainForm.EffectLibraryChanged(Sender: TObject);
begin RefreshEffectMaterials; FRenderer.ClearCache; FCanvas.Invalidate; end;
procedure TMainForm.EffectCategoryChanged(Sender: TObject);
begin CancelDrag; FEffectIndex:=-1; FEffectPages.ActivePageIndex:=FEffectCategory.ItemIndex; LoadPanelEffectControls; UpdateIconState; FCanvas.Invalidate; end;
procedure TMainForm.DrawEffectItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
var R: TRect; Material: TComicEffectMaterial; C: TCanvas; X,Y,Step: Integer;
begin
  C:=FEffectList.Canvas; C.Brush.Color:=$302B28; C.FillRect(Rect); Material:=TComicEffectMaterial(FEffectList.Items.Objects[Index]);
  Step:=MulDiv(8,CurrentPPI,96); R:=System.Types.Rect(Rect.Left+8,Rect.Top+6,Rect.Right-8,Rect.Top+MulDiv(84,CurrentPPI,96));
  Y:=R.Top;
  while Y<R.Bottom do begin X:=R.Left; while X<R.Right do begin
    if (((X-R.Left) div Step+(Y-R.Top) div Step) mod 2)=0 then C.Brush.Color:=clWhite else C.Brush.Color:=$CCCCCC;
    C.FillRect(System.Types.Rect(X,Y,Min(R.Right,X+Step),Min(R.Bottom,Y+Step))); Inc(X,Step); end; Inc(Y,Step); end;
  try FRenderer.DrawOverlay(C,EffectMaterialPath(Material),R); except end;
  C.Font.Color:=clWhite; C.Brush.Style:=bsClear; C.TextOut(Rect.Left+8,R.Bottom+4,Material.Name); C.Brush.Style:=bsSolid;
  if odSelected in State then begin C.Brush.Style:=bsClear; C.Pen.Color:=$E5B45B; C.Rectangle(Rect); C.Brush.Style:=bsSolid; end;
end;
function TMainForm.SelectedEffect: TComicOverlay;
begin
  Result:=nil; if (Page=nil) or (FPanelIndex<0) or (FPanelIndex>=Page.Panels.Count) then Exit;
  if (FEffectIndex>=0) and (FEffectIndex<Page.Panels[FPanelIndex].Overlays.Count) then Result:=Page.Panels[FPanelIndex].Overlays[FEffectIndex];
end;
function TMainForm.HitEffect(Panel: TComicPanel; const P: TPointF): Integer;
var I: Integer;
begin Result:=-1; for I:=Panel.Overlays.Count-1 downto 0 do if OverlayBounds(Panel,Panel.Overlays[I]).Contains(P) then Exit(I); end;
procedure TMainForm.ApplyEffectMaterial(PanelIndex: Integer; Material: TComicEffectMaterial);
var Overlay: TComicOverlay; Source,Dest: string; PNG: TPngImage;
begin
  CancelDrag;
  if (Page=nil) or (PanelIndex<0) or (PanelIndex>=Page.Panels.Count) or (Material=nil) or not HasCharacter then Exit;
  if Page.Panels[PanelIndex].Overlays.Count>=1000 then raise Exception.Create('コマの効果素材は1000件までです。');
  Source:=EffectMaterialPath(Material); PNG:=TPngImage.Create;
  try PNG.LoadFromFile(Source); if (PNG.Width<1) or (PNG.Height<1) or (Int64(PNG.Width)*PNG.Height>64000000) then raise Exception.Create('効果素材のサイズが不正です。');
  finally PNG.Free; end;
  Overlay:=TComicOverlay.Create; Overlay.MaterialID:=Material.ID; Overlay.FileName:='Effects\'+NewUID+'.png'; Dest:=SafeChild(FProject.Folder,Overlay.FileName);
  try
    ForceDirectories(ExtractFilePath(Dest)); TFile.Copy(Source,Dest,False); Checkpoint;
    Page.Panels[PanelIndex].Overlays.Add(Overlay); Overlay:=nil; FPanelIndex:=PanelIndex; FEffectIndex:=Page.Panels[PanelIndex].Overlays.Count-1;
    FBalloonIndex:=-1; Changed;
  finally Overlay.Free; end;
end;
procedure TMainForm.LoadPanelEffectControls;
var Panel: TComicPanel; At: Integer;
begin
  if (FFilterKind=nil) or (Page=nil) or (FPanelIndex<0) or (FPanelIndex>=Page.Panels.Count) then Exit;
  Panel:=Page.Panels[FPanelIndex]; FFilterKind.ItemIndex:=Panel.FilterKind;
  At:=FFilterStrength.Items.IndexOf(IntToStr(Panel.FilterStrength)); if At<0 then At:=FFilterStrength.Items.Add(IntToStr(Panel.FilterStrength)); FFilterStrength.ItemIndex:=At;
  FFrameKind.ItemIndex:=Panel.FrameKind; FPanelBorderColor:=Panel.BorderColor;
  At:=FPanelBorderWidth.Items.IndexOf(FloatToStr(Panel.BorderWidth)); if At<0 then At:=FPanelBorderWidth.Items.Add(FloatToStr(Panel.BorderWidth)); FPanelBorderWidth.ItemIndex:=At;
end;
procedure TMainForm.ApplyFilter(Sender: TObject);
var Panel: TComicPanel; Strength,Kind: Integer;
begin
  CancelDrag;
  if (Page=nil) or (FPanelIndex<0) or (FPanelIndex>=Page.Panels.Count) then Exit;
  Panel:=Page.Panels[FPanelIndex]; Strength:=StrToIntDef(FFilterStrength.Text,100); Kind:=FFilterKind.ItemIndex;
  if not (Strength in [0..100]) or not (Kind in [0..4]) then raise Exception.Create('フィルターの指定が不正です。');
  if (Panel.FilterKind=Kind) and (Panel.FilterStrength=Strength) then Exit;
  Checkpoint; Panel.FilterKind:=Kind; Panel.FilterStrength:=Strength; Changed;
end;
procedure TMainForm.ApplyFrame(Sender: TObject);
var Panel: TComicPanel; Width: Double; Kind: Integer;
begin
  CancelDrag;
  if (Page=nil) or (FPanelIndex<0) or (FPanelIndex>=Page.Panels.Count) then Exit;
  Panel:=Page.Panels[FPanelIndex]; Width:=StrToFloatDef(FPanelBorderWidth.Text,4); Kind:=FFrameKind.ItemIndex;
  if IsNan(Width) or IsInfinite(Width) or (Width<0) or (Width>100) or not (Kind in [0..2]) then raise Exception.Create('枠設定が不正です。');
  if (Panel.FrameKind=Kind) and (Panel.BorderWidth=Width) and (Panel.BorderColor=FPanelBorderColor) then Exit;
  Checkpoint; Panel.FrameKind:=Kind; Panel.BorderWidth:=Width; Panel.BorderColor:=FPanelBorderColor; Changed;
end;
procedure TMainForm.ChoosePanelBorderColor(Sender: TObject);
var Dialog: TColorDialog;
begin
  if (Page=nil) or (FPanelIndex<0) then Exit; Dialog:=TColorDialog.Create(Self);
  try Dialog.Color:=FPanelBorderColor; Dialog.Options:=[cdFullOpen]; if Dialog.Execute then FPanelBorderColor:=Dialog.Color; finally Dialog.Free; end;
end;
procedure TMainForm.DeleteEffect(Sender: TObject);
var Panel: TComicPanel;
begin
  CancelDrag;
  if (Page=nil) or (FPanelIndex<0) or (FPanelIndex>=Page.Panels.Count) then Exit; Panel:=Page.Panels[FPanelIndex];
  case FEffectCategory.ItemIndex of
    0: begin if SelectedEffect=nil then Exit; Checkpoint; Panel.Overlays.Delete(FEffectIndex); FEffectIndex:=-1; end;
    1: begin if Panel.FilterKind=0 then Exit; Checkpoint; Panel.FilterKind:=0; end;
    2: begin if (Panel.FrameKind=0) and (Panel.BorderWidth=4) and (Panel.BorderColor=0) then Exit;
      Checkpoint; Panel.FrameKind:=0; Panel.BorderWidth:=4; Panel.BorderColor:=0; end;
  end;
  LoadPanelEffectControls; Changed;
end;
procedure TMainForm.BuildUI;
var Menu: TMainMenu; M,N: TMenuItem; Top,Left,Right,Bar,P,Modes: TPanel; Layout: TComicLayout; I: Integer;
  Tab: TTabSheet; Body: TScrollBox; L: TLabel; ColorButton: TButton; IconButton: TComicIconButton;
  function D(Value: Integer): Integer; begin Result:=MulDiv(Value,CurrentPPI,96); end;
  function Icon(Parent: TWinControl; const Caption: string; X,Y,W,H: Integer; Glyph: TComicIcon;
    Tag: Integer; Role: TComicButtonRole; Handler: TNotifyEvent; Text: Boolean=False; Context: Integer=-1): TComicIconButton;
  begin
    Result:=TComicIconButton.Create(Self); Result.Parent:=Parent; Result.ParentFont:=True;
    Result.SetBounds(D(X),D(Y),D(W),D(H)); Result.Caption:=Caption; Result.Hint:=Caption;
    Result.Icon:=Glyph; Result.Tag:=Tag; Result.Role:=Role; Result.Context:=Context; Result.ShowText:=Text;
    Result.OnClick:=Handler; Result.OnHelp:=ButtonHelp; Result.OnNavigate:=IconNavigate; FIconButtons.Add(Result);
    if FTesting then Result.ControlStyle:=Result.ControlStyle-[csCaptureMouse];
  end;
  procedure Item(const Caption: string; Handler: TNotifyEvent; Shortcut: TShortCut=0);
  begin N:=TMenuItem.Create(Self); N.Caption:=Caption; N.OnClick:=Handler; N.ShortCut:=Shortcut; M.Add(N); end;
  function TabSheet(const Caption: string): TTabSheet;
  begin
    Result:=TTabSheet.Create(Self); Result.PageControl:=FTabs; Result.Caption:=Caption; Result.TabVisible:=False;
  end;
  function Scrolling(Parent: TWinControl): TScrollBox;
  begin
    Result:=TScrollBox.Create(Self); Result.Parent:=Parent; Result.Align:=alClient;
    Result.BorderStyle:=bsNone; Result.HorzScrollBar.Visible:=False; Result.VertScrollBar.Tracking:=True;
  end;
  procedure LabelAt(Parent: TWinControl; const Caption: string; X,Y: Integer; Height: Integer=44);
  begin L:=TLabel.Create(Self); L.Parent:=Parent; L.AutoSize:=False;
    L.SetBounds(D(X),D(Y),D(270),D(Height)); L.WordWrap:=True; L.Caption:=Caption; end;
begin
  Width:=Min(D(1420),Screen.WorkAreaWidth-D(32)); Height:=Min(D(920),Screen.WorkAreaHeight-D(32));
  Constraints.MinWidth:=D(900); Constraints.MinHeight:=D(620);
  Font.Name:='Yu Gothic UI'; Font.Size:=10; DoubleBuffered:=True; ImeMode:=imDisable;
  KeyPreview:=True; OnKeyDown:=Key; OnCloseQuery:=CloseCheck;
  Menu:=TMainMenu.Create(Self); Self.Menu:=Menu;
  M:=TMenuItem.Create(Self); M.Caption:='ファイル'; Menu.Items.Add(M);
  Item('新規作品...',NewProject,ShortCut(Ord('N'),[ssCtrl]));
  Item('作品を開く...',OpenProject,ShortCut(Ord('O'),[ssCtrl]));
  FRecentMenu:=TMenuItem.Create(Self); FRecentMenu.Caption:='読込履歴'; M.Add(FRecentMenu);
  for I:=0 to High(FRecentItems) do begin FRecentItems[I]:=TMenuItem.Create(Self); FRecentItems[I].Tag:=I; FRecentItems[I].OnClick:=RecentClick; FRecentMenu.Add(FRecentItems[I]); end;
  FRecentEmpty:=TMenuItem.Create(Self); FRecentEmpty.Caption:='履歴なし'; FRecentEmpty.Enabled:=False; FRecentMenu.Add(FRecentEmpty);
  N:=TMenuItem.Create(Self); N.Caption:='-'; FRecentMenu.Add(N);
  FRecentClear:=TMenuItem.Create(Self); FRecentClear.Caption:='履歴をクリア'; FRecentClear.OnClick:=ClearRecent; FRecentMenu.Add(FRecentClear); RefreshRecentMenu;
  Item('保存',SaveProject,ShortCut(Ord('S'),[ssCtrl])); Item('連番PNG出力...',ExportPNG);
  M:=TMenuItem.Create(Self); M.Caption:='編集'; Menu.Items.Add(M);
  Item('元に戻す',Undo,ShortCut(Ord('Z'),[ssCtrl])); Item('やり直す',Redo,ShortCut(Ord('Y'),[ssCtrl]));
  M:=TMenuItem.Create(Self); M.Caption:='設定・管理'; Menu.Items.Add(M);
  Item('キャラクター管理...',Characters); Item('画像管理...',Images);
  Item('ページ基準・共通プリセット...',PageSettings);
  Item('画像生成の共通指示プリセット...',GenerationPresets);
  Item('漫画効果素材...',EffectMaterials);
  Top:=TPanel.Create(Self); Top.Parent:=Self; Top.Align:=alTop; Top.Height:=D(64); Top.BevelOuter:=bvNone;
  Icon(Top,'新規作品 (Ctrl+N)',12,10,44,44,ciNew,0,brAlways,NewProject);
  Icon(Top,'作品を開く (Ctrl+O)',68,10,44,44,ciOpen,0,brAlways,OpenProject);
  Icon(Top,'保存 (Ctrl+S)',124,10,44,44,ciSave,0,brSave,SaveProject);
  Icon(Top,'キャラ管理',200,10,128,44,ciCharacters,0,brAlways,Characters,True);
  Icon(Top,'画像管理',340,10,128,44,ciImage,0,brProject,Images,True);
  Icon(Top,'元に戻す (Ctrl+Z)',496,10,44,44,ciUndo,0,brUndo,Undo);
  Icon(Top,'やり直す (Ctrl+Y)',552,10,44,44,ciRedo,0,brRedo,Redo);
  Icon(Top,'PNG出力',624,10,132,44,ciExport,0,brExport,ExportPNG,True);
  FStatus:=TStatusBar.Create(Self); FStatus.Parent:=Self; FStatus.SimplePanel:=True; FStatus.Align:=alBottom;
  Left:=TPanel.Create(Self); Left.Parent:=Self; Left.Align:=alLeft; Left.Width:=D(184); Left.BevelOuter:=bvNone;
  Bar:=TPanel.Create(Self); Bar.Parent:=Left; Bar.Align:=alTop; Bar.Height:=D(82); Bar.BevelOuter:=bvNone;
  LabelAt(Bar,'ページ',8,6,22);
  L.Width:=D(164);
  Icon(Bar,'ページを追加',6,34,40,40,ciAddPage,0,brAddPage,AddPage);
  Icon(Bar,'選択ページを削除',50,34,40,40,ciDelete,0,brDeletePage,DeletePage);
  Icon(Bar,'選択ページを上へ',94,34,40,40,ciUp,-1,brPageUp,MovePage);
  Icon(Bar,'選択ページを下へ',138,34,40,40,ciDown,1,brPageDown,MovePage);
  FPages:=TListBox.Create(Self); FPages.Parent:=Left; FPages.Align:=alClient;
  FPages.Style:=lbOwnerDrawFixed; FPages.ItemHeight:=D(158); FPages.OnDrawItem:=DrawPageItem; FPages.OnClick:=PageSelect;
  FPages.MultiSelect:=True; FPages.ExtendedSelect:=True; FPages.DragMode:=dmAutomatic;
  FPages.OnDragOver:=PagesDragOver; FPages.OnDragDrop:=PagesDragDrop; FPages.OnEndDrag:=PagesDragEnd;
  Right:=TPanel.Create(Self); Right.Parent:=Self; Right.Align:=alRight; Right.Width:=D(310); Right.BevelOuter:=bvNone;
  Modes:=TPanel.Create(Self); Modes.Parent:=Right; Modes.Align:=alTop; Modes.Height:=D(88); Modes.BevelOuter:=bvNone;
  FModeButtons[0]:=Icon(Modes,'コマ割り管理 (Ctrl+1)',12,8,44,44,ciLayout,0,brMode,ModeClick);
  FModeButtons[1]:=Icon(Modes,'コマ編集 (Ctrl+2)',72,8,44,44,ciPanelEdit,1,brMode,ModeClick);
  FModeButtons[2]:=Icon(Modes,'画像配置 (Ctrl+3)',132,8,44,44,ciImage,2,brMode,ModeClick);
  FModeButtons[3]:=Icon(Modes,'吹き出し (Ctrl+4)',192,8,44,44,ciBalloonEllipse,3,brMode,ModeClick);
  FModeButtons[4]:=Icon(Modes,'漫画効果 (Ctrl+5)',252,8,44,44,ciEffects,4,brMode,ModeClick);
  FModeTitle:=TLabel.Create(Self); FModeTitle.Parent:=Modes; FModeTitle.AutoSize:=False;
  FModeTitle.SetBounds(D(12),D(60),D(282),D(24)); FModeTitle.Font.Style:=[fsBold];
  FTabs:=TPageControl.Create(Self); FTabs.Parent:=Right; FTabs.Align:=alClient;
  Tab:=TabSheet('コマ割り管理');
  P:=TPanel.Create(Self); P.Parent:=Tab; P.Align:=alTop; P.Height:=D(188); P.BevelOuter:=bvNone;
  LabelAt(P,'中央：内容を置換（元に戻せます）'+sLineBreak+'左のページ間：新規ページに挿入',10,8);
  Icon(P,'現在のコマ割りを登録',10,56,270,36,ciRegister,0,brRegister,RegisterLayout,True);
  Icon(P,'選択に適用',10,100,132,36,ciApplyLayout,0,brApplyLayout,Template,True);
  Icon(P,'直下に挿入',148,100,132,36,ciInsertLayout,0,brInsertLayout,InsertLayout,True);
  Icon(P,'名前変更',10,144,132,36,ciApplyText,0,brManageLayout,RenameSelectedLayout,True);
  Icon(P,'削除',148,144,132,36,ciDelete,0,brManageLayout,DeleteSelectedLayout,True);
  FLayoutList:=TListBox.Create(Self); FLayoutList.Parent:=Tab; FLayoutList.Align:=alClient;
  FLayoutList.Style:=lbOwnerDrawFixed; FLayoutList.ItemHeight:=D(116); FLayoutList.DragMode:=dmAutomatic;
  FLayoutList.OnDrawItem:=DrawLayoutItem; FLayoutList.OnDblClick:=Template;
  FLayoutList.OnClick:=LayoutSelectionChanged;
  for Layout in FLayouts do FLayoutList.Items.AddObject(Layout.Name,Layout);
  FLayoutList.ItemIndex:=0;
  Tab:=TabSheet('コマ編集'); Body:=Scrolling(Tab);
  LabelAt(Body,'Ctrl+クリック：コマを複数選択'+sLineBreak+'青8点：全体拡縮／黄色：頂点移動',12,10);
  Icon(Body,'選択・移動',12,62,44,44,ciSelect,0,brTool,Tool,False,1).Hint:='青の外周8点で拡縮、黄色の内側点で頂点移動。頂点を右クリックで削除、辺を右クリックで追加。';
  Icon(Body,'四角コマ：対角2点をクリック',68,62,44,44,ciRectangle,1,brTool,Tool,False,1);
  Icon(Body,'楕円コマ：対角2点をクリック',124,62,44,44,ciEllipse,2,brTool,Tool,False,1);
  Icon(Body,'角丸コマ：対角2点をクリック',180,62,44,44,ciRounded,3,brTool,Tool,False,1);
  Icon(Body,'読む順番にコマをクリック',236,62,44,44,ciOrder,4,brTool,Tool,False,1);
  LabelAt(Body,'選択  /  四角  /  楕円  /  角丸  /  順序',12,114,28);
  Icon(Body,'多角形コマ',12,150,132,44,ciPolygon,8,brTool,Tool,True,1).Hint:='頂点をクリックし、最初の点で閉じます。右クリックで最後の点を戻す。Escで中止。';
  Icon(Body,'4点分割',150,150,130,44,ciSplit,9,brTool,Tool,True,1).Hint:='四角・凸多角形の外周2点、帯の幅、対側交点をクリックして分割します。';
  FSnap:=TCheckBox.Create(Self); FSnap.Parent:=Body; FSnap.SetBounds(D(12),D(202),D(268),D(26));
  FSnap.Caption:='外枠・コマ・間隔スナップ（Altで解除）'; FSnap.Checked:=True;
  LabelAt(Body,'多角形は最初の点で閉じる。'+sLineBreak+'分割は四角・凸多角形の外周から4点。',12,236);
  Icon(Body,'選択コマを削除',12,290,268,40,ciDelete,0,brDeletePanel,DeleteObject,True);
  Icon(Body,'現在のコマ割りを登録',12,340,268,40,ciRegister,0,brRegister,RegisterLayout,True);
  Body.VertScrollBar.Range:=D(392);
  Tab:=TabSheet('画像配置');
  P:=TPanel.Create(Self); P.Parent:=Tab; P.Align:=alTop; P.Height:=D(188); P.BevelOuter:=bvNone;
  Icon(P,'画像管理・取り込み',10,10,270,36,ciImage,0,brProject,Images,True);
  Icon(P,'選択コマに配置',10,54,170,36,ciAssignImage,0,brAssignImage,AssignImage,True);
  FZoom:=TComboBox.Create(Self); FZoom.Parent:=P; FZoom.SetBounds(D(188),D(58),D(90),D(28)); FZoom.Style:=csDropDownList;
  FZoom.Items.AddStrings(['100%','125%','150%','200%','300%']); FZoom.ItemIndex:=0; FZoom.OnChange:=ImageZoom;
  Icon(P,'画像の割り当て解除',10,98,270,36,ciDetachImage,0,brDetachImage,DetachImage,True);
  LabelAt(P,'画像をコマへドラッグ。外周8点で比率を保って拡縮。',10,138);
  FImages:=TListBox.Create(Self); FImages.Parent:=Tab; FImages.Align:=alClient;
  FImages.Style:=lbOwnerDrawFixed; FImages.ItemHeight:=D(104); FImages.OnDrawItem:=DrawImageItem;
  FImages.DragMode:=dmAutomatic; FImages.OnDblClick:=AssignImage; FImages.OnClick:=ImageSelectionChanged;
  Tab:=TabSheet('吹き出し'); Body:=Scrolling(Tab);
  Icon(Body,'選択・移動／ダブルクリックで文字再入力',12,12,40,44,ciSelect,0,brTool,Tool,False,3);
  Icon(Body,'四角の吹き出し：対角2点をクリック',66,12,40,44,ciRectangle,10,brTool,Tool,False,3);
  Icon(Body,'楕円の吹き出し：対角2点をクリック',120,12,40,44,ciBalloonEllipse,5,brTool,Tool,False,3);
  Icon(Body,'角丸の吹き出し：対角2点をクリック',174,12,40,44,ciBalloonRounded,6,brTool,Tool,False,3);
  Icon(Body,'文字配置：移動と比率を保つサイズ変更',228,12,40,44,ciApplyText,13,brTextPlacement,Tool,False,3);
  Icon(Body,'三角しっぽ：根元と先端を2点指定',12,66,44,44,ciTail,7,brTail,Tail,False,3);
  Icon(Body,'思考しっぽ：根元と先端を2点指定',72,66,44,44,ciThought,11,brTail,Tail,False,3);
  Icon(Body,'しっぽ編集：根元・幅・先端の3点',132,66,44,44,ciSelect,12,brTail,Tail,False,3);
  Icon(Body,'選択しっぽを削除',192,66,44,44,ciDelete,0,brDeleteTail,DeleteTail,False,3);
  LabelAt(Body,'本体の選択 / 作成 / 文字配置'+sLineBreak+'しっぽ作成 / 3点編集 / 削除',12,118,44);
  LabelAt(Body,'選択中の吹き出しのセリフ',12,164,24);
  FText:=TMemo.Create(Self); FText.Parent:=Body; FText.SetBounds(D(12),D(192),D(270),D(100)); FText.ScrollBars:=ssVertical;
  FText.ImeMode:=imOpen;
  Icon(Body,'専用文字入力',12,298,270,32,ciApplyText,0,brApplyText,TextInputDialog,True).Hint:='IMEとUTF-16編集バッファを使う専用入力。確定で反映、取消で作品を維持。';
  FVertical:=TCheckBox.Create(Self); FVertical.Parent:=Body; FVertical.SetBounds(D(12),D(280),D(130),D(26)); FVertical.Caption:='縦書き';
  FTransparent:=TCheckBox.Create(Self); FTransparent.Parent:=Body; FTransparent.SetBounds(D(144),D(280),D(130),D(26)); FTransparent.Caption:='文字だけ表示';
  FOverflow:=TCheckBox.Create(Self); FOverflow.Parent:=Body; FOverflow.SetBounds(D(12),D(312),D(270),D(26)); FOverflow.Caption:='コマ枠からはみ出すことを許可'; FOverflow.Checked:=True;
  FFont:=TComboBox.Create(Self); FFont.Parent:=Body; FFont.SetBounds(D(12),D(354),D(92),D(28)); FFont.Style:=csDropDownList;
  FFont.Items.AddStrings(['24','32','40','48','64','80']); FFont.ItemIndex:=2;
  FFontBold:=TCheckBox.Create(Self); FFontBold.Parent:=Body; FFontBold.SetBounds(D(114),D(354),D(80),D(26)); FFontBold.Caption:='太字';
  FFontItalic:=TCheckBox.Create(Self); FFontItalic.Parent:=Body; FFontItalic.SetBounds(D(202),D(354),D(80),D(26)); FFontItalic.Caption:='斜体';
  FFontFamily:=TComboBox.Create(Self); FFontFamily.Parent:=Body; FFontFamily.SetBounds(D(12),D(394),D(270),D(28));
  FFontFamily.Style:=csDropDownList; FFontFamily.OnDropDown:=FontDropDown; FontDropDown(nil);
  FFontFamily.ItemIndex:=FFontFamily.Items.IndexOf('Yu Gothic');
  FFontUnderline:=TCheckBox.Create(Self); FFontUnderline.Parent:=Body; FFontUnderline.SetBounds(D(12),D(432),D(128),D(26)); FFontUnderline.Caption:='下線';
  FFontStrikeOut:=TCheckBox.Create(Self); FFontStrikeOut.Parent:=Body; FFontStrikeOut.SetBounds(D(154),D(432),D(128),D(26)); FFontStrikeOut.Caption:='取消線';
  ColorButton:=TButton.Create(Self); ColorButton.Parent:=Body; ColorButton.SetBounds(D(12),D(472),D(96),D(34)); ColorButton.Caption:='文字色...'; ColorButton.OnClick:=ChooseTextColor;
  Icon(Body,'文字・設定を反映',114,468,168,40,ciApplyText,0,brApplyText,ApplyText,True);
  Icon(Body,'選択した吹き出しを削除',12,524,270,40,ciDelete,1,brDeleteBalloon,DeleteObject,True);
  // Move the settings below the two rows of body/tail tools.
  FVertical.Top:=FVertical.Top+D(60); FTransparent.Top:=FTransparent.Top+D(60); FOverflow.Top:=FOverflow.Top+D(60);
  FFont.Top:=FFont.Top+D(60); FFontBold.Top:=FFontBold.Top+D(60); FFontItalic.Top:=FFontItalic.Top+D(60);
  FFontFamily.Top:=FFontFamily.Top+D(60); FFontUnderline.Top:=FFontUnderline.Top+D(60); FFontStrikeOut.Top:=FFontStrikeOut.Top+D(60);
  ColorButton.Top:=ColorButton.Top+D(60);
  for IconButton in FIconButtons do if IconButton.Parent=Body then begin
    if (IconButton.Role=brApplyText) and (IconButton.Top=D(468)) then IconButton.Top:=D(528);
    if IconButton.Role=brDeleteBalloon then IconButton.Top:=D(704);
  end;
  LabelAt(Body,'本体の輪郭',12,586,24);
  FContour:=TComboBox.Create(Self); FContour.Parent:=Body; FContour.SetBounds(D(114),D(582),D(168),D(28));
  FContour.Style:=csDropDownList; FContour.Items.AddStrings(['通常','ギザギザ','波線','雲形']); FContour.ItemIndex:=0;
  FContour.Hint:='基本形状を保った輪郭。選択後に「文字・設定を反映」で適用。'; FContour.ShowHint:=True;
  LabelAt(Body,'縁の太さ（出力px）',12,626,24);
  FBorderWidth:=TComboBox.Create(Self); FBorderWidth.Parent:=Body; FBorderWidth.SetBounds(D(12),D(654),D(96),D(28));
  FBorderWidth.Style:=csDropDownList; FBorderWidth.Items.AddStrings(['0','1','2','3','4','6','8','12']); FBorderWidth.ItemIndex:=3;
  ColorButton:=TButton.Create(Self); ColorButton.Parent:=Body; ColorButton.SetBounds(D(114),D(650),D(78),D(34)); ColorButton.Caption:='塗り色'; ColorButton.Tag:=1; ColorButton.OnClick:=ChooseTextColor;
  ColorButton:=TButton.Create(Self); ColorButton.Parent:=Body; ColorButton.SetBounds(D(204),D(650),D(78),D(34)); ColorButton.Caption:='縁色'; ColorButton.Tag:=2; ColorButton.OnClick:=ChooseTextColor;
  Body.VertScrollBar.Range:=D(748);
  Tab:=TabSheet('漫画効果'); P:=TPanel.Create(Self); P.Parent:=Tab; P.Align:=alTop; P.Height:=D(54); P.BevelOuter:=bvNone;
  FEffectCategory:=TComboBox.Create(Self); FEffectCategory.Parent:=P; FEffectCategory.SetBounds(D(10),D(12),D(270),D(28));
  FEffectCategory.Style:=csDropDownList; FEffectCategory.Items.AddStrings(['効果素材','フィルター','枠装飾']); FEffectCategory.ItemIndex:=0; FEffectCategory.OnChange:=EffectCategoryChanged;
  FEffectPages:=TPageControl.Create(Self); FEffectPages.Parent:=Tab; FEffectPages.Align:=alClient;
  Tab:=TTabSheet.Create(Self); Tab.PageControl:=FEffectPages; Tab.Caption:='効果素材'; Tab.TabVisible:=False;
  P:=TPanel.Create(Self); P.Parent:=Tab; P.Align:=alTop; P.Height:=D(108); P.BevelOuter:=bvNone;
  Icon(P,'効果素材を管理',10,8,270,36,ciRegister,0,brAlways,EffectMaterials,True);
  Icon(P,'選択した効果素材を削除',10,54,270,36,ciDelete,0,brDeleteEffect,DeleteEffect,True);
  FEffectList:=TListBox.Create(Self); FEffectList.Parent:=Tab; FEffectList.Align:=alClient; FEffectList.Style:=lbOwnerDrawFixed;
  FEffectList.ItemHeight:=D(116); FEffectList.OnDrawItem:=DrawEffectItem; FEffectList.DragMode:=dmAutomatic; RefreshEffectMaterials;
  Tab:=TTabSheet.Create(Self); Tab.PageControl:=FEffectPages; Tab.Caption:='フィルター'; Tab.TabVisible:=False; Body:=Scrolling(Tab);
  LabelAt(Body,'中央のコマを選び、種類と強度を反映します。',12,10);
  FFilterKind:=TComboBox.Create(Self); FFilterKind.Parent:=Body; FFilterKind.SetBounds(D(12),D(68),D(166),D(28)); FFilterKind.Style:=csDropDownList;
  FFilterKind.Items.AddStrings(['なし','セピア','モノクロ','ぼかし','夢']); FFilterKind.ItemIndex:=0;
  FFilterStrength:=TComboBox.Create(Self); FFilterStrength.Parent:=Body; FFilterStrength.SetBounds(D(190),D(68),D(90),D(28)); FFilterStrength.Style:=csDropDownList;
  FFilterStrength.Items.AddStrings(['25','50','75','100']); FFilterStrength.ItemIndex:=3;
  Icon(Body,'フィルターを反映',12,116,268,40,ciEffects,0,brApplyFilter,ApplyFilter,True);
  Icon(Body,'フィルターを解除',12,170,268,40,ciDelete,1,brDeleteEffect,DeleteEffect,True); Body.VertScrollBar.Range:=D(220);
  Tab:=TTabSheet.Create(Self); Tab.PageControl:=FEffectPages; Tab.Caption:='枠装飾'; Tab.TabVisible:=False; Body:=Scrolling(Tab);
  LabelAt(Body,'中央のコマを選び、枠の種類・出力pxの太さを反映します。',12,10);
  FFrameKind:=TComboBox.Create(Self); FFrameKind.Parent:=Body; FFrameKind.SetBounds(D(12),D(68),D(268),D(28)); FFrameKind.Style:=csDropDownList;
  FFrameKind.Items.AddStrings(['通常','二重枠','破線']); FFrameKind.ItemIndex:=0;
  FPanelBorderWidth:=TComboBox.Create(Self); FPanelBorderWidth.Parent:=Body; FPanelBorderWidth.SetBounds(D(12),D(112),D(96),D(28)); FPanelBorderWidth.Style:=csDropDownList;
  FPanelBorderWidth.Items.AddStrings(['0','1','2','4','6','8','12']); FPanelBorderWidth.ItemIndex:=3;
  ColorButton:=TButton.Create(Self); ColorButton.Parent:=Body; ColorButton.SetBounds(D(120),D(110),D(160),D(32)); ColorButton.Caption:='枠の色...'; ColorButton.OnClick:=ChoosePanelBorderColor;
  Icon(Body,'枠設定を反映',12,164,268,40,ciPanelEdit,0,brApplyFrame,ApplyFrame,True);
  Icon(Body,'枠設定を初期化',12,218,268,40,ciDelete,2,brDeleteEffect,DeleteEffect,True); Body.VertScrollBar.Range:=D(270);
  FEffectPages.ActivePageIndex:=0;
  FView:=TComicView.Create(Self); FView.Parent:=Self; FView.Align:=alClient; FView.BevelOuter:=bvNone;
  FView.Color:=$302B28; FView.ParentBackground:=False; FView.DoubleBuffered:=True;
  FView.ImeMode:=imDisable; FView.TabStop:=True; FView.OnCaptureLost:=ViewCaptureLost;
  OnMouseWheel:=ViewWheel;
  FCanvas:=TComicPaintBox.Create(Self); FCanvas.Parent:=FView; FCanvas.Align:=alClient; FCanvas.OnPaint:=Paint;
  // Edits and view pans capture explicitly. VCL's automatic left-button
  // release occurs before OnMouseUp and would look like unexpected capture
  // loss, cancelling a legitimate edit before it can commit.
  FCanvas.ControlStyle:=FCanvas.ControlStyle-[csCaptureMouse];
  FCanvas.Hint:='ホイール: 表示拡大縮小 / 中央ドラッグ・空白の左ドラッグ: 表示移動 / Ctrl+0: 全体表示'; FCanvas.ShowHint:=True;
  FCanvas.OnMouseDown:=MouseDown; FCanvas.OnMouseMove:=MouseMove; FCanvas.OnMouseUp:=MouseUp;
  FCanvas.OnDblClick:=EditBalloonText; FCanvas.OnDragOver:=DragOver; FCanvas.OnDragDrop:=DragDrop;
  FTabs.ActivePageIndex:=0; FTabs.OnChange:=TabChanged;
end;
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
begin
  FDirty:=True; if ContentChanged and (Page<>nil) then Inc(Page.Revision);
  FProject.SaveDraft; RefreshUI;
end;
procedure TMainForm.RefreshUI;
var I,SelectedImage: Integer; A: TComicAsset; SelectedPages: TList<string>;
begin
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
    SyncZoom; UpdateIconState;
    FCanvas.Invalidate;
  finally SelectedPages.Free; FRefreshing:=False; end;
end;
procedure TMainForm.ModeClick(Sender: TObject);
begin
  if not FTabs.Enabled then Exit;
  FTabs.ActivePageIndex:=TControl(Sender).Tag; TabChanged(nil); ActiveControl:=TWinControl(Sender);
  FStatus.SimpleText:=FTabs.ActivePage.Caption+'：右側のアイコンや一覧から操作を選択してください。';
end;
procedure TMainForm.ButtonHelp(Sender: TObject);
begin
  if (Sender is TComicIconButton) and TComicIconButton(Sender).Available then
    FStatus.SimpleText:=TComicIconButton(Sender).Hint;
end;
procedure TMainForm.ImageSelectionChanged(Sender: TObject);
begin UpdateIconState; end;
procedure TMainForm.IconTestClick(Sender: TObject);
begin Inc(FIconTestClicks); end;
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
var Button: TComicIconButton; CanEdit,HasPage,HasPanel,HasBalloon: Boolean;
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
      brAssignImage: Button.Enabled:=HasPanel and (FImages.ItemIndex>=0);
      brDetachImage: Button.Enabled:=HasPanel and (Page.Panels[FPanelIndex].ImageID<>'');
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
  FModeTitle.Caption:=FTabs.ActivePage.Caption;
  FZoom.Enabled:=HasPanel and (Page.Panels[FPanelIndex].ImageID<>'');
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
procedure TMainForm.SyncZoom;
var Value: string; Index: Integer;
begin
  if (Page=nil) or (FPanelIndex<0) or (FPanelIndex>=Page.Panels.Count) then Exit;
  Value:=IntToStr(Round(Page.Panels[FPanelIndex].Zoom*100))+'%'; Index:=FZoom.Items.IndexOf(Value);
  if Index<0 then Index:=FZoom.Items.Add(Value); FZoom.ItemIndex:=Index;
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
  CancelDrag; ResetGeometryInput;
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
  // Reading an existing project must not divert into the unrelated character
  // manager. Character validation still guards creation/editing/production.
  if not ConfirmLeave then Exit; D:=CreateProjectDialog;
  try
    if not D.Execute then Exit;
    OpenProjectFile(D.FileName);
  finally D.Free; end;
end;
procedure TMainForm.SaveProject(Sender: TObject);
begin CancelDrag; if FProject=nil then Exit; FProject.Save; FDirty:=False; RefreshUI; FStatus.SimpleText:='保存しました：'+FProject.Folder;
  RememberProject(TPath.Combine(FProject.Folder,'Project.json')); end;
procedure TMainForm.OpenProjectFile(const FileName: string; DraftChoice: Integer);
var Project,Candidate: TComicProject; Saved,Draft,HistoryFile,SavedID: string; Restore,Dirty: Boolean;
begin
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
  D:=TAssetDialog.CreateManager(Self,FCharacters,nil,True,FCharacterLibraryWritable);
  FAssetManager:=D;
  try D.ShowModal; finally FAssetManager:=nil; D.Free; end; RefreshUI;
end;
procedure TMainForm.Images(Sender: TObject);
var D: TAssetDialog; Before: string;
begin
  CancelDrag;
  if not NeedProject then Exit;
  if not HasCharacter then begin Notify('参照画像付きのキャラを先に登録してください。'); Exit; end;
  Before:=FProject.Snapshot;
  D:=TAssetDialog.CreateManager(Self,FProject.Assets,FProject,False,True,GenerationPresets,FCharacters);
  FAssetManager:=D;
  try D.ShowModal; finally FAssetManager:=nil; D.Free; end;
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
begin if FRefreshing then Exit; CancelDrag; ResetGeometryInput; FSelectedPanels.Clear; FPageIndex:=FPages.ItemIndex; ResetViewport; FPanelIndex:=-1; FBalloonIndex:=-1; FFirst:=False; ShowPageStatus; UpdateIconState; FCanvas.Invalidate; end;
procedure TMainForm.TabChanged(Sender: TObject);
begin CancelDrag; ResetGeometryInput; FSelectedPanels.Clear; FEffectIndex:=-1; FTool:=0; FFirst:=False; if FTabs.ActivePageIndex<>3 then FBalloonIndex:=-1; UpdateIconState; FCanvas.Invalidate; end;
procedure TMainForm.DrawPageItem(Control: TWinControl; Index: Integer; Rect: TRect; State: TOwnerDrawState);
var R: TRect; B: TBitmap; I: Integer;
  function D(Value: Integer): Integer; begin Result:=MulDiv(Value,CurrentPPI,96); end;
begin
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
var P: TComicPage;
begin
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
var P: TComicPage;
begin
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
  CancelDrag;
  if (Page=nil) or (FPanelIndex<0) then Exit; P:=Page.Panels[FPanelIndex]; if P.ImageID='' then Exit;
  Checkpoint; P.ImageID:=''; P.Zoom:=1; P.PanX:=0; P.PanY:=0; FZoom.ItemIndex:=0; Changed;
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
var Current: TRectF;
begin
  if Original.IsEmpty then Exit;
  Current:=FRenderer.ImageBounds(FProject,Panel); if Current.IsEmpty then Exit;
  Panel.Zoom:=Panel.Zoom*Original.Width/Current.Width;
  Panel.PanX:=Original.CenterPoint.X-Panel.Bounds.CenterPoint.X;
  Panel.PanY:=Original.CenterPoint.Y-Panel.Bounds.CenterPoint.Y;
end;
function TMainForm.VertexHandles(Panel: TComicPanel): TArray<TPointF>;
var Points: TArray<TPointF>; I,N,K: Integer; Direction,Q: TPointF; LengthValue,Step: Double;
begin
  Result:=nil; if not (Panel.Shape in [0,3]) then Exit;
  Points:=Panel.Outline; N:=Length(Points); SetLength(Result,N);
  for I:=0 to N-1 do begin
    Direction:=TPointF.Create((Points[(I+N-1) mod N].X+Points[(I+1) mod N].X)/2-Points[I].X,
      (Points[(I+N-1) mod N].Y+Points[(I+1) mod N].Y)/2-Points[I].Y);
    if Abs((Double(Points[(I+N-1) mod N].X)-Points[I].X)*(Points[(I+1) mod N].Y-Points[I].Y)-
      (Double(Points[(I+N-1) mod N].Y)-Points[I].Y)*(Points[(I+1) mod N].X-Points[I].X))<0.001 then
      Direction:=TPointF.Create(-(Points[(I+1) mod N].Y-Points[I].Y),Points[(I+1) mod N].X-Points[I].X);
    LengthValue:=Hypot(Direction.X,Direction.Y); Result[I]:=Points[I]; if LengthValue<0.001 then Continue;
    Step:=MulDiv(14,CurrentPPI,96)/Max(FScale,0.001);
    for K:=0 to 8 do begin
      Q:=TPointF.Create(Points[I].X+Direction.X/LengthValue*Step,Points[I].Y+Direction.Y/LengthValue*Step);
      if PolygonContains(Points,Q) then begin Result[I]:=Q; Break; end;
      Q:=TPointF.Create(Points[I].X-Direction.X/LengthValue*Step,Points[I].Y-Direction.Y/LengthValue*Step);
      if PolygonContains(Points,Q) then begin Result[I]:=Q; Break; end;
      Step:=Step/2;
    end;
  end;
end;
function TMainForm.HitVertex(Panel: TComicPanel; const P: TPointF): Integer;
var Points: TArray<TPointF>; I: Integer; Distance,Best: Double;
begin
  Result:=-1; Best:=MulDiv(7,CurrentPPI,96)/Max(FScale,0.001); Points:=VertexHandles(Panel);
  for I:=0 to High(Points) do begin
    Distance:=Hypot(Double(P.X)-Points[I].X,Double(P.Y)-Points[I].Y);
    if Distance<=Best then begin Best:=Distance; Result:=I; end;
  end;
end;
procedure TMainForm.EditVertexContext(const P: TPointF);
var Panel: TComicPanel; Points,Candidate: TArray<TPointF>; I,J,Index,N: Integer; Q: TPointF;
  T,LengthSquared,Distance,Best: Double; Image: TRectF;
begin
  CancelDrag;
  if (Page=nil) or (FPanelIndex<0) or (FPanelIndex>=Page.Panels.Count) then Exit;
  Panel:=Page.Panels[FPanelIndex]; if not (Panel.Shape in [0,3]) then begin
    FStatus.SimpleText:='楕円・角丸は固有形状を保つため頂点編集の対象外です。'; Exit;
  end;
  Points:=Panel.Outline; N:=Length(Points); Index:=HitVertex(Panel,P);
  if Index<0 then for I:=0 to High(Points) do
    if Hypot(Double(P.X)-Points[I].X,Double(P.Y)-Points[I].Y)*FScale<=MulDiv(7,CurrentPPI,96) then begin Index:=I; Break; end;
  if Index>=0 then begin
    if N<=3 then begin FStatus.SimpleText:='コマには最低3頂点が必要です。'; Exit; end;
    SetLength(Candidate,N-1); J:=0;
    for I:=0 to N-1 do if I<>Index then begin Candidate[J]:=Points[I]; Inc(J); end;
  end else begin
    if N>=256 then begin FStatus.SimpleText:='頂点は256点までです。'; Exit; end;
    Index:=-1; Best:=MulDiv(7,CurrentPPI,96)/Max(FScale,0.001);
    for I:=0 to N-1 do begin
      LengthSquared:=Sqr(Double(Points[(I+1) mod N].X)-Points[I].X)+Sqr(Double(Points[(I+1) mod N].Y)-Points[I].Y);
      if LengthSquared<0.001 then Continue;
      T:=EnsureRange(((Double(P.X)-Points[I].X)*(Points[(I+1) mod N].X-Points[I].X)+
        (Double(P.Y)-Points[I].Y)*(Points[(I+1) mod N].Y-Points[I].Y))/LengthSquared,0.0,1.0);
      Q:=TPointF.Create(Points[I].X+(Points[(I+1) mod N].X-Points[I].X)*T,
        Points[I].Y+(Points[(I+1) mod N].Y-Points[I].Y)*T);
      Distance:=Hypot(Double(P.X)-Q.X,Double(P.Y)-Q.Y);
      if Distance<=Best then begin Best:=Distance; Index:=I; FLast:=Q; end;
    end;
    if Index<0 then begin FStatus.SimpleText:='選択コマの内側の頂点を右クリックして削除、辺を右クリックして追加。'; Exit; end;
    SetLength(Candidate,N+1);
    for I:=0 to Index do Candidate[I]:=Points[I]; Candidate[Index+1]:=FLast;
    for I:=Index+1 to N-1 do Candidate[I+1]:=Points[I];
  end;
  if not ValidPolygon(Candidate) then begin FStatus.SimpleText:='頂点操作が交差やゼロ面積を生むため確定できません。'; Exit; end;
  Image:=FRenderer.ImageBounds(FProject,Panel); Checkpoint;
  Panel.SetVertices(Candidate); PreservePanelImage(Panel,Image); Changed;
  FStatus.SimpleText:='頂点を更新しました。画像位置を維持し、Ctrl+Zで戻せます。';
end;
procedure TMainForm.ResetGeometryInput;
begin
  if FGeometryPoints<>nil then FGeometryPoints.Clear;
  FSplitStage:=0; FSplitPanelID:='';
  FTailIndex:=-1; FDragTailHandle:=0;
end;
function TMainForm.SnapCreationPoint(const P: TPointF; const ExcludePanelID: string): TPointF;
var Tolerance,Best,BestEdge,DX,DY,Distance: Double; Panel: TComicPanel; Point,Q,EdgePoint,VertexPoint,AxisPoint: TPointF; Values: TArray<TPointF>; Gap: TComicGapSnap; UsedGap: Boolean;
  function Earlier(const A,B: TPointF): Boolean;
  begin Result:=(A.X<B.X) or ((A.X=B.X) and (A.Y<B.Y)); end;
  procedure Axis(X,Y: Single);
  var AX,AY: Double;
  begin
    AX:=Abs(Double(P.X)-X); AY:=Abs(Double(P.Y)-Y);
    if (AX<DX) or ((AX=DX) and (X<AxisPoint.X)) then begin DX:=AX; if DX<=Tolerance then AxisPoint.X:=X; end;
    if (AY<DY) or ((AY=DY) and (Y<AxisPoint.Y)) then begin DY:=AY; if DY<=Tolerance then AxisPoint.Y:=Y; end;
  end;
begin
  Result:=P; if (Page=nil) or not FSnap.Checked then Exit;
  AxisPoint:=P; VertexPoint:=P; EdgePoint:=P;
  Tolerance:=MulDiv(8,CurrentPPI,96)/Max(FScale,0.001); DX:=Tolerance+1; DY:=Tolerance+1; Best:=Tolerance+1; BestEdge:=Tolerance+1;
  Axis(FProject.MarginLeft,FProject.MarginTop); Axis(FProject.Width-FProject.MarginRight,FProject.Height-FProject.MarginBottom);
  for Panel in Page.Panels do begin
    if Panel.ID=ExcludePanelID then Continue;
    Axis(Panel.Bounds.Left,Panel.Bounds.Top); Axis(Panel.Bounds.Right,Panel.Bounds.Bottom);
    Values:=Panel.Outline;
    for Point in Values do begin
      Distance:=Hypot(Double(P.X)-Point.X,Double(P.Y)-Point.Y);
      if (Distance<=Tolerance) and ((Distance<Best) or ((Distance=Best) and Earlier(Point,VertexPoint))) then
        begin VertexPoint:=Point; Best:=Distance; end;
    end;
    if Panel.Shape in [0,3] then begin
      Distance:=NearestEdgePoint(Values,P,Q);
      if (Distance<=Tolerance) and ((Distance<BestEdge) or ((Distance=BestEdge) and Earlier(Q,EdgePoint))) then
        begin BestEdge:=Distance; EdgePoint:=Q; end;
    end;
  end;
  Gap:=FindGapSnap(Page.Panels,P,Tolerance,ExcludePanelID);
  UsedGap:=False;
  if Gap.HasX and (Abs(Double(Gap.Point.X)-P.X)<DX) then begin AxisPoint.X:=Gap.Point.X; UsedGap:=True; end;
  if Gap.HasY and (Abs(Double(Gap.Point.Y)-P.Y)<DY) then begin AxisPoint.Y:=Gap.Point.Y; UsedGap:=True; end;
  if Best<=Tolerance then Result:=VertexPoint
  else if BestEdge<=Tolerance then Result:=EdgePoint
  else Result:=AxisPoint;
  if UsedGap and (Hypot(Double(AxisPoint.X)-P.X,Double(AxisPoint.Y)-P.Y)+0.0001<Hypot(Double(Result.X)-P.X,Double(Result.Y)-P.Y)) then Result:=AxisPoint;
end;
function TMainForm.SnapPanelDragBounds(const Bounds: TRectF): TRectF;
var Frame: TRectF; IDs: TArray<string>; MinimumWidth,MinimumHeight: Double; I: Integer;
begin
  Result:=Bounds; if (Page=nil) or not FSnap.Checked then Exit;
  MinimumWidth:=30; MinimumHeight:=30;
  if Length(FDragGroup)>1 then begin
    SetLength(IDs,Length(FDragGroup)); MinimumWidth:=1; MinimumHeight:=1;
    for I:=0 to High(FDragGroup) do begin
      IDs[I]:=FDragGroup[I].ID;
      MinimumWidth:=Max(MinimumWidth,FDragBounds.Width*Min(1,30/Max(0.001,FDragGroup[I].Bounds.Width)));
      MinimumHeight:=Max(MinimumHeight,FDragBounds.Height*Min(1,30/Max(0.001,FDragGroup[I].Bounds.Height)));
    end;
  end else begin
    if (FPanelIndex<0) or (FPanelIndex>=Page.Panels.Count) then Exit;
    IDs:=[Page.Panels[FPanelIndex].ID];
  end;
  Frame:=TRectF.Create(FProject.MarginLeft,FProject.MarginTop,FProject.Width-FProject.MarginRight,FProject.Height-FProject.MarginBottom);
  Result:=SnapPanelBounds(Page.Panels,Bounds,Frame,MulDiv(8,CurrentPPI,96)/Max(FScale,0.001),FDragHandle,IDs,MinimumWidth,MinimumHeight);
end;
procedure TMainForm.PolygonClick(const P: TPointF);
var Panel: TComicPanel; Values: TArray<TPointF>;
begin
  if (FGeometryPoints.Count>=3) and (Hypot(Double(P.X)-FGeometryPoints[0].X,Double(P.Y)-FGeometryPoints[0].Y)*FScale<=MulDiv(10,CurrentPPI,96)) then begin
    Values:=FGeometryPoints.ToArray;
    if not ValidPolygon(Values) or (PolygonArea(Values)<25) then begin
      FStatus.SimpleText:='交差・重複点・小さすぎる面積があるため確定できません。右クリックで最後の点を戻せます。'; Exit;
    end;
    Panel:=TComicPanel.Create;
    try Panel.SetVertices(Values); except Panel.Free; raise; end;
    Checkpoint; Panel.Number:=Page.Panels.Count+1; Page.Panels.Add(Panel); SelectSinglePanel(Page.Panels.Count-1);
    FGeometryPoints.Clear; Changed; FStatus.SimpleText:='多角形コマを作成しました。画像サムネイルから配置できます。'; Exit;
  end;
  if FGeometryPoints.Count>=256 then begin FStatus.SimpleText:='頂点は256点までです。最初の点で閉じるか、右クリックで戻してください。'; Exit; end;
  if (FGeometryPoints.Count>0) and (Hypot(Double(P.X)-FGeometryPoints.Last.X,Double(P.Y)-FGeometryPoints.Last.Y)<0.01) then Exit;
  FGeometryPoints.Add(P); FLast:=P; FCanvas.Invalidate;
  FStatus.SimpleText:=Format('%d 頂点。最初の点をクリックして閉じる／右クリックで戻す／Escで中止。',[FGeometryPoints.Count]);
end;
procedure TMainForm.SplitClick(const P: TPointF);
var I,Index: Integer; Owner: TComicPanel; Near,Mid: TPointF; Dist,Best,Tolerance: Double;
begin
  Tolerance:=MulDiv(12,CurrentPPI,96)/Max(FScale,0.001); Index:=-1;
  if FSplitStage=0 then begin
    Best:=Tolerance+1;
    for I:=Page.Panels.Count-1 downto 0 do if Page.Panels[I].CanSplit then begin
      Dist:=NearestEdgePoint(Page.Panels[I].Outline,P,Near);
      if Dist<Best then begin Best:=Dist; Index:=I; FSplitA:=Near; end;
    end;
    if (Index<0) or (Best>Tolerance) then begin FStatus.SimpleText:='四角・凸多角形の外周付近をクリックしてください。'; Exit; end;
    FSplitPanelID:=Page.Panels[Index].ID; FPanelIndex:=Index; FBalloonIndex:=-1; FSplitStage:=1;
    FStatus.SimpleText:='第2点：反対側の外周をクリックして最初の境界線を決めてください。';
  end else begin
    for I:=0 to Page.Panels.Count-1 do if Page.Panels[I].ID=FSplitPanelID then Index:=I;
    if Index<0 then begin ResetGeometryInput; Exit; end;
    Owner:=Page.Panels[Index];
    case FSplitStage of
      1: begin
        if NearestEdgePoint(Owner.Outline,P,Near)>Tolerance then begin FStatus.SimpleText:='第2点は対象コマの外周付近です。'; Exit; end;
        Mid:=TPointF.Create((FSplitA.X+Near.X)/2,(FSplitA.Y+Near.Y)/2);
        if (Hypot(Double(Near.X)-FSplitA.X,Double(Near.Y)-FSplitA.Y)<10) or
          (NearestEdgePoint(Owner.Outline,Mid,FSplitB)<0.5) then begin
          FStatus.SimpleText:='第2点はコマ内部を横切る別の外周に指定してください。'; Exit;
        end;
        FSplitB:=Near; FSplitStage:=2; FStatus.SimpleText:='第3点：分割帯の幅を指定してください（最低4px）。';
      end;
      2: begin
        if not BandEndpoints(Owner.Outline,FSplitA,FSplitB,P,FSplitC,FSplitD) then begin
          FStatus.SimpleText:='コマ内に幅4px以上の平行な帯を作れる位置を指定してください。'; Exit;
        end;
        FSplitStage:=3; FStatus.SimpleText:='第4点：表示した対側の交点付近をクリック。平行・同じ幅に補正します。';
      end;
      3: begin
        if Hypot(Double(P.X)-FSplitD.X,Double(P.Y)-FSplitD.Y)>Tolerance then begin
          FStatus.SimpleText:='第4点は表示された対側の交点付近です。右クリックで幅指定へ戻れます。'; Exit;
        end;
        CommitSplit(Index); Exit;
      end;
    end;
  end;
  UpdateIconState; FCanvas.Invalidate;
end;
procedure TMainForm.CommitSplit(Index: Integer);
var Owner,First,Second,Other: TComicPanel; One,Two: TArray<TPointF>; J: TJSONObject;
  OriginalImage,DefaultImage: TRectF; Balloon: TComicBalloon; Center,Near: TPointF; OldID: string; Number: Integer;
  procedure PreserveImage(Panel: TComicPanel);
  begin
    if OriginalImage.IsEmpty then Exit;
    DefaultImage:=FRenderer.ImageBounds(FProject,Panel);
    if DefaultImage.IsEmpty then Exit;
    Panel.Zoom:=Panel.Zoom*OriginalImage.Width/DefaultImage.Width;
    Panel.PanX:=OriginalImage.CenterPoint.X-Panel.Bounds.CenterPoint.X;
    Panel.PanY:=OriginalImage.CenterPoint.Y-Panel.Bounds.CenterPoint.Y;
  end;
begin
  CancelDrag;
  Owner:=Page.Panels[Index];
  if not SplitPolygonBand(Owner.Outline,FSplitA,FSplitB,FSplitC,One,Two) then begin
    FStatus.SimpleText:='この帯では有効な2コマになりません。右クリックで幅指定へ戻してください。'; Exit;
  end;
  First:=TComicPanel.Create; Second:=TComicPanel.Create;
  try
    J:=Owner.Json;
    try First.Read(J); Second.Read(J); finally J.Free; end;
    OldID:=Owner.ID; Number:=Owner.Number; Second.ID:=NewUID; Second.Number:=Number+1;
    First.SetVertices(One); Second.SetVertices(Two);
    PreservePanelOverlays(First,Owner.Bounds,False); PreservePanelOverlays(Second,Owner.Bounds,True);
    OriginalImage:=FRenderer.ImageBounds(FProject,Owner); PreserveImage(First); PreserveImage(Second);
    Checkpoint;
    for Other in Page.Panels do if (Other<>Owner) and (Other.Number>Number) then Inc(Other.Number);
    for Balloon in Page.Balloons do if Balloon.PanelID=OldID then begin
      Center:=Balloon.Bounds.CenterPoint;
      if PolygonContains(Two,Center) then Balloon.PanelID:=Second.ID
      else if not PolygonContains(One,Center) and
        (NearestEdgePoint(Two,Center,Near)<NearestEdgePoint(One,Center,Near)) then Balloon.PanelID:=Second.ID;
    end;
    Page.Panels.Delete(Index); Page.Panels.Insert(Index,First); First:=nil; Page.Panels.Insert(Index+1,Second); Second:=nil;
    ResetGeometryInput; SelectSinglePanel(Index); Changed;
    FStatus.SimpleText:='2コマへ分割しました。画像の位置・倍率を維持し、Undoで全体を戻せます。';
  finally First.Free; Second.Free; end;
end;
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
var C: TCanvas; R: TRect; B: TRectF; HandlePoint: TPointF; HX,HY,I: Integer; IDs: TArray<string>; Panel: TComicPanel; ID: string;
  function ScreenPoint(const P: TPointF): TPoint;
  begin Result:=Point(FPageRect.Left+Round(P.X*FScale),FPageRect.Top+Round(P.Y*FScale)); end;
  procedure GuideLine(const A,B: TPointF);
  var P,Q: TPoint;
  begin P:=ScreenPoint(A); Q:=ScreenPoint(B); C.MoveTo(P.X,P.Y); C.LineTo(Q.X,Q.Y); end;
begin
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
var Fit,BaseX,BaseY,DPI: Double; W,H,L,T,KeepX,KeepY,Margin: Integer;
begin
  if (FCanvas=nil) or (Page=nil) then begin FPageRect:=TRect.Empty; FScale:=1; Exit; end;
  if FViewportPageID<>Page.ID then begin
    EndViewPan(False); FViewZoom:=1; FViewPan:=TPointF.Zero; FViewportPageID:=Page.ID;
  end;
  DPI:=CurrentPPI/96; Margin:=MulDiv(24,CurrentPPI,96);
  Fit:=Min(Max(1,FCanvas.Width-2*Margin)/FProject.Width,Max(1,FCanvas.Height-2*Margin)/FProject.Height);
  FViewZoom:=EnsureRange(FViewZoom,0.1,16.0);
  W:=Max(1,Round(FProject.Width*Fit*FViewZoom)); FScale:=W/FProject.Width;
  H:=Max(1,Round(FProject.Height*FScale));
  BaseX:=(FCanvas.Width-W)/2; BaseY:=Margin;
  KeepX:=Max(1,Min(MulDiv(32,CurrentPPI,96),Min(W,FCanvas.Width)));
  KeepY:=Max(1,Min(MulDiv(32,CurrentPPI,96),Min(H,FCanvas.Height)));
  L:=EnsureRange(Round(BaseX+FViewPan.X*DPI),-W+KeepX,Max(-W+KeepX,FCanvas.Width-KeepX));
  T:=EnsureRange(Round(BaseY+FViewPan.Y*DPI),-H+KeepY,Max(-H+KeepY,FCanvas.Height-KeepY));
  FViewPan:=TPointF.Create((L-BaseX)/DPI,(T-BaseY)/DPI);
  FPageRect:=Rect(L,T,L+W,T+H);
end;
procedure TMainForm.ResetViewport;
begin
  EndViewPan(False); FViewZoom:=1; FViewPan:=TPointF.Zero; FViewportPageID:='';
  FScale:=1; FPageRect:=TRect.Empty;
  if FCanvas<>nil then FCanvas.Invalidate;
end;
procedure TMainForm.BeginViewPan(Button: TMouseButton; X,Y: Integer);
begin
  if FDragging or FViewPanning then Exit;
  ActiveControl:=FView; UpdateViewport;
  FViewPanStart:=FViewPan; FViewPanMouse:=Point(X,Y); FViewPanButton:=Button;
  FViewPanning:=True; FViewPanMoved:=False; FCanvas.Cursor:=crSizeAll;
  if not FTesting then FCanvas.MouseCapture:=True;
end;
procedure TMainForm.EndViewPan(Cancel: Boolean);
begin
  if not FViewPanning then Exit;
  FViewPanning:=False;
  if Cancel then FViewPan:=FViewPanStart;
  FCanvas.Cursor:=crDefault; FCanvas.MouseCapture:=False;
  UpdateViewport; FCanvas.Invalidate;
end;
procedure TMainForm.ViewCaptureLost(Sender: TObject);
begin
  if FViewPanning then EndViewPan(False);
  if FDragging then CancelDrag;
end;
procedure TMainForm.ViewWheel(Sender: TObject; Shift: TShiftState; WheelDelta: Integer; MousePos: TPoint; var Handled: Boolean);
var P: TPoint; Anchor: TPointF; Zoom,DPI: Double;
begin
  if (Page=nil) or (FCanvas=nil) then Exit;
  P:=FCanvas.ScreenToClient(MousePos);
  if not FCanvas.ClientRect.Contains(P) then Exit;
  Handled:=True;
  // A held edit/pan keeps its original coordinate frame until released.
  if FDragging or FViewPanning or (WheelDelta=0) then Exit;
  UpdateViewport; Anchor:=ToPage(P.X,P.Y);
  Zoom:=EnsureRange(FViewZoom*Power(1.15,EnsureRange(WheelDelta/120.0,-32.0,32.0)),0.1,16.0);
  if SameValue(Zoom,FViewZoom,1E-9) then Exit;
  FViewZoom:=Zoom; UpdateViewport; DPI:=CurrentPPI/96;
  FViewPan.Offset((P.X-FPageRect.Left-Anchor.X*FScale)/DPI,(P.Y-FPageRect.Top-Anchor.Y*FScale)/DPI);
  UpdateViewport; FCanvas.Invalidate;
  FStatus.SimpleText:=Format('表示 %.0f%% | ホイール: 拡大縮小 / 中央ドラッグ・空白の左ドラッグ: 移動 / Ctrl+0: 全体表示',[FScale*100]);
end;
function TMainForm.EmptyViewPoint(const P: TPointF): Boolean;
var Balloon: TComicBalloon; Tail: TComicTail; G: HRGN; R: TRectF; Point: TPointF; Overlay: TComicOverlay;
begin
  Result:=False;
  if not (FTool in [0,12,13]) then Exit;
  if (HitPanel(P)>=0) or (HitBalloon(P)>=0) then Exit;
  for Balloon in Page.Balloons do begin
    if FRenderer.BalloonTextBounds(Balloon).Contains(P) then Exit;
    for Tail in Balloon.Tails do begin
      G:=TailRegion(Tail,System.Types.Point(0,0),1);
      try if PtInRegion(G,Round(P.X),Round(P.Y)) then Exit; finally Winapi.Windows.DeleteObject(G); end;
    end;
  end;
  if (FPanelIndex>=0) and (FPanelIndex<Page.Panels.Count) then begin
    R:=Page.Panels[FPanelIndex].Bounds;
    if FTabs.ActivePageIndex=1 then begin
      R:=SelectedPanelBounds;
      if (Length(SelectedPanelIDs)>1) and R.Contains(P) then Exit;
      if (Length(SelectedPanelIDs)<=1) and (HitVertex(Page.Panels[FPanelIndex],P)>=0) then Exit;
    end;
    if FTabs.ActivePageIndex=2 then R:=FRenderer.ImageBounds(FProject,Page.Panels[FPanelIndex]);
    if HitHandle(R,P,9/FScale)<>0 then Exit;
  end;
  if (FBalloonIndex>=0) and (FBalloonIndex<Page.Balloons.Count) and (FTabs.ActivePageIndex=3) then begin
    Balloon:=Page.Balloons[FBalloonIndex]; R:=Balloon.Bounds;
    if FTool=13 then R:=FRenderer.BalloonTextBounds(Balloon);
    if HitHandle(R,P,9/FScale)<>0 then Exit;
    if (FTool=12) and (FTailIndex>=0) and (FTailIndex<Balloon.Tails.Count) then
      for Point in Balloon.Tails[FTailIndex].Handles do
        if Hypot(Point.X-P.X,Point.Y-P.Y)*FScale<=MulDiv(12,CurrentPPI,96) then Exit;
  end;
  if FTabs.ActivePageIndex=4 then begin
    Overlay:=SelectedEffect;
    if (FEffectCategory.ItemIndex=0) and (Overlay<>nil) and
      (HitHandle(OverlayBounds(Page.Panels[FPanelIndex],Overlay),P,9/FScale)<>0) then Exit;
  end;
  Result:=True;
end;

function TMainForm.ToPage(X,Y: Integer): TPointF;
begin UpdateViewport; Result:=TPointF.Create((X-FPageRect.Left)/FScale,(Y-FPageRect.Top)/FScale); end;
function TMainForm.HitPanel(const P: TPointF): Integer;
var I: Integer; G: HRGN; R: TRectF;
begin
  Result:=-1; if Page=nil then Exit;
  for I:=Page.Panels.Count-1 downto 0 do begin
    R:=Page.Panels[I].Bounds; if not R.Contains(P) then Continue;
    G:=PanelRegion(Page.Panels[I],Point(0,0),1);
    try if PtInRegion(G,Round(P.X),Round(P.Y)) then Exit(I); finally Winapi.Windows.DeleteObject(G); end;
  end;
end;
function TMainForm.HitBalloon(const P: TPointF): Integer;
var I: Integer; G: HRGN; R: TRectF;
begin
  Result:=-1; if Page=nil then Exit;
  for I:=Page.Balloons.Count-1 downto 0 do begin
    R:=Page.Balloons[I].Bounds; if not R.Contains(P) then Continue;
    if Page.Balloons[I].Transparent then Exit(I);
    G:=BalloonBodyRegion(Page.Balloons[I],Point(0,0),1);
    try if PtInRegion(G,Round(P.X),Round(P.Y)) then Exit(I); finally Winapi.Windows.DeleteObject(G); end;
  end;
end;
procedure TMainForm.CancelDrag;
begin
  EndViewPan(True);
  if not FDragging then Exit;
  FDragging:=False; FCanvas.MouseCapture:=False;
  FDragVertex:=-1;
  FDragTailHandle:=0;
  if FDragMoved then begin FProject.Restore(FDragSnapshot); RefreshUI; end;
  FDragMoved:=False; FDragSnapshot:=''; FCanvas.Invalidate;
  FDragGroup:=nil;
end;
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
// Selection is stored by UID and must follow the primary panel after creation.
// Synchronizing both prevents a later Ctrl click from resurrecting an old group.
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
var P: TPointF; R,Selected: TRectF; Panel: TComicPanel; Balloon: TComicBalloon; Handle: Integer; GroupMove: Boolean; Overlay: TComicOverlay;
begin
  // VCL dispatches DblClick before its trailing MouseDown(ssDouble).
  // Do not restart a drag or steal the text editor's focus after that event.
  if ssDouble in Shift then Exit;
  if Page=nil then Exit;
  if Button=mbMiddle then begin BeginViewPan(Button,X,Y); Exit; end;
  if FViewPanning then Exit;
  if (Button=mbRight) and (FTool=0) and (FTabs.ActivePageIndex=1) then begin
    if Length(SelectedPanelIDs)>1 then begin FStatus.SimpleText:='頂点を編集するコマを1つ選択してください。'; Exit; end;
    CancelDrag; EditVertexContext(ToPage(X,Y)); Exit;
  end;
  if (Button=mbRight) and (FTool in [8,9]) then begin
    if (FTool=8) and (FGeometryPoints.Count>0) then FGeometryPoints.Delete(FGeometryPoints.Count-1);
    if (FTool=9) and (FSplitStage>0) then Dec(FSplitStage);
    FCanvas.Invalidate; FStatus.SimpleText:='直前の指定へ戻りました。Escで全体を中止できます。'; Exit;
  end;
  if Button<>mbLeft then Exit; P:=ToPage(X,Y);
  FDragMouse:=Point(X,Y);
  if not FDragging and not (ssCtrl in Shift) and EmptyViewPoint(P) then begin BeginViewPan(Button,X,Y); Exit; end;
  ActiveControl:=FView;
  if FTabs.ActivePageIndex=4 then begin
    Overlay:=SelectedEffect; Handle:=0; R:=TRectF.Empty;
    if (FEffectCategory.ItemIndex=0) and (Overlay<>nil) then begin R:=OverlayBounds(Page.Panels[FPanelIndex],Overlay); Handle:=HitHandle(R,P,9/FScale); end;
    if (FEffectCategory.ItemIndex<>0) or ((Handle=0) and not R.Contains(P)) then begin
      FPanelIndex:=HitPanel(P); FEffectIndex:=-1;
      if (FPanelIndex>=0) and (FEffectCategory.ItemIndex=0) then FEffectIndex:=HitEffect(Page.Panels[FPanelIndex],P);
    end;
    FBalloonIndex:=-1; LoadPanelEffectControls; UpdateIconState; FCanvas.Invalidate;
    Overlay:=SelectedEffect; if Overlay=nil then Exit;
    FDragBounds:=OverlayBounds(Page.Panels[FPanelIndex],Overlay); FDragHandle:=HitHandle(FDragBounds,P,9/FScale);
    FDragSnapshot:=FProject.Snapshot; FDragMoved:=False; FDragging:=True; FStart:=P; FLast:=P; FDragVertex:=-1; FDragTailHandle:=0;
    if not FTesting then FCanvas.MouseCapture:=True; Exit;
  end;
  if FTool=12 then begin TailEditClick(P); Exit; end;
  if FTool=13 then begin
    if (FBalloonIndex<0) or (FBalloonIndex>=Page.Balloons.Count) then Exit; Balloon:=Page.Balloons[FBalloonIndex];
    FDragBounds:=FRenderer.BalloonTextBounds(Balloon); if FDragBounds.IsEmpty then Exit;
    FDragHandle:=HitHandle(FDragBounds,P,9/FScale); if (FDragHandle=0) and not FDragBounds.Contains(P) then Exit;
    FDragTextOffset:=Balloon.TextOffset; FDragFontSize:=Balloon.FontSize; FDragSnapshot:=FProject.Snapshot;
    FDragBalloonTransform:=Balloon.CaptureTransform;
    FStart:=P; FLast:=P; FDragMoved:=False; FDragging:=True; FDragTailHandle:=0;
    if not FTesting then FCanvas.MouseCapture:=True; UpdateIconState; FCanvas.Invalidate; Exit;
  end;
  if (FTool=0) and (FTabs.ActivePageIndex=1) and (ssCtrl in Shift) then begin
    CancelDrag; TogglePanelSelection(HitPanel(P)); Exit;
  end;
  FDragGroup:=nil;
  Handle:=0; FDragVertex:=-1; Selected:=TRectF.Empty; GroupMove:=False;
  if FTool=0 then begin
    if (FTabs.ActivePageIndex=3) and (FBalloonIndex>=0) and (FBalloonIndex<Page.Balloons.Count) then
      Selected:=Page.Balloons[FBalloonIndex].Bounds
    else if (FPanelIndex>=0) and (FPanelIndex<Page.Panels.Count) then begin
      Selected:=Page.Panels[FPanelIndex].Bounds;
      if FTabs.ActivePageIndex=1 then Selected:=SelectedPanelBounds;
      if FTabs.ActivePageIndex=2 then Selected:=FRenderer.ImageBounds(FProject,Page.Panels[FPanelIndex]);
    end;
    Handle:=HitHandle(Selected,P,9/FScale);
    GroupMove:=(FTabs.ActivePageIndex=1) and (Length(SelectedPanelIDs)>1) and Selected.Contains(P) and (HitPanel(P)<0);
    if (Handle=0) and (FTabs.ActivePageIndex=1) and (FPanelIndex>=0) and (FPanelIndex<Page.Panels.Count) and (Length(SelectedPanelIDs)<=1) then
      FDragVertex:=HitVertex(Page.Panels[FPanelIndex],P);
  end;
  if (Handle=0) and not FPageRect.Contains(Point(X,Y)) and not (FTool in [8,9]) then Exit;
  if FTool=9 then begin SplitClick(P); Exit; end;
  if FTool=8 then begin
    if FImages.Count=0 then Exit;
    if not (ssAlt in Shift) then P:=SnapCreationPoint(P); PolygonClick(P); Exit;
  end;
  if FTool in [7,11] then begin TailClick(P); Exit; end;
  if FTool in [1,2,3,5,6,10] then begin
    if FImages.Count=0 then begin Notify('画像管理で画像を登録してください。'); Exit; end;
    if (FTool in [1,2,3]) and not (ssAlt in Shift) then P:=SnapCreationPoint(P);
    if not FFirst then begin FStart:=P; FLast:=P; FFirst:=True; FStatus.SimpleText:='2点目をクリックしてください。'; FCanvas.Invalidate; Exit; end;
    R:=TRectF.Create(Min(P.X,FStart.X),Min(P.Y,FStart.Y),Max(P.X,FStart.X),Max(P.Y,FStart.Y));
    if (R.Width<30) or (R.Height<30) then Exit; Checkpoint; FFirst:=False;
    if FTool<5 then begin Panel:=TComicPanel.Create; Panel.Bounds:=R; Panel.Shape:=FTool-1; Panel.Number:=Page.Panels.Count+1;
      Page.Panels.Add(Panel); SelectSinglePanel(Page.Panels.Count-1); end
    else begin Balloon:=TComicBalloon.Create; Balloon.Bounds:=R; Balloon.Contour:=TComicBalloonContour(Max(0,FContour.ItemIndex));
      if FTool=10 then Balloon.Shape:=0 else Balloon.Shape:=FTool-4;
      FPanelIndex:=HitPanel(FStart); if FPanelIndex>=0 then Balloon.PanelID:=Page.Panels[FPanelIndex].ID;
      Page.Balloons.Add(Balloon); FBalloonIndex:=Page.Balloons.Count-1; LoadBalloonControls(Balloon); end;
    Changed; Exit;
  end;
  if FTool=4 then begin
    FPanelIndex:=HitPanel(P); if FPanelIndex>=0 then begin Checkpoint; Page.Panels[FPanelIndex].Number:=FNumber; Inc(FNumber); Changed; end;
    UpdateIconState; FCanvas.Invalidate; Exit;
  end;
  if (Handle=0) and (FDragVertex<0) and not GroupMove then begin
    FBalloonIndex:=-1; if FTabs.ActivePageIndex=3 then FBalloonIndex:=HitBalloon(P);
    FPanelIndex:=HitPanel(P);
    if (FTabs.ActivePageIndex=1) and ((FPanelIndex<0) or not FSelectedPanels.Contains(Page.Panels[FPanelIndex].ID)) then begin
      FSelectedPanels.Clear; if FPanelIndex>=0 then FSelectedPanels.Add(Page.Panels[FPanelIndex].ID);
    end;
  end;
  if FBalloonIndex>=0 then begin
    Balloon:=Page.Balloons[FBalloonIndex]; FDragBounds:=Balloon.Bounds; LoadBalloonControls(Balloon);
    FDragBalloonTransform:=Balloon.CaptureTransform;
  end else if FPanelIndex>=0 then begin
    Panel:=Page.Panels[FPanelIndex]; FDragBounds:=Panel.Bounds; FDragZoom:=Panel.Zoom;
    FDragVertices:=Copy(Panel.Vertices,0,Length(Panel.Vertices));
    if (FTabs.ActivePageIndex=1) and (Length(SelectedPanelIDs)>1) then begin
      FDragGroup:=CapturePanelTransforms(Page,SelectedPanelIDs); FDragBounds:=PanelGroupBounds(FDragGroup); FDragVertices:=nil;
    end;
    if FDragVertex>=0 then begin FDragVertices:=Panel.Outline; FDragImageBounds:=FRenderer.ImageBounds(FProject,Panel); end;
    if FTabs.ActivePageIndex=2 then begin
      FDragBounds:=FRenderer.ImageBounds(FProject,Panel);
      SyncZoom;
      if FDragBounds.IsEmpty then begin UpdateIconState; FCanvas.Invalidate; Exit; end;
    end;
  end else begin UpdateIconState; FCanvas.Invalidate; Exit; end;
  FDragSnapshot:=FProject.Snapshot; FDragMoved:=False; FDragging:=True;
  if not FTesting then FCanvas.MouseCapture:=True;
  FStart:=P; FLast:=P;
  FDragHandle:=HitHandle(FDragBounds,P,9/FScale);
  UpdateIconState; FCanvas.Invalidate;
end;
procedure TMainForm.MouseMove(Sender: TObject; Shift: TShiftState; X,Y: Integer);
var P,Delta,Q: TPointF; R,Actual: TRectF; Panel: TComicPanel; Candidate: TArray<TPointF>; I,FontSize: Integer;
  Balloon,TextProbe: TComicBalloon; Offset: TPointF;
  TextLayoutSize: TSizeF; TextLayoutFontSize: Integer;
  Tail,Probe: TComicTail; TailLength: Double; Overlay: TComicOverlay;
begin
  if FViewPanning then begin
    if (Page=nil) or ((FViewPanButton=mbMiddle) and not (ssMiddle in Shift)) or
      ((FViewPanButton=mbLeft) and not (ssLeft in Shift)) then begin EndViewPan(False); Exit; end;
    if not FViewPanMoved and (Abs(X-FViewPanMouse.X)+Abs(Y-FViewPanMouse.Y)<MulDiv(3,CurrentPPI,96)) then Exit;
    FViewPanMoved:=True;
    FViewPan:=TPointF.Create(FViewPanStart.X+(X-FViewPanMouse.X)*96/CurrentPPI,
      FViewPanStart.Y+(Y-FViewPanMouse.Y)*96/CurrentPPI);
    UpdateViewport; FCanvas.Invalidate; Exit;
  end;
  if Page=nil then Exit; P:=ToPage(X,Y);
  if not FDragging then begin
    if FFirst or (FGeometryPoints.Count>0) or (FSplitStage>0) then begin
      if (FTool in [1,2,3,8]) and not (ssAlt in Shift) then P:=SnapCreationPoint(P);
      FLast:=P; FCanvas.Invalidate;
    end;
    Exit;
  end;
  if not (ssLeft in Shift) then begin CancelDrag; Exit; end;
  Delta:=TPointF.Create(P.X-FStart.X,P.Y-FStart.Y);
  // Use integer screen displacement for the one-pixel threshold. Converting
  // a one-pixel move through Single page coordinates can round below 1.0.
  if not FDragMoved and (X=FDragMouse.X) and (Y=FDragMouse.Y) then Exit;
  FDragMoved:=True; R:=FDragBounds;
  if FTabs.ActivePageIndex=4 then begin
    Overlay:=SelectedEffect; if Overlay=nil then Exit; Panel:=Page.Panels[FPanelIndex];
    if FDragHandle<>0 then R:=ResizeImageRect(FDragBounds,Delta,FDragHandle,0.01) else R.Offset(Delta.X,Delta.Y);
    R:=TRectF.Create((R.Left-Panel.Bounds.Left)/Panel.Bounds.Width,(R.Top-Panel.Bounds.Top)/Panel.Bounds.Height,
      (R.Right-Panel.Bounds.Left)/Panel.Bounds.Width,(R.Bottom-Panel.Bounds.Top)/Panel.Bounds.Height);
    if IsNan(R.Left) or IsNan(R.Top) or IsNan(R.Width) or IsNan(R.Height) or IsInfinite(R.Left) or IsInfinite(R.Top) or
      IsInfinite(R.Width) or IsInfinite(R.Height) or (Abs(R.Left)>1000) or (Abs(R.Top)>1000) or
      (R.Width<=0) or (R.Height<=0) or (R.Width>1000) or (R.Height>1000) then Exit;
    Overlay.Bounds:=R; FLast:=P; FCanvas.Invalidate; Exit;
  end;
  if (FTool=13) and (FBalloonIndex>=0) then begin
    Balloon:=Page.Balloons[FBalloonIndex]; FontSize:=FDragFontSize; Offset:=FDragTextOffset;
    TextLayoutSize:=FDragBalloonTransform.TextLayoutSize; TextLayoutFontSize:=FDragBalloonTransform.TextLayoutFontSize;
    if FDragHandle=0 then Offset.Offset(Delta.X,Delta.Y)
    else begin
      R:=ResizeImageRect(FDragBounds,Delta,FDragHandle,1/Max(1,FDragFontSize));
      FontSize:=EnsureRange(Round(FDragFontSize*R.Width/FDragBounds.Width),1,1000); TextProbe:=TComicBalloon.Create;
      try
        TextProbe.Bounds:=Balloon.Bounds; TextProbe.Text:=Balloon.Text; TextProbe.Vertical:=Balloon.Vertical;
        TextProbe.FontFamily:=Balloon.FontFamily; TextProbe.FontStyle:=Balloon.FontStyle; TextProbe.FontSize:=FontSize; TextProbe.TextOffset:=FDragTextOffset;
        TextProbe.TextLayoutSize:=FDragBalloonTransform.TextLayoutSize; TextProbe.TextLayoutFontSize:=FDragBalloonTransform.TextLayoutFontSize;
        if TextProbe.TextLayoutFontSize=0 then begin
          TextProbe.TextLayoutSize:=TSizeF.Create(Max(1,Round(Balloon.Bounds.Right)-Round(Balloon.Bounds.Left)-36),Max(1,Round(Balloon.Bounds.Bottom)-Round(Balloon.Bounds.Top)-36));
          TextProbe.TextLayoutFontSize:=FDragFontSize;
        end;
        Actual:=FRenderer.BalloonTextBounds(TextProbe); Offset.Offset(R.CenterPoint.X-Actual.CenterPoint.X,R.CenterPoint.Y-Actual.CenterPoint.Y);
        TextLayoutSize:=TextProbe.TextLayoutSize; TextLayoutFontSize:=TextProbe.TextLayoutFontSize;
      finally TextProbe.Free; end;
    end;
    if IsNan(Offset.X) or IsInfinite(Offset.X) or IsNan(Offset.Y) or IsInfinite(Offset.Y) or (Abs(Offset.X)>80000) or (Abs(Offset.Y)>80000) then Exit;
    Balloon.TextOffset:=Offset; Balloon.FontSize:=FontSize; Balloon.TextLayoutSize:=TextLayoutSize;
    Balloon.TextLayoutFontSize:=TextLayoutFontSize; FLast:=P; FCanvas.Invalidate; Exit;
  end;
  if (FDragTailHandle>0) and (FBalloonIndex>=0) and (FTailIndex>=0) then begin
    Tail:=Page.Balloons[FBalloonIndex].Tails[FTailIndex]; Probe:=TComicTail.Create;
    try
      Probe.Root:=FDragTailState.Root; Probe.Tip:=FDragTailState.Tip; Probe.Width:=FDragTailState.Width;
      case FDragTailHandle of
        1: begin Probe.Root.Offset(Delta.X,Delta.Y); if not InsideBalloonBody(Page.Balloons[FBalloonIndex],Probe.Root) then Exit; end;
        2: begin
          Q:=TPointF.Create(Probe.Tip.X-Probe.Root.X,Probe.Tip.Y-Probe.Root.Y); TailLength:=Max(1,Hypot(Q.X,Q.Y));
          Probe.Width:=EnsureRange(Abs(FDragTailState.Width/2+(-Q.Y*Delta.X+Q.X*Delta.Y)/TailLength)*2,1.0,2000.0);
        end;
        3: Probe.Tip.Offset(Delta.X,Delta.Y);
      end;
      if not Probe.Valid then Exit;
      Tail.Root:=Probe.Root; Tail.Tip:=Probe.Tip; Tail.Width:=Probe.Width;
    finally Probe.Free; end;
    FLast:=P; FCanvas.Invalidate; Exit;
  end;
  if Length(FDragGroup)>1 then begin
    if FDragHandle<>0 then R:=ResizePanelGroup(FDragGroup,FDragBounds,Delta,FDragHandle) else R.Offset(Delta.X,Delta.Y);
    if not (ssAlt in Shift) then R:=SnapPanelDragBounds(R);
    if not ApplyPanelGroupTransform(Page,FDragGroup,FDragBounds,R) then begin
      FStatus.SimpleText:='複数選択の変形で無効なコマが生じるため、直前の有効形状を維持します。'; Exit;
    end;
    FLast:=P; FCanvas.Invalidate; Exit;
  end;
  if (FDragVertex>=0) and (FPanelIndex>=0) then begin
    Candidate:=Copy(FDragVertices,0,Length(FDragVertices));
    Candidate[FDragVertex]:=TPointF.Create(FDragVertices[FDragVertex].X+Delta.X,FDragVertices[FDragVertex].Y+Delta.Y);
    if not (ssAlt in Shift) then Candidate[FDragVertex]:=SnapCreationPoint(Candidate[FDragVertex],Page.Panels[FPanelIndex].ID);
    if not ValidPolygon(Candidate) then begin FStatus.SimpleText:='交差やゼロ面積になる頂点移動は確定できません。'; Exit; end;
    Panel:=Page.Panels[FPanelIndex]; Panel.SetVertices(Candidate); PreservePanelImage(Panel,FDragImageBounds);
    FLast:=P; FCanvas.Invalidate; Exit;
  end;
  if (FTabs.ActivePageIndex=2) and (FPanelIndex>=0) then begin
    Panel:=Page.Panels[FPanelIndex];
    if FDragHandle<>0 then R:=ResizeImageRect(FDragBounds,Delta,FDragHandle,0.1/Max(0.1,FDragZoom))
    else R.Offset(Delta.X,Delta.Y);
    Panel.Zoom:=FDragZoom*R.Width/FDragBounds.Width;
    Panel.PanX:=(R.Left+R.Right-Panel.Bounds.Left-Panel.Bounds.Right)/2;
    Panel.PanY:=(R.Top+R.Bottom-Panel.Bounds.Top-Panel.Bounds.Bottom)/2;
  end else begin
    if FDragHandle<>0 then R:=ResizeRect(FDragBounds,Delta,FDragHandle,30)
    else R.Offset(Delta.X,Delta.Y);
    if (FTabs.ActivePageIndex=1) and (FBalloonIndex<0) and (FPanelIndex>=0) and not (ssAlt in Shift) then R:=SnapPanelDragBounds(R);
    if FBalloonIndex>=0 then begin
      if not Page.Balloons[FBalloonIndex].ApplyTransform(FDragBalloonTransform,R) then begin
        FStatus.SimpleText:='本体としっぽの有効な形状を維持できない変形は確定できません。'; Exit;
      end;
    end else if FPanelIndex>=0 then begin
      Panel:=Page.Panels[FPanelIndex];
      if Length(FDragVertices)>0 then begin
        SetLength(Candidate,Length(FDragVertices));
        for I:=0 to High(Candidate) do Candidate[I]:=TPointF.Create(
          R.Left+(FDragVertices[I].X-FDragBounds.Left)*R.Width/FDragBounds.Width,
          R.Top+(FDragVertices[I].Y-FDragBounds.Top)*R.Height/FDragBounds.Height);
        if not ValidPolygon(Candidate) then begin
          FStatus.SimpleText:='縮小後の多角形が小さすぎるため、直前の有効な形を維持します。'; Exit;
        end;
        Panel.SetVertices(Candidate);
      end else Panel.SetBounds(R);
    end;
  end;
  FLast:=P; FCanvas.Invalidate;
end;
procedure TMainForm.MouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X,Y: Integer);
begin
  if FViewPanning then begin
    if Button<>FViewPanButton then Exit;
    EndViewPan(False);
    if (Button=mbLeft) and not FViewPanMoved and (FTool=0) and FPageRect.Contains(Point(X,Y)) then begin
      FSelectedPanels.Clear; FPanelIndex:=-1; FBalloonIndex:=-1; FEffectIndex:=-1;
      UpdateIconState; FCanvas.Invalidate;
    end;
    Exit;
  end;
  if not FDragging or (Button<>mbLeft) then Exit;
  FDragging:=False; FCanvas.MouseCapture:=False;
  if FDragMoved and (FProject.Snapshot<>FDragSnapshot) then begin
    if (FBalloonIndex>=0) and (FDragTailHandle=0) then LoadBalloonControls(Page.Balloons[FBalloonIndex]);
    FUndo.Add(FDragSnapshot); FRedo.Clear; if FUndo.Count>40 then FUndo.Delete(0); Changed;
  end;
  FDragSnapshot:=''; FDragMoved:=False;
  FDragVertex:=-1;
  FDragTailHandle:=0;
  FDragGroup:=nil;
end;
procedure TMainForm.DeleteObject(Sender: TObject);
var I: Integer; UID: string; IDs: TArray<string>;
begin
  if Page=nil then Exit;
  if (Sender<>nil) and (TControl(Sender).Tag=1) then begin
    if FBalloonIndex<0 then Exit; Checkpoint; Page.Balloons.Delete(FBalloonIndex); FBalloonIndex:=-1;
  end else begin
    IDs:=SelectedPanelIDs; if Length(IDs)=0 then Exit; Checkpoint;
    for I:=Page.Balloons.Count-1 downto 0 do for UID in IDs do if Page.Balloons[I].PanelID=UID then begin Page.Balloons.Delete(I); Break; end;
    for I:=Page.Panels.Count-1 downto 0 do for UID in IDs do if Page.Panels[I].ID=UID then begin Page.Panels.Delete(I); Break; end;
    FSelectedPanels.Clear; FPanelIndex:=-1; FBalloonIndex:=-1;
  end; Changed;
end;
procedure TMainForm.AssignImage(Sender: TObject);
var A: TComicAsset; P: TComicPanel;
begin
  if (Page=nil) or (FPanelIndex<0) or (FImages.ItemIndex<0) then Exit;
  Checkpoint; A:=TComicAsset(FImages.Items.Objects[FImages.ItemIndex]); P:=Page.Panels[FPanelIndex];
  P.ImageID:=A.ID; P.Zoom:=1; P.PanX:=0; P.PanY:=0; FZoom.ItemIndex:=0; Changed;
end;
procedure TMainForm.DragOver(Sender,Source: TObject; X,Y: Integer; State: TDragState; var Accept: Boolean);
begin
  Accept:=(Page<>nil) and HasCharacter and FPageRect.Contains(Point(X,Y)) and
    (((Source=FImages) and (FImages.ItemIndex>=0) and (HitPanel(ToPage(X,Y))>=0)) or
     ((Source=FLayoutList) and (FLayoutList.ItemIndex>=0)) or
     ((Source=FEffectList) and (FEffectList.ItemIndex>=0) and (FTabs.ActivePageIndex=4) and (FEffectCategory.ItemIndex=0) and (HitPanel(ToPage(X,Y))>=0)));
end;
procedure TMainForm.DragDrop(Sender,Source: TObject; X,Y: Integer);
begin
  if (Page=nil) or not FPageRect.Contains(Point(X,Y)) then Exit;
  if Source=FLayoutList then begin Template(nil); Exit; end;
  if Source=FEffectList then begin
    if (FTabs.ActivePageIndex=4) and (FEffectCategory.ItemIndex=0) and (FEffectList.ItemIndex>=0) then
      ApplyEffectMaterial(HitPanel(ToPage(X,Y)),TComicEffectMaterial(FEffectList.Items.Objects[FEffectList.ItemIndex])); Exit;
  end;
  if Source<>FImages then Exit; FPanelIndex:=HitPanel(ToPage(X,Y)); AssignImage(nil);
end;
procedure TMainForm.ImageZoom(Sender: TObject);
begin
  if (Page=nil) or (FPanelIndex<0) then Exit; Checkpoint;
  Page.Panels[FPanelIndex].Zoom:=StrToIntDef(StringReplace(FZoom.Text,'%','',[rfReplaceAll]),100)/100; Changed;
end;
procedure TMainForm.ApplyText(Sender: TObject);
var B: TComicBalloon; OldText,OldFamily: string; OldVertical: Boolean; OldStyle: TFontStyles;
begin
  if (Page=nil) or (FBalloonIndex<0) then Exit; Checkpoint; B:=Page.Balloons[FBalloonIndex];
  OldText:=B.Text; OldFamily:=B.FontFamily; OldVertical:=B.Vertical; OldStyle:=B.FontStyle;
  B.Text:=FText.Text; B.Vertical:=FVertical.Checked; B.Transparent:=FTransparent.Checked;
  B.Overflow:=FOverflow.Checked; B.FontSize:=StrToIntDef(FFont.Text,40);
  B.FontFamily:=FFontFamily.Text; if B.FontFamily='' then B.FontFamily:='Yu Gothic'; B.FontColor:=FTextColor; B.FontStyle:=[];
  if FFontBold.Checked then Include(B.FontStyle,fsBold); if FFontItalic.Checked then Include(B.FontStyle,fsItalic);
  if FFontUnderline.Checked then Include(B.FontStyle,fsUnderline); if FFontStrikeOut.Checked then Include(B.FontStyle,fsStrikeOut);
  if (B.Text<>OldText) or (B.FontFamily<>OldFamily) or (B.Vertical<>OldVertical) or (B.FontStyle<>OldStyle) then B.ResetTextLayout;
  B.FillColor:=FFillColor; B.BorderColor:=FBorderColor; B.BorderWidth:=StrToFloatDef(FBorderWidth.Text,3);
  B.Contour:=TComicBalloonContour(Max(0,FContour.ItemIndex));
  Changed;
  if FFontHistoryWritable then
    try FFontHistory.Remember(B.FontFamily,TPath.Combine(DataRoot,'Presets\FontHistory.json'));
    except on E: Exception do begin FFontHistoryWritable:=False; FStatus.SimpleText:='文字は反映しました。フォント履歴の保存に失敗しました：'+E.Message; end; end;
end;
procedure TMainForm.LoadBalloonControls(Balloon: TComicBalloon);
var Index: Integer;
begin
  FText.Text:=Balloon.Text; FVertical.Checked:=Balloon.Vertical; FTransparent.Checked:=Balloon.Transparent; FOverflow.Checked:=Balloon.Overflow;
  FContour.ItemIndex:=Ord(Balloon.Contour);
  Index:=FFont.Items.IndexOf(IntToStr(Balloon.FontSize)); if Index<0 then Index:=FFont.Items.Add(IntToStr(Balloon.FontSize)); FFont.ItemIndex:=Index;
  Index:=FFontFamily.Items.IndexOf(Balloon.FontFamily); if Index<0 then Index:=FFontFamily.Items.Add(Balloon.FontFamily); FFontFamily.ItemIndex:=Index;
  FTextColor:=Balloon.FontColor; FFontBold.Checked:=fsBold in Balloon.FontStyle; FFontItalic.Checked:=fsItalic in Balloon.FontStyle;
  FFontUnderline.Checked:=fsUnderline in Balloon.FontStyle; FFontStrikeOut.Checked:=fsStrikeOut in Balloon.FontStyle;
  FFillColor:=Balloon.FillColor; FBorderColor:=Balloon.BorderColor;
  Index:=FBorderWidth.Items.IndexOf(FloatToStr(Balloon.BorderWidth)); if Index<0 then Index:=FBorderWidth.Items.Add(FloatToStr(Balloon.BorderWidth)); FBorderWidth.ItemIndex:=Index;
end;
procedure TMainForm.FontDropDown(Sender: TObject);
var Current: string; Index: Integer;
begin
  Current:=FFontFamily.Text; FFontFamily.Items.BeginUpdate;
  try
    FFontFamily.Items.Clear; FFontFamily.Items.AddStrings(FFontHistory.Choices(Screen.Fonts));
    if Current<>'' then begin Index:=FFontFamily.Items.IndexOf(Current); if Index<0 then Index:=FFontFamily.Items.Add(Current); FFontFamily.ItemIndex:=Index; end;
  finally FFontFamily.Items.EndUpdate; end;
end;
procedure TMainForm.ChooseTextColor(Sender: TObject);
var Dialog: TColorDialog; Tag: Integer;
begin
  if (Page=nil) or (FBalloonIndex<0) then Exit;
  Tag:=TControl(Sender).Tag; Dialog:=TColorDialog.Create(Self);
  try
    case Tag of 1: Dialog.Color:=FFillColor; 2: Dialog.Color:=FBorderColor; else Dialog.Color:=FTextColor; end;
    Dialog.Options:=[cdFullOpen]; if Dialog.Execute then
      case Tag of 1: FFillColor:=Dialog.Color; 2: FBorderColor:=Dialog.Color; else FTextColor:=Dialog.Color; end;
  finally Dialog.Free; end;
end;
procedure TMainForm.TextInputDialog(Sender: TObject);
var Dialog: TComicTextDialog;
begin
  if (Page=nil) or (FBalloonIndex<0) or (FBalloonIndex>=Page.Balloons.Count) then Exit;
  CancelDrag; Dialog:=CreateBalloonTextDialog;
  try
    Dialog.ShowModal; FinishTextDialog(Dialog);
  finally Dialog.Free; end;
end;
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
begin
  if Dialog.ModalResult=mrOK then begin FText.Text:=Dialog.Editor.Text; ApplyText(nil); end;
end;
procedure TMainForm.Tail(Sender: TObject);
begin
  if FBalloonIndex<0 then begin Notify('先に吹き出しを選択してください。'); Exit; end;
  CancelDrag; ResetGeometryInput; FTool:=TControl(Sender).Tag; FFirst:=False;
  if FTool=12 then begin FTailIndex:=Page.Balloons[FBalloonIndex].Tails.Count-1; FStatus.SimpleText:='しっぽをクリック。3点で根元・幅・先端を編集。削除は右のボタン。'; end
  else FStatus.SimpleText:='根元を本体内でクリックし、次に先端位置をクリックしてください。';
  UpdateIconState; FCanvas.Invalidate;
end;
function TMainForm.InsideBalloonBody(Balloon: TComicBalloon; const P: TPointF): Boolean;
var Region: HRGN;
begin
  Region:=BalloonBodyRegion(Balloon,Point(0,0),1);
  try Result:=PtInRegion(Region,Round(P.X),Round(P.Y)); finally Winapi.Windows.DeleteObject(Region); end;
end;
procedure TMainForm.TailClick(const P: TPointF);
var Balloon: TComicBalloon; Tail: TComicTail;
begin
  CancelDrag;
  if (FBalloonIndex<0) or (FBalloonIndex>=Page.Balloons.Count) then Exit; Balloon:=Page.Balloons[FBalloonIndex];
  if not FFirst then begin
    if not InsideBalloonBody(Balloon,P) then begin FStatus.SimpleText:='しっぽの根元は選択中の吹き出し本体内に指定してください。'; Exit; end;
    FStart:=P; FLast:=P; FFirst:=True; FCanvas.Invalidate; Exit;
  end;
  if Balloon.Tails.Count>=64 then begin FStatus.SimpleText:='1つの吹き出しのしっぽは最大64個です。'; Exit; end;
  Tail:=TComicTail.Create; Tail.Root:=FStart; Tail.Tip:=P; Tail.Width:=Min(2000,Max(8,Balloon.Bounds.Width/6));
  if FTool=11 then Tail.Kind:=ctThought;
  if not Tail.Valid then begin Tail.Free; FStatus.SimpleText:='根元と先端を離して指定してください。'; Exit; end;
  Checkpoint; Balloon.Tails.Add(Tail); FTailIndex:=Balloon.Tails.Count-1; FFirst:=False; FTool:=12; Changed;
end;
procedure TMainForm.TailEditClick(const P: TPointF);
var Balloon: TComicBalloon; Tail: TComicTail; Handles: TArray<TPointF>; I,K: Integer; Best,Distance: Double; Region: HRGN;
begin
  if (FBalloonIndex<0) or (FBalloonIndex>=Page.Balloons.Count) then Exit; Balloon:=Page.Balloons[FBalloonIndex];
  FDragTailHandle:=0; Best:=MulDiv(9,CurrentPPI,96)/Max(0.001,FScale);
  for I:=0 to Balloon.Tails.Count-1 do begin
    Handles:=Balloon.Tails[I].Handles;
    for K:=0 to High(Handles) do begin Distance:=Hypot(Handles[K].X-P.X,Handles[K].Y-P.Y);
      if Distance<=Best then begin Best:=Distance; FTailIndex:=I; FDragTailHandle:=K+1; end;
    end;
  end;
  if FDragTailHandle=0 then begin
    for I:=Balloon.Tails.Count-1 downto 0 do begin Region:=TailRegion(Balloon.Tails[I],Point(0,0),1);
      try if PtInRegion(Region,Round(P.X),Round(P.Y)) then begin FTailIndex:=I; Break; end; finally Winapi.Windows.DeleteObject(Region); end;
    end;
    UpdateIconState; FCanvas.Invalidate; Exit;
  end;
  Tail:=Balloon.Tails[FTailIndex]; FDragTailState.Root:=Tail.Root; FDragTailState.Tip:=Tail.Tip; FDragTailState.Width:=Tail.Width;
  FStart:=P; FLast:=P; FDragSnapshot:=FProject.Snapshot; FDragMoved:=False; FDragging:=True; FDragHandle:=0;
  FDragMouse:=Point(FPageRect.Left+Round(P.X*FScale),FPageRect.Top+Round(P.Y*FScale));
  if not FTesting then FCanvas.MouseCapture:=True;
  UpdateIconState; FCanvas.Invalidate;
end;
procedure TMainForm.DeleteTail(Sender: TObject);
begin
  if (Page=nil) or (FBalloonIndex<0) or (FTailIndex<0) or (FTailIndex>=Page.Balloons[FBalloonIndex].Tails.Count) then Exit;
  Checkpoint; Page.Balloons[FBalloonIndex].Tails.Delete(FTailIndex); FTailIndex:=Min(FTailIndex,Page.Balloons[FBalloonIndex].Tails.Count-1);
  if FTailIndex<0 then FTool:=0; Changed;
end;
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
  if (ssCtrl in Shift) and FTabs.Enabled then begin
    if Key=VK_TAB then begin
      if ssShift in Shift then FModeButtons[(FTabs.ActivePageIndex+High(FModeButtons)) mod Length(FModeButtons)].Click
      else FModeButtons[(FTabs.ActivePageIndex+1) mod Length(FModeButtons)].Click;
      Key:=0; Exit;
    end;
    if (Key>=Ord('1')) and (Key<=Ord('1')+High(FModeButtons)) then begin FModeButtons[Key-Ord('1')].Click; Key:=0; Exit; end;
    if (Key=Ord('A')) and (ActiveControl=FView) and (FTabs.ActivePageIndex=1) and (Page<>nil) then begin
      CancelDrag; FSelectedPanels.Clear; for Panel in Page.Panels do FSelectedPanels.Add(Panel.ID);
      FPanelIndex:=Page.Panels.Count-1; FBalloonIndex:=-1; FTool:=0; FFirst:=False; ResetGeometryInput;
      UpdateIconState; FCanvas.Invalidate; Key:=0; Exit;
    end;
  end;
  if (ssCtrl in Shift) and (Key in [Ord('0'),VK_NUMPAD0]) and (FProject<>nil) then begin
    CancelDrag; ResetViewport; Key:=0; Exit;
  end;
  if ActiveControl=FText then Exit;
  if (Key=VK_DELETE) and (ActiveControl=FView) and (FTabs.ActivePageIndex=1) then begin DeleteObject(nil); Key:=0; Exit; end;
  if (Key=VK_DELETE) and (ActiveControl=FView) and (FTabs.ActivePageIndex=4) then begin DeleteEffect(nil); Key:=0; Exit; end;
  if Key=VK_ESCAPE then begin CancelDrag; ResetGeometryInput; FFirst:=False; FTool:=0; UpdateIconState; FCanvas.Invalidate; Key:=0; end;
end;

procedure TMainForm.SmokeTest(const Folder: string);
var B: TBitmap; A,A2: TComicAsset; P: TComicPanel; Balloon: TComicBalloon;
  Loaded: TComicProject; Snapshot,AssetID,FirstID,SecondID,ThirdID,FourthID,CacheFile: string;
  Dialog: TAssetDialog; Layout: TComicLayout; LibraryCopy: TObjectList<TComicLayout>;
  J: TJSONObject; R: TRect; Accept,Failed: Boolean; N,BeforeOutput: Integer; Lines: TStringList;
  SignatureLock: THandle;
  procedure Check(Condition: Boolean; const Message: string);
  begin
    if not Condition then raise Exception.Create(Message);
    Lines.Add('PASS: '+Message);
    Lines.SaveToFile(TPath.Combine(Folder,'progress.txt'),TEncoding.UTF8);
  end;
  procedure Capture(const Name: string);
  begin
    UpdateIconState; HandleNeeded; B.SetSize(ClientWidth,ClientHeight); PaintTo(B.Canvas,0,0);
    B.SaveToFile(TPath.Combine(Folder,Name+'.bmp'));
  end;
  procedure SelectOnly(Index: Integer);
  var K: Integer;
  begin
    FPages.ItemIndex:=Index; for K:=0 to FPages.Count-1 do FPages.Selected[K]:=K=Index;
    PageSelect(nil);
  end;
  procedure EditingChecks;
  var Original,AfterResize,ImageRect,Scaled: TRectF; Handles: TArray<TPointF>;
    K,X,Y,UndoCount,Revision: Integer; Before,ID: string; KeyValue: Word;
    OldZoom,OldPanX,OldPanY,TailRatioX,TailRatioY: Double;
  begin
    FTabs.ActivePageIndex:=1; TabChanged(nil); FPanelIndex:=0;
    Capture('window-panel-handles'); Original:=Page.Panels[0].Bounds;
    Before:=FProject.Snapshot; UndoCount:=FUndo.Count; Revision:=Page.Revision;
    X:=FPageRect.Left+Round((Original.Left+Original.Right)/2*FScale);
    Y:=FPageRect.Top+Round((Original.Top+Original.Bottom)/2*FScale);
    MouseDown(FCanvas,mbLeft,[],X,Y); MouseUp(FCanvas,mbLeft,[],X,Y);
    Check((FProject.Snapshot=Before) and (FUndo.Count=UndoCount) and (Page.Revision=Revision),
      'selection without dragging does not create an edit');
    for K:=1 to 8 do begin
      FPanelIndex:=0; Handles:=EditHandles(Page.Panels[0].Bounds);
      X:=FPageRect.Left+Round(Handles[K-1].X*FScale); Y:=FPageRect.Top+Round(Handles[K-1].Y*FScale);
      MouseDown(FCanvas,mbLeft,[],X,Y); Check(FDragHandle=K,'panel handle '+IntToStr(K)+' can be selected');
      MouseMove(FCanvas,[ssLeft],X+20,Y+20); MouseUp(FCanvas,mbLeft,[],X+20,Y+20);
      AfterResize:=Page.Panels[0].Bounds;
      Check((AfterResize.Width>=30) and (AfterResize.Height>=30) and (AfterResize<>Original),
        'panel handle '+IntToStr(K)+' resizes valid bounds');
      Undo(nil); Check(Page.Panels[0].Bounds=Original,'panel handle '+IntToStr(K)+' undo restores bounds');
    end;
    Scaled:=ResizeRect(Original,TPointF.Create(100000,100000),1,30);
    Check((Scaled.Width=30) and (Scaled.Height=30),'panel resize cannot invert geometry');
    FPanelIndex:=0; Before:=FProject.Snapshot; UndoCount:=FUndo.Count;
    Handles:=EditHandles(Original); X:=FPageRect.Left+Round(Handles[4].X*FScale); Y:=FPageRect.Top+Round(Handles[4].Y*FScale);
    MouseDown(FCanvas,mbLeft,[],X,Y); MouseMove(FCanvas,[ssLeft],X+25,Y+25);
    KeyValue:=VK_ESCAPE; Key(Self,KeyValue,[]);
    Check((FProject.Snapshot=Before) and (FUndo.Count=UndoCount) and not FDragging,
      'Esc cancels in-progress drag without changing undo history');
    Page.Panels[0].Shape:=1;
    Check((HitPanel(TPointF.Create(Original.Left+2,Original.Top+2))=-1) and
      (HitPanel(TPointF.Create((Original.Left+Original.Right)/2,(Original.Top+Original.Bottom)/2))=0),
      'ellipse hit test follows actual shape');
    Page.Panels[0].Shape:=2;
    Check(HitPanel(TPointF.Create(Original.Left+1,Original.Top+1))=-1,'rounded panel excludes outside corners');
    Page.Panels[0].Shape:=0;
    FTabs.ActivePageIndex:=2; TabChanged(nil); FPanelIndex:=0;
    ImageRect:=FRenderer.ImageBounds(FProject,Page.Panels[0]);
    OldZoom:=Page.Panels[0].Zoom; OldPanX:=Page.Panels[0].PanX; OldPanY:=Page.Panels[0].PanY;
    for K:=1 to 8 do begin
      Scaled:=ResizeImageRect(ImageRect,TPointF.Create(60,40),K,0.1);
      Check(Abs(Scaled.Width/Scaled.Height-ImageRect.Width/ImageRect.Height)<0.0001,
        'image handle '+IntToStr(K)+' preserves aspect ratio');
    end;
    FPanelIndex:=0; Capture('window-image-handles');
    Handles:=EditHandles(ImageRect); X:=FPageRect.Left+Round(Handles[5].X*FScale); Y:=FPageRect.Top+Round(Handles[5].Y*FScale);
    MouseDown(FCanvas,mbLeft,[],X,Y); Check(FDragHandle=6,'image edge handle selects beyond the panel');
    MouseMove(FCanvas,[ssLeft],X,Y+30); MouseUp(FCanvas,mbLeft,[],X,Y+30);
    Check((Page.Panels[0].Bounds=Original) and (Page.Panels[0].Zoom>OldZoom),'image resize changes zoom while keeping panel geometry');
    Undo(nil); Check((Abs(Page.Panels[0].Zoom-OldZoom)<0.0001) and (Page.Panels[0].PanX=OldPanX) and
      (Page.Panels[0].PanY=OldPanY),'image resize undo restores zoom and position together');
    FPanelIndex:=0; X:=FPageRect.Left+Round((Original.Left+Original.Right)/2*FScale);
    Y:=FPageRect.Top+Round((Original.Top+Original.Bottom)/2*FScale);
    MouseDown(FCanvas,mbLeft,[],X,Y); MouseMove(FCanvas,[ssLeft],X+25,Y+10); MouseUp(FCanvas,mbLeft,[],X+25,Y+10);
    Check((Page.Panels[0].Bounds=Original) and (Page.Panels[0].PanX>OldPanX) and
      (Page.Panels[0].PanY>OldPanY),'image drag pans without moving the panel'); Undo(nil);
    FTabs.ActivePageIndex:=3; TabChanged(nil); FBalloonIndex:=0; FPanelIndex:=0;
    Original:=Page.Balloons[0].Bounds; ID:=Page.Balloons[0].PanelID;
    TailRatioX:=(Page.Balloons[0].TailX-Original.Left)/Original.Width;
    TailRatioY:=(Page.Balloons[0].TailY-Original.Top)/Original.Height;
    Capture('window-balloon-handles'); Handles:=EditHandles(Original);
    X:=FPageRect.Left+Round(Handles[4].X*FScale); Y:=FPageRect.Top+Round(Handles[4].Y*FScale);
    MouseDown(FCanvas,mbLeft,[],X,Y); MouseMove(FCanvas,[ssLeft],X+20,Y+30); MouseUp(FCanvas,mbLeft,[],X+20,Y+30);
    AfterResize:=Page.Balloons[0].Bounds;
    Check((Page.Balloons[0].PanelID=ID) and
      (Abs((Page.Balloons[0].TailX-AfterResize.Left)/AfterResize.Width-TailRatioX)<0.0001) and
      (Abs((Page.Balloons[0].TailY-AfterResize.Top)/AfterResize.Height-TailRatioY)<0.0001) and
      (Page.Balloons[0].Text='漫画を作ろう！'),'balloon resize keeps tail and text attached');
    Undo(nil); Check(Page.Balloons[0].Bounds=Original,'balloon resize undo');
    FBalloonIndex:=0; FTool:=5; EditBalloonText(nil);
    Check(FTool=5,'double click cannot interrupt balloon creation');
    FTool:=0; EditBalloonText(nil);
    Check((ActiveControl=FText) and (FText.Text=Page.Balloons[0].Text),'double click reopens selected balloon text');
    X:=FPageRect.Left+Round((Original.Left+Original.Right)/2*FScale);
    Y:=FPageRect.Top+Round((Original.Top+Original.Bottom)/2*FScale);
    FCanvas.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(X,Y));
    Check(ActiveControl=FView,'normal canvas MouseDown transfers focus through shared production path');
    FCanvas.Perform(WM_LBUTTONUP,0,MakeLParam(X,Y));
    FCanvas.Perform(WM_LBUTTONDBLCLK,MK_LBUTTON,MakeLParam(X,Y));
    FCanvas.Perform(WM_LBUTTONUP,0,MakeLParam(X,Y));
    Check((ActiveControl=FText) and not FDragging and (FText.ImeMode=imOpen),
      'real VCL double-click then ssDouble MouseDown preserves balloon editor focus');
    ActiveControl:=FText; KeyValue:=VK_ESCAPE; Key(Self,KeyValue,[]);
    Check(KeyValue=VK_ESCAPE,'IME editor keeps its own Esc handling'); ActiveControl:=nil;
    FTabs.ActivePageIndex:=0; TabChanged(nil);
  end;
  procedure SafetyChecks;
  var LibraryPath,ValidText,BadText: string; OriginalBytes: TBytes;
    Assets: TObjectList<TComicAsset>; Existing: TComicAsset; Probe: TMainForm;
    Manager: TAssetDialog; P: TComicProject; Failed,CanClose: Boolean; State: string;
  begin
    LibraryPath:=TPath.Combine(DataRoot,'Characters\Library.json');
    OriginalBytes:=TFile.ReadAllBytes(LibraryPath); ValidText:=TFile.ReadAllText(LibraryPath,TEncoding.UTF8);
    Assets:=TObjectList<TComicAsset>.Create; Probe:=nil;
    try
      Existing:=TComicAsset.Create; Existing.Name:='既存の保持項目'; Assets.Add(Existing);
      BadText:=Copy(ValidText,1,Length(ValidText)-1)+',42]'; AtomicWrite(LibraryPath,BadText);
      Failed:=False; try ReadAssets(Assets,LibraryPath); except Failed:=True; end;
      Check(Failed and (Assets.Count=1) and (Assets[0]=Existing) and (Existing.Name='既存の保持項目'),
        'invalid trailing character-library item cannot publish a valid prefix');
      Check(TFile.ReadAllText(LibraryPath,TEncoding.UTF8)=BadText,'failed character-library read preserves the entire source file');
      Probe:=TMainForm.Create(nil);
      Check(not Probe.FCharacterLibraryWritable and (Probe.FCharacters.Count=0) and not Probe.HasCharacter,
        'startup with an invalid character library blocks production and persistence');
      Manager:=TAssetDialog.CreateManager(Probe,Probe.FCharacters,nil,True,Probe.FCharacterLibraryWritable);
      try CanClose:=True; Manager.OnCloseQuery(Manager,CanClose);
        Check(CanClose and (TFile.ReadAllText(LibraryPath,TEncoding.UTF8)=BadText),
          'closing read-only character manager cannot overwrite an unreadable library');
      finally Manager.Free; end;
      BadText:='[{"id":"safe","name":"prefix"},{"id":"unsafe","file":"..\\escape.png"}]';
      AtomicWrite(LibraryPath,BadText); Failed:=False;
      try ReadAssets(Assets,LibraryPath); except Failed:=True; end;
      Check(Failed and (Assets.Count=1) and (Assets[0]=Existing),
        'invalid character image path cannot publish earlier library entries');
      AtomicWrite(LibraryPath,ValidText); ReadAssets(Assets,LibraryPath);
      Check((Assets.Count=2) and (Assets[1].Name=FCharacters[0].Name),'repaired character library loads completely on retry');

      P:=TComicProject.Create; P.Initialize('切替元 fixture','1'); Probe.AdoptProject(P,False);
      Probe.FGeometryPoints.Add(TPointF.Create(120,130)); Probe.FTool:=8; Probe.FFirst:=True;
      Probe.FSplitStage:=2; Probe.FSplitPanelID:='previous-panel'; Probe.FPageDropIndex:=3;
      P:=TComicProject.Create; P.Initialize('切替先 fixture','2'); State:=P.Snapshot;
      Probe.AdoptProject(P,False);
      Check((Probe.FGeometryPoints.Count=0) and (Probe.FSplitStage=0) and (Probe.FSplitPanelID='') and
        not Probe.FFirst and (Probe.FTool=0) and (Probe.FPageDropIndex=-1),
        'new/open project adoption clears pending polygon rectangle split and page-drop state');
      Check((Probe.FProject.Snapshot=State) and (Probe.FUndo.Count=0) and (Probe.FRedo.Count=0),
        'project adoption preserves new project content and starts clean history');
      Probe.FDragging:=True; Probe.FDragMoved:=True; Probe.FDragSnapshot:=Probe.FProject.Snapshot;
      Probe.FProject.Title:='temporary drag mutation'; Probe.FDragVertex:=1;
      P:=TComicProject.Create; P.Folder:=Probe.FProject.Folder; P.Restore(Probe.FDragSnapshot); State:=P.Snapshot;
      Probe.AdoptProject(P,True);
      Check(not Probe.FDragging and not Probe.FDragMoved and (Probe.FDragVertex=-1) and
        (Probe.FDragSnapshot='') and (Probe.FProject.Snapshot=State) and Probe.FDirty,
        'project adoption cancels the previous drag before installing recovered content');
    finally Probe.Free; Assets.Free; TFile.WriteAllBytes(LibraryPath,OriginalBytes); end;
    Check(TFile.ReadAllText(LibraryPath,TEncoding.UTF8)=ValidText,'isolated library corruption tests restore the fixture library');
  end;
  procedure TextNavigationChecks;
  var EditorDialog,NativeDialog: TComicTextDialog; KeyValue: Word; Text,Emoji,Joined,Before: string;
    Count,I,PPI,OldPPI: Integer; PNG: TPngImage; Stop: TComicCaretStop;
    Context,OriginalContext: HIMC; ImeState: TWindowsImeState; OriginalOpen,SessionOpen: Boolean; Conversion,Sentence: DWORD;
    procedure Command(Key: Word; Shift: TShiftState=[]);
    begin KeyValue:=Key; EditorDialog.Editor.Command(KeyValue,Shift); end;
    procedure CaptureText(const Name: string);
    begin
      EditorDialog.HandleNeeded; B.SetSize(EditorDialog.ClientWidth,EditorDialog.ClientHeight); EditorDialog.PaintTo(B.Canvas,0,0);
      PNG.Assign(B); PNG.SaveToFile(TPath.Combine(Folder,Name+'.png'));
    end;
  begin
    Before:=FProject.Snapshot; PNG:=TPngImage.Create;
    EditorDialog:=TComicTextDialog.CreateEditor(Self,'',False,True);
    try
      EditorDialog.Editor.Font.Name:='Consolas';
      EditorDialog.Editor.Text:='abcd'+#13#10+'xy'+#13#10+'12345';
      Command(VK_HOME,[ssCtrl]); Command(VK_RIGHT); Command(VK_RIGHT); Command(VK_RIGHT);
      Command(VK_DOWN); Check(EditorDialog.Editor.CaretIndex=8,'down arrow reaches the nearest position on a shorter visual line');
      Command(VK_UP); Check(EditorDialog.Editor.CaretIndex=3,'up arrow restores the preferred column after a short line');
      Command(VK_DOWN); Command(VK_DOWN); Check(EditorDialog.Editor.CaretIndex=13,'repeated line movement preserves preferred column');
      Command(VK_UP,[ssShift]); Check((EditorDialog.Editor.SelectionAnchor=13) and (EditorDialog.Editor.CaretIndex=8),
        'shift line movement extends selection without losing the anchor');
      Command(VK_HOME); Check(EditorDialog.Editor.CaretIndex=6,'home moves to the current visual-line start');
      Command(VK_END); Check(EditorDialog.Editor.CaretIndex=8,'end moves to the current visual-line end');
      EditorDialog.Editor.Text:='one two  three'; Command(VK_HOME,[ssCtrl]); Command(VK_RIGHT,[ssCtrl]);
      Check(EditorDialog.Editor.CaretIndex=4,'control right moves to the next word'); Command(VK_DELETE,[ssCtrl]);
      Check(EditorDialog.Editor.Text='one three','control delete removes the following word and spaces as one edit');
      Command(Ord('Z'),[ssCtrl]); Check((EditorDialog.Editor.Text='one two  three') and (EditorDialog.Editor.CaretIndex=4),
        'input undo restores text caret and selection'); Command(Ord('Y'),[ssCtrl]);
      Check(EditorDialog.Editor.Text='one three','input redo restores a word edit');
      EditorDialog.Editor.Input.Perform(WM_CHAR,Ord('日'),0); Command(Ord('Z'),[ssCtrl]);
      Check(EditorDialog.Editor.Text='one three','typing creates an independent input undo step');
      EditorDialog.Editor.Input.Perform(WM_CHAR,Ord('本'),0); Command(Ord('Y'),[ssCtrl]);
      Check(EditorDialog.Editor.Text='one 本three','new typing after input undo clears redo');
      Emoji:=WideChar($D83D)+WideChar($DE00); Joined:=WideChar($D83D)+WideChar($DC69)+WideChar($200D)+WideChar($D83D)+WideChar($DCBB);
      EditorDialog.Editor.Text:='A'+'か'+WideChar($3099)+Emoji+Joined+#13#10+'B';
      Command(VK_LEFT); Command(VK_LEFT); Command(VK_LEFT); Check(EditorDialog.Editor.CaretIndex=5,
        'caret treats a joined emoji sequence as one unit'); Command(VK_LEFT); Check(EditorDialog.Editor.CaretIndex=3,
        'caret keeps surrogate pairs intact with adjacent clusters'); Command(VK_BACK);
      Check(EditorDialog.Editor.Text='A'+Emoji+Joined+#13#10+'B','backspace deletes a kana and combining mark together');
      Command(Ord('Z'),[ssCtrl]); Check(EditorDialog.Editor.Text='A'+'か'+WideChar($3099)+Emoji+Joined+#13#10+'B',
        'input undo restores an entire combining cluster');
      EditorDialog.Editor.Text:=''; EditorDialog.Editor.Input.Perform(WM_CHAR,$D83D,0);
      Check(EditorDialog.Editor.Text='','high surrogate is buffered until its complete character arrives');
      EditorDialog.Editor.Input.Perform(WM_CHAR,$DE00,0);
      Check(EditorDialog.Editor.Text=Emoji,'paired WM_CHAR messages insert one complete character');
      Command(Ord('Z'),[ssCtrl]); Check(EditorDialog.Editor.Text='','one input undo removes the complete surrogate pair');
      EditorDialog.Editor.Input.Perform(WM_UNICHAR,$1F600,0);
      Check(EditorDialog.Editor.Text=Emoji,'WM_UNICHAR inserts a supplementary Unicode character intact');
      EditorDialog.Editor.Text:='AB'; Command(VK_HOME,[ssCtrl]); Command(VK_RIGHT,[ssShift]);
      EditorDialog.Editor.Input.DeliverComposition('','にほん',2,True);
      CaptureText('text-ime-preedit-horizontal');
      Check((EditorDialog.Editor.Text='AB') and EditorDialog.Editor.Composing and
        (EditorDialog.Editor.CompositionText='にほん') and (EditorDialog.Editor.CompositionCursor=2),
        'IME preedit replaces selected display text without mutating the edit buffer');
      Command(Ord('Z'),[ssCtrl]); Check(EditorDialog.Editor.Text='AB','input undo passes through while IME composition is active');
      EditorDialog.Editor.Vertical:=True; CaptureText('text-ime-preedit-vertical');
      Check(EditorDialog.Editor.CaretBounds.Width>EditorDialog.Editor.CaretBounds.Height,
        'vertical IME preedit uses column layout and a horizontal caret');
      EditorDialog.Editor.Input.DeliverComposition('日本','',0,False);
      Check(EditorDialog.Editor.Text='日本B','IME result replaces selection once as one committed string');
      Command(Ord('Z'),[ssCtrl]); Check((EditorDialog.Editor.Text='AB') and (EditorDialog.Editor.SelectionAnchor=0) and
        (EditorDialog.Editor.CaretIndex=1),'one input undo restores the selection before IME result insertion');
      Context:=ImmCreateContext; Check(Context<>0,'isolated Windows IME context can be created for API lifecycle checks');
      OriginalContext:=ImmAssociateContext(EditorDialog.Editor.Input.Handle,Context);
      try
        OriginalOpen:=ImmGetOpenStatus(Context); SuspendWindowsIme(EditorDialog.Editor.Input.Handle,ImeState);
        Check(ImeState.Valid and (ImeState.Context=Context) and (ImeState.WasOpen=OriginalOpen),
          'IME snapshot retains its actual context and previous open state');
        if ImeState.HasConversionMode then ImmSetConversionStatus(Context,ImeState.ConversionMode xor IME_CMODE_FULLSHAPE,ImeState.SentenceMode);
        ImmAssociateContext(EditorDialog.Editor.Input.Handle,0); RestoreWindowsIme(EditorDialog.Editor.Input.Handle,ImeState);
        Check(not ImeState.Valid and (ImmGetOpenStatus(Context)=OriginalOpen),
          'IME state restores even after the input receiver detaches its context');
        if ImeState.HasConversionMode then
          Check(ImmGetConversionStatus(Context,Conversion,Sentence) and (Conversion=ImeState.ConversionMode) and
            (Sentence=ImeState.SentenceMode),'isolated IME context restores its captured conversion and sentence modes');
      finally ImmAssociateContext(EditorDialog.Editor.Input.Handle,OriginalContext); ImmDestroyContext(Context); end;
      OriginalContext:=ImmGetContext(EditorDialog.Editor.Input.Handle);
      Check(OriginalContext<>0,'input receiver has an isolated process-default IME context before detachment');
      if OriginalContext<>0 then begin
        OriginalOpen:=ImmGetOpenStatus(OriginalContext); ImmReleaseContext(EditorDialog.Editor.Input.Handle,OriginalContext);
        ImmAssociateContext(EditorDialog.Editor.Input.Handle,0);
        try
          SuspendWindowsIme(EditorDialog.Editor.Input.Handle,ImeState);
          Check(ImeState.Valid and (ImeState.Context=OriginalContext) and (ImeState.WasOpen=OriginalOpen),
            'IME snapshot before re-entry captures state even while receiver context is detached');
          Context:=ImmGetContext(EditorDialog.Editor.Input.Handle);
          Check(Context=0,'capturing detached IME state keeps the inactive receiver detached');
          if Context<>0 then ImmReleaseContext(EditorDialog.Editor.Input.Handle,Context);
          RestoreWindowsIme(EditorDialog.Editor.Input.Handle,ImeState);
          Check(ImmGetOpenStatus(OriginalContext)=OriginalOpen,'detached receiver snapshot restores original default-context open state');
        finally ImmAssociateContext(EditorDialog.Editor.Input.Handle,OriginalContext); ImmSetOpenStatus(OriginalContext,OriginalOpen); end;
        EditorDialog.Editor.EndSession;
        try
          for I:=0 to 1 do begin
            ImmSetOpenStatus(OriginalContext,I<>0); SessionOpen:=ImmGetOpenStatus(OriginalContext);
            Lines.Add('INFO: IME API requestedOpen='+BoolToStr(I<>0,True)+' observedOpen='+BoolToStr(SessionOpen,True));
            ImmAssociateContext(EditorDialog.Editor.Input.Handle,0); EditorDialog.Editor.BeginSession(False);
            EditorDialog.Editor.Input.Perform(CM_ENTER,0,0); EditorDialog.Editor.Input.Perform(WM_SETFOCUS,0,0);
            Check(EditorDialog.Editor.SessionActive,'real session activates from detached IME context '+IntToStr(I));
            EditorDialog.Editor.Input.Perform(CM_EXIT,0,0); EditorDialog.Editor.Input.Perform(WM_KILLFOCUS,0,0);
            Check(ImmGetOpenStatus(OriginalContext)=SessionOpen,'input focus exit restores actual original open state '+IntToStr(I));
            EditorDialog.Editor.Input.Perform(CM_ENTER,0,0); EditorDialog.Editor.Input.Perform(WM_SETFOCUS,0,0);
            EditorDialog.Editor.EndSession;
            Check(not EditorDialog.Editor.SessionActive and (EditorDialog.Editor.Input.ImeMode=imDisable) and
              (ImmGetOpenStatus(OriginalContext)=SessionOpen),'session completion after focus re-entry restores IME state '+IntToStr(I));
            NativeDialog:=TComicTextDialog.CreateEditor(Self,'native modal 取消',I=1,False);
            try
              PostMessage(NativeDialog.Handle,WM_CLOSE,0,0);
              Check((NativeDialog.ShowModal=mrCancel) and (NativeDialog.Editor.Text='native modal 取消') and
                (FProject.Snapshot=Before),'native text dialog focus and close preserve cancelled text and project '+IntToStr(I));
            finally NativeDialog.Free; end;
            Check(ImmGetOpenStatus(OriginalContext)=SessionOpen,'native text dialog destruction restores its original IME open state '+IntToStr(I));
          end;
        finally
          EditorDialog.Editor.EndSession; ImmAssociateContext(EditorDialog.Editor.Input.Handle,OriginalContext);
          ImmSetOpenStatus(OriginalContext,OriginalOpen); EditorDialog.Editor.BeginSession(True);
        end;
      end;
      EditorDialog.Editor.Vertical:=True; EditorDialog.Editor.Text:='abcd'+#13#10+'xy'+#13#10+'12345';
      Command(VK_HOME,[ssCtrl]); Command(VK_DOWN); Command(VK_DOWN); Command(VK_DOWN); Command(VK_LEFT);
      Check(EditorDialog.Editor.CaretIndex=8,'vertical left arrow moves to the next column at the nearest height');
      Command(VK_RIGHT); Check(EditorDialog.Editor.CaretIndex=3,'vertical right arrow restores preferred height');
      Command(VK_UP); Check(EditorDialog.Editor.CaretIndex=2,'vertical up arrow moves to the previous text unit');
      Text:=''; for I:=1 to 160 do Text:=Text+'長い文字入力 '+IntToStr(I)+#13#10;
      OldPPI:=EditorDialog.CurrentPPI;
      for PPI in [96,144] do begin
        EditorDialog.Scaled:=True; EditorDialog.ScaleForPPI(PPI); EditorDialog.Scaled:=False;
        EditorDialog.ClientWidth:=MulDiv(680,PPI,96); EditorDialog.ClientHeight:=MulDiv(440,PPI,96); EditorDialog.Realign;
        EditorDialog.Editor.Vertical:=False; EditorDialog.Editor.Text:=Text; CaptureText('text-long-horizontal-'+IntToStr(PPI));
        Check((EditorDialog.Editor.ScrollPosition>0) and (EditorDialog.Editor.CaretBounds.Top>=0) and
          (EditorDialog.Editor.CaretBounds.Bottom<=EditorDialog.Editor.ClientHeight),
          'long horizontal input scrolls the caret into view at PPI '+IntToStr(PPI));
        Command(VK_HOME,[ssCtrl]); Check(EditorDialog.Editor.ScrollPosition=0,'document home returns horizontal scroll to start at PPI '+IntToStr(PPI));
        Count:=EditorDialog.Editor.Text.Length; Stop:=EditorDialog.Editor.Layout.CaretStop(0);
        EditorDialog.Editor.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(Stop.Point.X+1,Stop.Point.Y+1));
        Check(EditorDialog.Editor.CaretIndex=0,'horizontal hit test uses the same layout as rendering at PPI '+IntToStr(PPI));
        Command(VK_END,[ssCtrl]); Check(EditorDialog.Editor.CaretIndex=Count,'document end retains the full long buffer at PPI '+IntToStr(PPI));
        EditorDialog.Editor.Vertical:=True; CaptureText('text-long-vertical-'+IntToStr(PPI));
        Check((EditorDialog.Editor.ScrollPosition>0) and (EditorDialog.Editor.CaretBounds.Left>=0) and
          (EditorDialog.Editor.CaretBounds.Right<=EditorDialog.Editor.ClientWidth),
          'long vertical input scrolls leftward columns into view at PPI '+IntToStr(PPI));
        Command(VK_HOME,[ssCtrl]); Check(EditorDialog.Editor.ScrollPosition=0,'document home returns vertical scroll to start at PPI '+IntToStr(PPI));
      end;
      EditorDialog.Scaled:=True; EditorDialog.ScaleForPPI(OldPPI); EditorDialog.Scaled:=False;
      Command(VK_ESCAPE);
      Check(FProject.Snapshot=Before,'navigation scrolling Unicode deletion and input undo leave project data unchanged on cancel');
    finally EditorDialog.Free; PNG.Free; end;
  end;
  procedure TextSessionChecks;
  var Dialog: TComicTextDialog; Before,NewText,Emoji: string; KeyValue: Word; OldUndo,OldRedo: TList<string>;
    OldPPI: Integer; OriginalScaled: Boolean; PPI,K: Integer; PNG: TPngImage;
    procedure Command(Key: Word; Shift: TShiftState=[]);
    begin KeyValue:=Key; Dialog.Editor.Command(KeyValue,Shift); end;
    procedure SaveEditor(const Name: string);
    begin
      Dialog.HandleNeeded; B.SetSize(Dialog.ClientWidth,Dialog.ClientHeight); Dialog.PaintTo(B.Canvas,0,0);
      PNG.Assign(B); PNG.SaveToFile(TPath.Combine(Folder,Name+'.png'));
    end;
  begin
    Before:=FProject.Snapshot; OldUndo:=FUndo; OldRedo:=FRedo;
    FUndo:=TList<string>.Create; FRedo:=TList<string>.Create; PNG:=TPngImage.Create;
    Emoji:=WideChar($D83D)+WideChar($DE00); NewText:='A'+Emoji+#13#10+'B';
    FTabs.ActivePageIndex:=3; TabChanged(nil); FBalloonIndex:=0; FPanelIndex:=0;
    try
      Dialog:=TComicTextDialog.CreateEditor(Self,Page.Balloons[0].Text,False,True);
      try
        Check(Dialog.Editor.SessionActive and (Dialog.Editor.Input.ImeMode=imOpen),'dedicated input session enables only its IME receiver');
        Dialog.Editor.Text:='A'+Emoji+#13#10+'B';
        Command(VK_LEFT); Check(Dialog.Editor.CaretIndex=5,'library caret moves before final character');
        Command(VK_LEFT); Check(Dialog.Editor.CaretIndex=3,'library caret crosses CRLF as one boundary');
        Command(VK_LEFT); Check(Dialog.Editor.CaretIndex=1,'library caret crosses surrogate pair without splitting');
        Command(VK_RIGHT,[ssShift]); Command(VK_BACK);
        Check(Dialog.Editor.Text='A'+#13#10+'B','selected surrogate pair deletes as a complete unit');
        Dialog.Editor.Text:=''; Dialog.Editor.Input.Perform(WM_CHAR,Ord('日'),0); Dialog.Editor.Input.Perform(WM_CHAR,Ord('本'),0);
        Check((Dialog.Editor.Text='日本') and (Dialog.Editor.Input.Text=''),'copied IME receiver WM_CHAR forwards committed text into external buffer');
        Dialog.Editor.Input.Perform(WM_IME_STARTCOMPOSITION,0,0);
        Check(Dialog.Editor.Composing,'IME start message activates pending composition state');
        Command(VK_RETURN,[ssCtrl]);
        Check((Dialog.ModalResult=0) and (Dialog.Editor.Text='日本'),'pending IME composition cannot commit whole dialog');
        KeyValue:=VK_RETURN; Dialog.KeyDown(KeyValue,[ssCtrl]);
        Check((KeyValue=VK_RETURN) and (Dialog.ModalResult=0),'dialog shortcut passes pending composition to IME receiver');
        Dialog.Editor.Input.Perform(WM_IME_ENDCOMPOSITION,0,0);
        Check(not Dialog.Editor.Composing,'IME end message clears pending composition state');
        Dialog.Editor.Text:=NewText; SaveEditor('text-horizontal-96');
        Check(Dialog.Editor.CaretBounds.Height>Dialog.Editor.CaretBounds.Width,'horizontal input preview uses a vertical pseudo caret');
        for K:=0 to Dialog.ComponentCount-1 do if (Dialog.Components[K] is TButton) and
          (Pos('取消',TButton(Dialog.Components[K]).Caption)>0) then Dialog.ActiveControl:=TWinControl(Dialog.Components[K]);
        KeyValue:=VK_ESCAPE; Dialog.KeyDown(KeyValue,[]); FinishTextDialog(Dialog);
        Check(KeyValue=0,'Esc cancels dedicated dialog while cancel button has focus');
        Check((Dialog.ModalResult=mrCancel) and (FProject.Snapshot=Before) and (FUndo.Count=0),
          'dedicated text cancel preserves balloon and undo history');
        Check(not Dialog.Editor.SessionActive and not Dialog.Editor.Input.Enabled and
          (Dialog.Editor.Input.ImeMode=imDisable),'closing input session disables receiver and ends composition');
      finally Dialog.Free; end;
      Dialog:=TComicTextDialog.CreateEditor(Self,Page.Balloons[0].Text,True,True);
      try
        Dialog.Editor.Text:=NewText; SaveEditor('text-vertical-96');
        Check(Dialog.Editor.CaretBounds.Width>Dialog.Editor.CaretBounds.Height,'vertical input preview uses the requested horizontal pseudo caret');
        OldPPI:=Dialog.CurrentPPI; OriginalScaled:=Dialog.Scaled;
        try
          for PPI in [96,144] do begin
            Dialog.Scaled:=True; Dialog.ScaleForPPI(PPI); Dialog.Scaled:=False;
            Dialog.ClientWidth:=MulDiv(680,PPI,96); Dialog.ClientHeight:=MulDiv(440,PPI,96); Dialog.Realign;
            SaveEditor('text-vertical-'+IntToStr(PPI));
            Check((Dialog.CurrentPPI=PPI) and (Dialog.Editor.CaretBounds.Width>Dialog.Editor.CaretBounds.Height),
              'vertical pseudo caret remains horizontal at VCL PPI '+IntToStr(PPI));
          end;
        finally
          Dialog.Scaled:=True; Dialog.ScaleForPPI(OldPPI);
          Dialog.ClientWidth:=MulDiv(680,OldPPI,96); Dialog.ClientHeight:=MulDiv(440,OldPPI,96); Dialog.Scaled:=OriginalScaled;
        end;
        Check(FProject.Snapshot=Before,'typing and DPI preview do not mutate the balloon before commit');
        for K:=0 to Dialog.ComponentCount-1 do if (Dialog.Components[K] is TButton) and
          (Pos('確定',TButton(Dialog.Components[K]).Caption)>0) then Dialog.ActiveControl:=TWinControl(Dialog.Components[K]);
        KeyValue:=VK_RETURN; Dialog.KeyDown(KeyValue,[ssCtrl]); FinishTextDialog(Dialog);
        Check(KeyValue=0,'Ctrl Enter commits dedicated dialog while accept button has focus');
        Check((Dialog.ModalResult=mrOK) and (Page.Balloons[0].Text=NewText) and (FUndo.Count=1),
          'dedicated text commit updates balloon as one undo operation');
        FProject.Save; Loaded:=TComicProject.Create;
        try Loaded.Load(TPath.Combine(FProject.Folder,'Project.json'));
          Check(Loaded.Pages[0].Balloons[0].Text=NewText,'committed Unicode and multiline buffer save and reload');
        finally Loaded.Free; end;
        Undo(nil); Check(Page.Balloons[0].Text='漫画を作ろう！','dedicated text undo restores previous balloon text');
        Redo(nil); Check(Page.Balloons[0].Text=NewText,'dedicated text redo restores committed Unicode text'); Undo(nil);
      finally Dialog.Free; end;
      Dialog:=TComicTextDialog.CreateEditor(Self,NewText,False,True);
      try
        Check(Dialog.Editor.Text=NewText,'dedicated text reopens existing multiline Unicode buffer');
        Command(VK_HOME,[ssCtrl]); Command(VK_DELETE);
        Check(Dialog.Editor.Text=Emoji+#13#10+'B','library delete at start preserves following surrogate pair');
        Command(VK_ESCAPE);
        Check(not Dialog.Visible,'all dedicated text checks remain hidden without focus transfer');
      finally Dialog.Free; end;
      Check(FProject.Snapshot=Before,'text session tests restore complete original project');
    finally
      PNG.Free; FUndo.Free; FRedo.Free; FUndo:=OldUndo; FRedo:=OldRedo;
      FText.Text:=Page.Balloons[0].Text; FTabs.ActivePageIndex:=0; TabChanged(nil); ActiveControl:=nil; RefreshUI;
    end;
  end;
  procedure BulkDataChecks;
  var Project,Reloaded: TComicProject; Page: TComicPage; Panel: TComicPanel; Balloon: TComicBalloon; Renderer: TComicRenderer;
    Metrics: TStringList; Bitmap: TBitmap; ImageID,Text,Snapshot,Path: string; I,K,Rendered: Integer; Started: UInt64; Basis: TComicPageBasis;
  begin
    Project:=TComicProject.Create; Reloaded:=TComicProject.Create; Renderer:=TComicRenderer.Create; Metrics:=TStringList.Create; Bitmap:=TBitmap.Create;
    try
      Project.Initialize('大量データ fixture','1'); Project.Pages.Clear; Basis:=Project.PageBasis;
      Basis.Width:=240; Basis.Height:=360; Basis.Left:=10; Basis.Right:=10; Basis.Top:=10; Basis.Bottom:=10; Project.SetPageBasis(Basis);
      ImageID:=Project.ImportImage(TPath.Combine(Folder,'reference.bmp'),'').ID;
      Text:='大量ページ・文字・画像参照の検証。';
      for I:=0 to 79 do begin
        Page:=TComicPage.Create; Project.Pages.Add(Page);
        for K:=0 to 5 do begin
          Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(10+(K mod 2)*112,10+(K div 2)*114,110+(K mod 2)*112,112+(K div 2)*114);
          Panel.ImageID:=ImageID; Panel.Number:=K+1; Panel.FilterKind:=(I+K) mod 3; Page.Panels.Add(Panel);
          Balloon:=TComicBalloon.Create; Balloon.PanelID:=Panel.ID; Balloon.Bounds:=Panel.Bounds; Balloon.Text:=Text+Text+Text+IntToStr(I);
          Balloon.FontSize:=8; Balloon.Vertical:=(I+K) mod 2=0; Balloon.Overflow:=False; Page.Balloons.Add(Balloon);
        end;
      end;
      Started:=GetTickCount64; Project.Save; Snapshot:=Project.Snapshot; Metrics.Add('save_80_pages_480_panels_ms='+UIntToStr(GetTickCount64-Started));
      Started:=GetTickCount64; Reloaded.Load(TPath.Combine(Project.Folder,'Project.json')); Metrics.Add('reload_80_pages_ms='+UIntToStr(GetTickCount64-Started));
      Check((Reloaded.Pages.Count=80) and (Reloaded.Pages[79].Panels.Count=6) and (Reloaded.Snapshot=Snapshot),
        'eighty pages with four hundred eighty panels and balloons save and reload exact Unicode data');
      Started:=GetTickCount64; Rendered:=ExportSequence(Project,Renderer,False); Metrics.Add('export_80_small_pages_ms='+UIntToStr(GetTickCount64-Started));
      Check(Rendered=80,'large page sequence exports every page'); Started:=GetTickCount64;
      Check(ExportSequence(Project,Renderer,False)=0,'large unchanged sequence reuses every cached PNG'); Metrics.Add('unchanged_export_80_pages_ms='+UIntToStr(GetTickCount64-Started));
      Project.Pages[40].Panels[0].PanX:=12; Check(ExportSequence(Project,Renderer,False)=1,'one changed panel redraws only its page in a large sequence');
      Project.Pages[0].Panels[0].Bounds:=TRectF.Create(-20000,-20000,50000,50000); Project.Pages[0].Panels[0].FilterKind:=3;
      Bitmap.PixelFormat:=pf24bit; Bitmap.SetSize(240,360); Started:=GetTickCount64;
      Renderer.Draw(Bitmap.Canvas,Project,Project.Pages[0],Rect(0,0,240,360),False);
      Check(Bitmap.Canvas.Pixels[120,300]<>clWhite,'huge off-page blurred panel renders through page-bounded scratch raster');
      Metrics.Add('huge_panel_bounded_render_ms='+UIntToStr(GetTickCount64-Started));
      Project.Pages[0].Balloons[0].Text:=StringOfChar('漢',6000); Project.Pages[0].Balloons[0].FontSize:=16;
      for K:=0 to 1 do begin
        Project.Pages[0].Balloons[0].Vertical:=K=1; Started:=GetTickCount64; Renderer.Draw(Bitmap.Canvas,Project,Project.Pages[0],Rect(0,0,240,360),False);
        Metrics.Add('render_6000_chars_'+IntToStr(K)+'_ms='+UIntToStr(GetTickCount64-Started));
        Check(Length(Project.Pages[0].Balloons[0].Text)=6000,'long horizontal or vertical render preserves its complete text '+IntToStr(K));
      end;
      Project.Pages.Clear; Basis.Width:=1200; Basis.Height:=1700; Basis.Left:=60; Basis.Right:=60; Basis.Top:=60; Basis.Bottom:=60; Project.SetPageBasis(Basis);
      Bitmap.SetSize(2400,3200); Bitmap.Canvas.Brush.Color:=clWhite; Bitmap.Canvas.FillRect(Rect(0,0,2400,3200));
      Bitmap.Canvas.Brush.Color:=clBlue; Bitmap.Canvas.Ellipse(300,400,2100,2800); Path:=TPath.Combine(Folder,'large-reference.bmp'); Bitmap.SaveToFile(Path);
      ImageID:=Project.ImportImage(Path,'').ID;
      for I:=0 to 5 do begin
        Page:=TComicPage.Create; Project.Pages.Add(Page);
        for K:=0 to 1 do begin
          Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(60,60+K*800,1140,820+K*800); Panel.ImageID:=ImageID;
          Panel.FilterKind:=3; Panel.FilterStrength:=75; Page.Panels.Add(Panel);
          Balloon:=TComicBalloon.Create; Balloon.PanelID:=Panel.ID; Balloon.Bounds:=TRectF.Create(220,160+K*800,620,560+K*800);
          Balloon.Text:=Text+Text+IntToStr(I); Balloon.Vertical:=K=1; Balloon.FontSize:=32; Page.Balloons.Add(Balloon);
        end;
      end;
      Started:=GetTickCount64; Project.Save; Reloaded.Load(TPath.Combine(Project.Folder,'Project.json'));
      Check(Reloaded.Snapshot=Project.Snapshot,'normal-resolution project with a large shared image saves and reloads');
      Metrics.Add('normal_6_pages_save_reload_ms='+UIntToStr(GetTickCount64-Started)); Started:=GetTickCount64;
      Check(ExportSequence(Project,Renderer,False)=6,'six normal 1200x1700 pages with 2400x3200 image and blur export successfully');
      Metrics.Add('normal_6_pages_large_image_export_ms='+UIntToStr(GetTickCount64-Started));
      Check(ExportSequence(Project,Renderer,False)=0,'normal-resolution large-image sequence reuses every cached page');
      Metrics.SaveToFile(TPath.Combine(Folder,'performance.txt'),TEncoding.UTF8);
    finally Bitmap.Free; Metrics.Free; Renderer.Free; Reloaded.Free; Project.Free; end;
  end;
  procedure GapSnapChecks;
  var Probe: TMainForm; Project,Reloaded: TComicProject; Panel: TComicPanel; Snap: TComicGapSnap; PointA: TPointF;
    Before,Original: string; X,Y,PPI: Integer; KeyValue: Word;
    procedure Add(L,T,R,B: Single);
    begin Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(L,T,R,B); Probe.Page.Panels.Add(Panel); end;
    procedure Click(PX,PY: Single; Shift: TShiftState);
    begin X:=Probe.FPageRect.Left+Round(PX*Probe.FScale); Y:=Probe.FPageRect.Top+Round(PY*Probe.FScale); Probe.MouseDown(Probe.FCanvas,mbLeft,Shift,X,Y); Probe.MouseUp(Probe.FCanvas,mbLeft,Shift,X,Y); end;
  begin
    Original:=FProject.Snapshot; Probe:=TMainForm.Create(nil);
    try
      Project:=TComicProject.Create; Project.Initialize('間隔スナップ fixture','1'); Probe.AdoptProject(Project,False); Project.ImportImage(TPath.Combine(Folder,'reference.bmp'),'');
      Add(100,100,300,350); Add(320,100,520,350); Add(100,380,300,630);
      Snap:=FindGapSnap(Probe.Page.Panels,TPointF.Create(538,200),6,''); Check(Snap.HasX and (Snap.Point.X=540) and not Snap.HasY,'horizontal gap repeats nearest-neighbour spacing');
      Snap:=FindGapSnap(Probe.Page.Panels,TPointF.Create(200,662),6,''); Check(Snap.HasY and (Snap.Point.Y=660) and not Snap.HasX,'vertical gap repeats nearest-neighbour spacing');
      Snap:=FindGapSnap(Probe.Page.Panels,TPointF.Create(538,200),6,Probe.Page.Panels[1].ID); Check(not Snap.HasX,'excluded edited panel cannot define its own gap');
      Add(700,100,900,350); Snap:=FindGapSnap(Probe.Page.Panels,TPointF.Create(1302,200),6,''); Check(not Snap.HasX,'non-neighbour distances are not inferred as reusable gaps');
      Probe.Page.Panels.Delete(3); Probe.RefreshUI; Probe.FTabs.ActivePageIndex:=1; Probe.TabChanged(nil); Probe.FSnap.Checked:=True;
      for PPI in [96,144] do begin
        Probe.Scaled:=True; Probe.ScaleForPPI(PPI); Probe.Scaled:=False; Probe.Width:=MulDiv(940,PPI,96); Probe.Height:=MulDiv(660,PPI,96); Probe.Realign;
        B.SetSize(Probe.ClientWidth,Probe.ClientHeight); Probe.PaintTo(B.Canvas,0,0);
        PointA:=Probe.SnapCreationPoint(TPointF.Create(538,200)); Check((PointA.X=540) and (Abs(PointA.Y-200)<0.001),'gap closer than an edge remains reachable at PPI '+IntToStr(PPI));
        Before:=Project.Snapshot; Probe.FTool:=1; Click(538,180,[]); Click(820,330,[]);
        Check((Probe.Page.Panels.Count=4) and (Abs(Probe.Page.Panels[3].Bounds.Left-540)<0.001),'rectangle creation uses repeated gap at PPI '+IntToStr(PPI));
        Project.Save; Reloaded:=TComicProject.Create;
        try Reloaded.Load(TPath.Combine(Project.Folder,'Project.json')); Check(Reloaded.Snapshot=Project.Snapshot,'gap-created panel saves and reloads '+IntToStr(PPI)); finally Reloaded.Free; end;
        Probe.Undo(nil); Check(Project.Snapshot=Before,'gap-created panel undo restores exact source spacing '+IntToStr(PPI));
        Probe.FSnap.Checked:=False; PointA:=Probe.SnapCreationPoint(TPointF.Create(538,200)); Check(PointA.X=538,'gap setting disables all snapping '+IntToStr(PPI)); Probe.FSnap.Checked:=True;
        Probe.FTool:=1; Click(538,200,[ssAlt]); Check(Abs(Probe.FStart.X-540)>0.5,'Alt bypasses repeated gap on creation '+IntToStr(PPI));
        KeyValue:=VK_ESCAPE; Probe.Key(Probe,KeyValue,[]); Check(Project.Snapshot=Before,'cancelled gap creation preserves history data '+IntToStr(PPI));
      end;
      Check(FProject.Snapshot=Original,'gap snap fixtures preserve the active project');
    finally Probe.Free; end;
  end;
  procedure PanelTransformSnapChecks;
  var Probe: TMainForm; Project,Reloaded: TComicProject; Panels: TObjectList<TComicPanel>; Panel: TComicPanel;
    Frame,Bounds,Target,Expected,OriginalBounds,OtherBounds: TRectF; IDs: TArray<string>;
    Before,After,Original,MovingID,ImageID: string; X,Y,TX,TY,K,PPI,History: Integer;
    PointA,Delta: TPointF; KeyValue: Word; PNG: TPngImage;
    procedure Add(L,T,R,B: Single);
    begin Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(L,T,R,B); Panels.Add(Panel); end;
    procedure Reverse;
    var I: Integer;
    begin for I:=0 to Panels.Count div 2-1 do Panels.Exchange(I,Panels.Count-1-I); end;
    procedure PaintProbe;
    begin Probe.HandleNeeded; B.SetSize(Probe.ClientWidth,Probe.ClientHeight); Probe.PaintTo(B.Canvas,0,0); end;
    procedure StartPanelDrag(Index,Handle: Integer);
    begin
      Probe.FTool:=0; Probe.SelectSinglePanel(Index); PaintProbe; OriginalBounds:=Probe.Page.Panels[Index].Bounds;
      if Handle=0 then PointA:=OriginalBounds.CenterPoint else PointA:=EditHandles(OriginalBounds)[Handle-1];
      X:=Probe.FPageRect.Left+Round(PointA.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(PointA.Y*Probe.FScale);
      Probe.FCanvas.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(X,Y));
      Check(Probe.FDragging and (Probe.FDragHandle=Handle) and (Probe.FDragVertex=-1),'panel snap starts the requested whole-object handle '+IntToStr(Handle));
    end;
    procedure MoveTo(const P: TPointF; Alt: Boolean=False);
    var Flags: Integer;
    begin
      TX:=Probe.FPageRect.Left+Round(P.X*Probe.FScale); TY:=Probe.FPageRect.Top+Round(P.Y*Probe.FScale);
      Flags:=MK_LBUTTON;
      // MouseMove receives VCL Alt state directly; no global keyboard or focus changes.
      if Alt then Probe.MouseMove(Probe.FCanvas,[ssLeft,ssAlt],TX,TY)
      else Probe.FCanvas.Perform(WM_MOUSEMOVE,Flags,MakeLParam(TX,TY));
    end;
    procedure Finish;
    begin Probe.FCanvas.Perform(WM_LBUTTONUP,0,MakeLParam(TX,TY)); end;
  begin
    Original:=FProject.Snapshot; Panels:=TObjectList<TComicPanel>.Create;
    Probe:=TMainForm.Create(nil); PNG:=TPngImage.Create;
    try
      Frame:=TRectF.Create(60,60,1140,1640); Bounds:=TRectF.Create(62,63,1137,1638);
      for K:=1 to 8 do begin
        Target:=SnapPanelBounds(Panels,Bounds,Frame,8,K,nil,30,30); Expected:=Bounds;
        if K in [1,7,8] then Expected.Left:=60; if K in [3,4,5] then Expected.Right:=1140;
        if K in [1,2,3] then Expected.Top:=60; if K in [5,6,7] then Expected.Bottom:=1640;
        Check(Target=Expected,'frame resize snaps only active edges and keeps opposite anchors '+IntToStr(K));
      end;
      Bounds:=TRectF.Create(62,63,262,313); Target:=SnapPanelBounds(Panels,Bounds,Frame,8,0,nil,30,30);
      Check((Target.Left=60) and (Target.Top=60) and (Target.Width=200) and (Target.Height=250),'whole-panel frame movement preserves size on both axes');
      Bounds:=TRectF.Create(-200,-200,-100,-100); Check(SnapPanelBounds(Panels,Bounds,Frame,8,0,nil,30,30)=Bounds,'snapping leaves deliberate frame overflow unrestricted');
      Bounds:=TRectF.Create(112,300,142,500); Check(SnapPanelBounds(Panels,Bounds,TRectF.Create(115,60,1140,1640),8,8,nil,30,30)=Bounds,
        'resize snap cannot cross the minimum panel width');
      Add(100,100,300,350); Add(320,100,520,350); Add(700,100,900,350); IDs:=[Panels[2].ID];
      Bounds:=TRectF.Create(538,100,738,350); Target:=SnapPanelBounds(Panels,Bounds,Frame,8,0,IDs,30,30);
      Check((Target.Left=540) and (Target.Width=200) and (Target.Top=100),'whole-panel move repeats a twenty-pixel stationary gap');
      Reverse; Check(SnapPanelBounds(Panels,Bounds,Frame,8,0,IDs,30,30)=Target,'move snap target is independent of panel iteration order'); Reverse;
      Bounds:=TRectF.Create(538,700,738,950); Check(SnapPanelBounds(Panels,Bounds,Frame,8,0,IDs,30,30)=Bounds,'repeated gap requires overlapping neighbour spans');
      Bounds:=TRectF.Create(521,100,721,350); Target:=SnapPanelBounds(Panels,Bounds,Frame,1,0,IDs,30,30);
      Check(Target.Left=520,'alignment remains reachable exactly at the snap tolerance');
      Bounds.Left:=521.1; Bounds.Right:=721.1; Check(SnapPanelBounds(Panels,Bounds,Frame,1,0,IDs,30,30)=Bounds,'movement outside the tolerance preserves exact coordinates');
      Bounds:=TRectF.Create(101,101,901,351); IDs:=[Panels[0].ID,Panels[1].ID,Panels[2].ID];
      Check(SnapPanelBounds(Panels,Bounds,Frame,8,0,IDs,30,30)=Bounds,'every selected member is excluded from alignment and gap measurement');
      Panels.Clear; Add(100,100,120,200); Add(120,300,140,400); Bounds:=TRectF.Create(110,600,180,800);
      Target:=SnapPanelBounds(Panels,Bounds,Frame,10,0,nil,30,30); Reverse;
      Check((Target.Left=100) and (SnapPanelBounds(Panels,Bounds,Frame,10,0,nil,30,30)=Target),'equidistant alignment uses a fixed coordinate tie break');
      Panels.Clear; Add(100,100,300,350); Add(100,380,300,630);
      Bounds:=TRectF.Create(100,658,300,908); Target:=SnapPanelBounds(Panels,Bounds,Frame,8,0,nil,30,30);
      Check((Target.Top=660) and (Target.Height=250),'whole-panel movement repeats a vertical stationary gap');
      Bounds:=TRectF.Create(100,700,300,900); Target:=SnapPanelBounds(Panels,Bounds,Frame,50,2,nil,30,30);
      Check((Target.Top=660) and (Target.Bottom=900),'top resize repeats a gap while retaining the opposite edge');
      Panels.Clear; Add(100,100,300,300); Panel.SetVertices([TPointF.Create(100,100),TPointF.Create(220,100),TPointF.Create(300,300)]);
      Bounds:=TRectF.Create(222,600,422,800); Target:=SnapPanelBounds(Panels,Bounds,Frame,8,0,nil,30,30);
      Check(Target.Left=220,'polygon corner axes remain available to whole-panel movement');
      Project:=TComicProject.Create; Project.Initialize('コマ全体スナップ fixture','1'); Probe.AdoptProject(Project,False);
      ImageID:=Project.ImportImage(TPath.Combine(Folder,'reference.bmp'),'').ID;
      Panels.Free; Panels:=nil;
      Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(100,100,300,350); Probe.Page.Panels.Add(Panel);
      Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(320,100,520,350); Probe.Page.Panels.Add(Panel);
      Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(700,100,900,350); Panel.ImageID:=ImageID; MovingID:=Panel.ID; Probe.Page.Panels.Add(Panel);
      Probe.RefreshUI; Probe.FTabs.ActivePageIndex:=1; Probe.TabChanged(nil); Probe.FSnap.Checked:=True;
      Before:=Project.Snapshot;
      for PPI in [96,144] do begin
        Probe.Scaled:=True; Probe.ScaleForPPI(PPI); Probe.Scaled:=False; Probe.Width:=MulDiv(940,PPI,96); Probe.Height:=MulDiv(660,PPI,96); Probe.Realign;
        Probe.FUndo.Clear; Probe.FRedo.Clear; StartPanelDrag(2,0); History:=Probe.FUndo.Count;
        MoveTo(TPointF.Create(PointA.X-162,PointA.Y)); Finish;
        Check((Probe.Page.Panels[2].Bounds.Left=540) and (Probe.Page.Panels[2].Bounds.Width=200) and
          (Probe.Page.Panels[2].ID=MovingID) and (Probe.Page.Panels[2].ImageID=ImageID) and (Probe.FUndo.Count=History+1),
          'VCL panel movement snaps to repeated gap and commits once at PPI '+IntToStr(PPI));
        After:=Project.Snapshot; Project.Save; Reloaded:=TComicProject.Create;
        try Reloaded.Load(TPath.Combine(Project.Folder,'Project.json')); Check(Reloaded.Snapshot=After,'snapped panel saves and reloads at PPI '+IntToStr(PPI)); finally Reloaded.Free; end;
        Probe.Undo(nil); Check(Project.Snapshot=Before,'snapped movement undo restores exact source data '+IntToStr(PPI));
        Probe.Redo(nil); Check(Project.Snapshot=After,'snapped movement redo restores all geometry '+IntToStr(PPI)); Probe.Undo(nil);
        StartPanelDrag(2,0); MoveTo(TPointF.Create(PointA.X-162,PointA.Y),True); Finish;
        Check(Abs(Probe.Page.Panels[2].Bounds.Left-540)>0.5,'Alt bypasses whole-panel movement snap '+IntToStr(PPI)); Probe.Undo(nil);
        Probe.FSnap.Checked:=False; StartPanelDrag(2,0); MoveTo(TPointF.Create(PointA.X-162,PointA.Y)); Finish;
        Check(Abs(Probe.Page.Panels[2].Bounds.Left-540)>0.5,'disabled checkbox bypasses whole-panel snap '+IntToStr(PPI)); Probe.Undo(nil); Probe.FSnap.Checked:=True;
        StartPanelDrag(2,0); History:=Probe.FUndo.Count; MoveTo(TPointF.Create(PointA.X-162,PointA.Y)); KeyValue:=VK_ESCAPE; Probe.Key(Probe,KeyValue,[]);
        Check((Project.Snapshot=Before) and (Probe.FUndo.Count=History) and not Probe.FDragging,'escape cancels snapped movement without an undo entry '+IntToStr(PPI));
        // Repeated updates use the original mouse-down bounds, not the last snapped result.
        StartPanelDrag(2,0); MoveTo(TPointF.Create(PointA.X-162,PointA.Y)); MoveTo(TPointF.Create(PointA.X-100,PointA.Y),True);
        Delta:=Probe.ToPage(TX,TY)-Probe.FStart;
        Check(Abs(Probe.Page.Panels[2].Bounds.Left-(OriginalBounds.Left+Delta.X))<0.001,'leaving a snap with Alt has no accumulated displacement '+IntToStr(PPI)); Probe.CancelDrag;
      end;
      Project.Restore(Before); Probe.RefreshUI; Probe.Page.Panels.Clear;
      Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(200,200,1000,1400); Probe.Page.Panels.Add(Panel);
      Before:=Project.Snapshot;
      for PPI in [96,144] do begin
        Probe.Scaled:=True; Probe.ScaleForPPI(PPI); Probe.Scaled:=False; Probe.Width:=MulDiv(940,PPI,96); Probe.Height:=MulDiv(660,PPI,96); Probe.Realign;
        for K:=1 to 8 do begin
          StartPanelDrag(0,K); Expected:=OriginalBounds;
          if K in [1,7,8] then Expected.Left:=60; if K in [3,4,5] then Expected.Right:=1140;
          if K in [1,2,3] then Expected.Top:=60; if K in [5,6,7] then Expected.Bottom:=1640;
          PointA:=EditHandles(Expected)[K-1]; MoveTo(PointA); Finish;
          Check((Probe.Page.Panels[0].Bounds=Expected) and (Probe.FUndo.Count=1),'all eight VCL resize handles snap active edges only '+IntToStr(K)+' PPI '+IntToStr(PPI));
          Probe.Undo(nil); Check(Project.Snapshot=Before,'snapped handle restores exact data on undo '+IntToStr(K)+' PPI '+IntToStr(PPI));
        end;
      end;
      Probe.Page.Panels[0].Bounds:=TRectF.Create(60,60,600,700); Before:=Project.Snapshot;
      for PPI in [96,144] do begin
        Probe.Scaled:=True; Probe.ScaleForPPI(PPI); Probe.Scaled:=False; Probe.Width:=MulDiv(940,PPI,96); Probe.Height:=MulDiv(660,PPI,96); Probe.Realign;
        StartPanelDrag(0,0); TX:=X+MulDiv(2,PPI,96); TY:=Y+MulDiv(2,PPI,96);
        Probe.FCanvas.Perform(WM_MOUSEMOVE,MK_LBUTTON,MakeLParam(TX,TY)); Finish;
        Check((Project.Snapshot=Before) and (Probe.FUndo.Count=0),'small frame-aligned movement snaps back without a phantom undo '+IntToStr(PPI));
      end;
      // A mixed group uses its outer rectangle, preserving internal proportions and stationary panels.
      Probe.Page.Panels.Clear; Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(100,200,300,400); Probe.Page.Panels.Add(Panel);
      Panel:=TComicPanel.Create; Panel.SetVertices([TPointF.Create(350,200),TPointF.Create(550,200),TPointF.Create(550,400),TPointF.Create(350,400)]); Probe.Page.Panels.Add(Panel);
      Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(700,200,900,400); Probe.Page.Panels.Add(Panel); OtherBounds:=Panel.Bounds;
      Before:=Project.Snapshot; Probe.RefreshUI;
      for PPI in [96,144] do begin
        Probe.Scaled:=True; Probe.ScaleForPPI(PPI); Probe.Scaled:=False; Probe.Width:=MulDiv(940,PPI,96); Probe.Height:=MulDiv(660,PPI,96); Probe.Realign;
        Probe.FSelectedPanels.Clear; Probe.FSelectedPanels.Add(Probe.Page.Panels[0].ID); Probe.FSelectedPanels.Add(Probe.Page.Panels[1].ID); Probe.FPanelIndex:=0; PaintProbe;
        Bounds:=Probe.SelectedPanelBounds; PointA:=Bounds.CenterPoint; X:=Probe.FPageRect.Left+Round(PointA.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(PointA.Y*Probe.FScale);
        Probe.FCanvas.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(X,Y)); Check(Length(Probe.FDragGroup)=2,'group snap starts through the gap between selected members '+IntToStr(PPI));
        MoveTo(TPointF.Create(PointA.X-38,PointA.Y)); Finish;
        Check((Probe.SelectedPanelBounds.Left=60) and (Abs(Probe.SelectedPanelBounds.Width-450)<0.001) and (Probe.Page.Panels[2].Bounds=OtherBounds) and
          ValidPolygon(Probe.Page.Panels[1].Vertices) and (Probe.FUndo.Count=1),'mixed-shape group snaps as one object and excludes both members '+IntToStr(PPI));
        PaintProbe; PNG.Assign(B); PNG.SaveToFile(TPath.Combine(Folder,'panel-transform-snap-'+IntToStr(PPI)+'.png'));
        Probe.Undo(nil); Check(Project.Snapshot=Before,'group frame snap cancels all member displacement in one undo '+IntToStr(PPI));
        for K:=1 to 8 do begin
          Probe.FSelectedPanels.Clear; Probe.FSelectedPanels.Add(Probe.Page.Panels[0].ID); Probe.FSelectedPanels.Add(Probe.Page.Panels[1].ID); Probe.FPanelIndex:=0; PaintProbe;
          Bounds:=Probe.SelectedPanelBounds; Expected:=Bounds; PointA:=EditHandles(Bounds)[K-1];
          X:=Probe.FPageRect.Left+Round(PointA.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(PointA.Y*Probe.FScale);
          Probe.FCanvas.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(X,Y));
          Check((Length(Probe.FDragGroup)=2) and (Probe.FDragHandle=K),'group snap selects outer resize handle '+IntToStr(K)+' PPI '+IntToStr(PPI));
          if K in [1,7,8] then Expected.Left:=60; if K in [3,4,5] then Expected.Right:=1140;
          if K in [1,2,3] then Expected.Top:=60; if K in [5,6,7] then Expected.Bottom:=1640;
          MoveTo(EditHandles(Expected)[K-1]); Finish; Target:=Probe.SelectedPanelBounds;
          Check((Abs(Target.Left-Expected.Left)<0.001) and (Abs(Target.Top-Expected.Top)<0.001) and
            (Abs(Target.Right-Expected.Right)<0.001) and (Abs(Target.Bottom-Expected.Bottom)<0.001) and
            (Probe.Page.Panels[2].Bounds=OtherBounds) and ValidPolygon(Probe.Page.Panels[1].Vertices) and (Probe.FUndo.Count=1),
            'mixed-shape group resize snaps active edges and preserves stationary geometry '+IntToStr(K)+' PPI '+IntToStr(PPI));
          Probe.Undo(nil); Check(Project.Snapshot=Before,'group snapped resize undo restores all proportions '+IntToStr(K)+' PPI '+IntToStr(PPI));
        end;
        Probe.FSelectedPanels.Clear; Probe.FSelectedPanels.Add(Probe.Page.Panels[0].ID); Probe.FSelectedPanels.Add(Probe.Page.Panels[1].ID); Probe.FPanelIndex:=0; PaintProbe;
        Bounds:=Probe.SelectedPanelBounds; PointA:=EditHandles(Bounds)[4]; X:=Probe.FPageRect.Left+Round(PointA.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(PointA.Y*Probe.FScale);
        Probe.FCanvas.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(X,Y)); MoveTo(TPointF.Create(1138,1638)); KeyValue:=VK_ESCAPE; Probe.Key(Probe,KeyValue,[]);
        Check((Project.Snapshot=Before) and (Probe.FUndo.Count=0) and not Probe.FDragging,'escape cancels an entire snapped group resize '+IntToStr(PPI));
        // Selected members cannot attract their own original edge during a short group move.
        Probe.FSelectedPanels.Clear; Probe.FSelectedPanels.Add(Probe.Page.Panels[0].ID); Probe.FSelectedPanels.Add(Probe.Page.Panels[1].ID); Probe.FPanelIndex:=0; PaintProbe;
        Bounds:=Probe.SelectedPanelBounds; PointA:=Bounds.CenterPoint; X:=Probe.FPageRect.Left+Round(PointA.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(PointA.Y*Probe.FScale);
        Probe.FCanvas.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(X,Y)); MoveTo(TPointF.Create(PointA.X+5,PointA.Y));
        Check(Probe.SelectedPanelBounds.Left>101,Format('short group movement does not stick to a selected member %d [drag=%s pan=%s group=%d handle=%d scale=%.6f left=%.3f start=%.3f last=%.3f]',[PPI,BoolToStr(Probe.FDragging,True),BoolToStr(Probe.FViewPanning,True),Length(Probe.FDragGroup),Probe.FDragHandle,Probe.FScale,Probe.SelectedPanelBounds.Left,Probe.FStart.X,Probe.FLast.X])); Probe.CancelDrag;
        for K:=0 to 1 do begin
          Probe.FSelectedPanels.Clear; Probe.FSelectedPanels.Add(Probe.Page.Panels[0].ID); Probe.FSelectedPanels.Add(Probe.Page.Panels[1].ID); Probe.FPanelIndex:=0; PaintProbe;
          Bounds:=Probe.SelectedPanelBounds; PointA:=EditHandles(Bounds)[4]; X:=Probe.FPageRect.Left+Round(PointA.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(PointA.Y*Probe.FScale);
          Probe.FSnap.Checked:=K=0; Probe.FCanvas.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(X,Y)); MoveTo(TPointF.Create(1136,1636),K=0); Finish;
          Check((Abs(Probe.Page.Panels[1].Bounds.Right-1140)>0.5) and (Abs(Probe.Page.Panels[1].Bounds.Bottom-1640)>0.5),
            'group resize bypasses snapping through Alt or setting '+IntToStr(K)+' PPI '+IntToStr(PPI)); Probe.Undo(nil); Probe.FSnap.Checked:=True;
        end;
      end;
      Check(FProject.Snapshot=Original,'panel transform snap fixtures preserve the active project');
    finally Panels.Free; PNG.Free; Probe.Free; end;
  end;
  procedure ExportReviewChecks;
  var Probe: TMainForm; Project: TComicProject; Panel: TComicPanel; D: TComicExportDialog;
    ImageID,Before,Original,Output: string; PPI,I,Kind,X,Y,History: Integer; All: Boolean;
    PointA: TPointF; PNG: TPngImage; Control: TControl; LabelControl: TLabel; Radio: TRadioGroup;
    procedure AddPanel(PageIndex: Integer; const ID: string; const Bounds: TRectF);
    begin Panel:=TComicPanel.Create; Panel.Bounds:=Bounds; Panel.ImageID:=ID; Project.Pages[PageIndex].Panels.Add(Panel); end;
    procedure CheckLayout(const Name: string);
    var Margin,I,J,RadioCount: Integer;
    begin
      D.HandleNeeded; D.Scaled:=True; D.ScaleForPPI(PPI); D.Scaled:=False;
      D.ClientWidth:=MulDiv(600,PPI,96); if D.WarningText='' then D.ClientHeight:=MulDiv(246,PPI,96) else D.ClientHeight:=MulDiv(340,PPI,96);
      D.Realign; B.SetSize(D.ClientWidth,D.ClientHeight); D.PaintTo(B.Canvas,0,0);
      PNG.Assign(B); PNG.SaveToFile(TPath.Combine(Folder,Name+'-'+IntToStr(PPI)+'.png'));
      RadioCount:=0; Margin:=MulDiv(8,PPI,96);
      for I:=0 to D.ComponentCount-1 do if D.Components[I] is TControl then begin
        Control:=TControl(D.Components[I]); if not Control.Visible then Continue;
        Check((Control.Left>=0) and (Control.Top>=0) and (Control.Left+Control.Width<=D.ClientWidth) and
          (Control.Top+Control.Height<=D.ClientHeight),'export review control fits '+Control.ClassName+' '+IntToStr(PPI)+' '+IntToStr(Kind));
        if Control is TRadioGroup then begin
          Radio:=TRadioGroup(Control); Inc(RadioCount);
          Check((Radio.Items.Count=2) and (Radio.ItemIndex=0) and (Radio.Height>=MulDiv(80,PPI,96)),
            'export review retains both reachable output choices with changed-only default '+IntToStr(PPI)+' '+IntToStr(Kind));
          for J:=0 to D.ComponentCount-1 do if (D.Components[J] is TLabel) and TLabel(D.Components[J]).Visible then begin
            LabelControl:=TLabel(D.Components[J]); Check(LabelControl.Top+LabelControl.Height+Margin<=Radio.Top,
              'export warning and output path do not overlap output choices '+IntToStr(PPI)+' '+IntToStr(Kind));
          end;
        end;
      end;
      Check(RadioCount=1,'export review has a single output selection stage '+IntToStr(PPI)+' '+IntToStr(Kind));
    end;
  begin
    Original:=FProject.Snapshot; Probe:=TMainForm.Create(nil); D:=nil; PNG:=TPngImage.Create;
    try
      Project:=TComicProject.Create; Project.Initialize('出力確認 fixture','1'); Probe.AdoptProject(Project,False);
      ImageID:=Project.ImportImage(TPath.Combine(Folder,'reference.bmp'),'').ID; Project.Pages.Add(TComicPage.Create);
      AddPanel(0,ImageID,TRectF.Create(100,100,400,400)); AddPanel(0,ImageID,TRectF.Create(450,100,750,400));
      AddPanel(0,'',TRectF.Create(800,100,1100,400)); AddPanel(1,'missing-asset',TRectF.Create(100,100,400,400));
      AddPanel(1,ImageID,TRectF.Create(450,100,750,400)); Before:=Project.Snapshot; Output:=TPath.Combine(Project.Folder,'Output');
      Probe.RefreshUI; Probe.FTabs.ActivePageIndex:=1; Probe.TabChanged(nil); Probe.SelectSinglePanel(2); Probe.FTool:=0;
      Probe.HandleNeeded; B.SetSize(Probe.ClientWidth,Probe.ClientHeight); Probe.PaintTo(B.Canvas,0,0);
      PointA:=Probe.Page.Panels[2].Bounds.CenterPoint; X:=Probe.FPageRect.Left+Round(PointA.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(PointA.Y*Probe.FScale);
      Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y); Probe.MouseMove(Probe.FCanvas,[ssLeft,ssAlt],X+20,Y+12);
      Check(Probe.FDragging and (Project.Snapshot<>Before),'export review starts with a pending panel drag');
      History:=Probe.FUndo.Count; D:=Probe.CreateExportOptions;
      Check(not Probe.FDragging and (Project.Snapshot=Before) and (Probe.FUndo.Count=History),'opening export review cancels a pending drag before counting warnings');
      Check((Pos('画像未配置・参照切れ：2 コマ',D.WarningText)>0) and (Pos('同じ画像の重複配置：2 コマ',D.WarningText)>0),
        'export review counts missing images and reused image identities across every page');
      Check(D.OutputPath=Output,'export review retains the complete project output path');
      for I:=0 to D.ComponentCount-1 do if D.Components[I] is TEdit then begin
        with TEdit(D.Components[I]) do begin
          Check(ReadOnly and (Text=Output) and ShowHint and (Hint=Output),'long export path is selectable read-only text with a full-path hint');
          SelectAll; Check(SelText=Output,'entire export path can be selected without modifying it');
        end;
      end;
      D.ModalResult:=mrCancel; Check(not D.Accepted(All) and not All,'warning review cancellation cannot accept output');
      D.ModalResult:=mrOK; Check(D.Accepted(All) and not All,'warnings allow explicit changed-only output without a second confirmation');
      for I:=0 to D.ComponentCount-1 do if D.Components[I] is TRadioGroup then TRadioGroup(D.Components[I]).ItemIndex:=1;
      Check(D.Accepted(All) and All,'warnings allow explicit all-page output without rejecting duplicate images'); FreeAndNil(D);
      for Kind:=0 to 2 do for PPI in [96,144] do begin
        case Kind of
          0: D:=TComicExportDialog.CreateOptions(Probe,Output,Probe.OpenOutput,'');
          1: D:=TComicExportDialog.CreateOptions(Probe,Output,Probe.OpenOutput,'画像未配置・参照切れ：2 コマ。画像のない部分も含めて出力します。');
          2: D:=Probe.CreateExportOptions;
        end;
        CheckLayout('export-review-'+IntToStr(Kind));
        PostMessage(D.Handle,WM_CLOSE,0,0); D.ShowModal;
        Check((D.ModalResult=mrCancel) and (Project.Snapshot=Before) and (Probe.FUndo.Count=History),
          'native export review close preserves project and undo '+IntToStr(PPI)+' '+IntToStr(Kind)); FreeAndNil(D);
      end;
      Project.Pages[0].Panels.Delete(2); Project.Pages.Delete(1); Project.Pages[0].Panels.Delete(1); Probe.RefreshUI;
      D:=Probe.CreateExportOptions; Check(D.WarningText='','unique valid image assignments do not show an export warning'); FreeAndNil(D);
      Check(Length(TDirectory.GetFiles(Output))=0,'cancelled export review creates no output PNG or cache files');
      Check(FProject.Snapshot=Original,'export review fixtures preserve the active project');
    finally D.Free; PNG.Free; Probe.Free; end;
  end;
  procedure RecentProjectChecks;
  var Recent,CopyRecent: TComicRecentProjects; Probe: TMainForm; Project: TComicProject; Path,Before,Original,Saved,Draft,SourceFile,BrokenFile: string;
    Lock: THandle; I,History: Integer; Failed: Boolean; Json: TJSONObject; Pair: TJSONPair; Pages: TJSONArray; BadBalloon: TComicBalloon;
  begin
    Original:=FProject.Snapshot; Recent:=TComicRecentProjects.Create; CopyRecent:=TComicRecentProjects.Create; Probe:=TMainForm.Create(nil);
    try
      Path:=TPath.Combine(Folder,'recent-projects.json');
      for I:=0 to 24 do Recent.Remember(TPath.Combine(Folder,'recent-'+IntToStr(I)+'.json'),'作品'+IntToStr(I),'第1話',Path);
      Check((Recent.Items.Count=20) and (Recent.Items[0].Title='作品24') and (Recent.Items[19].Title='作品5'),'recent projects retain the newest twenty entries');
      Recent.Remember(UpperCase(Recent.Items[10].FileName),'再度開く','第2話',Path);
      Check((Recent.Items.Count=20) and (Recent.Items[0].Title='再度開く'),'recent projects deduplicate Windows paths case-insensitively');
      CopyRecent.Load(Path); Check((CopyRecent.Items.Count=20) and (CopyRecent.Items[0].Episode='第2話'),'recent metadata and ordering save and reload');
      Before:=TFile.ReadAllText(Path,TEncoding.UTF8); Lock:=CreateFile(PChar(Path),GENERIC_READ,FILE_SHARE_READ,nil,OPEN_EXISTING,0,0);
      try
        Failed:=False; try Recent.Remember(TPath.Combine(Folder,'failed-project.json'),'失敗','1',Path); except Failed:=True; end;
        Check(Failed and (Recent.Items[0].Title='再度開く') and (TFile.ReadAllText(Path,TEncoding.UTF8)=Before),'failed recent write preserves memory order and original file');
        Failed:=False; try Recent.Clear(Path); except Failed:=True; end; Check(Failed and (Recent.Items.Count=20),'failed history clear restores all entries');
      finally CloseHandle(Lock); end;
      Json:=Recent.Items[0].Json; try AtomicWrite(Path,'{"version":1,"projects":['+Json.ToJSON+',42]}'); finally Json.Free; end;
      Failed:=False; try CopyRecent.Load(Path); except Failed:=True; end;
      Check(Failed and (CopyRecent.Items.Count=20) and (CopyRecent.Items[0].Title='再度開く'),'malformed recent file cannot publish a prefix or replace existing history');
      AtomicWrite(Path,Before); Recent.Clear(Path); CopyRecent.Load(Path); Check(CopyRecent.Items.Count=0,'explicit history clear saves an empty list');
      Project:=TComicProject.Create; Project.Initialize('履歴から開く','第1話'); SourceFile:=TPath.Combine(Project.Folder,'Project.json');
      Saved:=Project.Snapshot; Project.Title:='未保存の作業を復元'; Project.SaveDraft; Draft:=Project.Snapshot; Project.Free;
      Probe.OpenProjectFile(SourceFile,0); Check((Probe.FProject.Snapshot=Saved) and not Probe.FDirty,'history open can keep the formally saved project');
      Check((Probe.FRecent.Items.Count>0) and (Probe.FRecent.Items[0].FileName=SourceFile),'successful open records the original Project.json path');
      Probe.OpenProjectFile(SourceFile,1); Check((Probe.FProject.Snapshot=Draft) and Probe.FDirty,'history open can restore a valid draft and mark the project dirty');
      Check(Probe.FRecent.Items[0].FileName=SourceFile,'draft restoration keeps the normal project path in history');
      Before:=Probe.FProject.Snapshot; History:=Probe.FUndo.Count; BrokenFile:=TPath.Combine(Folder,'invalid-recent-project.json'); AtomicWrite(BrokenFile,'{invalid}');
      Failed:=False; try Probe.OpenProjectFile(BrokenFile,0); except Failed:=True; end;
      Check(Failed and (Probe.FProject.Snapshot=Before) and (Probe.FUndo.Count=History) and (Probe.FRecent.Items[0].FileName=SourceFile),
        'failed history load preserves active project history and selected original path');
      AtomicWrite(TPath.Combine(Probe.FProject.Folder,'Draft.json'),'{invalid}'); Failed:=False; try Probe.OpenProjectFile(SourceFile,1); except Failed:=True; end;
      Check(Failed and (Probe.FProject.Snapshot=Before),'failed draft restoration preserves the active project');
      Json:=Probe.FProject.Json;
      try Pair:=Json.RemovePair('id'); Pair.Free; Json.AddPair('id','different-project'); AtomicWrite(TPath.Combine(Probe.FProject.Folder,'Draft.json'),Json.ToJSON);
      finally Json.Free; end;
      Failed:=False; try Probe.OpenProjectFile(SourceFile,1); except Failed:=True; end;
      Check(Failed and (Probe.FProject.Snapshot=Before),'draft for a different project cannot replace the active project');
      Json:=Probe.FProject.Json;
      try Pages:=Json.GetValue<TJSONArray>('pages'); Pages.AddElement(Probe.FProject.Pages[0].Json); AtomicWrite(BrokenFile,Json.ToJSON); finally Json.Free; end;
      Failed:=False; try Probe.OpenProjectFile(BrokenFile,0); except Failed:=True; end;
      Check(Failed and (Probe.FProject.Snapshot=Before),'duplicate page identities are rejected before replacing the active project');
      Json:=Probe.FProject.Json;
      try
        Pages:=Json.GetValue<TJSONArray>('pages'); Pair:=TJSONObject(Pages.Items[0]).RemovePair('id'); Pair.Free;
        TJSONObject(Pages.Items[0]).AddPair('id','page-identity');
        Pages.AddElement(Probe.FProject.Pages[0].Json); Pair:=TJSONObject(Pages.Items[Pages.Count-1]).RemovePair('id'); Pair.Free;
        TJSONObject(Pages.Items[Pages.Count-1]).AddPair('id','PAGE-IDENTITY'); AtomicWrite(BrokenFile,Json.ToJSON);
      finally Json.Free; end;
      Failed:=False; try Probe.OpenProjectFile(BrokenFile,0); except Failed:=True; end;
      Check(Failed and (Probe.FProject.Snapshot=Before),'page identities cannot alias the same Windows save and cache path');
      BadBalloon:=TComicBalloon.Create; Json:=BadBalloon.Json;
      try Pair:=Json.RemovePair('fontSize'); Pair.Free; Json.AddPair('fontSize',TJSONNumber.Create(0)); Failed:=False;
        try BadBalloon.Read(Json); except Failed:=True; end; Check(Failed,'zero-sized text cannot enter a restored project');
      finally Json.Free; BadBalloon.Free; end;
      Probe.FRecent.Remember(BrokenFile,'壊れた作品','1',TPath.Combine(Folder,'menu-history.json')); TFile.Delete(BrokenFile); Probe.RefreshRecentMenu;
      Check(Probe.FRecentItems[0].Visible and not Probe.FRecentItems[0].Enabled,'missing project remains listed with an unavailable history action');
      Check(FProject.Snapshot=Original,'recent project fixtures preserve the active project');
    finally Probe.Free; CopyRecent.Free; Recent.Free; end;
  end;
  procedure DragCommandChecks;
  var Probe: TMainForm; Project: TComicProject; Panel: TComicPanel; Base,Before,Original,After: string;
    Bounds: TRectF; P: TPointF; X,Y,K,History,I,PPI: Integer; KeyValue: Word; ExportDialog: TComicExportDialog; All: Boolean;
    procedure StartDrag;
    begin
      Probe.FTabs.ActivePageIndex:=4; Probe.FEffectCategory.ItemIndex:=0; Probe.FEffectPages.ActivePageIndex:=0;
      Probe.FPanelIndex:=0; Probe.FEffectIndex:=0; Probe.RefreshUI; Probe.HandleNeeded;
      B.SetSize(Probe.ClientWidth,Probe.ClientHeight); Probe.PaintTo(B.Canvas,0,0);
      Bounds:=OverlayBounds(Probe.Page.Panels[0],Probe.Page.Panels[0].Overlays[0]); P:=Bounds.CenterPoint;
      X:=Probe.FPageRect.Left+Round(P.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(P.Y*Probe.FScale);
      Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y); Probe.MouseMove(Probe.FCanvas,[ssLeft],X+12,Y+10);
      Check(Probe.FDragging and (Project.Snapshot<>Base),'command fixture starts a moved uncommitted material');
    end;
  begin
    Original:=FProject.Snapshot; Probe:=TMainForm.Create(nil);
    try
      Project:=TComicProject.Create; Project.Initialize('ドラッグ中コマンド fixture','1'); Probe.AdoptProject(Project,False);
      Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(100,100,550,1200); Panel.ImageID:=Project.ImportImage(TPath.Combine(Folder,'reference.bmp'),'').ID; Probe.Page.Panels.Add(Panel);
      Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(650,100,1100,1200); Probe.Page.Panels.Add(Panel); Project.Pages.Add(TComicPage.Create);
      Probe.ApplyEffectMaterial(0,Probe.FEffectMaterials[0]); Base:=Project.Snapshot;
      for K:=0 to 5 do begin
        Project.Restore(Base); Probe.FUndo.Clear; Probe.FRedo.Clear; Probe.FPageIndex:=0; StartDrag;
        case K of
          0: begin KeyValue:=VK_DELETE; Probe.ActiveControl:=Probe.FView; Probe.Key(Probe,KeyValue,[]);
            Check(Probe.Page.Panels[0].Overlays.Count=0,'delete during material dragging resolves the restored owner before deletion'); end;
          1: begin Probe.FPanelIndex:=1; Probe.FFilterKind.ItemIndex:=2; Probe.FFilterStrength.ItemIndex:=3; Probe.ApplyFilter(nil);
            Check((Probe.Page.Panels[1].FilterKind=2) and (OverlayBounds(Probe.Page.Panels[0],Probe.Page.Panels[0].Overlays[0])=Bounds),
              'filter on another panel cancels the material drag and uses the current target'); end;
          2: begin Probe.FPanelIndex:=1; Probe.FFrameKind.ItemIndex:=1; Probe.FPanelBorderWidth.ItemIndex:=3; Probe.ApplyFrame(nil);
            Check(Probe.Page.Panels[1].FrameKind=1,'frame command during material drag resolves its restored target'); end;
          3: begin Probe.FPanelIndex:=0; Probe.DetachImage(nil); Check(Probe.Page.Panels[0].ImageID='','image detach during material dragging does not use a freed panel'); end;
          4: begin Probe.FTabs.ActivePageIndex:=1; Probe.SelectSinglePanel(0); Probe.DeleteObject(nil); Check(Probe.Page.Panels.Count=1,'panel delete during dragging removes its restored owner'); end;
          5: begin Probe.FPages.ClearSelection; Probe.FPages.Selected[0]:=True;
            Probe.PagesDragDrop(Probe.FPages,Probe.FPages,8,Probe.FPages.ItemRect(1).Bottom-1);
            Check((Probe.FPageIndex=1) and (Project.Pages[1].Panels.Count=2),'page reorder during dragging resolves fresh page objects'); end;
        end;
        Check(not Probe.FDragging and (Probe.FUndo.Count=1),'command cancels pending material edit and commits once '+IntToStr(K));
        Probe.Undo(nil); Check(Project.Snapshot=Base,'command undo restores unmodified original material and project '+IntToStr(K));
      end;
      Project.Restore(Base); Probe.FUndo.Clear; Probe.FRedo.Clear; Probe.FPageIndex:=0; Probe.Checkpoint;
      Probe.Page.Panels[0].BorderWidth:=6; Probe.Changed; Before:=Project.Snapshot; StartDrag; Probe.Undo(nil);
      Check((Project.Snapshot=Base) and not Probe.FDragging,'undo during dragging cancels the drag then undoes the previous committed operation');
      StartDrag; Probe.Redo(nil); Check((Project.Snapshot=Before) and not Probe.FDragging,'redo during dragging cancels it before restoring committed data');
      for PPI in [96,144] do begin
        Probe.Scaled:=True; Probe.ScaleForPPI(PPI); Probe.Scaled:=False; Probe.Width:=MulDiv(940,PPI,96); Probe.Height:=MulDiv(660,PPI,96); Probe.Realign;
        Before:=Project.Snapshot; History:=Probe.FUndo.Count; StartDrag; ExportDialog:=Probe.CreateExportOptions;
        try
          ExportDialog.ModalResult:=mrCancel;
          Check(not ExportDialog.Accepted(All) and not All and not Probe.FDragging and (Project.Snapshot=Before) and (Probe.FUndo.Count=History),
            'export dialog cancellation after dragging preserves exact committed data '+IntToStr(PPI));
          ExportDialog.HandleNeeded; ExportDialog.Scaled:=True; ExportDialog.ScaleForPPI(PPI); ExportDialog.Scaled:=False;
          ExportDialog.ClientWidth:=MulDiv(600,PPI,96); if ExportDialog.WarningText='' then ExportDialog.ClientHeight:=MulDiv(246,PPI,96) else ExportDialog.ClientHeight:=MulDiv(340,PPI,96); ExportDialog.Realign;
          ExportDialog.HandleNeeded; B.SetSize(ExportDialog.ClientWidth,ExportDialog.ClientHeight); ExportDialog.PaintTo(B.Canvas,0,0);
          for I:=0 to ExportDialog.ComponentCount-1 do if ExportDialog.Components[I] is TButton then with TButton(ExportDialog.Components[I]) do
            Check((Left>=0) and (Top>=0) and (Left+Width<=Parent.ClientWidth) and (Top+Height<=Parent.ClientHeight),
              'export dialog action remains reachable '+Caption+' '+IntToStr(PPI)+' '+Format('bounds %d,%d,%d,%d parent %d,%d',[Left,Top,Width,Height,Parent.ClientWidth,Parent.ClientHeight]));
          PostMessage(ExportDialog.Handle,WM_CLOSE,0,0);
          Check((ExportDialog.ShowModal=mrCancel) and not ExportDialog.Accepted(All) and not All and
            (Project.Snapshot=Before) and (Probe.FUndo.Count=History),
            'native export modal cancellation preserves committed data and history '+IntToStr(PPI));
        finally ExportDialog.Free; end;
      end;
      After:=Project.Snapshot; History:=Probe.FUndo.Count; Probe.FPanelIndex:=0; StartDrag; KeyValue:=VK_ESCAPE; Probe.Key(Probe,KeyValue,[]);
      Check((Project.Snapshot=After) and (Probe.FUndo.Count=History),'escape after command replay preserves history and exact restored data');
      Check(FProject.Snapshot=Original,'drag command fixtures preserve the active project');
    finally Probe.Free; end;
  end;
  procedure BlurScaleChecks;
  var Project: TComicProject; Panel: TComicPanel; Renderer: TComicRenderer; Pattern,Full,Preview,Reduced: TBitmap;
    Asset: TComicAsset; Path: string; X,Y,Size: Integer; Same: Boolean;
  begin
    Project:=TComicProject.Create; Renderer:=TComicRenderer.Create; Pattern:=TBitmap.Create; Full:=TBitmap.Create; Preview:=TBitmap.Create; Reduced:=TBitmap.Create;
    try
      Project.Initialize('ぼかし解像度 fixture','1'); Project.Width:=320; Project.Height:=320;
      Pattern.PixelFormat:=pf24bit; Pattern.SetSize(320,320); Pattern.Canvas.Brush.Color:=clWhite; Pattern.Canvas.FillRect(Rect(0,0,320,320));
      Pattern.Canvas.Brush.Color:=clBlack; Pattern.Canvas.FillRect(Rect(128,0,192,320)); Path:=TPath.Combine(Folder,'blur-pattern.bmp'); Pattern.SaveToFile(Path);
      Asset:=Project.ImportImage(Path,''); Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(0,0,320,320); Panel.ImageID:=Asset.ID;
      Panel.BorderWidth:=0; Panel.FilterKind:=3; Panel.FilterStrength:=100; Project.Pages[0].Panels.Add(Panel);
      Full.PixelFormat:=pf24bit; Full.SetSize(320,320); Renderer.Draw(Full.Canvas,Project,Project.Pages[0],Rect(0,0,320,320),False);
      for Size in [80,160,240] do begin
        Preview.PixelFormat:=pf24bit; Preview.SetSize(Size,Size); Reduced.PixelFormat:=pf24bit; Reduced.SetSize(Size,Size);
        Renderer.Draw(Preview.Canvas,Project,Project.Pages[0],Rect(0,0,Size,Size),False); SetStretchBltMode(Reduced.Canvas.Handle,HALFTONE);
        Reduced.Canvas.StretchDraw(Rect(0,0,Size,Size),Full); Same:=True;
        for X:=0 to Size-1 do for Y:=0 to Size-1 do if Preview.Canvas.Pixels[X,Y]<>Reduced.Canvas.Pixels[X,Y] then Same:=False;
        Check(Same,'blur preview exactly matches the downsampled output raster at size '+IntToStr(Size));
      end;
    finally Reduced.Free; Preview.Free; Full.Free; Pattern.Free; Renderer.Free; Project.Free; end;
  end;
  procedure EffectChecks;
  var Probe: TMainForm; Project,Reloaded: TComicProject; Panel: TComicPanel; Material: TComicEffectMaterial;
    MaterialLibrary,CopyLibrary,Broken: TObjectList<TComicEffectMaterial>; Manager: TComicEffectDialog; Layout: TComicLayout;
    Before,After,Original,Path,ID,CopyPath,LibraryBytes: string; PNG: TPngImage; Reference,Shifted,Pixels: TBitmap;
    PointA: TPointF; Bounds,OriginalBounds: TRectF; X,Y,K,Kind,Shape,Frame,PPI,History,Saved,I: Integer; Lock: THandle; KeyValue: Word;
    Failed,Accept,Same: Boolean; Color: TColor; Json: TJSONObject;
    function CurrentPanel: TComicPanel;
    begin Result:=Probe.Page.Panels[0]; end;
    procedure CaptureEffect(const Name: string);
    begin Probe.UpdateIconState; Probe.HandleNeeded; B.SetSize(Probe.ClientWidth,Probe.ClientHeight); Probe.PaintTo(B.Canvas,0,0); PNG.Assign(B);
      PNG.SaveToFile(TPath.Combine(Folder,Name+'.png')); end;
  begin
    Original:=FProject.Snapshot; Probe:=TMainForm.Create(nil); PNG:=TPngImage.Create; Reference:=TBitmap.Create; Shifted:=TBitmap.Create; Pixels:=TBitmap.Create;
    MaterialLibrary:=TObjectList<TComicEffectMaterial>.Create; CopyLibrary:=TObjectList<TComicEffectMaterial>.Create; Broken:=TObjectList<TComicEffectMaterial>.Create; Manager:=nil; Layout:=TComicLayout.Create;
    try
      SeedEffectMaterials(MaterialLibrary); EnsureBuiltInMaterialFiles(MaterialLibrary);
      PNG.LoadFromFile(EffectMaterialPath(MaterialLibrary[0])); Check((PNG.Width=512) and (PNG.AlphaScanline[256]^[256]=0), 'built-in focus material leaves its centre transparent');
      Pixels.PixelFormat:=pf24bit; Pixels.SetSize(64,64); Pixels.Canvas.Brush.Color:=clRed; Pixels.Canvas.FillRect(Rect(0,0,64,64)); PNG.Assign(Pixels); PNG.CreateAlpha;
      for Y:=0 to 63 do for X:=0 to 63 do if X<32 then PNG.AlphaScanline[Y]^[X]:=128 else PNG.AlphaScanline[Y]^[X]:=0;
      Path:=TPath.Combine(Folder,'half-transparent-effect.png'); PNG.SaveToFile(Path);
      Path:=TPath.Combine(Folder,'effect-library.json'); Material:=ImportEffectMaterial(MaterialLibrary,'半透明効果',TPath.Combine(Folder,'half-transparent-effect.png'),Path); ID:=Material.ID;
      SaveEffectMaterials(MaterialLibrary,Path); SeedEffectMaterials(CopyLibrary); LoadEffectMaterials(CopyLibrary,Path);
      Check((CopyLibrary.Count=4) and (CopyLibrary[3].ID=ID) and (CopyLibrary[3].Name='半透明効果'),'custom effect material saves and reloads stable identity');
      LibraryBytes:=TFile.ReadAllText(Path,TEncoding.UTF8); Lock:=CreateFile(PChar(Path),GENERIC_READ,FILE_SHARE_READ,nil,OPEN_EXISTING,0,0);
      try
        Failed:=False; try RenameEffectMaterial(MaterialLibrary,Material,'保存に失敗',Path); except Failed:=True; end;
        Check(Failed and (Material.Name='半透明効果') and (TFile.ReadAllText(Path,TEncoding.UTF8)=LibraryBytes),'failed effect rename preserves name and original library');
        Failed:=False; try DeleteEffectMaterial(MaterialLibrary,Material,Path); except Failed:=True; end;
        Check(Failed and (MaterialLibrary.Count=4) and (MaterialLibrary[3]=Material),'failed effect deletion restores the exact item and order');
      finally CloseHandle(Lock); end;
      Json:=Material.Json; try AtomicWrite(Path,'{"version":1,"materials":['+Json.ToJSON+',42]}'); finally Json.Free; end;
      Failed:=False; try LoadEffectMaterials(Broken,Path); except Failed:=True; end;
      Check(Failed and (Broken.Count=0),'malformed effect library cannot publish a valid prefix'); AtomicWrite(Path,LibraryBytes);
      Project:=TComicProject.Create; Project.Initialize('漫画効果 fixture','1'); Probe.AdoptProject(Project,False); Project.ImportImage(TPath.Combine(Folder,'reference.bmp'),'');
      Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(100,100,900,1300); OriginalBounds:=Panel.Bounds; Probe.Page.Panels.Add(Panel); Probe.RefreshUI;
      Probe.FModeButtons[4].Click; CaptureEffect('effects-material-empty'); Probe.FEffectList.Items.AddObject(Material.Name,Material); Probe.FEffectList.ItemIndex:=Probe.FEffectList.Count-1;
      PointA:=OriginalBounds.CenterPoint; X:=Probe.FPageRect.Left+Round(PointA.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(PointA.Y*Probe.FScale);
      Before:=Project.Snapshot; Probe.DragOver(Probe.FCanvas,Probe.FEffectList,X,Y,dsDragMove,Accept); Check(Accept,'material D&D accepts a target panel');
      Probe.DragDrop(Probe.FCanvas,Probe.FEffectList,X,Y);
      Check((CurrentPanel.Overlays.Count=1) and (CurrentPanel.Overlays[0].MaterialID=ID) and (OverlayBounds(CurrentPanel,CurrentPanel.Overlays[0])=OriginalBounds),
        'material drop creates a separately identified panel-sized overlay');
      CopyPath:=SafeChild(Project.Folder,CurrentPanel.Overlays[0].FileName); Check(FileExists(CopyPath),'applied material receives a project-local PNG snapshot');
      Reference.SetSize(320,452); Probe.FRenderer.Draw(Reference.Canvas,Project,Probe.Page,Rect(0,0,320,452),False);
      Color:=Reference.Canvas.Pixels[80,110]; Check((GetRValue(Color)>240) and (GetGValue(Color)<170),'half-transparent PNG blends its red ink with the panel background');
      Check(Reference.Canvas.Pixels[187,110]=$F5F2EF,'transparent PNG half preserves the panel background');
      After:=Project.Snapshot; Probe.Undo(nil); Check(Project.Snapshot=Before,'material application undoes as one operation'); Probe.Redo(nil); Check(Project.Snapshot=After,'material application redo restores its retained PNG');
      for K:=1 to 8 do begin
        Probe.FPanelIndex:=0; Probe.FEffectIndex:=0; Bounds:=OverlayBounds(CurrentPanel,CurrentPanel.Overlays[0]); PointA:=EditHandles(Bounds)[K-1];
        X:=Probe.FPageRect.Left+Round(PointA.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(PointA.Y*Probe.FScale); Before:=Project.Snapshot;
        Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y); Check(Probe.FDragHandle=K,'effect material handle '+IntToStr(K)+' is selectable');
        Probe.MouseMove(Probe.FCanvas,[ssLeft],X+14,Y+10); Probe.MouseUp(Probe.FCanvas,mbLeft,[],X+14,Y+10);
        Bounds:=OverlayBounds(CurrentPanel,CurrentPanel.Overlays[0]);
        Check((CurrentPanel.Bounds=OriginalBounds) and (Abs(Bounds.Width/Bounds.Height-OriginalBounds.Width/OriginalBounds.Height)<0.0001),
          'effect material handle '+IntToStr(K)+' keeps aspect ratio and owner geometry');
        Project.Save; Reloaded:=TComicProject.Create;
        try Reloaded.Load(TPath.Combine(Project.Folder,'Project.json')); Check(Reloaded.Snapshot=Project.Snapshot,'effect handle saves and reloads '+IntToStr(K)); finally Reloaded.Free; end;
        Probe.Undo(nil); Check(Project.Snapshot=Before,'effect handle undo restores exact placement '+IntToStr(K));
      end;
      Probe.FPanelIndex:=0; Probe.FEffectIndex:=0; Bounds:=OverlayBounds(CurrentPanel,CurrentPanel.Overlays[0]); PointA:=Bounds.CenterPoint;
      X:=Probe.FPageRect.Left+Round(PointA.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(PointA.Y*Probe.FScale); Before:=Project.Snapshot; History:=Probe.FUndo.Count;
      Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y); Probe.MouseMove(Probe.FCanvas,[ssLeft],X+20,Y+15); KeyValue:=VK_ESCAPE; Probe.Key(Probe,KeyValue,[]);
      Check((Project.Snapshot=Before) and (Probe.FUndo.Count=History),'escape restores a pending material movement without history');
      Probe.FPanelIndex:=0; Probe.FEffectIndex:=0; Probe.ApplyEffectMaterial(0,MaterialLibrary[2]);
      Check(CurrentPanel.Overlays.Count=2,'panel supports multiple independently placed materials');
      Before:=Project.Snapshot; Probe.DeleteEffect(nil); Check(CurrentPanel.Overlays.Count=1,'material deletion affects only selected overlay'); Probe.Undo(nil); Check(Project.Snapshot=Before,'material deletion undo restores its identity and file');
      for Kind:=1 to 4 do begin
        Probe.FEffectCategory.ItemIndex:=1; Probe.EffectCategoryChanged(nil); Probe.FPanelIndex:=0; Probe.LoadPanelEffectControls;
        Probe.FFilterKind.ItemIndex:=Kind; Probe.FFilterStrength.ItemIndex:=3; Before:=Project.Snapshot; Probe.ApplyFilter(nil);
        Check(CurrentPanel.FilterKind=Kind,'filter type '+IntToStr(Kind)+' applies without an overlay geometry');
        History:=Probe.FUndo.Count; Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y); Probe.MouseMove(Probe.FCanvas,[ssLeft],X+10,Y+10);
        Check(not Probe.FDragging and (Probe.FUndo.Count=History),'filter selection has no drag or eight-point geometry '+IntToStr(Kind));
        Probe.Undo(nil); Check(Project.Snapshot=Before,'filter undo restores the previous state '+IntToStr(Kind));
      end;
      Pixels.SetSize(31,31); Pixels.Canvas.Brush.Color:=clWhite; Pixels.Canvas.FillRect(Rect(0,0,31,31)); Pixels.Canvas.Pixels[15,15]:=clBlack;
      ApplyComicFilter(Pixels,3,100); Check((Pixels.Canvas.Pixels[15,15]<>clBlack) and (Pixels.Canvas.Pixels[16,15]<>clWhite) and
        (Pixels.Canvas.Pixels[0,0]=clWhite),'blur spreads a local impulse and retains remote white pixels');
      Pixels.SetSize(1,1); Pixels.Canvas.Pixels[0,0]:=RGB(100,120,140); ApplyComicFilter(Pixels,2,100);
      Check(Pixels.Canvas.Pixels[0,0]=TColor(RGB(116,116,116)),'grayscale uses deterministic weighted luminance');
      Failed:=False; try ApplyComicFilter(Pixels,99,0); except Failed:=True; end; Check(Failed,'invalid filter kind is rejected even at zero strength');
      Probe.FEffectCategory.ItemIndex:=2; Probe.EffectCategoryChanged(nil); Probe.FPanelIndex:=0; Probe.LoadPanelEffectControls;
      Probe.FFrameKind.ItemIndex:=1; Probe.FPanelBorderColor:=clNavy; Before:=Project.Snapshot; Probe.ApplyFrame(nil);
      Check((CurrentPanel.FrameKind=1) and (CurrentPanel.BorderColor=clNavy),'frame appearance stores decoration and colour');
      Probe.Undo(nil); Check(Project.Snapshot=Before,'frame appearance undo restores its original border');
      Reference.SetSize(240,340); Shifted.SetSize(360,430);
      for Shape:=0 to 3 do for Frame:=0 to 2 do begin
        Panel:=CurrentPanel; Panel.Shape:=Shape;
        if Shape=3 then Panel.SetVertices([TPointF.Create(100,100),TPointF.Create(900,100),TPointF.Create(700,1300),TPointF.Create(100,1100)]);
        Panel.FrameKind:=Frame; Panel.FilterKind:=1+(Shape mod 4); Panel.FilterStrength:=75;
        Probe.FRenderer.Draw(Reference.Canvas,Project,Probe.Page,Rect(0,0,240,340),False); Saved:=SaveDC(Shifted.Canvas.Handle);
        try SetViewportOrgEx(Shifted.Canvas.Handle,75,50,nil); Probe.FRenderer.Draw(Shifted.Canvas,Project,Probe.Page,Rect(0,0,240,340),False);
        finally RestoreDC(Shifted.Canvas.Handle,Saved); Shifted.Canvas.Refresh; end;
        Same:=True; for X:=0 to 239 do for Y:=0 to 339 do if Reference.Canvas.Pixels[X,Y]<>Shifted.Canvas.Pixels[X+75,Y+50] then Same:=False;
        Check(Same,'filtered panel alpha materials and frame match translated DC '+IntToStr(Shape)+' '+IntToStr(Frame));
      end;
      Panel:=CurrentPanel; Panel.Shape:=0; Panel.SetBounds(OriginalBounds); Panel.FrameKind:=1; Panel.FilterKind:=1;
      Bounds:=OverlayBounds(Panel,Panel.Overlays[0]); Before:=Project.Snapshot;
      Probe.FSplitA:=TPointF.Create(500,100); Probe.FSplitB:=TPointF.Create(500,1300);
      Probe.FSplitC:=TPointF.Create(520,100); Probe.FSplitD:=TPointF.Create(520,1300); Probe.CommitSplit(0);
      Check((Probe.Page.Panels.Count=2) and (OverlayBounds(Probe.Page.Panels[0],Probe.Page.Panels[0].Overlays[0])=Bounds) and
        (OverlayBounds(Probe.Page.Panels[1],Probe.Page.Panels[1].Overlays[0])=Bounds), 'panel split preserves the global material position in both clipped fragments');
      Check((Probe.Page.Panels[0].Overlays[0].ID<>Probe.Page.Panels[1].Overlays[0].ID) and
        (Probe.Page.Panels[0].FilterKind=1) and (Probe.Page.Panels[1].FrameKind=1), 'panel split assigns new second-fragment effect identity and retains filter frame settings');
      Probe.Undo(nil); Check(Project.Snapshot=Before,'split undo restores the complete material and style owner');
      Layout.Capture(Project,Probe.Page); Layout.Apply(Project.Pages[0],Project.Width,Project.Height);
      Check((CurrentPanel.Overlays.Count=0) and (CurrentPanel.FilterKind=0) and (CurrentPanel.FrameKind=0),'common layout templates exclude materials filters and frame decoration');
      Project.Restore(After); Probe.FPanelIndex:=0; Probe.FEffectIndex:=0; Probe.RefreshUI;
      DeleteEffectMaterial(MaterialLibrary,Material,Path); Probe.RefreshEffectMaterials; Probe.FRenderer.ClearCache;
      Check((FindEffectMaterial(MaterialLibrary,ID)=nil) and FileExists(CopyPath),'common material deletion preserves the project-local applied PNG');
      Check(ExportSequence(Project,Probe.FRenderer,False)=1,'effect fixture exports with its applied material snapshot');
      Check(ExportSequence(Project,Probe.FRenderer,False)=0,'unchanged material snapshot reuses cached page PNG');
      PNG.LoadFromFile(CopyPath); PNG.Canvas.Pixels[0,0]:=clGreen; PNG.SaveToFile(CopyPath);
      Check(ExportSequence(Project,Probe.FRenderer,False)=1,'same-path effect PNG byte changes invalidate the page cache');
      Before:=Project.Snapshot; Project.Save; Reloaded:=TComicProject.Create;
      try Reloaded.Load(TPath.Combine(Project.Folder,'Project.json')); Check(Reloaded.Snapshot=Before,'complete material ownership and style data save and reload'); finally Reloaded.Free; end;
      // Undo deliberately resets output status. Compare DPI editing against that same status.
      Project.Pages[0].OutputRevision:=-1;
      Manager:=TComicEffectDialog.CreateManager(Self,CopyLibrary,True,Path);
      for PPI in [96,144] do begin
        Probe.Scaled:=True; Probe.ScaleForPPI(PPI); Probe.Scaled:=False; Probe.Width:=MulDiv(940,PPI,96); Probe.Height:=MulDiv(660,PPI,96); Probe.Realign;
        Probe.FEffectCategory.ItemIndex:=0; Probe.EffectCategoryChanged(nil); Probe.FPanelIndex:=0; Probe.FEffectIndex:=0;
        CaptureEffect('effects-material-'+IntToStr(PPI));
        Before:=Project.Snapshot; History:=Probe.FUndo.Count; Bounds:=OverlayBounds(CurrentPanel,CurrentPanel.Overlays[0]); PointA:=Bounds.CenterPoint;
        X:=Probe.FPageRect.Left+Round(PointA.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(PointA.Y*Probe.FScale);
        Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y); Probe.MouseMove(Probe.FCanvas,[ssLeft],X+MulDiv(12,PPI,96),Y+MulDiv(15,PPI,96));
        Probe.MouseUp(Probe.FCanvas,mbLeft,[],X+MulDiv(12,PPI,96),Y+MulDiv(15,PPI,96));
        Check((Probe.FUndo.Count=History+1) and (CurrentPanel.Bounds=OriginalBounds),'effect movement commits one operation at PPI '+IntToStr(PPI));
        Probe.Undo(nil); Check(Project.Snapshot=Before,'effect DPI movement undo '+IntToStr(PPI));
        for K:=1 to 8 do begin
          Probe.FPanelIndex:=0; Probe.FEffectIndex:=0; Bounds:=OverlayBounds(CurrentPanel,CurrentPanel.Overlays[0]); PointA:=EditHandles(Bounds)[K-1];
          X:=Probe.FPageRect.Left+Round(PointA.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(PointA.Y*Probe.FScale);
          Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y); Check(Probe.FDragHandle=K,'effect DPI handle '+IntToStr(K)+' '+IntToStr(PPI));
          Probe.MouseMove(Probe.FCanvas,[ssLeft],X+MulDiv(10,PPI,96),Y+MulDiv(8,PPI,96)); KeyValue:=VK_ESCAPE; Probe.Key(Probe,KeyValue,[]);
          Check(Project.Snapshot=Before,'effect DPI handle cancel '+IntToStr(K)+' '+IntToStr(PPI));
        end;
        Manager.Scaled:=True; Manager.ScaleForPPI(PPI); Manager.Scaled:=False; Manager.ClientWidth:=MulDiv(880,PPI,96); Manager.ClientHeight:=MulDiv(620,PPI,96); Manager.Realign;
        Manager.HandleNeeded; B.SetSize(Manager.ClientWidth,Manager.ClientHeight); Manager.PaintTo(B.Canvas,0,0); PNG.Assign(B); PNG.SaveToFile(TPath.Combine(Folder,'effect-library-'+IntToStr(PPI)+'.png'));
        for I:=0 to Manager.ComponentCount-1 do if Manager.Components[I] is TButton then with TButton(Manager.Components[I]) do
          Check((Left>=0) and (Top>=0) and (Left+Width<=Parent.ClientWidth) and (Top+Height<=Parent.ClientHeight),'material manager action is reachable '+Caption+' '+IntToStr(PPI));
      end;
      Check(ExportSequence(Project,Probe.FRenderer,False)=0,'effect DPI undo reuses the unchanged rendered page despite pending output status');
      Check(FProject.Snapshot=Original,'effect fixtures preserve the active project');
    finally Manager.Free; Layout.Free; Broken.Free; CopyLibrary.Free; MaterialLibrary.Free; Pixels.Free; Shifted.Free; Reference.Free; PNG.Free; Probe.Free; end;
  end;
  procedure SceneGenerationChecks;
  var Probe: TMainForm; Project,Reloaded: TComicProject; Parent,Child,Alternate,TitleAsset: TComicAsset;
    Manager: TAssetDialog; Selector: TComicCharacterRefDialog; PNG: TPngImage; Request,Response,Data: TJSONObject; JsonRefs: TJSONArray;
    Before,After,Original,ParentID,ChildID,CharacterID,ReplyText: string; IDs: TArray<string>; History,PPI,I: Integer; CanClose: Boolean;
    procedure Command;
    begin
      Probe.BridgeRequest(Request.ToJSON,ReplyText); FreeAndNil(Request); FreeAndNil(Response);
      Response:=TJSONObject.ParseJSONValue(ReplyText) as TJSONObject;
    end;
    procedure CreateRequest(const Action: string);
    begin Request:=TJSONObject.Create; Request.AddPair('version',TJSONNumber.Create(1)); Request.AddPair('action',Action);
      Request.AddPair('library','images'); Request.AddPair('projectId',Project.ID); end;
  begin
    Original:=FProject.Snapshot; Probe:=TMainForm.Create(nil); PNG:=TPngImage.Create; Manager:=nil; Selector:=nil; Request:=nil; Response:=nil;
    try
      Project:=TComicProject.Create; Project.Initialize('場面とタイトル fixture','第2話'); Probe.AdoptProject(Project,False);
      Parent:=Project.ImportImage(TPath.Combine(Folder,'reference.bmp'),''); ParentID:=Parent.ID;
      CharacterID:=Probe.FCharacters[0].ID; Before:=Project.Snapshot; History:=Probe.FUndo.Count;
      Manager:=TAssetDialog.CreateManager(Probe,Project.Assets,Project,False,True,Probe.GenerationPresets,Probe.FCharacters); Probe.FAssetManager:=Manager;
      Manager.SelectAsset(ParentID); Manager.ApplyReferences([CharacterID]);
      Check(Length(Parent.CharacterRefs)=0,'background root cannot receive character references through its manager');
      Child:=NewSceneAsset(Project.Assets,Parent,'child','本文の子','追加指示',Project.Title,Project.Episode); Project.Assets.Add(Child); ChildID:=Child.ID;
      Manager.RefreshFromExternal; Manager.SelectAsset(ChildID); Manager.ApplyReferences([CharacterID]);
      Check((Child.ParentID=ParentID) and (Child.SourceID=ParentID) and (Child.SceneID=ParentID) and (Length(Child.CharacterRefs)=1),
        'scene child retains background source scene relation and selected character identity');
      Selector:=TComicCharacterRefDialog.CreateSelector(Manager,Probe.FCharacters,Child.CharacterRefs); Selector.SetChecked(CharacterID,False);
      Selector.ModalResult:=mrCancel; Check((Length(Child.CharacterRefs)=1) and (Selector.SelectedIDs[0]=CharacterID),
        'cancelling reference selection retains its existing draft and asset'); FreeAndNil(Selector);
      Selector:=TComicCharacterRefDialog.CreateSelector(Manager,Probe.FCharacters,[CharacterID,'missing-reference']);
      Selector.AcceptSelection; IDs:=Selector.SelectedIDs;
      Check((Length(IDs)=2) and (IDs[1]='missing-reference'),'unresolved existing reference is retained until explicitly unchecked'); FreeAndNil(Selector);
      Selector:=TComicCharacterRefDialog.CreateSelector(Manager,Probe.FCharacters,Child.CharacterRefs); Selector.SetChecked(CharacterID,False); Selector.AcceptSelection;
      Manager.ApplyReferences(Selector.SelectedIDs); Check(Length(Child.CharacterRefs)=0,'scene child supports generation with zero characters'); FreeAndNil(Selector);
      Manager.ApplyReferences([CharacterID]); Manager.AddSceneVariant('alternate_scene'); Alternate:=Manager.CurrentAsset;
      Check((Alternate.ParentID='') and (Alternate.SourceID=ParentID) and (Alternate.SceneID=ParentID) and (Length(Alternate.CharacterRefs)=0),
        'alternate background becomes a sibling root retaining its source and scene relation');
      Manager.SelectAsset(ChildID); Manager.AddSceneVariant('title'); TitleAsset:=Manager.CurrentAsset;
      Check((TitleAsset.ParentID=ParentID) and (TitleAsset.SourceID=ChildID) and TitleAsset.TitleImage and
        (TitleAsset.TitleText=Project.Title) and (TitleAsset.EpisodeText=Project.Episode) and (TitleAsset.CharacterRefs[0]=CharacterID),
        'title derivative remains at the second level and snapshots title episode and character references');
      Probe.ApplyGenerationPreset('manager-preset','管理から適用','共通本文'); Check(Probe.FUndo.Count=History,'generation apply inside image management defers its project history');
      CreateRequest('register_image'); Request.AddPair('assetId',TitleAsset.ID); Request.AddPair('sourcePath',TPath.Combine(Folder,'reference.bmp')); Command;
      Check((JStr(Response,'ok','')='true') and (Probe.FUndo.Count=History),'pipe adoption during image management shares its pending undo operation');
      CreateRequest('read_asset'); Request.AddPair('assetId',TitleAsset.ID); Command; Data:=Response.GetValue<TJSONObject>('data');
      Check((JStr(Response,'ok','')='true') and (JStr(Data.GetValue<TJSONObject>('source'),'id','')=ChildID) and
        (Data.GetValue<TJSONArray>('references').Count=1) and
        (JStr(Data.GetValue<TJSONArray>('references').Items[0] as TJSONObject,'id','')=CharacterID),
        'title generation query returns its actual child source and only selected character data');
      CreateRequest('create_asset'); Request.AddPair('name','パイプ別位置'); Request.AddPair('mode','alternate_scene'); Request.AddPair('sourceId',ParentID); Command;
      Check((JStr(Response,'ok','')='true') and (JStr(Response.GetValue<TJSONObject>('data').GetValue<TJSONObject>('asset'),'parentId','')=''),
        'pipe creates alternate backgrounds at root level');
      CreateRequest('create_asset'); Request.AddPair('name','パイプタイトル'); Request.AddPair('mode','title'); Request.AddPair('sourceId',ChildID); Command;
      Check((JStr(Response,'ok','')='true') and (JStr(Response.GetValue<TJSONObject>('data').GetValue<TJSONObject>('asset'),'sourceId','')=ChildID),
        'pipe creates title derivatives from second-level source images');
      After:=Project.Snapshot;
      CreateRequest('create_asset'); Request.AddPair('name','不正な人物参照'); Request.AddPair('parentId',ParentID);
      JsonRefs:=TJSONArray.Create; JsonRefs.Add('unknown-person'); Request.AddPair('characterIds',JsonRefs); Command;
      Check((JStr(Response,'ok','')='false') and (Project.Snapshot=After),'unknown explicit character reference rejects creation before any mutation');
      CreateRequest('create_asset'); Request.AddPair('name','親の人物参照'); JsonRefs:=TJSONArray.Create; JsonRefs.Add(CharacterID); Request.AddPair('characterIds',JsonRefs); Command;
      Check((JStr(Response,'ok','')='false') and (Project.Snapshot=After),'background parent generation excludes character references');
      for PPI in [96,144] do begin
        Selector:=TComicCharacterRefDialog.CreateSelector(Manager,Probe.FCharacters,Child.CharacterRefs);
        try
          Selector.Scaled:=True; Selector.ScaleForPPI(PPI); Selector.Scaled:=False; Selector.ClientWidth:=MulDiv(600,PPI,96); Selector.ClientHeight:=MulDiv(500,PPI,96); Selector.Realign;
          Selector.HandleNeeded; B.SetSize(Selector.ClientWidth,Selector.ClientHeight); Selector.PaintTo(B.Canvas,0,0); PNG.Assign(B);
          PNG.SaveToFile(TPath.Combine(Folder,'character-references-'+IntToStr(PPI)+'.png'));
          for I:=0 to Selector.ComponentCount-1 do if Selector.Components[I] is TButton then with TButton(Selector.Components[I]) do
            Check((Left>=0) and (Top>=0) and (Left+Width<=Parent.ClientWidth) and (Top+Height<=Parent.ClientHeight),
              'reference selector button remains reachable '+Caption+' '+IntToStr(PPI));
        finally FreeAndNil(Selector); end;
        Manager.Scaled:=True; Manager.ScaleForPPI(PPI); Manager.Scaled:=False; Manager.ClientWidth:=MulDiv(940,PPI,96); Manager.ClientHeight:=MulDiv(660,PPI,96); Manager.Realign;
        B.SetSize(Manager.ClientWidth,Manager.ClientHeight); Manager.PaintTo(B.Canvas,0,0); PNG.Assign(B);
        PNG.SaveToFile(TPath.Combine(Folder,'scene-generation-'+IntToStr(PPI)+'.png'));
      end;
      CanClose:=True; Manager.OnCloseQuery(Manager,CanClose); Probe.FAssetManager:=nil; FreeAndNil(Manager); Probe.FinishImageManagement(Before);
      After:=Project.Snapshot; Check(Probe.FUndo.Count=History+1,'image manager changes pipe adoption and generation snapshot commit as one undo');
      Project.Save; Reloaded:=TComicProject.Create;
      try Reloaded.Load(TPath.Combine(Project.Folder,'Project.json')); Check(Reloaded.Snapshot=After,'scene sources title metadata selected references and generation conditions save and reload');
      finally Reloaded.Free; end;
      Probe.Undo(nil); Check(Project.Snapshot=Before,'image manager undo removes all newly added derivations and conditions');
      Probe.Redo(nil); Check(Project.Snapshot=After,'image manager redo restores every relation and retained adopted image');
      Check(FProject.Snapshot=Original,'scene generation fixtures preserve the active project');
    finally Probe.FAssetManager:=nil; Response.Free; Request.Free; Selector.Free; Manager.Free; PNG.Free; Probe.Free; end;
  end;
  procedure CharacterGroupChecks;
  var Items,Reloaded,Broken: TObjectList<TComicAsset>; A,A1,A2,BRoot,B1: TComicAsset; Manager: TAssetDialog;
    AID,A1ID,A2ID,BID,GroupID,Before,Path,LibraryPath,LibraryBytes,Original: string; State: TArray<TComicAssetState>;
    Node: TTreeNode; PNG: TPngImage; Lock: THandle; Failed,CanClose: Boolean; PPI,I: Integer; Json: TJSONObject;
    function ListJson(List: TObjectList<TComicAsset>): string;
    var Json: TJSONArray; Item: TComicAsset;
    begin Json:=TJSONArray.Create; try for Item in List do Json.AddElement(Item.Json); Result:=Json.ToJSON; finally Json.Free; end; end;
    function Add(const Name,ParentID: string): TComicAsset;
    begin Result:=TComicAsset.Create; Result.Name:=Name; Result.ParentID:=ParentID; Result.Notes:='状態の補足 '+Name;
      Result.FileName:='reference.bmp'; Items.Add(Result); end;
    procedure Drag(const MovingID,TargetID: string; Expected: Boolean);
    var DragObject: TDragObject; Target,Node: TTreeNode; R: TRect; Accept: Boolean;
    begin
      Manager.SelectAsset(MovingID); Manager.HandleNeeded; Target:=nil;
      for Node in Manager.AssetTree.Items do if (Node.Data<>nil) and (TComicAsset(Node.Data).ID=TargetID) then Target:=Node;
      if Target=nil then raise Exception.Create('Character drag target missing.');
      DragObject:=nil; Manager.AssetTree.OnStartDrag(Manager.AssetTree,DragObject); Target.MakeVisible; R:=Target.DisplayRect(True);
      Manager.AssetTree.OnDragOver(Manager.AssetTree,Manager.AssetTree,R.CenterPoint.X,R.CenterPoint.Y,dsDragMove,Accept);
      Check(Accept=Expected,'character tree drag permission '+MovingID+' to '+TargetID);
      if Accept then Manager.AssetTree.OnDragDrop(Manager.AssetTree,Manager.AssetTree,R.CenterPoint.X,R.CenterPoint.Y);
      Manager.AssetTree.OnEndDrag(Manager.AssetTree,Manager.AssetTree,R.CenterPoint.X,R.CenterPoint.Y);
    end;
  begin
    Original:=FProject.Snapshot; LibraryPath:=TPath.Combine(DataRoot,'Characters\Library.json'); LibraryBytes:=TFile.ReadAllText(LibraryPath,TEncoding.UTF8);
    Items:=TObjectList<TComicAsset>.Create; Reloaded:=TObjectList<TComicAsset>.Create; Broken:=TObjectList<TComicAsset>.Create; Manager:=nil; PNG:=TPngImage.Create;
    try
      A:=Add('人物A',''); AID:=A.ID; A1:=Add('冬服',AID); A1ID:=A1.ID; A2:=Add('夏服',AID); A2ID:=A2.ID;
      BRoot:=Add('人物B',''); BID:=BRoot.ID; B1:=Add('外出着',BID); NormalizeCharacters(Items); GroupID:=A.CharacterID;
      Check((GroupID=AID) and (A1.CharacterID=GroupID) and (A2.CharacterID=GroupID) and (A.StateName='基本服装'),
        'legacy character names initialize stable shared identity and state names');
      SetCharacterInfo(Items,A1,'人物Aの共通名','共通の外見補足');
      Check((A.Name='人物Aの共通名') and (A2.CharacterName=A.Name) and (A2.CharacterNotes='共通の外見補足') and (A1.Name='冬服'),
        'editing common character information from a child preserves individual state names');
      A.CharacterNotes:=''; NormalizeCharacters(Items); Check(A.CharacterNotes='','normalization preserves an intentionally empty common supplement');
      State:=CaptureAssets(Items); Before:=ListJson(Items);
      Check(PromoteCharacter(Items,A1),'character child promotes to the base reference');
      Check((A1.ParentID='') and (A1.Name='人物Aの共通名') and (A1.StateName='冬服') and (A1.CharacterID=GroupID) and
        (A.ParentID=A1ID) and (A.Name='基本服装') and (A2.ParentID=A1ID) and (A.ID=AID) and (A2.ID=A2ID),
        'promotion swaps parent role while preserving character and every variant identity');
      Check((A.FileName='reference.bmp') and (A1.FileName='reference.bmp') and (BRoot.ParentID='') and (B1.ParentID=BID),
        'promotion retains image references and unrelated groups');
      Path:=TPath.Combine(Folder,'character-groups.json'); WriteAssets(Items,Path); ReadAssets(Reloaded,Path); NormalizeCharacters(Reloaded);
      Check(ListJson(Reloaded)=ListJson(Items),'promoted character group saves and reloads stable metadata order and hierarchy');
      RestoreAssets(Items,State); Check(ListJson(Items)=Before,'asset state restore keeps original object pointers and exact order');
      Check(not ReorderCharacter(Items,A1,B1) and (ListJson(Items)=Before),'character child cannot move to another person');
      Check(ReorderCharacter(Items,BRoot,A) and (Items[0]=BRoot) and (Items[1]=B1),'moving a parent carries its full group together');
      Check(ReorderCharacter(Items,A2,A1) and (Items.IndexOf(A2)<Items.IndexOf(A1)) and (A2.ParentID=AID),'child reordering remains inside the same person');
      RestoreAssets(Items,State); Manager:=TAssetDialog.CreateManager(Self,Items,nil,True); Manager.SelectAsset(A1ID);
      Manager.CommonName.Text:='画面から変更した人物'; Manager.CommonNotes.Text:='共通情報を保持'; Manager.DraftName.Text:='冬の制服'; Manager.FlushDraft;
      Check((A.Name='画面から変更した人物') and (A2.CharacterNotes='共通情報を保持') and (A1.Name='冬の制服'),
        'character manager stores common and state edits independently');
      Manager.PromoteSelected; Check((Manager.CurrentAsset=A1) and (A1.ParentID='') and (A.ParentID=A1ID) and (A1.CharacterID=GroupID),
        'promotion from the actual management command preserves selected reference and shared identity');
      for Node in Manager.AssetTree.Items do if Node.Data=Pointer(A1) then Node.Expand(False);
      Drag(A1ID,BID,True);
      Check((Items[0]=A1) and (Items[1]=A) and (Items[2]=A2),'tree parent drag moves its reference and all children as a block');
      for Node in Manager.AssetTree.Items do if Node.Data=Pointer(A1) then Check(Node.Expanded,'parent drag restores its previous expanded state');
      Drag(A2ID,AID,True); Check(Items.IndexOf(A2)<Items.IndexOf(A),'tree child drag changes same-parent order');
      Before:=ListJson(Items); Drag(A2ID,B1.ID,False); Check(ListJson(Items)=Before,'rejected cross-person tree drag preserves all assets');
      Lock:=CreateFile(PChar(LibraryPath),GENERIC_READ,FILE_SHARE_READ,nil,OPEN_EXISTING,0,0);
      Check(Lock<>INVALID_HANDLE_VALUE,'character group library locks for rollback regression');
      try
        Manager.SelectAsset(AID); Before:=ListJson(Items); Failed:=False; try Manager.PromoteSelected; except Failed:=True; end;
        Check(Failed and (ListJson(Items)=Before) and (Manager.CurrentAsset=A),'failed promotion restores the exact hierarchy metadata and object selection');
        Failed:=False; try Manager.MoveAsset(BID,A1ID); except Failed:=True; end;
        Check(Failed and (ListJson(Items)=Before),'failed group reorder restores all object positions');
      finally CloseHandle(Lock); end;
      for PPI in [96,144] do begin
        Manager.Scaled:=True; Manager.ScaleForPPI(PPI); Manager.Scaled:=False; Manager.ClientWidth:=MulDiv(940,PPI,96); Manager.ClientHeight:=MulDiv(660,PPI,96); Manager.Realign;
        B.SetSize(Manager.ClientWidth,Manager.ClientHeight); Manager.PaintTo(B.Canvas,0,0); PNG.Assign(B);
        PNG.SaveToFile(TPath.Combine(Folder,'character-groups-'+IntToStr(PPI)+'.png'));
        Check((Manager.CommonName.Left>=0) and (Manager.CommonName.Top>=0) and
          (Manager.CommonName.Top+Manager.CommonName.Height<=Manager.CommonName.Parent.ClientHeight) and
          (Manager.CommonNotes.Height>0),'character shared fields remain reachable at PPI '+IntToStr(PPI));
        for I:=0 to Manager.ComponentCount-1 do if Manager.Components[I] is TButton then with TButton(Manager.Components[I]) do
          Check((Left>=0) and (Top>=0) and (Left+Width<=Parent.ClientWidth) and (Top+Height<=Parent.ClientHeight),
            'character group action remains reachable '+Caption+' '+IntToStr(PPI));
      end;
      CanClose:=True; Manager.OnCloseQuery(Manager,CanClose); Reloaded.Clear; ReadAssets(Reloaded,LibraryPath); NormalizeCharacters(Reloaded);
      Check(ListJson(Reloaded)=ListJson(Items),'character UI promotion order and shared edits survive close save and reload');
      Manager.Free; Manager:=TAssetDialog.CreateManager(Self,Items,nil,True,False); Manager.SelectAsset(AID); Before:=ListJson(Items);
      Manager.PromoteSelected; Manager.MoveAsset(BID,A1ID); Check(ListJson(Items)=Before,'protected character manager rejects promotion and reorder');
      Json:=A1.Json; try AtomicWrite(Path,'['+Json.ToJSON+','+Json.ToJSON+']'); finally Json.Free; end;
      Failed:=False; try ReadAssets(Broken,Path); except Failed:=True; end;
      Check(Failed and (Broken.Count=0),'duplicate character IDs cannot publish an ambiguous prefix');
      Check(FProject.Snapshot=Original,'character group fixtures preserve the active project');
    finally Manager.Free; PNG.Free; Broken.Free; Reloaded.Free; Items.Free; AtomicWrite(LibraryPath,LibraryBytes); end;
  end;
  procedure BridgeChecks;
  var Probe: TMainForm; Bridge: TComicBridge; Project,Reloaded: TComicProject; Manager: TAssetDialog;
    Request,Reply,Data,AssetDataValue: TJSONObject; Pair: TJSONPair; Asset,Other: TComicAsset;
    UID,ChildID,ImageID,OldFile,NewFile,LibraryPath,LibraryBytes,Manifest,Before,After,Original: string;
    Client: TThread; Completed,Lock,Pipe: THandle; Deadline,Started: UInt64; ReplyText,ErrorText: string;
    Failed: Boolean; History,FileCount: Integer; PNG: TPngImage; CorruptPath,AdoptedID: string; ImageBytes: TBytes;
    function Send(const Text: string): TJSONObject;
    begin
      ReplyText:=''; ErrorText:=''; Completed:=CreateEvent(nil,True,False,nil); if Completed=0 then RaiseLastOSError;
      Client:=TThread.CreateAnonymousThread(procedure
        begin
          try ReplyText:=ComicBridgeRequest(Bridge.PipeName,Text,3000);
          except on E: Exception do ErrorText:=E.Message; end;
          SetEvent(Completed);
        end);
      Client.FreeOnTerminate:=False;
      try
        Client.Start; Deadline:=GetTickCount64+5000;
        while (WaitForSingleObject(Completed,10)=WAIT_TIMEOUT) and (GetTickCount64<Deadline) do CheckSynchronize(0);
        Client.WaitFor;
        if ErrorText<>'' then raise Exception.Create('Bridge client: '+ErrorText);
        Result:=TJSONObject.ParseJSONValue(ReplyText) as TJSONObject;
        if Result=nil then raise Exception.Create('Bridge response is not JSON.');
      finally Client.Free; CloseHandle(Completed); end;
    end;
    function NewRequest(const Action,LibraryName: string): TJSONObject;
    begin
      Result:=TJSONObject.Create; Result.AddPair('version',TJSONNumber.Create(1)); Result.AddPair('action',Action);
      if LibraryName<>'' then Result.AddPair('library',LibraryName);
      if LibraryName='images' then Result.AddPair('projectId',Project.ID);
    end;
    procedure Run;
    begin FreeAndNil(Reply); Reply:=Send(Request.ToJSON); FreeAndNil(Request); end;
    procedure Good(const Message: string);
    begin Check(JStr(Reply,'ok','')='true',Message+' '+JStr(Reply,'error','')); end;
    procedure Bad(const Message: string);
    begin Check((JStr(Reply,'ok','')='false') and (JStr(Reply,'error','')<>''),Message); end;
    procedure ExternalClient;
    var Script,ResultFile,Command,ShellPath: string; Startup: TStartupInfo; Process: TProcessInformation; Code: DWORD; ResultJson: TJSONObject;
      function PSQuote(const Value: string): string;
      begin Result:=''''+StringReplace(Value,'''','''''',[rfReplaceAll])+''''; end;
    begin
      Script:=TPath.Combine(Folder,'bridge-client-test.ps1'); ResultFile:=TPath.Combine(Folder,'bridge-client-result.json');
      AtomicWrite(Script,'$ErrorActionPreference = ''Stop'''+#13#10+
        '$result = & '+PSQuote(TPath.GetFullPath('Tools\MangaMakerBridge.ps1'))+' -ManifestPath '+PSQuote(Bridge.ManifestPath)+' -TimeoutMS 3000'+#13#10+
        '[IO.File]::WriteAllText('+PSQuote(ResultFile)+', ($result | ConvertTo-Json -Depth 64), [Text.UTF8Encoding]::new($false))');
      ShellPath:=TPath.Combine(GetEnvironmentVariable('SystemRoot'),'System32\WindowsPowerShell\v1.0\powershell.exe');
      Command:='"'+ShellPath+'" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+Script+'"';
      Startup:=Default(TStartupInfo); Startup.cb:=SizeOf(Startup); Startup.dwFlags:=STARTF_USESHOWWINDOW; Startup.wShowWindow:=SW_HIDE;
      Process:=Default(TProcessInformation);
      if not CreateProcess(nil,PChar(Command),nil,nil,False,CREATE_NO_WINDOW,nil,PChar(Folder),Startup,Process) then RaiseLastOSError;
      try
        Deadline:=GetTickCount64+12000;
        while (WaitForSingleObject(Process.hProcess,10)=WAIT_TIMEOUT) and (GetTickCount64<Deadline) do CheckSynchronize(0);
        GetExitCodeProcess(Process.hProcess,Code); Check((Code=0) and FileExists(ResultFile),'PowerShell helper reaches live pipe from a separate process');
      finally CloseHandle(Process.hThread); CloseHandle(Process.hProcess); end;
      ResultJson:=TJSONObject.ParseJSONValue(TFile.ReadAllText(ResultFile,TEncoding.UTF8)) as TJSONObject;
      try Check((JStr(ResultJson,'ok','')='true') and
        (JStr(ResultJson.GetValue<TJSONObject>('data').GetValue<TJSONObject>('project'),'generationInstructions','')=Project.GenerationInstructions),
        'separate PowerShell client preserves multiline Japanese generation instructions');
      finally ResultJson.Free; end;
    end;
  begin
    Original:=FProject.Snapshot; LibraryPath:=TPath.Combine(DataRoot,'Characters\Library.json'); LibraryBytes:=TFile.ReadAllText(LibraryPath,TEncoding.UTF8);
    Probe:=TMainForm.Create(nil); Bridge:=nil; Request:=nil; Reply:=nil; Manager:=nil; PNG:=TPngImage.Create;
    try
      Project:=TComicProject.Create; Project.Initialize('パイプ fixture','1'); Project.GenerationInstructions:='作品の指示'+#13#10+'第2行'; Probe.AdoptProject(Project,False);
      Bridge:=TComicBridge.Create(TPath.Combine(Folder,'Runtime'),Probe.BridgeRequest); Manifest:=Bridge.ManifestPath;
      Check(FileExists(Manifest) and (Pos(Bridge.PipeName,TFile.ReadAllText(Manifest,TEncoding.UTF8))>0),'local pipe publishes a unique process manifest');
      Request:=NewRequest('status',''); Request.AddPair('requestId','照会-1'); Run; Good('live pipe answers UTF-8 status');
      Data:=Reply.GetValue<TJSONObject>('data'); AssetDataValue:=Data.GetValue<TJSONObject>('project');
      Check((JStr(Reply,'requestId','')='照会-1') and (JStr(AssetDataValue,'id','')=Project.ID) and
        (JStr(AssetDataValue,'generationInstructions','')=Project.GenerationInstructions),'status carries project identity and generation snapshot');
      Probe.HandleNeeded; Before:=TFile.ReadAllText(LibraryPath,TEncoding.UTF8); FileCount:=Probe.FCharacters.Count;
      EnableWindow(Probe.Handle,False);
      try
        Request:=NewRequest('status',''); Run; Good('native disabled main window still allows bridge status');
        Request:=NewRequest('create_asset','characters'); Request.AddPair('name','native modal blocked'); Run;
        Bad('native common dialog owner blocks bridge mutation before publication');
        Check((Probe.FCharacters.Count=FileCount) and (TFile.ReadAllText(LibraryPath,TEncoding.UTF8)=Before),
          'native modal write rejection preserves character list and library bytes');
      finally EnableWindow(Probe.Handle,True); end;
      Request:=NewRequest('create_asset','characters'); Request.AddPair('name','パイプ人物'); Request.AddPair('notes','親の外見補足'); Run; Good('pipe creates a named character without an image');
      UID:=JStr(Reply.GetValue<TJSONObject>('data').GetValue<TJSONObject>('asset'),'id','');
      Request:=NewRequest('register_image','characters'); Request.AddPair('assetId',UID); Request.AddPair('sourcePath',TPath.Combine(Folder,'reference.bmp')); Run; Good('pipe registers a validated image by character identity');
      OldFile:=JStr(Reply.GetValue<TJSONObject>('data').GetValue<TJSONObject>('asset'),'file','');
      Asset:=nil; for Other in Probe.FCharacters do if Other.ID=UID then Asset:=Other;
      Check((Asset<>nil) and (Asset.FileName<>'') and FileExists(SafeChild(TPath.Combine(DataRoot,'Characters'),Asset.FileName)),
        'registered character image is copied into app storage'); OldFile:=Asset.FileName;
      Request:=NewRequest('create_asset','characters'); Request.AddPair('name','服装の子'); Request.AddPair('parentId',UID); Run; Good('pipe creates a second-level clothing item');
      ChildID:=JStr(Reply.GetValue<TJSONObject>('data').GetValue<TJSONObject>('asset'),'id','');
      Request:=NewRequest('create_asset','characters'); Request.AddPair('name','3階層'); Request.AddPair('parentId',ChildID); Run; Bad('pipe rejects a third hierarchy level');
      Manager:=TAssetDialog.CreateManager(Probe,Probe.FCharacters,nil,True); Probe.FAssetManager:=Manager; Manager.SelectAsset(ChildID);
      Manager.DraftName.Text:='編集中の服装'; Manager.DraftNotes.Text:='選択中の下書き';
      Request:=NewRequest('status',''); Run; Good('pipe status works while character management is open');
      Data:=Reply.GetValue<TJSONObject>('data').GetValue<TJSONObject>('selection');
      Check((JStr(Data,'id','')=ChildID) and (JStr(Data,'draftNotes','')='選択中の下書き') and (JStr(Data,'library','')='characters'),
        'pipe status exposes selected identity and unsaved draft without changing selection');
      Manager.HandleNeeded; EnableWindow(Probe.Handle,False);
      try
        Request:=NewRequest('create_asset','characters'); Request.AddPair('name','manager remains writable'); Run;
        Good('enabled asset manager allows registration while its main owner is disabled');
        Before:=TFile.ReadAllText(LibraryPath,TEncoding.UTF8); FileCount:=Probe.FCharacters.Count; Manager.DraftNotes.Text:='native picker pending draft';
        EnableWindow(Manager.Handle,False);
        try
          Request:=NewRequest('status',''); Run; Good('nested native dialog still allows selected draft status');
          Request:=NewRequest('create_asset','characters'); Request.AddPair('name','nested native blocked'); Run;
          Bad('nested native dialog blocks writes to its disabled asset manager');
          Check((Probe.FCharacters.Count=FileCount) and (TFile.ReadAllText(LibraryPath,TEncoding.UTF8)=Before) and
            (Manager.DraftNotes.Text='native picker pending draft') and (Manager.CurrentAsset.Notes='選択中の下書き'),
            'nested native write rejection keeps library and uncommitted manager draft');
        finally EnableWindow(Manager.Handle,True); Manager.DraftNotes.Text:='選択中の下書き'; end;
      finally EnableWindow(Probe.Handle,True); end;
      Request:=NewRequest('register_image','characters'); Request.AddPair('assetId',UID); Request.AddPair('expectedFileName',OldFile);
      Request.AddPair('sourcePath',TPath.Combine(Folder,'reference.bmp')); Run; Good('registration targets its identity after selection changes');
      NewFile:=Asset.FileName;
      Check((Manager.CurrentAsset.ID=ChildID) and (Manager.CurrentAsset.FileName='') and (NewFile<>OldFile) and
        FileExists(SafeChild(TPath.Combine(DataRoot,'Characters'),OldFile)), 'registration preserves changed selection and previous image bytes');
      Request:=NewRequest('read_asset','characters'); Request.AddPair('assetId',ChildID); Run; Good('pipe reads the requested child and parent');
      Data:=Reply.GetValue<TJSONObject>('data'); Check((JStr(Data.GetValue<TJSONObject>('parent'),'id','')=UID) and
        (JStr(Data.GetValue<TJSONObject>('parent'),'referencePath','')<>''),'child query carries only its named parent reference');
      Request:=NewRequest('register_image','characters'); Request.AddPair('assetId',UID); Request.AddPair('expectedFileName',OldFile);
      Request.AddPair('sourcePath',TPath.Combine(Folder,'reference.bmp')); Run; Bad('stale image expectation rejects registration');
      Request:=NewRequest('register_image','characters'); Request.AddPair('assetId',UID); Request.AddPair('sourcePath',TPath.Combine(Folder,'missing.png')); Run; Bad('missing generated image leaves the existing reference');
      Check(Asset.FileName=NewFile,'failed registration preserves the adopted image');
      Manager.SelectAsset(UID); CorruptPath:=SafeChild(TPath.Combine(DataRoot,'Characters'),Asset.FileName); ImageBytes:=TFile.ReadAllBytes(CorruptPath);
      try
        AtomicWrite(CorruptPath,'broken image');
        Request:=NewRequest('create_asset','characters'); Request.AddPair('name','別の登録先'); Request.AddPair('parentId',UID); Run;
        Good('a broken selected preview cannot turn a saved creation into an error');
        AdoptedID:=JStr(Reply.GetValue<TJSONObject>('data').GetValue<TJSONObject>('asset'),'id','');
        Check((Manager.CurrentAsset.ID=UID) and (Manager.PreviewError<>'') and
          (Reply.GetValue<TJSONObject>('data').GetValue('warnings') is TJSONArray), 'preview failure is reported separately while manager selection remains usable');
        Request:=NewRequest('register_image','characters'); Request.AddPair('assetId',AdoptedID); Request.AddPair('expectedFileName','');
        Request.AddPair('sourcePath',TPath.Combine(Folder,'reference.bmp')); Run;
        Good('saved image registration succeeds while another selected preview is corrupt');
        Check(Reply.GetValue<TJSONObject>('data').GetValue('warnings') is TJSONArray,'successful adoption includes a separate preview warning');
        Request:=NewRequest('register_image','characters'); Request.AddPair('assetId',AdoptedID); Request.AddPair('expectedFileName','');
        Request.AddPair('sourcePath',TPath.Combine(Folder,'reference.bmp')); Run; Bad('repeating stale registration after a preview warning cannot adopt twice');
        Request:=NewRequest('read_asset','characters'); Request.AddPair('assetId',AdoptedID); Run;
        Good('saved target can be queried after a preview warning without repeating creation');
      finally TFile.WriteAllBytes(CorruptPath,ImageBytes); Manager.RefreshFromExternal; end;
      Check((Manager.PreviewError='') and (Manager.CurrentAsset.ID=UID),'repaired external preview resumes without changing adopted target or selection');
      FileCount:=Length(TDirectory.GetFiles(TPath.Combine(DataRoot,'Characters'),'*.bmp')); Before:=TFile.ReadAllText(LibraryPath,TEncoding.UTF8);
      Lock:=CreateFile(PChar(LibraryPath),GENERIC_READ,FILE_SHARE_READ,nil,OPEN_EXISTING,0,0);
      try
        Request:=NewRequest('register_image','characters'); Request.AddPair('assetId',UID); Request.AddPair('sourcePath',TPath.Combine(Folder,'reference.bmp')); Run;
        Bad('library publication failure is returned through the live pipe');
        Check((Asset.FileName=NewFile) and (Length(TDirectory.GetFiles(TPath.Combine(DataRoot,'Characters'),'*.bmp'))=FileCount) and
          (TFile.ReadAllText(LibraryPath,TEncoding.UTF8)=Before),'failed registration rolls back metadata and removes only its new copied file');
      finally CloseHandle(Lock); end;
      Probe.FAssetManager:=nil; FreeAndNil(Manager);
      Probe.FCharacterLibraryWritable:=False; Request:=NewRequest('create_asset','characters'); Request.AddPair('name','禁止'); Run; Bad('pipe respects protected character library'); Probe.FCharacterLibraryWritable:=True;
      Request:=NewRequest('create_asset','images'); Request.AddPair('name','背景'); Run; Good('pipe creates a project scene');
      ImageID:=JStr(Reply.GetValue<TJSONObject>('data').GetValue<TJSONObject>('asset'),'id',''); Before:=Project.Snapshot; History:=Probe.FUndo.Count;
      Request:=NewRequest('register_image','images'); Request.AddPair('assetId',ImageID); Request.AddPair('sourcePath',TPath.Combine(Folder,'reference.bmp')); Run; Good('pipe registers a project image');
      After:=Project.Snapshot; NewFile:=Project.Asset(ImageID).FileName;
      Check((Probe.FUndo.Count=History+1) and (Project.Asset(ImageID).FileName<>'') and FileExists(Project.ImagePath(ImageID)),
        'project image registration commits one undo operation');
      Reloaded:=TComicProject.Create;
      try Reloaded.Load(TPath.Combine(Project.Folder,'Draft.json')); Check(Reloaded.Snapshot=After,'registered image and project generation snapshot persist in recoverable draft');
      finally Reloaded.Free; end;
      Probe.Undo(nil); Check(Project.Snapshot=Before,'pipe image registration undo restores previous reference');
      Probe.Redo(nil); Check((Project.Snapshot=After) and FileExists(Project.ImagePath(ImageID)),'pipe registration redo reuses retained copied bytes');
      Request:=NewRequest('register_image','images'); Pair:=Request.RemovePair('projectId'); Pair.Free; Request.AddPair('projectId','old-project');
      Request.AddPair('assetId',ImageID); Request.AddPair('sourcePath',TPath.Combine(Folder,'reference.bmp')); Run; Bad('changed project identity rejects a late image');
      Check(Project.Snapshot=After,'late registration cannot mutate the newly selected project');
      Probe.FDragging:=True; Request:=NewRequest('create_asset','images'); Request.AddPair('name','操作中'); Run; Bad('pending edit blocks pipe mutation'); Probe.FDragging:=False;
      FreeAndNil(Reply); Reply:=Send('{bad}'); Bad('malformed JSON returns a framed error and keeps server alive');
      FreeAndNil(Reply); Reply:=Send('{"version":1,"action":"status","action":"action"}'); Bad('duplicate JSON keys cannot change command meaning');
      Request:=NewRequest('list_presets',''); Run; Good('pipe exposes common generation instructions');
      Failed:=False; try ComicBridgeRequest('\\remote\pipe\unsafe','{}',10); except Failed:=True; end; Check(Failed,'native bridge client rejects remote pipe names');
      Request:=NewRequest('status',''); Run; Good('pipe remains usable after rejected requests');
      ExternalClient;
      // Leave a connection without a complete line: shutdown must cancel its overlapped read.
      WaitNamedPipe(PChar('\\.\pipe\'+Bridge.PipeName),1000);
      Pipe:=CreateFile(PChar('\\.\pipe\'+Bridge.PipeName),GENERIC_READ or GENERIC_WRITE,0,nil,OPEN_EXISTING,FILE_FLAG_OVERLAPPED,0);
      Check(Pipe<>INVALID_HANDLE_VALUE,'incomplete bridge connection opens for cancellation regression');
      try Started:=GetTickCount64; FreeAndNil(Bridge); Check(GetTickCount64-Started<1500,'app shutdown cancels an incomplete pipe read promptly');
      finally CloseHandle(Pipe); end;
      Check(not FileExists(Manifest),'shutdown removes only this process bridge manifest');
      Check(FProject.Snapshot=Original,'live pipe fixtures preserve the active project');
    finally
      Probe.FAssetManager:=nil; Manager.Free; Request.Free; Reply.Free; Bridge.Free; PNG.Free; Probe.Free;
      AtomicWrite(LibraryPath,LibraryBytes);
    end;
  end;
  procedure GenerationPresetChecks;
  var Probe: TMainForm; Project,Reloaded: TComicProject; Presets,CopyPresets,Broken: TObjectList<TComicGenerationPreset>;
    Preset: TComicGenerationPreset; Dialog: TComicGenerationDialog; Path,ID,Instructions,Before,Original: string;
    Lock: THandle; Failed: Boolean; I,PPI: Integer; PNG: TPngImage;
  begin
    Original:=FProject.Snapshot; Probe:=TMainForm.Create(nil); Presets:=TObjectList<TComicGenerationPreset>.Create; CopyPresets:=TObjectList<TComicGenerationPreset>.Create;
    Broken:=TObjectList<TComicGenerationPreset>.Create; PNG:=TPngImage.Create;
    try
      Project:=TComicProject.Create; Project.Initialize('生成指示 fixture','1'); Probe.AdoptProject(Project,False);
      Preset:=TComicGenerationPreset.Create; Preset.Name:='漫画の共通指示'; Preset.Instructions:='人物の同一性を保つ。'+#13#10+'背景の位置関係を維持する。';
      ID:=Preset.ID; Instructions:=Preset.Instructions; Presets.Add(Preset);
      Preset:=TComicGenerationPreset.Create; Preset.Name:='別の指示'; Preset.Instructions:='追加の指示'; Presets.Add(Preset);
      Path:=TPath.Combine(Folder,'generation-presets.json'); SaveGenerationPresets(Presets,Path); LoadGenerationPresets(CopyPresets,Path);
      Check((CopyPresets.Count=2) and (CopyPresets[0].ID=ID) and (CopyPresets[0].Instructions=Instructions),
        'generation presets save and reload stable identity and multiline Japanese instructions');
      Check(ExportSequence(Project,Probe.FRenderer,False)=1,'generation fixture exports its initial blank page');
      Probe.ApplyGenerationPreset(ID,Presets[0].Name,Instructions);
      Check((Project.GenerationPresetID=ID) and (Project.GenerationInstructions=Instructions),'applying generation preset copies its instruction snapshot into the project');
      Check(ExportSequence(Project,Probe.FRenderer,False)=0,'generation instruction changes leave completed PNG cache intact');
      UpdateGenerationPreset(Presets,Presets[0],'変更した共通指示','将来用の本文',Path);
      Check((Project.GenerationPresetName='漫画の共通指示') and (Project.GenerationInstructions=Instructions),
        'later common generation edits cannot alter an applied project snapshot');
      RemoveGenerationPreset(Presets,Presets[0],Path);
      Check((Presets.Count=1) and (Project.GenerationPresetID=ID) and (Project.GenerationInstructions=Instructions),
        'deleting a common generation preset preserves project instructions');
      Probe.Undo(nil); Check((Project.GenerationPresetID='') and (Project.GenerationInstructions=''),'generation preset apply undoes as one project operation');
      Probe.Redo(nil); Check(Project.GenerationInstructions=Instructions,'generation preset redo restores its exact snapshot');
      Project.Save; Reloaded:=TComicProject.Create;
      try Reloaded.Load(TPath.Combine(Project.Folder,'Project.json')); Check(Reloaded.GenerationInstructions=Instructions,'project generation snapshot survives save and reload');
      finally Reloaded.Free; end;
      Before:=TFile.ReadAllText(Path,TEncoding.UTF8); Lock:=CreateFile(PChar(Path),GENERIC_READ,FILE_SHARE_READ,nil,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,0);
      Check(Lock<>INVALID_HANDLE_VALUE,'generation library can be locked to inject publication failure');
      try
        Failed:=False; try UpdateGenerationPreset(Presets,Presets[0],'失敗する名前','失敗する本文',Path); except Failed:=True; end;
        Check(Failed and (Presets[0].Name='別の指示') and (Presets[0].Instructions='追加の指示') and (TFile.ReadAllText(Path,TEncoding.UTF8)=Before),
          'failed generation preset update restores name body and original library');
        Failed:=False; try RemoveGenerationPreset(Presets,Presets[0],Path); except Failed:=True; end;
        Check(Failed and (Presets.Count=1) and (Presets[0].Name='別の指示'),'failed generation preset deletion restores the item and order');
      finally CloseHandle(Lock); end;
      Dialog:=TComicGenerationDialog.CreateManager(Self,CopyPresets,Path,True,True);
      try
        Dialog.SelectPreset(1); Dialog.SetDraft('作品専用に変更','表示中の本文だけを適用'); Dialog.AcceptSelection;
        Check((Dialog.ModalResult=mrOK) and (Dialog.SelectedName='作品専用に変更') and (Dialog.SelectedInstructions='表示中の本文だけを適用') and
          (CopyPresets[1].Name='別の指示') and (TFile.ReadAllText(Path,TEncoding.UTF8)=Before),
          'generation dialog applies its displayed draft without silently rewriting the common preset');
        for PPI in [96,144] do begin
          Dialog.Scaled:=True; Dialog.ScaleForPPI(PPI); Dialog.Scaled:=False; Dialog.ClientWidth:=MulDiv(880,PPI,96); Dialog.ClientHeight:=MulDiv(580,PPI,96); Dialog.Realign;
          Dialog.HandleNeeded; B.SetSize(Dialog.ClientWidth,Dialog.ClientHeight); Dialog.PaintTo(B.Canvas,0,0); PNG.Assign(B); PNG.SaveToFile(TPath.Combine(Folder,'generation-presets-'+IntToStr(PPI)+'.png'));
          for I:=0 to Dialog.ComponentCount-1 do if Dialog.Components[I] is TButton then with TButton(Dialog.Components[I]) do
            Check((Left>=0) and (Top>=0) and (Left+Width<=Parent.ClientWidth) and (Top+Height<=Parent.ClientHeight),
              'generation preset button remains reachable at PPI '+IntToStr(PPI)+' '+Caption);
        end;
      finally Dialog.Free; end;
      Dialog:=TComicGenerationDialog.CreateManager(Self,CopyPresets,Path,False,False);
      try
        Dialog.AcceptSelection; Check(Dialog.ModalResult=0,'generation preset cannot be applied without an open project');
        Failed:=False; try Dialog.SetDraft('禁止','本文'); except Failed:=True; end;
        Check(Failed and (CopyPresets[0].Name='漫画の共通指示'),'read-only generation manager preserves existing entries');
      finally Dialog.Free; end;
      J:=CopyPresets[0].Json; try Before:='{"version":1,"presets":['+J.ToJSON+',42]}'; finally J.Free; end;
      AtomicWrite(Path,Before); Failed:=False; try LoadGenerationPresets(Broken,Path); except Failed:=True; end;
      Check(Failed and (Broken.Count=0) and (TFile.ReadAllText(Path,TEncoding.UTF8)=Before),
        'invalid generation library cannot publish a valid prefix or overwrite source data');
      Check(FProject.Snapshot=Original,'generation fixture preserves the active editing project');
    finally PNG.Free; Broken.Free; CopyPresets.Free; Presets.Free; Probe.Free; end;
  end;
  procedure TextPlacementChecks;
  var Probe: TMainForm; Project,Reloaded: TComicProject; Balloon: TComicBalloon; Tail: TComicTail;
    Before,TailBefore: string; BodyBounds,TextBounds: TRectF; PointA: TPointF; X,Y,K,PPI,Orientation,History: Integer;
    KeyValue: Word; PNG: TPngImage; Original: TComicBalloonTransform; Invalid: TRectF;
    procedure CaptureText(const Name: string);
    begin
      Probe.UpdateIconState; Probe.HandleNeeded; B.SetSize(Probe.ClientWidth,Probe.ClientHeight); Probe.PaintTo(B.Canvas,0,0);
      PNG.Assign(B); PNG.SaveToFile(TPath.Combine(Folder,Name+'.png'));
    end;
    procedure SelectText;
    var Button: TComicIconButton;
    begin
      Probe.FBalloonIndex:=0; Probe.LoadBalloonControls(Probe.Page.Balloons[0]); Probe.UpdateIconState;
      for Button in Probe.FIconButtons do if Button.Role=brTextPlacement then begin Button.Click; Exit; end;
    end;
  begin
    Probe:=TMainForm.Create(nil); PNG:=TPngImage.Create;
    try
      Project:=TComicProject.Create; Project.Initialize('文字配置 fixture','1'); Probe.AdoptProject(Project,False);
      Project.ImportImage(TPath.Combine(Folder,'reference.bmp'),'');
      Balloon:=TComicBalloon.Create; Balloon.Text:='文字位置'; Balloon.Bounds:=TRectF.Create(150,150,650,650);
      Tail:=TComicTail.Create; Tail.Root:=Balloon.Bounds.CenterPoint; Tail.Tip:=TPointF.Create(850,800); Balloon.Tails.Add(Tail);
      Probe.Page.Balloons.Add(Balloon); BodyBounds:=Balloon.Bounds; Probe.RefreshUI; Probe.FTabs.ActivePageIndex:=3; Probe.TabChanged(nil);
      SelectText; CaptureText('text-placement-centered'); TextBounds:=Probe.FRenderer.BalloonTextBounds(Balloon);
      Check((Abs(TextBounds.CenterPoint.X-BodyBounds.CenterPoint.X)<=1) and (Abs(TextBounds.CenterPoint.Y-BodyBounds.CenterPoint.Y)<=1),
        'default balloon text block is centered inside its body');
      Before:=Project.Snapshot; J:=Tail.Json; try TailBefore:=J.ToJSON; finally J.Free; end;
      PointA:=TextBounds.CenterPoint; X:=Probe.FPageRect.Left+Round(PointA.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(PointA.Y*Probe.FScale);
      Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y); Check(Probe.FDragHandle=0,'text interior starts a text-only movement');
      Probe.MouseMove(Probe.FCanvas,[ssLeft],X+15,Y+11); Probe.MouseUp(Probe.FCanvas,mbLeft,[],X+15,Y+11);
      J:=Probe.Page.Balloons[0].Tails[0].Json;
      try Check((Probe.Page.Balloons[0].Bounds=BodyBounds) and (J.ToJSON=TailBefore) and
        (Abs(Probe.Page.Balloons[0].TextOffset.X)>1) and (Abs(Probe.Page.Balloons[0].TextOffset.Y)>1),
        'text movement updates its relative offset while preserving body and tail geometry'); finally J.Free; end;
      Probe.Undo(nil); Check(Project.Snapshot=Before,'text placement undo restores the compound balloon in one operation');
      for K:=1 to 8 do begin
        SelectText; TextBounds:=Probe.FRenderer.BalloonTextBounds(Probe.Page.Balloons[0]); PointA:=EditHandles(TextBounds)[K-1];
        X:=Probe.FPageRect.Left+Round(PointA.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(PointA.Y*Probe.FScale);
        Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y); Check(Probe.FDragHandle=K,'text outer handle '+IntToStr(K)+' is selectable');
        Probe.MouseMove(Probe.FCanvas,[ssLeft],X+12,Y+8); Probe.MouseUp(Probe.FCanvas,mbLeft,[],X+12,Y+8);
        Check((Probe.Page.Balloons[0].Bounds=BodyBounds) and (Probe.Page.Balloons[0].FontSize<>40) and
          (Probe.FFont.Text=IntToStr(Probe.Page.Balloons[0].FontSize)), 'text handle '+IntToStr(K)+' scales glyphs without resizing the body');
        Probe.Undo(nil); Check(Project.Snapshot=Before,'text handle '+IntToStr(K)+' undo restores size and placement');
      end;
      SelectText; TextBounds:=Probe.FRenderer.BalloonTextBounds(Probe.Page.Balloons[0]); PointA:=TextBounds.CenterPoint;
      X:=Probe.FPageRect.Left+Round(PointA.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(PointA.Y*Probe.FScale);
      History:=Probe.FUndo.Count; Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y); Probe.MouseMove(Probe.FCanvas,[ssLeft],X+20,Y+20);
      KeyValue:=VK_ESCAPE; Probe.Key(Probe,KeyValue,[]);
      Check((Project.Snapshot=Before) and (Probe.FUndo.Count=History),'escape cancels pending text movement without mutating the body');
      Probe.Page.Balloons[0].TextOffset:=TPointF.Create(40,-25); Original:=Probe.Page.Balloons[0].CaptureTransform;
      Invalid:=Original.Bounds; Invalid.Right:=Invalid.Left+Invalid.Width*1.5; Invalid.Bottom:=Invalid.Top+Invalid.Height*0.8;
      Check(Probe.Page.Balloons[0].ApplyTransform(Original,Invalid) and
        (Abs(Probe.Page.Balloons[0].TextOffset.X-60)<0.001) and (Abs(Probe.Page.Balloons[0].TextOffset.Y+20)<0.001),
        'whole balloon resize carries the text offset with independent axis ratios');
      Project.Save; Reloaded:=TComicProject.Create;
      try Reloaded.Load(TPath.Combine(Project.Folder,'Project.json')); Check(Reloaded.Snapshot=Project.Snapshot,'text placement and styled compound data survive save and reload');
      finally Reloaded.Free; end;
      Original:=Probe.Page.Balloons[0].CaptureTransform; Probe.Page.Balloons[0].TextOffset:=TPointF.Create(80000,0);
      Original:=Probe.Page.Balloons[0].CaptureTransform; Invalid:=Original.Bounds; Invalid.Right:=Invalid.Left+Invalid.Width*2; Before:=Project.Snapshot;
      Check(not Probe.Page.Balloons[0].ApplyTransform(Original,Invalid) and (Project.Snapshot=Before),'invalid scaled text offset rejects every compound component atomically');
      Probe.Page.Balloons[0].TextOffset:=TPointF.Create(15,12);
      for Orientation:=0 to 1 do for PPI in [96,144] do begin
        Probe.Page.Balloons[0].Vertical:=Orientation=1; Before:=Project.Snapshot;
        Probe.Scaled:=True; Probe.ScaleForPPI(PPI); Probe.Scaled:=False; Probe.Width:=MulDiv(940,PPI,96); Probe.Height:=MulDiv(660,PPI,96); Probe.Realign;
        SelectText; CaptureText('text-placement-'+IntToStr(Orientation)+'-dpi'+IntToStr(PPI)+'-before');
        TextBounds:=Probe.FRenderer.BalloonTextBounds(Probe.Page.Balloons[0]); PointA:=TextBounds.CenterPoint;
        X:=Probe.FPageRect.Left+Round(PointA.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(PointA.Y*Probe.FScale);
        History:=Probe.FUndo.Count; Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y);
        Probe.MouseMove(Probe.FCanvas,[ssLeft],X+MulDiv(12,PPI,96),Y+MulDiv(14,PPI,96)); Probe.MouseUp(Probe.FCanvas,mbLeft,[],X+MulDiv(12,PPI,96),Y+MulDiv(14,PPI,96));
        Check(Probe.FUndo.Count=History+1,'text placement commits once for orientation '+IntToStr(Orientation)+' at PPI '+IntToStr(PPI));
        CaptureText('text-placement-'+IntToStr(Orientation)+'-dpi'+IntToStr(PPI)+'-after'); Probe.Undo(nil);
        Check(Project.Snapshot=Before,'text DPI placement undo restores exact content '+IntToStr(Orientation)+' '+IntToStr(PPI));
      end;
    finally PNG.Free; Probe.Free; end;
  end;
  procedure TextScaledWrappingChecks;
  var Probe: TMainForm; Project,Reloaded: TComicProject; Balloon: TComicBalloon; Layout: TComicTextLayout;
    Base,After,Before,Resized,LabelText: string; OldBounds,NewBounds: TRectF; P,Q: TPointF;
    K,Orientation,PPI,X,Y,DX,DY,History: Integer; Ratio,Scale: Double; KeyValue: Word; PNG: TPngImage;
    function LayoutSignature(Target: TComicBalloon): string;
    var Cell: TComicTextCell;
    begin
      Scale:=BuildBalloonTextLayout(B.Canvas,Target,Layout); Result:=IntToStr(Layout.LineCount)+'|';
      for Cell in Layout.Cells do Result:=Result+Format('%d,%d,%d,%d,%d,%d,%d;',[Cell.Index,Cell.Count,Cell.Line,
        Cell.Bounds.Left,Cell.Bounds.Top,Cell.Bounds.Right,Cell.Bounds.Bottom]);
    end;
  begin
    Probe:=TMainForm.Create(nil); Layout:=TComicTextLayout.Create; PNG:=TPngImage.Create;
    try
      Project:=TComicProject.Create; Project.Initialize('折返し拡縮 fixture','1'); Probe.AdoptProject(Project,False);
      Project.ImportImage(TPath.Combine(Folder,'reference.bmp'),''); Balloon:=TComicBalloon.Create;
      Balloon.Bounds:=TRectF.Create(350,400,650,760); Balloon.FontSize:=32;
      Balloon.Text:='長文の折返し12を保つ。ーABC「配置」と幅を確認する。'+
        '長文の折返し12を保つ。ーABC「配置」と幅を確認する。'+
        '長文の折返し12を保つ。ーABC「配置」と幅を確認する。';
      Project.Pages[0].Balloons.Add(Balloon); Probe.RefreshUI; Probe.FTabs.ActivePageIndex:=3; Probe.TabChanged(nil);
      for Orientation:=0 to 1 do for PPI in [96,144] do begin
        Balloon:=Probe.Page.Balloons[0]; Balloon.Vertical:=Orientation=1; Before:=Project.Snapshot;
        Probe.Scaled:=True; Probe.ScaleForPPI(PPI); Probe.Scaled:=False;
        Probe.Width:=MulDiv(940,PPI,96); Probe.Height:=MulDiv(660,PPI,96); Probe.Realign; Probe.HandleNeeded;
        B.SetSize(Probe.ClientWidth,Probe.ClientHeight); Probe.PaintTo(B.Canvas,0,0);
        Base:=LayoutSignature(Balloon); Check(Layout.LineCount>2,'long scaling fixture wraps into several lines or columns '+IntToStr(Orientation));
        for K:=1 to 8 do begin
          Balloon:=Probe.Page.Balloons[0]; Probe.FBalloonIndex:=0; Probe.LoadBalloonControls(Balloon); Probe.FTool:=13; Probe.UpdateIconState;
          OldBounds:=Probe.FRenderer.BalloonTextBounds(Balloon); P:=EditHandles(OldBounds)[K-1];
          X:=Probe.FPageRect.Left+Round(P.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(P.Y*Probe.FScale);
          DX:=0; DY:=0;
          case K of
            1: begin DX:=-20; DY:=-20; end; 2: DY:=-20;
            3: begin DX:=20; DY:=-20; end; 4: DX:=20;
            5: begin DX:=20; DY:=20; end; 6: DY:=20;
            7: begin DX:=-20; DY:=20; end; 8: DX:=-20;
          end;
          DX:=MulDiv(DX,PPI,96); DY:=MulDiv(DY,PPI,96); History:=Probe.FUndo.Count;
          Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y); Probe.MouseMove(Probe.FCanvas,[ssLeft],X+DX,Y+DY);
          Probe.MouseUp(Probe.FCanvas,mbLeft,[],X+DX,Y+DY); Balloon:=Probe.Page.Balloons[0];
          LabelText:=Format('long text %d PPI%d handle%d',[Orientation,PPI,K]);
          After:=LayoutSignature(Balloon); Ratio:=Balloon.FontSize/32; NewBounds:=Probe.FRenderer.BalloonTextBounds(Balloon);
          Check((After=Base) and (Scale=Ratio) and (Ratio>1) and (Balloon.TextLayoutFontSize=32),LabelText+' retains every wrap and cell while scaling');
          Check((Abs(NewBounds.Width/OldBounds.Width-Ratio)<0.0001) and (Abs(NewBounds.Height/OldBounds.Height-Ratio)<0.0001) and
            (Balloon.Bounds=TRectF.Create(350,400,650,760)),LabelText+' keeps the full block aspect ratio and body');
          Resized:=Project.Snapshot; Project.Save; Reloaded:=TComicProject.Create;
          try Reloaded.Load(TPath.Combine(Project.Folder,'Project.json'));
            Check((Reloaded.Snapshot=Resized) and (LayoutSignature(Reloaded.Pages[0].Balloons[0])=Base),LabelText+' saves and reloads its wrapping basis');
          finally Reloaded.Free; end;
          Check(Probe.FUndo.Count=History+1,LabelText+' commits once');
          if K=5 then begin
            B.SetSize(Probe.ClientWidth,Probe.ClientHeight); Probe.PaintTo(B.Canvas,0,0); PNG.Assign(B);
            PNG.SaveToFile(TPath.Combine(Folder,Format('text-scaled-wrapped-%d-%d.png',[Orientation,PPI])));
          end;
          Probe.Undo(nil); Check(Project.Snapshot=Before,LabelText+' undo restores automatic layout');
          Probe.Redo(nil); Check(Project.Snapshot=Resized,LabelText+' redo restores exact scaled geometry'); Probe.Undo(nil);
        end;
        Balloon:=Probe.Page.Balloons[0]; Probe.FBalloonIndex:=0; Probe.FTool:=13; OldBounds:=Probe.FRenderer.BalloonTextBounds(Balloon);
        Q:=EditHandles(OldBounds)[4]; X:=Probe.FPageRect.Left+Round(Q.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(Q.Y*Probe.FScale);
        History:=Probe.FUndo.Count; Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y); Probe.MouseMove(Probe.FCanvas,[ssLeft],X+30,Y+30);
        KeyValue:=VK_ESCAPE; Probe.Key(Probe,KeyValue,[]);
        Check((Project.Snapshot=Before) and (Probe.FUndo.Count=History),'cancelled long text scaling restores layout basis and history '+IntToStr(Orientation)+' '+IntToStr(PPI));
      end;
    finally PNG.Free; Layout.Free; Probe.Free; end;
  end;
  procedure TailChecks;
  var Probe: TMainForm; Project,Reloaded: TComicProject; Balloon,LegacyA,LegacyB: TComicBalloon;
    Panel: TComicPanel; Tail: TComicTail; ID1,ID2,Before,Text: string; History,K,X,Y,PPI: Integer;
    KeyValue: Word; Original: TComicBalloonTransform; R: TRectF; PointA,Sample: TPointF;
    Region: HRGN; J: TJSONObject; Pair: TJSONPair; Failed: Boolean; PNG: TPngImage;
    Reference,Shifted: TBitmap; Saved: Integer; Same: Boolean;
    procedure CaptureTail(const Name: string);
    begin
      Probe.UpdateIconState; Probe.HandleNeeded; B.SetSize(Probe.ClientWidth,Probe.ClientHeight); Probe.PaintTo(B.Canvas,0,0);
      PNG.Assign(B); PNG.SaveToFile(TPath.Combine(Folder,Name+'.png'));
    end;
    procedure Tool(Tag: Integer);
    var Button: TComicIconButton;
    begin
      for Button in Probe.FIconButtons do if (Button.Context=3) and (Button.Tag=Tag) and (Button.Role in [brTool,brTail]) then begin Button.Click; Exit; end;
    end;
    procedure Click(PX,PY: Single);
    begin
      X:=Probe.FPageRect.Left+Round(PX*Probe.FScale); Y:=Probe.FPageRect.Top+Round(PY*Probe.FScale);
      Probe.FCanvas.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(X,Y)); Probe.FCanvas.Perform(WM_LBUTTONUP,0,MakeLParam(X,Y));
    end;
    procedure SelectBalloon;
    begin
      Tool(0); R:=Probe.Page.Balloons[0].Bounds; Click(R.CenterPoint.X,R.CenterPoint.Y);
    end;
    procedure TailStateEqual(const Source: TComicBalloonTransform; const Target: TRectF; const Message: string);
    var I: Integer; SX,SY: Double;
    begin
      SX:=Target.Width/Source.Bounds.Width; SY:=Target.Height/Source.Bounds.Height;
      for I:=0 to High(Source.Tails) do begin Tail:=Probe.Page.Balloons[0].Tails[I];
        Check((Abs(Tail.Root.X-(Target.Left+(Source.Tails[I].Root.X-Source.Bounds.Left)*SX))<0.01) and
          (Abs(Tail.Root.Y-(Target.Top+(Source.Tails[I].Root.Y-Source.Bounds.Top)*SY))<0.01) and
          (Abs(Tail.Tip.X-(Target.Left+(Source.Tails[I].Tip.X-Source.Bounds.Left)*SX))<0.01) and
          (Abs(Tail.Tip.Y-(Target.Top+(Source.Tails[I].Tip.Y-Source.Bounds.Top)*SY))<0.01),Message+' '+IntToStr(I));
      end;
    end;
  begin
    Probe:=TMainForm.Create(nil); PNG:=TPngImage.Create; Reference:=TBitmap.Create; Shifted:=TBitmap.Create;
    try
      Project:=TComicProject.Create; Project.Initialize('複数しっぽ fixture','1'); Probe.AdoptProject(Project,False);
      Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(100,100,900,1200); Panel.ImageID:=Project.ImportImage(TPath.Combine(Folder,'reference.bmp'),'').ID;
      Probe.Page.Panels.Add(Panel);
      Balloon:=TComicBalloon.Create; Balloon.Bounds:=TRectF.Create(150,150,550,550); Balloon.PanelID:=Panel.ID; Balloon.Text:='複数のしっぽ';
      Probe.Page.Balloons.Add(Balloon); Probe.RefreshUI; Probe.FTabs.ActivePageIndex:=3; Probe.TabChanged(nil); Probe.FBalloonIndex:=0; Probe.LoadBalloonControls(Balloon);
      CaptureTail('tail-empty'); Before:=Project.Snapshot; History:=Probe.FUndo.Count;
      Tool(7); Click(350,350); Check(Probe.FFirst and (Project.Snapshot=Before) and (Probe.FUndo.Count=History),
        Format('first tail click only previews a root without changing project or history: tool=%d first=%s balloon=%d same=%s undo=%d/%d',
          [Probe.FTool,BoolToStr(Probe.FFirst,True),Probe.FBalloonIndex,BoolToStr(Project.Snapshot=Before,True),Probe.FUndo.Count,History]));
      KeyValue:=VK_ESCAPE; Probe.Key(Probe,KeyValue,[]);
      Check(not Probe.FFirst and (Project.Snapshot=Before),'escape cancels pending tail creation');
      Tool(7); Click(50,50); Check(not Probe.FFirst and (Project.Snapshot=Before),'tail creation refuses a root outside its selected body');
      Click(350,350); Click(200,750); ID1:=Probe.Page.Balloons[0].Tails[0].ID;
      Check((Probe.Page.Balloons[0].Tails.Count=1) and (Probe.Page.Balloons[0].Tails[0].Kind=ctTriangle) and (Probe.FUndo.Count=History+1),
        'two clicks create one owned triangular tail as one undo operation');
      Tool(11); Click(450,450); Click(850,600); ID2:=Probe.Page.Balloons[0].Tails[1].ID;
      Check((Probe.Page.Balloons[0].Tails.Count=2) and (Probe.Page.Balloons[0].Tails[1].Kind=ctThought),
        'thought tail appends without replacing the existing triangular tail');
      Region:=TailRegion(Probe.Page.Balloons[0].Tails[1],Point(0,0),1);
      try Check(PtInRegion(Region,583,500) and PtInRegion(Region,717,550) and PtInRegion(Region,850,600) and not PtInRegion(Region,650,525),
        'thought tail is composed of three separate decreasing circles'); finally Winapi.Windows.DeleteObject(Region); end;
      Probe.Undo(nil); Check((Probe.Page.Balloons[0].Tails.Count=1) and (Probe.Page.Balloons[0].Tails[0].ID=ID1),'tail addition undo retains previous tail identity');
      Probe.Redo(nil); Check((Probe.Page.Balloons[0].Tails.Count=2) and (Probe.Page.Balloons[0].Tails[1].ID=ID2),'tail addition redo restores both owned identities');
      SelectBalloon; Before:=Project.Snapshot; Probe.FTailIndex:=0; Tool(12); Probe.FTailIndex:=0;
      for K:=1 to 3 do begin
        Tail:=Probe.Page.Balloons[0].Tails[0]; PointA:=Tail.Handles[K-1];
        X:=Probe.FPageRect.Left+Round(PointA.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(PointA.Y*Probe.FScale);
        Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y);
        Check(Probe.FDragTailHandle=K,'tail edit handle '+IntToStr(K)+' selects root width or tip');
        Probe.MouseMove(Probe.FCanvas,[ssLeft],X+9,Y+7); Probe.MouseUp(Probe.FCanvas,mbLeft,[],X+9,Y+7);
        Check((Probe.Page.Balloons[0].Tails[0].ID=ID1) and (Probe.Page.Balloons[0].Tails[1].ID=ID2) and
          Probe.Page.Balloons[0].Tails[0].Valid,'tail handle '+IntToStr(K)+' edits geometry while retaining sibling and ownership');
        Probe.Undo(nil); Check(Project.Snapshot=Before,'tail handle '+IntToStr(K)+' undo restores the entire compound balloon');
        SelectBalloon; Tool(12); Probe.FTailIndex:=0;
      end;
      Tail:=Probe.Page.Balloons[0].Tails[0]; PointA:=Tail.Tip;
      X:=Probe.FPageRect.Left+Round(PointA.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(PointA.Y*Probe.FScale);
      Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y); Probe.MouseMove(Probe.FCanvas,[ssLeft],X+12,Y+9);
      KeyValue:=VK_ESCAPE; Probe.Key(Probe,KeyValue,[]);
      Check((Project.Snapshot=Before) and not Probe.FDragging,'escape cancels individual tail dragging without changing siblings');
      SelectBalloon; Tool(12); Probe.FTailIndex:=0; Probe.DeleteTail(nil);
      Check((Probe.Page.Balloons[0].Tails.Count=1) and (Probe.Page.Balloons[0].Tails[0].ID=ID2) and (Probe.Page.Balloons.Count=1),
        'individual tail deletion keeps the other tail body and text');
      Probe.Undo(nil); Check(Project.Snapshot=Before,'individual tail deletion undo restores stable identities');
      SelectBalloon; Original:=Probe.Page.Balloons[0].CaptureTransform; R:=Original.Bounds;
      X:=Probe.FPageRect.Left+Round(R.CenterPoint.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(R.CenterPoint.Y*Probe.FScale);
      Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y); Probe.MouseMove(Probe.FCanvas,[ssLeft],X+20,Y+12); Probe.MouseUp(Probe.FCanvas,mbLeft,[],X+20,Y+12);
      TailStateEqual(Original,Probe.Page.Balloons[0].Bounds,'body move carries every owned tail root and tip');
      Probe.Undo(nil); Check(Project.Snapshot=Before,'body move undo restores all owned components');
      SelectBalloon; Original:=Probe.Page.Balloons[0].CaptureTransform; R:=Original.Bounds;
      X:=Probe.FPageRect.Left+Round(R.Right*Probe.FScale); Y:=Probe.FPageRect.Top+Round(R.Bottom*Probe.FScale);
      Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y); Probe.MouseMove(Probe.FCanvas,[ssLeft],X+35,Y+20); Probe.MouseUp(Probe.FCanvas,mbLeft,[],X+35,Y+20);
      TailStateEqual(Original,Probe.Page.Balloons[0].Bounds,'body resize carries every owned tail root and tip');
      Check((Probe.Page.Balloons[0].FontSize>Original.FontSize) and (Probe.Page.Balloons[0].BorderWidth=3) and
        (Probe.FFont.Text=IntToStr(Probe.Page.Balloons[0].FontSize)),'body resize scales text while retaining output-pixel border width and matching controls');
      Project.Save; Reloaded:=TComicProject.Create;
      try Reloaded.Load(TPath.Combine(Project.Folder,'Project.json'));
        Check((Reloaded.Snapshot=Project.Snapshot) and (Reloaded.Pages[0].Balloons[0].Tails.Count=2),'multiple triangular and thought tails save and reload with exact geometry');
      finally Reloaded.Free; end;
      Probe.Undo(nil); Check(Project.Snapshot=Before,'compound balloon resize undo restores original font and tails');
      SelectBalloon; Balloon:=Probe.Page.Balloons[0]; Original:=Balloon.CaptureTransform; R:=Original.Bounds; R.Offset(70,40);
      R.Right:=R.Left+Original.Bounds.Width*1.3; R.Bottom:=R.Top+Original.Bounds.Height*1.15;
      Check(Balloon.ApplyTransform(Original,R),'compound balloon model applies independent axis scales');
      Probe.LoadBalloonControls(Balloon); Probe.FFillColor:=clYellow; Probe.FBorderColor:=clNavy; Probe.FBorderWidth.ItemIndex:=Probe.FBorderWidth.Items.IndexOf('4'); Probe.ApplyText(nil);
      Check((Balloon.FillColor=clYellow) and (Balloon.BorderColor=clNavy) and (Balloon.BorderWidth=4),'balloon appearance applies fill border color and fixed pixel width');
      Reference.SetSize(600,850); Shifted.SetSize(750,950);
      FRenderer.Draw(Reference.Canvas,Project,Probe.Page,Rect(0,0,600,850),False); PNG.Assign(Reference); PNG.SaveToFile(TPath.Combine(Folder,'tails-composite.png'));
      Saved:=SaveDC(Shifted.Canvas.Handle);
      try SetViewportOrgEx(Shifted.Canvas.Handle,75,50,nil); FRenderer.Draw(Shifted.Canvas,Project,Probe.Page,Rect(0,0,600,850),False);
      finally RestoreDC(Shifted.Canvas.Handle,Saved); Shifted.Canvas.Refresh; end;
      Same:=True; for X:=0 to 599 do for Y:=0 to 849 do if Reference.Canvas.Pixels[X,Y]<>Shifted.Canvas.Pixels[X+75,Y+50] then Same:=False;
      Check(Same,'compound tail unions circles text and fixed borders match under translated DC rendering');
      Tail:=Balloon.Tails[1]; X:=Round(Tail.Tip.X/2); Y:=Round(Tail.Tip.Y/2);
      Check(Reference.Canvas.Pixels[X,Y]=clYellow,'overflow thought tail paints its tip circle above neighboring space');
      Balloon.Overflow:=False; FRenderer.Draw(Reference.Canvas,Project,Probe.Page,Rect(0,0,600,850),False);
      Check(Reference.Canvas.Pixels[X,Y]=clWhite,'owner clipping applies to all tails as part of the compound balloon'); Balloon.Overflow:=True;
      Tail:=Balloon.Tails[0]; Sample:=TPointF.Create(Tail.Root.X+(Tail.Tip.X-Tail.Root.X)*0.8,Tail.Root.Y+(Tail.Tip.Y-Tail.Root.Y)*0.8);
      Balloon.Transparent:=True; FRenderer.Draw(Reference.Canvas,Project,Probe.Page,Rect(0,0,600,850),False);
      Check(Reference.Canvas.Pixels[Round(Sample.X/2),Round(Sample.Y/2)]<>clYellow,'text-only transparency omits every owned tail from completed PNG'); Balloon.Transparent:=False;
      J:=Balloon.Json; Pair:=J.RemovePair('tails'); Pair.Free; LegacyA:=TComicBalloon.Create; LegacyB:=TComicBalloon.Create;
      try LegacyA.Read(J); LegacyB.Read(J);
        Check((LegacyA.Tails.Count=1) and (LegacyA.Tails[0].ID=LegacyB.Tails[0].ID) and
          (LegacyA.TailX=Balloon.TailX) and (LegacyA.TailY=Balloon.TailY),'legacy single-tail data receives a stable default identity without losing its tip');
      finally LegacyA.Free; LegacyB.Free; J.Free; end;
      J:=Balloon.Tails[0].Json; Pair:=J.RemovePair('width'); Pair.Free; J.AddPair('width',TJSONNumber.Create(-1)); Tail:=TComicTail.Create;
      try Failed:=False; try Tail.Read(J); except Failed:=True; end; Check(Failed,'invalid tail width cannot be loaded'); finally Tail.Free; J.Free; end;
      Before:=Project.Snapshot; Original:=Balloon.CaptureTransform; R:=Original.Bounds; R.Left:=NaN;
      Check(not Balloon.ApplyTransform(Original,R) and (Project.Snapshot=Before),'invalid compound target cannot partially mutate tails body or font');
      for PPI in [96,144] do begin
        Probe.Scaled:=True; Probe.ScaleForPPI(PPI); Probe.Scaled:=False; Probe.Width:=MulDiv(940,PPI,96); Probe.Height:=MulDiv(660,PPI,96); Probe.Realign;
        Probe.FBalloonIndex:=0; Tool(12); Probe.FTailIndex:=1; CaptureTail('tail-dpi'+IntToStr(PPI)+'-before');
        PointA:=Probe.Page.Balloons[0].Tails[1].Tip; X:=Probe.FPageRect.Left+Round(PointA.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(PointA.Y*Probe.FScale);
        History:=Probe.FUndo.Count; Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y);
        Check((Probe.FDragTailHandle=3) and (Probe.FTailIndex=1),'thought tip handle selects the correct owned tail at PPI '+IntToStr(PPI));
        Probe.MouseMove(Probe.FCanvas,[ssLeft],X-MulDiv(15,PPI,96),Y+MulDiv(12,PPI,96)); Probe.MouseUp(Probe.FCanvas,mbLeft,[],X-MulDiv(15,PPI,96),Y+MulDiv(12,PPI,96));
        Check((Probe.FUndo.Count=History+1) and Probe.Page.Balloons[0].Tails[1].Valid,'thought tip edit commits once at PPI '+IntToStr(PPI));
        CaptureTail('tail-dpi'+IntToStr(PPI)+'-after'); Probe.Undo(nil);
        Check(Project.Snapshot=Before,'DPI tail edit undo restores exact compound data '+IntToStr(PPI));
      end;
      Probe.FBalloonIndex:=0; Probe.FPanelIndex:=0; Text:=Probe.Page.Balloons[0].Text;
      Check(ExportSequence(Project,Probe.FRenderer,False)=1,'new multiple-tail scene exports to a complete PNG');
      Check(ExportSequence(Project,Probe.FRenderer,False)=0,'unchanged compound-tail scene reuses its PNG');
      Before:=Project.Snapshot; Probe.FTailIndex:=0; Probe.DeleteTail(nil);
      Check(ExportSequence(Project,Probe.FRenderer,False)=1,'individual tail deletion invalidates its page PNG');
      Probe.Undo(nil); Check((Probe.Page.Balloons[0].Tails.Count=2) and (Probe.Page.Balloons[0].Text=Text),'undo after tail export restores every original owned tail and text');
      Check(ExportSequence(Project,Probe.FRenderer,False)=1,'undo after tail export redraws the restored compound content safely');
    finally Shifted.Free; Reference.Free; PNG.Free; Probe.Free; end;
  end;
  procedure BalloonContourChecks;
  const ShapeNames: array[0..2] of string = ('四角','楕円','角丸');
    ContourNames: array[1..3] of string = ('ギザギザ','波線','雲形');
  var Probe: TMainForm; Project,Reloaded: TComicProject; Balloon,Legacy: TComicBalloon;
    Panel: TComicPanel; Tail: TComicTail; Reference,Shifted: TBitmap;
    Shape,Kind,PPI,X,Y,Saved,History,Index: Integer; Body,Plain,Difference,Translated: HRGN;
    RegionBounds: TRect; Bounds: TRectF; Before,After,LabelText: string; Same,Failed: Boolean;
    J: TJSONObject; Pair: TJSONPair; Q,Outside: TPointF; KeyValue: Word;
    procedure SelectBalloon;
    begin Probe.FBalloonIndex:=0; Probe.FTool:=0; Probe.LoadBalloonControls(Probe.Page.Balloons[0]); Probe.UpdateIconState; end;
    procedure PaintProbe;
    begin Probe.HandleNeeded; B.SetSize(Probe.ClientWidth,Probe.ClientHeight); Probe.PaintTo(B.Canvas,0,0); end;
  begin
    Probe:=TMainForm.Create(nil); Reference:=TBitmap.Create; Shifted:=TBitmap.Create;
    try
      Project:=TComicProject.Create; Project.Initialize('吹き出し輪郭サンプル','1'); Project.Width:=900; Project.Height:=1050;
      Probe.AdoptProject(Project,False); Project.ImportImage(TPath.Combine(Folder,'reference.bmp'),'');
      Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(30,30,870,1020); Panel.ImageID:=Project.Assets[0].ID;
      Probe.Page.Panels.Add(Panel); Balloon:=TComicBalloon.Create; Balloon.Bounds:=TRectF.Create(200,250,650,650);
      Balloon.PanelID:=Panel.ID; Balloon.Text:='輪郭テスト'; Probe.Page.Balloons.Add(Balloon);
      Tail:=TComicTail.Create; Tail.Root:=Balloon.Bounds.CenterPoint; Tail.Tip:=TPointF.Create(780,800); Tail.Width:=120; Balloon.Tails.Add(Tail);
      Probe.RefreshUI; Probe.FTabs.ActivePageIndex:=3; Probe.TabChanged(nil); SelectBalloon;
      Reference.PixelFormat:=pf24bit; Reference.SetSize(450,525); Shifted.PixelFormat:=pf24bit; Shifted.SetSize(500,560);
      for Shape:=0 to 2 do for Kind:=1 to 3 do begin
        Balloon:=Probe.Page.Balloons[0]; Balloon.Shape:=Shape; Balloon.Contour:=TComicBalloonContour(Kind);
        LabelText:=Format('contour %d shape %d',[Kind,Shape]);
        Body:=BalloonBodyRegion(Balloon,Point(0,0),1); Plain:=ShapeRegion(Rect(200,250,650,650),Shape);
        Difference:=CreateRectRgn(0,0,0,0); Translated:=BalloonBodyRegion(Balloon,Point(23,17),1);
        try
          GetRgnBox(Body,RegionBounds);
          Check((RegionBounds.Width>300) and (RegionBounds.Height>300) and (RegionBounds.Left>=200) and
            (RegionBounds.Top>=250) and (RegionBounds.Right<=651) and (RegionBounds.Bottom<=651) and
            PtInRegion(Body,425,450),LabelText+' has a filled center and stays inside the editable body bounds');
          Check(CombineRgn(Difference,Plain,Body,RGN_XOR)=COMPLEXREGION,LabelText+' differs from its plain basic shape');
          OffsetRgn(Translated,-23,-17); Check(EqualRgn(Body,Translated),LabelText+' geometry is independent of canvas origin');
          Outside:=TPointF.Create(0,0);
          for X:=200 to 650 do for Y:=250 to 650 do
            if PtInRegion(Plain,X,Y) and not PtInRegion(Body,X,Y) then begin Outside:=TPointF.Create(X,Y); Break; end;
          Probe.FBalloonIndex:=-1;
          Check((Outside.X<>0) and (Probe.HitBalloon(Outside)=-1) and not Probe.InsideBalloonBody(Balloon,Outside) and
            (Probe.HitBalloon(Balloon.Bounds.CenterPoint)=0),LabelText+' selection and tail roots follow the visible contour');
        finally Winapi.Windows.DeleteObject(Translated); Winapi.Windows.DeleteObject(Difference);
          Winapi.Windows.DeleteObject(Plain); Winapi.Windows.DeleteObject(Body); end;
        FRenderer.Draw(Reference.Canvas,Project,Probe.Page,Rect(0,0,450,525),False);
        Saved:=SaveDC(Shifted.Canvas.Handle);
        try SetViewportOrgEx(Shifted.Canvas.Handle,23,17,nil); FRenderer.Draw(Shifted.Canvas,Project,Probe.Page,Rect(0,0,450,525),False);
        finally RestoreDC(Shifted.Canvas.Handle,Saved); Shifted.Canvas.Refresh; end;
        Same:=True;
        for Y:=0 to 524 do if not CompareMem(Reference.ScanLine[Y],
          Pointer(NativeUInt(Shifted.ScanLine[Y+17])+23*3),450*3) then Same:=False;
        if not Same then begin
          Reference.SaveToFile(TPath.Combine(Folder,'contour-reference.bmp'));
          Shifted.SaveToFile(TPath.Combine(Folder,'contour-translated.bmp'));
        end;
        Check(Same,LabelText+' body tails border and text match under translated DC rendering');
        // A tail rooted at the body center must not introduce a border seam inside the union.
        Check(Reference.Canvas.Pixels[215,240]=clWhite,LabelText+' merged tail has no internal border at its root');
        Before:=Project.Snapshot; Project.Save; Reloaded:=TComicProject.Create;
        try Reloaded.Load(TPath.Combine(Project.Folder,'Project.json'));
          Check(Reloaded.Snapshot=Before,LabelText+' saves and reloads without changing text or tail identity');
        finally Reloaded.Free; end;
        SelectBalloon; Before:=Project.Snapshot; History:=Probe.FUndo.Count;
        Probe.FContour.ItemIndex:=0; Probe.ApplyText(nil); After:=Project.Snapshot;
        Check((Probe.Page.Balloons[0].Contour=bcPlain) and (Probe.FUndo.Count=History+1),LabelText+' setting applies as one undo operation');
        Probe.Undo(nil); Check(Project.Snapshot=Before,LabelText+' undo restores the original compound balloon');
        Probe.Redo(nil); Check(Project.Snapshot=After,LabelText+' redo restores the chosen contour'); Probe.Undo(nil);
      end;
      Balloon:=Probe.Page.Balloons[0]; Balloon.Contour:=bcCloud;
      J:=Balloon.Json; Pair:=J.RemovePair('contour'); Pair.Free; Legacy:=TComicBalloon.Create;
      try Legacy.Read(J); Check(Legacy.Contour=bcPlain,'missing contour in existing version 3 data defaults to plain');
        for Index:=0 to 3 do begin
          Pair:=J.RemovePair('contour'); Pair.Free;
          case Index of
            0: J.AddPair('contour',TJSONNumber.Create(-1)); 1: J.AddPair('contour',TJSONNumber.Create(4));
            2: J.AddPair('contour',TJSONNumber.Create(1.5)); 3: J.AddPair('contour',TJSONString.Create('cloud'));
          end;
          Failed:=False; try Legacy.Read(J); except Failed:=True; end;
          Check(Failed,'invalid contour is rejected '+IntToStr(Index));
        end;
      finally Legacy.Free; J.Free; end;
      // All three variants remain compound objects during normal VCL drag/resize and cancellation.
      for PPI in [96,144] do for Kind:=1 to 3 do begin
        Probe.Scaled:=True; Probe.ScaleForPPI(PPI); Probe.Scaled:=False;
        Probe.Width:=MulDiv(940,PPI,96); Probe.Height:=MulDiv(660,PPI,96); Probe.Realign;
        Balloon:=Probe.Page.Balloons[0]; Balloon.Contour:=TComicBalloonContour(Kind); SelectBalloon; PaintProbe;
        Before:=Project.Snapshot; Bounds:=Balloon.Bounds; Q:=Bounds.BottomRight;
        X:=Probe.FPageRect.Left+Round(Q.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(Q.Y*Probe.FScale);
        Probe.FCanvas.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(X,Y));
        Probe.FCanvas.Perform(WM_MOUSEMOVE,MK_LBUTTON,MakeLParam(X+20,Y+15));
        Probe.FCanvas.Perform(WM_LBUTTONUP,0,MakeLParam(X+20,Y+15));
        Balloon:=Probe.Page.Balloons[0]; LabelText:=Format('contour %d at PPI %d',[Kind,PPI]);
        Check((Balloon.Contour=TComicBalloonContour(Kind)) and (Balloon.Bounds.Width>Bounds.Width) and
          (Balloon.BorderWidth=3) and (Balloon.Tails.Count=1),LabelText+' resize preserves contour and fixed border with its owned tail');
        Probe.Undo(nil); Check(Project.Snapshot=Before,LabelText+' resize undo restores all compound data');
        SelectBalloon; PaintProbe; Q:=Probe.Page.Balloons[0].Bounds.CenterPoint;
        X:=Probe.FPageRect.Left+Round(Q.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(Q.Y*Probe.FScale);
        Probe.FCanvas.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(X,Y));
        Probe.FCanvas.Perform(WM_MOUSEMOVE,MK_LBUTTON,MakeLParam(X+20,Y+15));
        KeyValue:=VK_ESCAPE; Probe.Key(Probe,KeyValue,[]);
        Check((Project.Snapshot=Before) and not Probe.FDragging,LabelText+' escape cancels the entire compound move');
        TScrollBox(Probe.FContour.Parent).ScrollInView(Probe.FContour); PaintProbe;
        Check(Probe.FContour.ClientToScreen(Point(0,0)).Y>=Probe.FContour.Parent.ClientToScreen(Point(0,0)).Y,
          LabelText+' contour choice can be reached by scrolling the narrow settings panel');
      end;
      Balloon:=Probe.Page.Balloons[0]; Balloon.Contour:=bcCloud; Balloon.Text:=''; Balloon.FillColor:=clYellow;
      Balloon.Overflow:=True; Panel:=Probe.Page.Panels[0]; Panel.Bounds:=TRectF.Create(30,30,600,720);
      FRenderer.Draw(Reference.Canvas,Project,Probe.Page,Rect(0,0,450,525),False);
      Check(Reference.Canvas.Pixels[354,365]=clYellow,'contour and tail overflow together above the panel edge');
      Balloon.Overflow:=False; FRenderer.Draw(Reference.Canvas,Project,Probe.Page,Rect(0,0,450,525),False);
      Check(Reference.Canvas.Pixels[354,365]=clWhite,'owner clipping covers decorated body and tail together');
      Balloon.Overflow:=True; Balloon.Transparent:=True;
      FRenderer.Draw(Reference.Canvas,Project,Probe.Page,Rect(0,0,450,525),False);
      Check(Reference.Canvas.Pixels[354,365]=clWhite,'text-only output hides decorated body and every tail');
      Balloon.Transparent:=False; Balloon.FillColor:=clWhite; Balloon.Text:='雲形'; SelectBalloon;
      Check(ExportSequence(Project,Probe.FRenderer,False)=1,'decorated balloon first export renders its page');
      Check(ExportSequence(Project,Probe.FRenderer,False)=0,'unchanged decorated balloon reuses its PNG');
      Probe.FContour.ItemIndex:=1; Probe.ApplyText(nil);
      Check(ExportSequence(Project,Probe.FRenderer,False)=1,'contour edit invalidates the page PNG');
      Probe.Undo(nil); Check(ExportSequence(Project,Probe.FRenderer,False)=1,'undo after contour export redraws restored content');
      // Keep one gallery using the same fixture image for every basic shape and contour.
      Probe.Page.Balloons.Clear; Panel:=Probe.Page.Panels[0]; Panel.Bounds:=TRectF.Create(30,30,870,1020);
      for Shape:=0 to 2 do for Kind:=1 to 3 do begin
        Balloon:=TComicBalloon.Create; Balloon.Shape:=Shape; Balloon.Contour:=TComicBalloonContour(Kind); Balloon.PanelID:=Panel.ID;
        X:=55+(Kind-1)*275; Y:=70+Shape*315; Balloon.Bounds:=TRectF.Create(X,Y,X+235,Y+230);
        Balloon.FontSize:=25; Balloon.Text:=ShapeNames[Shape]+sLineBreak+ContourNames[Kind]; Probe.Page.Balloons.Add(Balloon);
        Tail:=TComicTail.Create; Tail.Root:=Balloon.Bounds.CenterPoint; Tail.Tip:=TPointF.Create(X+200,Y+275); Tail.Width:=32; Balloon.Tails.Add(Tail);
      end;
      Project.Save; FRenderer.ExportPage(Project,Probe.Page,TPath.Combine(Folder,'balloon-contours.png'));
      AtomicWrite(TPath.Combine(Folder,'contour-sample-project.txt'),TPath.Combine(Project.Folder,'Project.json'));
      // Tiny previews and narrow bodies must remain valid GDI objects without changing the model.
      Balloon:=Probe.Page.Balloons[0]; Before:=Project.Snapshot;
      Body:=BalloonBodyRegion(Balloon,Point(0,0),0.01);
      try Check(Body<>0,'tiny decorated balloon preview creates a valid region'); finally Winapi.Windows.DeleteObject(Body); end;
      Check(Project.Snapshot=Before,'previewing contours never mutates the saved model');
    finally Shifted.Free; Reference.Free; Probe.Free; end;
  end;
  procedure CreatedPanelSelectionChecks;
  var Probe: TMainForm; Project,Reloaded: TComicProject; Panel: TComicPanel; Initial,Before,AID,BID,DID,CID: string;
    X,Y,Kind: Integer;
    procedure Tool(Tag: Integer);
    var Button: TComicIconButton;
    begin
      for Button in Probe.FIconButtons do if (Button.Role=brTool) and (Button.Context=1) and (Button.Tag=Tag) then begin Button.Click; Exit; end;
    end;
    procedure Click(PX,PY: Integer; Ctrl: Boolean=False);
    var Flags: Integer;
    begin
      X:=Probe.FPageRect.Left+Round(PX*Probe.FScale); Y:=Probe.FPageRect.Top+Round(PY*Probe.FScale);
      Flags:=MK_LBUTTON; if Ctrl then Flags:=Flags or MK_CONTROL;
      Probe.FCanvas.Perform(WM_LBUTTONDOWN,Flags,MakeLParam(X,Y)); Probe.FCanvas.Perform(WM_LBUTTONUP,0,MakeLParam(X,Y));
    end;
  begin
    Probe:=TMainForm.Create(nil);
    try
      Project:=TComicProject.Create; Project.Initialize('新規コマ選択 fixture','1'); Probe.AdoptProject(Project,False);
      Project.ImportImage(TPath.Combine(Folder,'reference.bmp'),'');
      Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(100,100,300,300); AID:=Panel.ID; Probe.Page.Panels.Add(Panel);
      Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(400,100,600,300); BID:=Panel.ID; Probe.Page.Panels.Add(Panel);
      Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(100,600,300,800); DID:=Panel.ID; Probe.Page.Panels.Add(Panel);
      Initial:=Project.Snapshot; Probe.RefreshUI; Probe.FTabs.ActivePageIndex:=1; Probe.TabChanged(nil);
      for Kind in [1,8] do begin
        Project.Restore(Initial); Probe.FUndo.Clear; Probe.FRedo.Clear; Probe.FSelectedPanels.Clear; Probe.FPanelIndex:=-1;
        Probe.RefreshUI; Probe.HandleNeeded; B.SetSize(Probe.ClientWidth,Probe.ClientHeight); Probe.PaintTo(B.Canvas,0,0);
        Tool(0); Click(200,200); Click(500,200,True);
        Check(Length(Probe.SelectedPanelIDs)=2,'creation fixture starts with a real two-panel selection '+IntToStr(Kind));
        Tool(Kind); Click(650,600);
        if Kind=1 then Click(850,800) else begin Click(850,600); Click(850,800); Click(650,600); end;
        Check(Probe.Page.Panels.Count=4,'creation fixture creates the new rectangle or polygon '+IntToStr(Kind));
        CID:=Probe.Page.Panels[3].ID;
        Check((Length(Probe.SelectedPanelIDs)=1) and (Probe.SelectedPanelIDs[0]=CID) and
          (Probe.FSelectedPanels.Count=1) and Probe.FSelectedPanels.Contains(CID),
          'newly created panel replaces both primary and UID selection '+IntToStr(Kind));
        Tool(0); Click(200,700,True);
        Check((Length(Probe.SelectedPanelIDs)=2) and Probe.FSelectedPanels.Contains(CID) and Probe.FSelectedPanels.Contains(DID) and
          not Probe.FSelectedPanels.Contains(AID) and not Probe.FSelectedPanels.Contains(BID),
          'control click after creation adds only the new panel and requested existing panel '+IntToStr(Kind));
        Before:=Project.Snapshot; Probe.DeleteObject(nil);
        Check((Probe.Page.Panels.Count=2) and (Probe.Page.Panels[0].ID=AID) and (Probe.Page.Panels[1].ID=BID),
          'delete after creation cannot remove a stale previous group '+IntToStr(Kind));
        Probe.Undo(nil); Check(Project.Snapshot=Before,'undo restores only the correctly deleted new selection '+IntToStr(Kind));
        Project.Save; Reloaded:=TComicProject.Create;
        try Reloaded.Load(TPath.Combine(Project.Folder,'Project.json')); Check(Reloaded.Snapshot=Before,'creation selection regression saves and reloads '+IntToStr(Kind));
        finally Reloaded.Free; end;
      end;
    finally Probe.Free; end;
  end;
  procedure FontStyleChecks;
  var Probe: TMainForm; Project,Reloaded: TComicProject; Balloon: TComicBalloon; Dialog: TComicTextDialog;
    History,CopyHistory: TComicFontHistory; FontFile,Path,Before,Choices: string; OriginalBytes: TBytes;
    Existed,Failed: Boolean; Lock: THandle; I,X,Y,RedPixels: Integer; PNG: TPngImage; KeyValue: Word;
  begin
    FontFile:=TPath.Combine(DataRoot,'Presets\FontHistory.json'); Existed:=FileExists(FontFile);
    if Existed then OriginalBytes:=TFile.ReadAllBytes(FontFile);
    Probe:=TMainForm.Create(nil); History:=TComicFontHistory.Create; CopyHistory:=TComicFontHistory.Create; PNG:=TPngImage.Create;
    try
      Project:=TComicProject.Create; Project.Initialize('文字装飾 fixture','1'); Probe.AdoptProject(Project,False);
      Balloon:=TComicBalloon.Create; Balloon.Transparent:=True; Balloon.Bounds:=TRectF.Create(100,100,900,1300);
      Probe.Page.Balloons.Add(Balloon); Probe.RefreshUI; Probe.FTabs.ActivePageIndex:=3; Probe.TabChanged(nil); Probe.FBalloonIndex:=0;
      Probe.LoadBalloonControls(Balloon); Before:=Project.Snapshot; Choices:=Probe.FFontFamily.Items.Text;
      Probe.FFontFamily.ItemIndex:=Probe.FFontFamily.Items.IndexOf('Consolas');
      Check(Probe.FFontFamily.ItemIndex>=0,'font selector offers installed Consolas');
      Probe.FFontBold.Checked:=True; Probe.FFontItalic.Checked:=True; Probe.FFontUnderline.Checked:=True; Probe.FFontStrikeOut.Checked:=True;
      Probe.FTextColor:=clRed; Probe.FText.Text:='Style 12 日本語'; Probe.ApplyText(nil);
      Check((Probe.Page.Balloons[0].FontFamily='Consolas') and (Probe.Page.Balloons[0].FontColor=clRed) and
        (Probe.Page.Balloons[0].FontStyle=[fsBold,fsItalic,fsUnderline,fsStrikeOut]),
        'applying balloon text stores family color and uniform decorations together');
      Check(Probe.FFontFamily.Items.Text=Choices,'recording a used font keeps the open font-selector order unchanged');
      Probe.FontDropDown(nil);
      Check((Probe.FFontFamily.Items[0]='Consolas') and (Probe.FFontFamily.Text='Consolas'),
        'next font dropdown places usage history first while retaining current selection');
      Project.Save; Reloaded:=TComicProject.Create;
      try Reloaded.Load(TPath.Combine(Project.Folder,'Project.json'));
        Check((Reloaded.Pages[0].Balloons[0].FontFamily='Consolas') and (Reloaded.Pages[0].Balloons[0].FontColor=clRed) and
          (Reloaded.Pages[0].Balloons[0].FontStyle=[fsBold,fsItalic,fsUnderline,fsStrikeOut]),
          'balloon font family color and all decorations survive save and reload');
      finally Reloaded.Free; end;
      B.SetSize(600,850); FRenderer.Draw(B.Canvas,Project,Probe.Page,Rect(0,0,600,850),False); RedPixels:=0;
      for X:=0 to 599 do for Y:=0 to 849 do if B.Canvas.Pixels[X,Y]=clRed then Inc(RedPixels);
      Check(RedPixels>0,'completed page renderer uses the stored text color'); PNG.Assign(B); PNG.SaveToFile(TPath.Combine(Folder,'text-font-style.png'));
      Probe.Undo(nil); Check(Project.Snapshot=Before,'one undo restores original text and every font attribute');
      Probe.Redo(nil); Probe.FBalloonIndex:=0; Probe.LoadBalloonControls(Probe.Page.Balloons[0]);
      Dialog:=Probe.CreateBalloonTextDialog;
      try
        Check((Dialog.Editor.Font.Name='Consolas') and (Dialog.Editor.Font.Color=clRed) and
          (Dialog.Editor.Font.Style=[fsBold,fsItalic,fsUnderline,fsStrikeOut]),
          'dedicated input receives the selected balloon font color and decoration');
        Before:=Project.Snapshot; KeyValue:=VK_ESCAPE; Dialog.KeyDown(KeyValue,[]); Probe.FinishTextDialog(Dialog);
        Check(Project.Snapshot=Before,'canceling styled dedicated input preserves the balloon');
      finally Dialog.Free; end;
      Path:=TPath.Combine(Folder,'font-history.json'); History.Remember('Yu Gothic',Path); History.Remember('Consolas',Path); History.Remember('Yu Gothic',Path);
      Check((Length(History.Names)=2) and (History.Names[0]='Yu Gothic'),'font history moves reused families to the front without duplication');
      CopyHistory.Load(Path); Check(string.Join('|',CopyHistory.Names)=string.Join('|',History.Names),'font usage history survives UTF-8 save and reload');
      Before:=string.Join('|',History.Names); Lock:=CreateFile(PChar(Path),GENERIC_READ,FILE_SHARE_READ,nil,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,0);
      Check(Lock<>INVALID_HANDLE_VALUE,'font-history publication failure can be injected with a file lock');
      try Failed:=False; try History.Remember('Segoe UI',Path); except Failed:=True; end;
        Check(Failed and (string.Join('|',History.Names)=Before),'failed font-history save restores the original usage order');
      finally CloseHandle(Lock); end;
      AtomicWrite(Path,'["valid-prefix",42]'); Failed:=False; try History.Load(Path); except Failed:=True; end;
      Check(Failed and (string.Join('|',History.Names)=Before),'malformed font history cannot replace valid state with a partial prefix');
      for I:=1 to 15 do History.Remember('font-'+IntToStr(I),Path);
      Check((Length(History.Names)=10) and (History.Names[0]='font-15'),'font usage history keeps only its ten most recent families');
    finally
      PNG.Free; CopyHistory.Free; History.Free; Probe.Free;
      if Existed then TFile.WriteAllBytes(FontFile,OriginalBytes) else if FileExists(FontFile) then TFile.Delete(FontFile);
    end;
  end;
  procedure LayoutManagementChecks;
  var TemplateList,CopyLibrary: TObjectList<TComicLayout>; Layout: TComicLayout; Applied: TComicProject;
    Path,ID,Before,ProjectBefore,TemplateJson: string; Bounds: TRectF; Lock: THandle; Failed,Writable: Boolean;
    Button: TComicIconButton; Index: Integer; J: TJSONObject;
  begin
    TemplateList:=TObjectList<TComicLayout>.Create; CopyLibrary:=TObjectList<TComicLayout>.Create;
    Applied:=TComicProject.Create; ProjectBefore:=FProject.Snapshot;
    try
      SeedLayouts(TemplateList); Layout:=TComicLayout.Create; Layout.Name:='管理テスト'; Layout.Capture(FProject,Page);
      TemplateList.Add(Layout); ID:=Layout.ID; Bounds:=Layout.Panels[0].Bounds; Path:=TPath.Combine(Folder,'managed-layouts.json');
      SaveLayouts(TemplateList,Path); Applied.Pages.Add(TComicPage.Create); Layout.Apply(Applied.Pages[0],1200,1700);
      RenameLayout(TemplateList,Layout,'日本語に名前変更',Path);
      Check((Layout.ID=ID) and (Layout.Name='日本語に名前変更') and (Layout.Panels[0].Bounds=Bounds),
        'template rename preserves identity and captured geometry');
      SeedLayouts(CopyLibrary); LoadLayouts(CopyLibrary,Path);
      Check((CopyLibrary.Count=6) and (CopyLibrary.Last.ID=ID) and (CopyLibrary.Last.Name=Layout.Name),
        'renamed template reloads with its stable identity');
      Before:=TFile.ReadAllText(Path,TEncoding.UTF8); Failed:=False;
      try RenameLayout(TemplateList,TemplateList[0],'変更禁止',Path); except Failed:=True; end;
      Check(Failed and (TFile.ReadAllText(Path,TEncoding.UTF8)=Before),'built-in template rename is rejected before persistence');
      Failed:=False; try RenameLayout(TemplateList,Layout,' ',Path); except Failed:=True; end;
      Check(Failed and (Layout.Name='日本語に名前変更'),'empty template rename leaves the previous name intact');
      Failed:=False; try RenameLayout(TemplateList,Layout,TemplateList[0].Name,Path); except Failed:=True; end;
      Check(Failed and (Layout.ID=ID),'duplicate template names are rejected without losing identity');
      Lock:=CreateFile(PChar(Path),GENERIC_READ,FILE_SHARE_READ,nil,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,0);
      Check(Lock<>INVALID_HANDLE_VALUE,'template library locks can inject publication failure');
      try
        Failed:=False; try RenameLayout(TemplateList,Layout,'書込失敗',Path); except Failed:=True; end;
        Check(Failed and (Layout.Name='日本語に名前変更') and (TFile.ReadAllText(Path,TEncoding.UTF8)=Before),
          'failed template rename restores memory and retains the original library');
        Failed:=False; try RemoveLayout(TemplateList,Layout,Path); except Failed:=True; end;
        Check(Failed and (TemplateList.Count=6) and (TemplateList[5]=Layout) and (TemplateList[5].ID=ID),
          'failed template deletion restores the exact item and list order');
      finally CloseHandle(Lock); end;
      J:=Layout.Json; try TemplateJson:=J.ToJSON; finally J.Free; end;
      Before:=Applied.Snapshot; RemoveLayout(TemplateList,Layout,Path);
      Check((TemplateList.Count=5) and (Applied.Snapshot=Before),'deleting a common template retains previously applied page contents');
      Failed:=False; try RemoveLayout(TemplateList,TemplateList[0],Path); except Failed:=True; end;
      Check(Failed and (TemplateList.Count=5),'built-in templates remain available after deletion attempts');
      Before:='{"version":2,"layouts":['+TemplateJson+',42]}'; AtomicWrite(Path,Before);
      Failed:=False; try LoadLayouts(TemplateList,Path); except Failed:=True; end;
      Check(Failed and (TemplateList.Count=5) and (TFile.ReadAllText(Path,TEncoding.UTF8)=Before),
        'invalid trailing template item cannot publish a valid prefix or overwrite the library');
      Layout:=TComicLayout.Create; Layout.Name:='UI管理 fixture'; Layout.Capture(FProject,Page); FLayouts.Add(Layout);
      Index:=FLayouts.Count-1; RefreshLayouts(Index);
      for Button in FIconButtons do if Button.Role=brManageLayout then Check(Button.Enabled,'custom template enables its management button '+Button.Caption);
      Writable:=FLayoutLibraryWritable; FLayoutLibraryWritable:=False; UpdateIconState;
      for Button in FIconButtons do if Button.Role=brManageLayout then Check(not Button.Enabled,'unreadable template library disables management '+Button.Caption);
      FLayoutLibraryWritable:=Writable; FLayouts.Extract(Layout); RefreshLayouts(0); Layout.Free;
      Check(FProject.Snapshot=ProjectBefore,'template management and persistence failures preserve the active project');
    finally Applied.Free; CopyLibrary.Free; TemplateList.Free; end;
  end;
  procedure PanelGroupChecks;
  var Probe: TMainForm; Project,Reloaded: TComicProject; Panel: TComicPanel; Balloon: TComicBalloon;
    IDs: TArray<string>; Items: TArray<TComicPanelTransform>; Original,Target,OtherBounds: TRectF;
    Before,BaseModel,FirstID,SecondID,ThirdID,ImageID: string; KeyValue: Word; K,X,Y,PPI,History: Integer;
    PNG: TPngImage; Point: TPointF;
    procedure CaptureGroup(const Name: string);
    begin
      Probe.HandleNeeded; B.SetSize(Probe.ClientWidth,Probe.ClientHeight); Probe.PaintTo(B.Canvas,0,0);
      PNG.Assign(B); PNG.SaveToFile(TPath.Combine(Folder,Name+'.png'));
    end;
    procedure ClickPanel(Index: Integer; Ctrl: Boolean=False);
    var Center: TPointF; Flags: Integer;
    begin
      Center:=Probe.Page.Panels[Index].Bounds.CenterPoint;
      // The triangle's bounding-box center lies on its sloping inside edge;
      // move upward so every DPI has an unambiguous actual-shape hit.
      if Index=1 then Center.Y:=Probe.Page.Panels[Index].Bounds.Top+Probe.Page.Panels[Index].Bounds.Height/3;
      X:=Probe.FPageRect.Left+Round(Center.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(Center.Y*Probe.FScale);
      Flags:=MK_LBUTTON; if Ctrl then Flags:=Flags or MK_CONTROL;
      Probe.FCanvas.Perform(WM_LBUTTONDOWN,Flags,MakeLParam(X,Y)); Probe.FCanvas.Perform(WM_LBUTTONUP,0,MakeLParam(X,Y));
    end;
    procedure SelectPair;
    begin
      X:=Probe.FPageRect.Left+Round(1100*Probe.FScale); Y:=Probe.FPageRect.Top+Round(1600*Probe.FScale);
      Probe.FCanvas.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(X,Y)); Probe.FCanvas.Perform(WM_LBUTTONUP,0,MakeLParam(X,Y));
      ClickPanel(0); ClickPanel(1,True);
    end;
  begin
    Probe:=TMainForm.Create(nil); PNG:=TPngImage.Create;
    try
      Project:=TComicProject.Create; Project.Initialize('複数コマ fixture','1'); Probe.AdoptProject(Project,False);
      ImageID:=Project.ImportImage(TPath.Combine(Folder,'reference.bmp'),'').ID;
      Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(100,100,500,500); Panel.ImageID:=ImageID; Panel.PanX:=20; Panel.PanY:=10;
      FirstID:=Panel.ID; Probe.Page.Panels.Add(Panel);
      Panel:=TComicPanel.Create; Panel.SetVertices([TPointF.Create(650,150),TPointF.Create(1000,150),TPointF.Create(900,550)]);
      Panel.ImageID:=ImageID; SecondID:=Panel.ID; Probe.Page.Panels.Add(Panel);
      Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(100,800,500,1200); Panel.Shape:=1; ThirdID:=Panel.ID;
      Probe.Page.Panels.Add(Panel); OtherBounds:=Panel.Bounds;
      Balloon:=TComicBalloon.Create; Balloon.PanelID:=FirstID; Balloon.Text:='選択側'; Probe.Page.Balloons.Add(Balloon);
      Balloon:=TComicBalloon.Create; Balloon.PanelID:=ThirdID; Balloon.Text:='保持側'; Probe.Page.Balloons.Add(Balloon);
      Probe.RefreshUI; Probe.FTabs.ActivePageIndex:=1; Probe.TabChanged(nil); Before:=Project.Snapshot; BaseModel:=Before; History:=Probe.FUndo.Count;
      CaptureGroup('panel-group-initial'); SelectPair;
      Check((Length(Probe.SelectedPanelIDs)=2) and (Project.Snapshot=Before) and (Probe.FUndo.Count=History),
        'real control-clicks select two panels without changing project or history');
      ClickPanel(1,True); Check(Length(Probe.SelectedPanelIDs)=1,'control-click toggles a selected panel off'); ClickPanel(1,True);
      Original:=Probe.SelectedPanelBounds; CaptureGroup('panel-group-selected');
      Check((Original.Left=100) and (Original.Top=100) and (Original.Right=1000) and (Original.Bottom=550),
        'multiple panels expose one combined outer selection rectangle');
      for K:=1 to 8 do begin
        if K>1 then SelectPair;
        Original:=Probe.SelectedPanelBounds; Point:=EditHandles(Original)[K-1];
        X:=Probe.FPageRect.Left+Round(Point.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(Point.Y*Probe.FScale);
        Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y);
        Check((Probe.FDragHandle=K) and (Length(Probe.FDragGroup)=2) and (Probe.FDragVertex=-1),
          'group outer handle '+IntToStr(K)+' starts a shared transform');
        Probe.MouseMove(Probe.FCanvas,[ssLeft],X+18,Y+11); Probe.MouseUp(Probe.FCanvas,mbLeft,[],X+18,Y+11);
        Check((Probe.Page.Panels[2].Bounds=OtherBounds) and (Probe.Page.Panels[0].ID=FirstID) and
          (Probe.Page.Panels[1].ID=SecondID) and ValidPolygon(Probe.Page.Panels[1].Vertices) and
          (Probe.Page.Panels[0].ImageID=ImageID), 'group handle '+IntToStr(K)+' keeps identities images and unselected geometry');
        Probe.Undo(nil); Check(Project.Snapshot=Before,'group handle '+IntToStr(K)+' undoes all members as one edit');
      end;
      SelectPair; Original:=Probe.SelectedPanelBounds; Point:=Original.CenterPoint;
      X:=Probe.FPageRect.Left+Round(Point.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(Point.Y*Probe.FScale);
      Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y); Check(Length(Probe.FDragGroup)=2,'dragging the gap inside a group starts a whole-selection move');
      Probe.MouseMove(Probe.FCanvas,[ssLeft],X+25,Y+18); KeyValue:=VK_ESCAPE; Probe.Key(Probe,KeyValue,[]);
      Check((Project.Snapshot=Before) and (Probe.FUndo.Count=0) and not Probe.FDragging,
        'escape cancels every group member without leaving history or partial geometry');
      SelectPair; IDs:=Probe.SelectedPanelIDs; Items:=CapturePanelTransforms(Probe.Page,IDs); Original:=PanelGroupBounds(Items);
      Target:=TRectF.Create(Original.Left+20,Original.Top+30,Original.Left+20+Original.Width*1.4,Original.Top+30+Original.Height*0.8);
      Check(ApplyPanelGroupTransform(Probe.Page,Items,Original,Target),'group model accepts independent horizontal and vertical scaling');
      Check((Abs(Probe.Page.Panels[0].Bounds.Width-560)<0.001) and (Abs(Probe.Page.Panels[0].Bounds.Height-320)<0.001) and
        (Abs(Probe.Page.Panels[0].PanX-28)<0.001) and (Abs(Probe.Page.Panels[0].PanY-8)<0.001),
        'group proportions scale panel sizes spacing and relative image pan independently');
      Check((Items[0].Bounds.Width=400) and (Items[1].Vertices[0].X=650),'group source transforms own stable original geometry for repeated drag updates');
      Project.Save; Reloaded:=TComicProject.Create;
      try Reloaded.Load(TPath.Combine(Project.Folder,'Project.json')); Check(Reloaded.Snapshot=Project.Snapshot,'mixed-shape group transforms survive save and reload');
      finally Reloaded.Free; end;
      Project.Restore(Before); Probe.RefreshUI; SelectPair;
      Probe.DeleteObject(nil); Check((Probe.Page.Panels.Count=1) and (Probe.Page.Panels[0].ID=ThirdID) and
        (Probe.Page.Balloons.Count=1) and (Probe.Page.Balloons[0].Text='保持側') and (Project.Assets.Count=1),
        'group deletion removes selected owners and their balloons while retaining other content and source images');
      Probe.Undo(nil); Check(Project.Snapshot=Before,'one undo restores deleted panel group and owned balloons');
      Probe.ActiveControl:=Probe.FView; KeyValue:=Ord('A'); Probe.Key(Probe,KeyValue,[ssCtrl]);
      Check(Length(Probe.SelectedPanelIDs)=3,'control A in the panel canvas selects every panel');
      KeyValue:=VK_DELETE; Probe.Key(Probe,KeyValue,[]);
      Check((Probe.Page.Panels.Count=0) and (Probe.Page.Balloons.Count=0) and (Project.Assets.Count=1),
        'delete key removes the whole canvas selection as one edit'); Probe.Undo(nil);
      Probe.Page.Panels[1].SetVertices([TPointF.Create(650,150),TPointF.Create(1000,550),TPointF.Create(998,550)]);
      IDs:=[FirstID,SecondID]; Items:=CapturePanelTransforms(Probe.Page,IDs); Original:=PanelGroupBounds(Items); Before:=Project.Snapshot;
      Target:=TRectF.Create(Original.Left,Original.Top,Original.Left+Original.Width/100,Original.Top+Original.Height/100);
      Check(not ApplyPanelGroupTransform(Probe.Page,Items,Original,Target) and (Project.Snapshot=Before),
        'one invalid thin member rejects the entire group transform atomically');
      Project.Restore(BaseModel); Before:=BaseModel; Probe.RefreshUI;
      for PPI in [96,144] do begin
        Probe.Scaled:=True; Probe.ScaleForPPI(PPI); Probe.Scaled:=False;
        Probe.Width:=MulDiv(940,PPI,96); Probe.Height:=MulDiv(660,PPI,96); Probe.Realign;
        Probe.FSelectedPanels.Clear; Probe.FPanelIndex:=-1; CaptureGroup('panel-group-dpi'+IntToStr(PPI)+'-before');
        SelectPair; Check(Length(Probe.SelectedPanelIDs)=2,'group selection uses VCL control-clicks at PPI '+IntToStr(PPI));
        Original:=Probe.SelectedPanelBounds; Point:=EditHandles(Original)[4];
        X:=Probe.FPageRect.Left+Round(Point.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(Point.Y*Probe.FScale);
        History:=Probe.FUndo.Count; Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y);
        Probe.MouseMove(Probe.FCanvas,[ssLeft],X+MulDiv(12,PPI,96),Y+MulDiv(20,PPI,96));
        Probe.MouseUp(Probe.FCanvas,mbLeft,[],X+MulDiv(12,PPI,96),Y+MulDiv(20,PPI,96));
        Check((Probe.FUndo.Count=History+1) and ValidPolygon(Probe.Page.Panels[1].Vertices),
          'group resize remains valid and commits once at PPI '+IntToStr(PPI));
        CaptureGroup('panel-group-dpi'+IntToStr(PPI)+'-after'); Probe.Undo(nil);
        Check(Project.Snapshot=Before,'group DPI resize restores all original members on undo '+IntToStr(PPI));
      end;
    finally PNG.Free; Probe.Free; end;
  end;
  procedure PageBasisChecks;
  var Probe: TMainForm; Project,Reloaded: TComicProject; Basis,OriginalBasis,Invalid: TComicPageBasis;
    Bounds: TRectF; Presets,CopyPresets: TObjectList<TComicPagePreset>; Dialog: TComicPageDialog;
    Preset: TComicPagePreset; Path,Before,Name,ID: string; Lock: THandle; KeyValue: Word;
    Failed: Boolean; History,I,PPI: Integer; Snap: TPointF; PNG: TPngImage;
  begin
    Probe:=TMainForm.Create(nil); Presets:=TObjectList<TComicPagePreset>.Create;
    CopyPresets:=TObjectList<TComicPagePreset>.Create; PNG:=TPngImage.Create;
    try
      Project:=TComicProject.Create; Project.Initialize('ページ基準 fixture','1'); Probe.AdoptProject(Project,False);
      Preset:=TComicPagePreset.Create; try OriginalBasis:=Preset.Basis; finally Preset.Free; end;
      Check(Project.PageBasis.Same(OriginalBasis),'new projects use the standard shared page basis');
      Project.Pages.Add(TComicPage.Create);
      P:=TComicPanel.Create; P.Bounds:=TRectF.Create(100,100,1100,1500); P.ImageID:=Project.ImportImage(TPath.Combine(Folder,'reference.bmp'),'').ID;
      Project.Pages[0].Panels.Add(P); Bounds:=P.Bounds;
      Check(ExportSequence(Project,Probe.FRenderer,False)=2,'page-basis fixture exports both initial pages');
      Basis:=OriginalBasis; Basis.Width:=600; Basis.Height:=850; Basis.Left:=32; Basis.Top:=40; Basis.Right:=44; Basis.Bottom:=48;
      Probe.ApplyPageBasis(Basis);
      Check(Project.PageBasis.Same(Basis) and (Project.Pages[0].Panels[0].Bounds=Bounds) and (Project.Pages.Count=2),
        'page basis applies to all pages while retaining existing object coordinates');
      Snap:=Probe.SnapCreationPoint(TPointF.Create(33,41));
      Check((Snap.X=32) and (Snap.Y=40),'creation snaps to the configured shared page frame');
      Project.Save; Reloaded:=TComicProject.Create;
      try Reloaded.Load(TPath.Combine(Project.Folder,'Project.json'));
        Check(Reloaded.PageBasis.Same(Basis),'page resolution and all four margins survive save and reload');
      finally Reloaded.Free; end;
      Check(ExportSequence(Project,Probe.FRenderer,False)=2,'page resolution change invalidates every rendered page');
      Basis.Left:=36; Probe.ApplyPageBasis(Basis);
      Check(ExportSequence(Project,Probe.FRenderer,False)=0,'guide-only margin change preserves completed PNG cache');
      History:=Probe.FUndo.Count; Probe.ApplyPageBasis(Basis);
      Check(Probe.FUndo.Count=History,'applying the same page basis does not create an undo entry');
      Before:=Project.Snapshot; Invalid:=Basis; Invalid.Right:=600; Failed:=False;
      try Probe.ApplyPageBasis(Invalid); except Failed:=True; end;
      Check(Failed and (Project.Snapshot=Before) and (Probe.FUndo.Count=History),'invalid page margins are rejected before content or undo changes');
      Probe.Undo(nil); Check(Project.PageBasis.Left=32,'one undo restores the previous page frame');
      Probe.Redo(nil); Check(Project.PageBasis.Left=36,'page frame redo restores all settings together');
      Probe.Undo(nil); Probe.Undo(nil); Check(Project.PageBasis.Same(OriginalBasis),'page resolution undo restores the original shared basis');
      Probe.Redo(nil); Probe.Redo(nil); Check(Project.PageBasis.Same(Basis),'page resolution and frame survive chained redo');
      Probe.AddPage(nil); Check((Project.Pages.Count=3) and Project.PageBasis.Same(Basis),'new pages inherit the project page basis');
      SeedPagePresets(Presets); Path:=TPath.Combine(Folder,'page-bases-library.json');
      Dialog:=TComicPageDialog.CreateSettings(Self,Basis,Presets,Path,True);
      try
        Dialog.SelectPreset(0); KeyValue:=VK_ESCAPE; Dialog.KeyDown(KeyValue,[]);
        Check((Dialog.ModalResult=mrCancel) and Dialog.ResultBasis.Same(Basis) and Project.PageBasis.Same(Basis),
          'canceling a preset selection preserves project and original dialog result');
        Dialog.ModalResult:=0; Dialog.SetDraftBasis(Invalid); KeyValue:=VK_RETURN; Dialog.KeyDown(KeyValue,[]);
        Check(Dialog.ModalResult=0,'invalid page settings keep the dialog open for correction');
        Dialog.SetDraftBasis(Basis); Preset:=Dialog.RegisterPreset('日本語・ページ基準'); ID:=Preset.ID;
        LoadPagePresets(CopyPresets,Path);
        Check((CopyPresets.Count=1) and (CopyPresets[0].ID=ID) and CopyPresets[0].Basis.Same(Basis),
          'common page preset saves and reloads its identity dimensions and margins');
        Dialog.RenamePreset(1,'更新したページ基準'); Name:=Presets[1].Name;
        Check((Presets[1].ID=ID) and (Name='更新したページ基準'),'renaming a page preset preserves its identity');
        Lock:=CreateFile(PChar(Path),GENERIC_READ,FILE_SHARE_READ,nil,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,0);
        Check(Lock<>INVALID_HANDLE_VALUE,'page-preset library can be locked to inject publication failure');
        Before:=TFile.ReadAllText(Path,TEncoding.UTF8);
        try
          Failed:=False; try Dialog.RenamePreset(1,'失敗する名前'); except Failed:=True; end;
          Check(Failed and (Presets[1].Name=Name) and (TFile.ReadAllText(Path,TEncoding.UTF8)=Before),
            'failed page-preset rename restores memory and retains original library bytes');
          Failed:=False; try Dialog.RegisterPreset('失敗する追加'); except Failed:=True; end;
          Check(Failed and (Presets.Count=2) and (TFile.ReadAllText(Path,TEncoding.UTF8)=Before),
            'failed page-preset registration cannot publish a partial item');
          Failed:=False; try Dialog.RemovePreset(1); except Failed:=True; end;
          Check(Failed and (Presets.Count=2) and (Presets[1].ID=ID),
            'failed page-preset deletion restores the exact item and order');
        finally CloseHandle(Lock); end;
        Dialog.RemovePreset(1);
        Check((Presets.Count=1) and Project.PageBasis.Same(Basis),'deleting a common preset keeps the applied project snapshot');
        Failed:=False; try Dialog.RemovePreset(0); except Failed:=True; end;
        Check(Failed and (Presets.Count=1),'built-in page basis remains available after deletion attempts');
        Dialog.SetDraftBasis(Basis); KeyValue:=VK_RETURN; Dialog.KeyDown(KeyValue,[]);
        Check((Dialog.ModalResult=mrOK) and Dialog.ResultBasis.Same(Basis),'valid page settings commit the complete basis');
        for PPI in [96,144] do begin
          Dialog.Scaled:=True; Dialog.ScaleForPPI(PPI); Dialog.Scaled:=False;
          Dialog.ClientWidth:=MulDiv(650,PPI,96); Dialog.ClientHeight:=MulDiv(510,PPI,96); Dialog.Realign;
          Dialog.HandleNeeded; B.SetSize(Dialog.ClientWidth,Dialog.ClientHeight); Dialog.PaintTo(B.Canvas,0,0);
          PNG.Assign(B); PNG.SaveToFile(TPath.Combine(Folder,'page-basis-'+IntToStr(PPI)+'.png'));
          for I:=0 to Dialog.ComponentCount-1 do if Dialog.Components[I] is TButton then with TButton(Dialog.Components[I]) do
            Check((Left>=0) and (Top>=0) and (Left+Width<=Parent.ClientWidth) and (Top+Height<=Parent.ClientHeight),
              'page-basis button remains reachable at PPI '+IntToStr(PPI)+' '+Caption);
        end;
      finally Dialog.Free; end;
      J:=CopyPresets[0].Json;
      try Before:='{"version":1,"presets":['+J.ToJSON+',42]}'; finally J.Free; end;
      AtomicWrite(Path,Before); Failed:=False; try LoadPagePresets(Presets,Path); except Failed:=True; end;
      Check(Failed and (Presets.Count=1) and (TFile.ReadAllText(Path,TEncoding.UTF8)=Before),
        'malformed page-preset library cannot publish a valid prefix or alter the file');
      Dialog:=TComicPageDialog.CreateSettings(Self,Basis,Presets,Path,False);
      try
        Failed:=False; try Dialog.RegisterPreset('書込禁止'); except Failed:=True; end;
        Check(Failed and (TFile.ReadAllText(Path,TEncoding.UTF8)=Before),'unreadable page-preset library remains protected from registration');
        Dialog.SetDraftBasis(Basis); KeyValue:=VK_RETURN; Dialog.KeyDown(KeyValue,[]);
        Check((Dialog.ModalResult=mrOK) and Dialog.ResultBasis.Same(Basis),'project settings remain editable when common preset persistence is blocked');
      finally Dialog.Free; end;
    finally PNG.Free; CopyPresets.Free; Presets.Free; Probe.Free; end;
  end;
  procedure TextLayoutChecks;
  var Layout: TComicTextLayout; Cell: TComicTextCell; Sample,Joined: string;
    Tcy,Rotated,Clustered,Same: Boolean; Clone: TComicProject; Balloon: TComicBalloon;
    Reference,Shifted: TBitmap; PNG: TPngImage; X,Y,Saved: Integer;
  begin
    Layout:=TComicTextLayout.Create; Reference:=TBitmap.Create; Shifted:=TBitmap.Create;
    Clone:=TComicProject.Create; PNG:=TPngImage.Create;
    try
      B.Canvas.Font.Name:='Yu Gothic'; B.Canvas.Font.Height:=-32;
      Joined:=WideChar($D83D)+WideChar($DC69)+WideChar($200D)+WideChar($D83D)+WideChar($DCBB);
      Sample:='「12月、かなーABC」'+'か'+WideChar($3099)+Joined;
      Layout.Build(B.Canvas,Sample,Rect(16,16,500,500),True); Tcy:=False; Rotated:=False; Clustered:=False;
      for Cell in Layout.Cells do begin
        if Copy(Sample,Cell.Index+1,Cell.Count)='12' then Tcy:=Cell.TateChuYoko and (Cell.Count=2);
        if Copy(Sample,Cell.Index+1,Cell.Count)='ー' then Rotated:=Cell.Rotate;
        if Copy(Sample,Cell.Index+1,Cell.Count)=Joined then Clustered:=Cell.Count=5;
      end;
      Check(Tcy,'vertical layout places a two-digit number in one upright cell');
      Check(Rotated,'vertical layout rotates the prolonged sound mark');
      Check(Clustered,'shared layout retains a joined supplementary emoji in one cell');
      Check(Layout.CaretStop(2).Index=2,'vertical two-digit cell retains an insertion position between its digits');
      Layout.Build(B.Canvas,'漢漢、字',Rect(0,0,200,Layout.Step*2),True);
      Check((Layout.Cells[2].Line=0) and (Layout.Cells[3].Line=1),'basic Japanese wrapping keeps closing punctuation with its previous column');
      Layout.Build(B.Canvas,'漢「字',Rect(0,0,200,Layout.Step*2),True);
      Check((Layout.Cells[1].Line=1) and (Layout.Cells[2].Line=1),'basic Japanese wrapping keeps an opening bracket with its following character');
      Clone.Folder:=FProject.Folder; Clone.Restore(FProject.Snapshot);
      Clone.Pages[0].Panels.Clear; Clone.Pages[0].Balloons.Clear;
      Balloon:=TComicBalloon.Create; Balloon.Text:=Sample+#13#10+'縦書き。35歳！'; Balloon.Vertical:=True;
      Balloon.Transparent:=True; Balloon.Overflow:=True; Balloon.Bounds:=TRectF.Create(100,100,950,1500);
      Clone.Pages[0].Balloons.Add(Balloon); Reference.SetSize(600,850); Shifted.SetSize(750,950);
      FRenderer.Draw(Reference.Canvas,Clone,Clone.Pages[0],Rect(0,0,600,850),False);
      Saved:=SaveDC(Shifted.Canvas.Handle);
      try SetViewportOrgEx(Shifted.Canvas.Handle,75,50,nil);
        FRenderer.Draw(Shifted.Canvas,Clone,Clone.Pages[0],Rect(0,0,600,850),False);
      finally RestoreDC(Shifted.Canvas.Handle,Saved); Shifted.Canvas.Refresh; end;
      Same:=True;
      for X:=0 to 599 do for Y:=0 to 849 do if Reference.Canvas.Pixels[X,Y]<>Shifted.Canvas.Pixels[X+75,Y+50] then Same:=False;
      PNG.Assign(Reference); PNG.SaveToFile(TPath.Combine(Folder,'text-shared-vertical.png'));
      PNG.Assign(Shifted); PNG.SaveToFile(TPath.Combine(Folder,'text-shared-vertical-shifted.png'));
      Check(Same,'vertical rotations and shared text layout render identically under a translated DC');
      PNG.Assign(Reference); PNG.SaveToFile(TPath.Combine(Folder,'text-shared-vertical.png'));
      Clone.Save; Loaded:=TComicProject.Create;
      try Loaded.Load(TPath.Combine(Clone.Folder,'Project.json'));
        Check(Loaded.Pages[0].Balloons[0].Text=Balloon.Text,'shared vertical layout text survives project save and reload');
      finally Loaded.Free; end;
      FProject.Save;
    finally PNG.Free; Clone.Free; Shifted.Free; Reference.Free; Layout.Free; end;
  end;
  procedure RenderChecks;
  var Clone: TComicProject; Reference,Shifted,Warm: TBitmap; Extra: TComicBalloon;
    X,Y,SavedDC: Integer; Same: Boolean;
  begin
    Clone:=TComicProject.Create; Reference:=TBitmap.Create; Shifted:=TBitmap.Create; Warm:=TBitmap.Create;
    try
      Clone.Folder:=FProject.Folder; Clone.Restore(FProject.Snapshot);
      Extra:=TComicBalloon.Create; Extra.Text:='二つ目の吹き出し'; Extra.Bounds:=TRectF.Create(650,300,950,600);
      Extra.PanelID:=Clone.Pages[0].Panels[0].ID; Extra.Overflow:=False;
      Extra.HasTail:=True; Extra.TailX:=650; Extra.TailY:=660;
      Clone.Pages[0].Panels[0].Shape:=1;
      Clone.Pages[0].Balloons.Add(Extra);
      Reference.SetSize(600,850); Shifted.SetSize(750,950);
      FRenderer.Draw(Reference.Canvas,Clone,Clone.Pages[0],Rect(0,0,600,850),False); Warm.Assign(Reference);
      SavedDC:=SaveDC(Shifted.Canvas.Handle);
      try
        SetViewportOrgEx(Shifted.Canvas.Handle,75,50,nil);
        FRenderer.Draw(Shifted.Canvas,Clone,Clone.Pages[0],Rect(0,0,600,850),False);
      finally RestoreDC(Shifted.Canvas.Handle,SavedDC); Shifted.Canvas.Refresh; end;
      Same:=True; X:=3;
      while X<600 do begin Y:=3;
        while Y<850 do begin
          if Reference.Canvas.Pixels[X,Y]<>Shifted.Canvas.Pixels[X+75,Y+50] then Same:=False;
          Inc(Y,13);
        end;
        Inc(X,13);
      end;
      Check(Same,'translated DC rendering matches PNG coordinates and balloon clipping');
      Check(Reference.Canvas.Pixels[462,225]=clWhite,'clipped balloon cannot paint beyond its owner panel');
      FRenderer.Draw(Reference.Canvas,Clone,Clone.Pages[0],Rect(0,0,600,850),False);
      Same:=True; X:=3;
      while X<600 do begin Y:=3;
        while Y<850 do begin
          if Reference.Canvas.Pixels[X,Y]<>Warm.Canvas.Pixels[X,Y] then Same:=False;
          Inc(Y,13);
        end;
        Inc(X,13);
      end;
      Check(Same,'repeated canvas rendering keeps multiple balloon fonts stable');
      Reference.SaveToFile(TPath.Combine(Folder,'render-balloons.bmp'));
      Clone.Pages[0].Panels[0].SetVertices([TPointF.Create(100,100),TPointF.Create(1100,100),TPointF.Create(1100,1500)]);
      Extra.Bounds:=TRectF.Create(100,900,600,1400); Extra.HasTail:=False;
      FRenderer.Draw(Reference.Canvas,Clone,Clone.Pages[0],Rect(0,0,600,850),False);
      SavedDC:=SaveDC(Shifted.Canvas.Handle);
      try SetViewportOrgEx(Shifted.Canvas.Handle,75,50,nil);
        FRenderer.Draw(Shifted.Canvas,Clone,Clone.Pages[0],Rect(0,0,600,850),False);
      finally RestoreDC(Shifted.Canvas.Handle,SavedDC); Shifted.Canvas.Refresh; end;
      Same:=True; X:=3;
      while X<600 do begin Y:=3;
        while Y<850 do begin
          if Reference.Canvas.Pixels[X,Y]<>Shifted.Canvas.Pixels[X+75,Y+50] then Same:=False;
          Inc(Y,13);
        end;
        Inc(X,13);
      end;
      Check(Same,'polygon and owner-clipped balloon match under translated DC rendering');
      Check(Reference.Canvas.Pixels[80,600]=clWhite,'polygon owner clips balloon outside actual triangle');
      Reference.SaveToFile(TPath.Combine(Folder,'render-polygon-balloons.bmp'));
    finally Warm.Free; Shifted.Free; Reference.Free; Clone.Free; end;
  end;
  procedure ViewportChecks;
  var Probe: TMainForm; Project: TComicProject; Panel: TComicPanel; Balloon: TComicBalloon;
    Tail: TComicTail; Overlay: TComicOverlay; Asset: TComicAsset; PPI,I: Integer;
    Before,Outer: string; World,After,Pan,Start: TPointF; At: TPoint; Zoom: Double;
    KeyCode: Word; Bitmap: TBitmap; PNG: TPngImage; Bounds: TRectF;
    function Pixel(const P: TPointF): TPoint;
    begin Probe.UpdateViewport; Result:=Point(Probe.FPageRect.Left+Round(P.X*Probe.FScale),Probe.FPageRect.Top+Round(P.Y*Probe.FScale)); end;
    procedure Wheel(Delta: Integer; const P: TPoint);
    var S: TPoint;
    begin S:=Probe.FCanvas.ClientToScreen(P); Probe.Perform(WM_MOUSEWHEEL,MakeWParam(0,Delta),MakeLParam(S.X,S.Y)); end;
    procedure Mode(Index,Tool: Integer);
    begin Probe.CancelDrag; Probe.FTabs.ActivePageIndex:=Index; Probe.TabChanged(nil); Probe.FTool:=Tool; Probe.FPanelIndex:=0; Probe.FBalloonIndex:=-1; Probe.SelectSinglePanel(0); end;
    procedure Draw(const Name: string);
    begin Probe.HandleNeeded; Bitmap.SetSize(Probe.ClientWidth,Probe.ClientHeight); Probe.PaintTo(Bitmap.Canvas,0,0);
      PNG.Assign(Bitmap); PNG.SaveToFile(TPath.Combine(Folder,Name+'-'+IntToStr(PPI)+'.png')); end;
    procedure Untouched(const Message: string);
    begin Check((Probe.FProject.Snapshot=Before) and (Probe.FUndo.Count=0) and (Probe.FRedo.Count=0) and not Probe.FDirty,Message+' '+IntToStr(PPI)); end;
  begin
    Outer:=FProject.Snapshot;
    Probe:=TMainForm.Create(nil); Bitmap:=TBitmap.Create; PNG:=TPngImage.Create;
    try
      Project:=TComicProject.Create; Project.Initialize('表示操作テスト','1');
      Asset:=Project.ImportImage(TPath.Combine(Folder,'reference.bmp'),'');
      Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(100,120,500,550); Panel.ImageID:=Asset.ID; Project.Pages[0].Panels.Add(Panel);
      Overlay:=TComicOverlay.Create; Overlay.Bounds:=TRectF.Create(0.2,0.2,0.7,0.7); Overlay.MaterialID:=Probe.FEffectMaterials[0].ID; Overlay.FileName:=Probe.FEffectMaterials[0].FileName; Panel.Overlays.Add(Overlay);
      Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(620,650,1000,1080); Panel.ImageID:=Asset.ID; Project.Pages[0].Panels.Add(Panel);
      Balloon:=TComicBalloon.Create; Balloon.Bounds:=TRectF.Create(200,200,420,330); Balloon.Text:='表示テスト'; Project.Pages[0].Balloons.Add(Balloon);
      Tail:=TComicTail.Create; Tail.Root:=TPointF.Create(280,320); Tail.Tip:=TPointF.Create(570,600); Tail.Width:=35; Balloon.Tails.Add(Tail);
      Project.Pages.Add(TComicPage.Create); Probe.AdoptProject(Project,False);
      Before:=Probe.FProject.Snapshot;
      for PPI in [96,144] do begin
        Probe.Scaled:=True; Probe.ScaleForPPI(PPI); Probe.Scaled:=False;
        Probe.Width:=MulDiv(1420,PPI,96); Probe.Height:=MulDiv(920,PPI,96);
        Check(Probe.CurrentPPI=PPI,'viewport uses requested real VCL PPI '+IntToStr(PPI));
        Mode(1,0); Probe.ResetViewport; Draw('viewport-fit');
        Check(SameValue(Probe.FViewZoom,1) and (Probe.FScale>0),'viewport starts in fit '+IntToStr(PPI));
        At:=Pixel(TPointF.Create(300,400)); World:=Probe.ToPage(At.X,At.Y); Zoom:=Probe.FViewZoom;
        Wheel(120,At); After:=Probe.ToPage(At.X,At.Y);
        Check((Probe.FViewZoom>Zoom) and (Hypot(World.X-After.X,World.Y-After.Y)*Probe.FScale<=1.5),'wheel zoom keeps cursor world anchor '+IntToStr(PPI));
        Zoom:=Probe.FViewZoom; Wheel(30,At); Check(Probe.FViewZoom>Zoom,'high-resolution wheel delta zooms smoothly '+IntToStr(PPI));
        Zoom:=Probe.FViewZoom; Wheel(120,Point(-5,-5)); Check(Probe.FViewZoom=Zoom,'wheel outside canvas leaves display alone '+IntToStr(PPI));
        Wheel(24000,At); Wheel(24000,At); Check(SameValue(Probe.FViewZoom,16),'wheel upper zoom limit '+IntToStr(PPI));
        Wheel(-24000,At); Wheel(-24000,At); Check(SameValue(Probe.FViewZoom,0.1),'wheel lower zoom limit '+IntToStr(PPI));
        KeyCode:=Ord('0'); Probe.Key(nil,KeyCode,[ssCtrl]); Check((KeyCode=0) and SameValue(Probe.FViewZoom,1),'Ctrl+0 restores fit '+IntToStr(PPI));
        Untouched('wheel and fit preserve data undo and dirty state');
        At:=Pixel(TPointF.Create(300,400)); Pan:=Probe.FViewPan;
        Probe.FCanvas.Perform(WM_MBUTTONDOWN,MK_MBUTTON,MakeLParam(At.X,At.Y));
        Check(Probe.FViewPanning and not Probe.FDragging,'middle button takes view priority over objects '+IntToStr(PPI));
        Probe.FCanvas.Perform(WM_MOUSEMOVE,MK_MBUTTON,MakeLParam(At.X+70,At.Y+40));
        Check((Probe.FViewPan<>Pan) and (Probe.FPanelIndex=0),'middle drag pans without changing selection '+IntToStr(PPI));
        Zoom:=Probe.FViewZoom; Wheel(120,At); Check(Probe.FViewZoom=Zoom,'wheel waits until active pan is released '+IntToStr(PPI));
        Probe.MouseUp(nil,mbLeft,[],At.X+70,At.Y+40); Check(Probe.FViewPanning,'other button release does not end middle pan '+IntToStr(PPI));
        Probe.FCanvas.Perform(WM_MBUTTONUP,0,MakeLParam(At.X+70,At.Y+40));
        Check(not Probe.FViewPanning and (Probe.FCanvas.Cursor=crDefault),'middle button release ends pan '+IntToStr(PPI));
        Untouched('middle pan preserves data undo and dirty state');
        At:=Pixel(TPointF.Create(35,35)); Check(Probe.EmptyViewPoint(Probe.ToPage(At.X,At.Y)),'blank page margin is an empty pan target '+IntToStr(PPI));
        Probe.FCanvas.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(At.X,At.Y));
        Check(Probe.FViewPanning and not Probe.FDragging,'empty left press starts view pan '+IntToStr(PPI));
        Probe.FCanvas.Perform(WM_MOUSEMOVE,MK_LBUTTON,MakeLParam(At.X+35,At.Y+25));
        Probe.FCanvas.Perform(WM_LBUTTONUP,0,MakeLParam(At.X+35,At.Y+25)); Untouched('empty left drag preserves data undo and dirty state');
        Pan:=Probe.FViewPan; Probe.MouseDown(nil,mbMiddle,[],At.X,At.Y); Probe.MouseMove(nil,[ssMiddle],At.X+40,At.Y+20);
        KeyCode:=VK_ESCAPE; Probe.Key(nil,KeyCode,[]);
        Check(not Probe.FViewPanning and (Probe.FViewPan=Pan),'Esc rolls back only the current view pan '+IntToStr(PPI));
        Probe.MouseDown(nil,mbMiddle,[],At.X,At.Y); Probe.MouseMove(nil,[ssMiddle],At.X+40,At.Y+20); Pan:=Probe.FViewPan;
        Probe.FView.Perform(WM_CAPTURECHANGED,0,0);
        Check(not Probe.FViewPanning and (Probe.FViewPan=Pan),'capture loss releases pan and retains display position '+IntToStr(PPI));
        Probe.MouseDown(nil,mbMiddle,[],At.X,At.Y); Probe.MouseMove(nil,[],At.X+5,At.Y+5);
        Check(not Probe.FViewPanning,'missing held-button flag releases pan '+IntToStr(PPI));
        Probe.MouseDown(nil,mbMiddle,[],At.X,At.Y); Probe.FPages.ItemIndex:=1; Probe.PageSelect(nil);
        Check(not Probe.FViewPanning and SameValue(Probe.FViewZoom,1),'page switch releases pan and restores fit '+IntToStr(PPI));
        Probe.FPages.ItemIndex:=0; Probe.PageSelect(nil); Mode(1,1); At:=Pixel(TPointF.Create(35,35));
        Probe.MouseDown(nil,mbLeft,[],At.X,At.Y); Start:=Probe.FStart;
        Check(Probe.FFirst and not Probe.FViewPanning,'creation tool keeps empty left click as its first point '+IntToStr(PPI));
        Wheel(120,At); Probe.MouseDown(nil,mbMiddle,[],At.X,At.Y); Probe.MouseMove(nil,[ssMiddle],At.X+20,At.Y+10); Probe.MouseUp(nil,mbMiddle,[],At.X+20,At.Y+10);
        Check(Probe.FFirst and (Probe.FStart=Start),'wheel and middle pan preserve pending creation coordinates '+IntToStr(PPI));
        KeyCode:=VK_ESCAPE; Probe.Key(nil,KeyCode,[]); Mode(1,0); Probe.ResetViewport;
        At:=Pixel(TPointF.Create(300,400)); Wheel(120,At); Wheel(120,At); Probe.MouseDown(nil,mbMiddle,[],At.X,At.Y); Probe.MouseMove(nil,[ssMiddle],At.X+20,At.Y+10); Probe.MouseUp(nil,mbMiddle,[],At.X+20,At.Y+10);
        Draw('viewport-zoom-pan'); Untouched('navigation after creation preserves project');
        Bounds:=Probe.Page.Panels[0].Bounds; At:=Pixel(Bounds.CenterPoint); Pan:=Probe.FViewPan;
        Probe.MouseDown(nil,mbLeft,[],At.X,At.Y); Check(Probe.FDragging and not Probe.FViewPanning,'panel body edits before empty-pan fallback after zoom '+IntToStr(PPI));
        Zoom:=Probe.FViewZoom; Wheel(120,At); Check(Probe.FViewZoom=Zoom,'wheel cannot shift an in-progress edit frame '+IntToStr(PPI));
        Probe.MouseMove(nil,[ssLeft,ssAlt],At.X+18,At.Y+12); Check(Probe.Page.Panels[0].Bounds<>Bounds,'zoomed canvas drag edits panel geometry '+IntToStr(PPI));
        Probe.FView.Perform(WM_CAPTURECHANGED,0,0);
        Check(not Probe.FDragging and (Probe.Page.Panels[0].Bounds=Bounds) and (Probe.FViewPan=Pan),'capture loss cancels edit without panning or adding undo '+IntToStr(PPI));
        for I:=0 to 7 do begin
          At:=Pixel(EditHandles(Probe.Page.Panels[0].Bounds)[I]); Probe.MouseDown(nil,mbLeft,[],At.X,At.Y);
          Check(Probe.FDragging and not Probe.FViewPanning and (Probe.FDragHandle=I+1),'zoomed panel handle keeps priority '+IntToStr(I)+' '+IntToStr(PPI)); Probe.CancelDrag;
        end;
        At:=Pixel(Probe.VertexHandles(Probe.Page.Panels[0])[0]); Probe.MouseDown(nil,mbLeft,[],At.X,At.Y);
        Check(Probe.FDragging and (Probe.FDragVertex>=0) and not Probe.FViewPanning,Format('vertex handle keeps priority %d [drag=%s pan=%s vertex=%d handle=%d scale=%.6f x=%d y=%d]',[PPI,BoolToStr(Probe.FDragging,True),BoolToStr(Probe.FViewPanning,True),Probe.FDragVertex,Probe.FDragHandle,Probe.FScale,At.X,At.Y])); Probe.CancelDrag;
        Probe.FSelectedPanels.Add(Probe.Page.Panels[1].ID); Probe.FPanelIndex:=1;
        At:=Pixel(Probe.SelectedPanelBounds.CenterPoint); Probe.MouseDown(nil,mbLeft,[],At.X,At.Y);
        Check(Probe.FDragging and (Length(Probe.FDragGroup)=2) and not Probe.FViewPanning,'selected group gap remains group move '+IntToStr(PPI)); Probe.CancelDrag;
        Mode(2,0); At:=Pixel(EditHandles(Probe.FRenderer.ImageBounds(Probe.FProject,Probe.Page.Panels[0]))[0]); Probe.MouseDown(nil,mbLeft,[],At.X,At.Y);
        Check(Probe.FDragging and not Probe.FViewPanning,'image handle keeps priority outside panel '+IntToStr(PPI)); Probe.CancelDrag;
        Mode(3,0); Probe.FBalloonIndex:=0; At:=Pixel(Probe.Page.Balloons[0].Bounds.CenterPoint); Probe.MouseDown(nil,mbLeft,[],At.X,At.Y);
        Check(Probe.FDragging and not Probe.FViewPanning,'balloon body keeps priority '+IntToStr(PPI)); Probe.CancelDrag;
        Probe.FTool:=13; At:=Pixel(Probe.FRenderer.BalloonTextBounds(Probe.Page.Balloons[0]).CenterPoint); Probe.MouseDown(nil,mbLeft,[],At.X,At.Y);
        Check(Probe.FDragging and not Probe.FViewPanning,'text placement keeps priority '+IntToStr(PPI)); Probe.CancelDrag;
        Probe.FTool:=12; Probe.FTailIndex:=0; At:=Pixel(Probe.Page.Balloons[0].Tails[0].Handles[2]); Probe.MouseDown(nil,mbLeft,[],At.X,At.Y);
        Check(Probe.FDragging and (Probe.FDragTailHandle>0) and not Probe.FViewPanning,'tail handle keeps priority '+IntToStr(PPI)); Probe.CancelDrag;
        Check(not Probe.EmptyViewPoint(TPointF.Create(550,580)),'visible tail is not empty space '+IntToStr(PPI));
        Mode(4,0); Probe.FEffectCategory.ItemIndex:=0; Probe.FEffectIndex:=0; At:=Pixel(EditHandles(OverlayBounds(Probe.Page.Panels[0],Probe.Page.Panels[0].Overlays[0]))[0]); Probe.MouseDown(nil,mbLeft,[],At.X,At.Y);
        Check(Probe.FDragging and not Probe.FViewPanning,'material handle keeps priority '+IntToStr(PPI)); Probe.CancelDrag;
        Mode(1,0); Probe.FSnap.Checked:=True; World:=Probe.FProject.PageBasis.Frame.TopLeft;
        After:=Probe.SnapCreationPoint(TPointF.Create(World.X+3/Probe.FScale,World.Y+2/Probe.FScale));
        Check(Hypot(After.X-World.X,After.Y-World.Y)<0.01,'zoom and pan retain frame snapping coordinates '+IntToStr(PPI));
        Untouched('all navigation and cancelled priority probes preserve data');
      end;
      Probe.MouseDown(nil,mbMiddle,[],10,10); Project:=TComicProject.Create; Project.Folder:=Probe.FProject.Folder; Project.Restore(Probe.FProject.Snapshot);
      Probe.AdoptProject(Project,False);
      Check(not Probe.FViewPanning and SameValue(Probe.FViewZoom,1),'project replacement releases view pan and resets camera');
      Check(FProject.Snapshot=Outer,'viewport checks preserve the outer smoke-test project');
    finally PNG.Free; Bitmap.Free; Probe.Free; end;
  end;

  procedure GeometryChecks;
  var OriginalProject,Reloaded: TComicProject; OriginalUndo,OriginalRedo: TList<string>;
    Model,Before,ImageID,OwnerID: string; Panel,Thin: TComicPanel;
    Points,One,Two: TArray<TPointF>; C,D,Q: TPointF; ImageRect,Actual,OldBounds: TRectF;
    PX,PY,UndoCount,OldIndex,X,Y: Integer; KeyValue: Word; OldSnap,SamePixels: Boolean;
    Layout,LayoutCopy: TComicLayout; J: TJSONObject; PNG: TPngImage; Reference: TBitmap;
    procedure SelectTool(Tag: Integer);
    var Button: TComicIconButton;
    begin
      for Button in FIconButtons do if (Button.Role=brTool) and (Button.Tag=Tag) and (Button.Context=1) then begin Button.Click; Exit; end;
      raise Exception.Create('Geometry icon missing.');
    end;
    procedure Click(X,Y: Single; Alt: Boolean=False);
    begin
      PX:=FPageRect.Left+Round(X*FScale); PY:=FPageRect.Top+Round(Y*FScale);
      if Alt then begin MouseDown(FCanvas,mbLeft,[ssAlt],PX,PY); MouseUp(FCanvas,mbLeft,[ssAlt],PX,PY); end
      else begin
        FCanvas.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(PX,PY));
        FCanvas.Perform(WM_LBUTTONUP,0,MakeLParam(PX,PY));
      end;
    end;
    procedure SameImage(const Message: string);
    var K: Integer;
    begin
      for K:=0 to Page.Panels.Count-1 do begin
        Actual:=FRenderer.ImageBounds(FProject,Page.Panels[K]);
        Check((Abs(Actual.Left-ImageRect.Left)<0.01) and (Abs(Actual.Top-ImageRect.Top)<0.01) and
          (Abs(Actual.Right-ImageRect.Right)<0.01) and (Abs(Actual.Bottom-ImageRect.Bottom)<0.01),Message+' '+IntToStr(K));
      end;
    end;
    procedure RoundTrip(const Message: string);
    begin
      FProject.Save; Reloaded:=TComicProject.Create;
      try Reloaded.Load(TPath.Combine(FProject.Folder,'Project.json'));
        Check(Reloaded.Snapshot=FProject.Snapshot,Message);
      finally Reloaded.Free; end;
    end;
    procedure SnapOrderChecks;
    var OriginalPanels,Temporary: TObjectList<TComicPanel>; A,B: TComicPanel;
      First,Second,P: TPointF; OriginalScale: Double; OriginalSnap: Boolean; Before: string; History: Integer;
      procedure Reverse;
      begin Temporary.Move(0,1); end;
    begin
      OriginalPanels:=Page.Panels; Temporary:=TObjectList<TComicPanel>.Create;
      OriginalScale:=FScale; OriginalSnap:=FSnap.Checked; Before:=FProject.Snapshot; History:=FUndo.Count;
      try
        Page.Panels:=Temporary; FScale:=1; FSnap.Checked:=True;
        A:=TComicPanel.Create; A.Bounds:=TRectF.Create(100,100,500,500); Temporary.Add(A);
        B:=TComicPanel.Create; B.Bounds:=TRectF.Create(102,800,400,1100); Temporary.Add(B);
        P:=TPointF.Create(102,103); First:=SnapCreationPoint(P);
        Check((First.X=100) and (First.Y=100),'nearest vertex takes priority over a later panel axis');
        Reverse; Second:=SnapCreationPoint(P);
        Check(First=Second,'vertex snap is independent of panel iteration order');
        P:=TPointF.Create(105,300); First:=SnapCreationPoint(P);
        Check((First.X=100) and (First.Y=300),'nearest real edge takes priority over an unrelated closer axis');
        Reverse; Second:=SnapCreationPoint(P);
        Check(First=Second,'edge snap is independent of panel iteration order');
        P:=TPointF.Create(105,650); First:=SnapCreationPoint(P); Reverse; Second:=SnapCreationPoint(P);
        Check((First.X=102) and (First.Y=650) and (First=Second),'axis fallback chooses the closest axis independent of order');
        B.Bounds:=TRectF.Create(104,100,504,500);
        P:=TPointF.Create(102,100); First:=SnapCreationPoint(P); Reverse; Second:=SnapCreationPoint(P);
        Check((First.X=100) and (First.Y=100) and (First=Second),'equidistant vertices use a deterministic coordinate tie break');
        P:=TPointF.Create(102,300); First:=SnapCreationPoint(P); Reverse; Second:=SnapCreationPoint(P);
        Check((First.X=100) and (First.Y=300) and (First=Second),'equidistant edges use a deterministic coordinate tie break');
        B.Bounds:=TRectF.Create(104,800,504,1100);
        P:=TPointF.Create(102,650); First:=SnapCreationPoint(P); Reverse; Second:=SnapCreationPoint(P);
        Check((First.X=100) and (First.Y=650) and (First=Second),'equidistant axes use a deterministic coordinate tie break');
        FSnap.Checked:=False;
        Check(SnapCreationPoint(TPointF.Create(102,103))=TPointF.Create(102,103),'disabled snapping preserves exact input coordinates');
      finally Page.Panels:=OriginalPanels; Temporary.Free; FScale:=OriginalScale; FSnap.Checked:=OriginalSnap; end;
      Check((FProject.Snapshot=Before) and (FUndo.Count=History),'snap order checks preserve project content and undo history');
    end;
    procedure VertexDPI(PPI: Integer);
    var OriginalPPI,OriginalW,OriginalH: Integer; OriginalScaled: Boolean; H: TPointF; X,Y: Integer;
    begin
      OriginalPPI:=CurrentPPI; OriginalW:=Width; OriginalH:=Height; OriginalScaled:=Scaled;
      try
        Scaled:=True; ScaleForPPI(PPI); Scaled:=False;
        Width:=MulDiv(940,PPI,96); Height:=MulDiv(660,PPI,96); Realign;
        Page.Panels.Clear; Page.Balloons.Clear; FUndo.Clear; FRedo.Clear;
        Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(100,100,1100,1600); Panel.ImageID:=ImageID; Page.Panels.Add(Panel);
        ImageRect:=FRenderer.ImageBounds(FProject,Panel); RefreshUI; SelectTool(0); FPanelIndex:=0;
        Capture('geometry-vertex-dpi'+IntToStr(PPI)+'-before'); H:=VertexHandles(Panel)[0];
        X:=FPageRect.Left+Round(H.X*FScale); Y:=FPageRect.Top+Round(H.Y*FScale);
        FCanvas.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(X,Y));
        Check(FDragVertex=0,'vertex handle is selectable at VCL PPI '+IntToStr(PPI));
        MouseMove(FCanvas,[ssLeft],X+MulDiv(20,PPI,96),Y+MulDiv(12,PPI,96));
        FCanvas.Perform(WM_LBUTTONUP,0,MakeLParam(X+MulDiv(20,PPI,96),Y+MulDiv(12,PPI,96)));
        Check((Page.Panels[0].Shape=3) and ValidPolygon(Page.Panels[0].Vertices),'vertex drag remains valid at VCL PPI '+IntToStr(PPI));
        SameImage('DPI vertex edit preserves image placement '+IntToStr(PPI));
        RoundTrip('DPI vertex edit saves and reloads '+IntToStr(PPI));
        Capture('geometry-vertex-dpi'+IntToStr(PPI)+'-after'); Undo(nil);
        Check(Page.Panels[0].Shape=0,'DPI vertex edit undo '+IntToStr(PPI));
      finally
        Scaled:=True; ScaleForPPI(OriginalPPI); Width:=OriginalW; Height:=OriginalH; Scaled:=OriginalScaled; Realign;
      end;
    end;
  begin
    OriginalProject:=FProject; OriginalUndo:=FUndo; OriginalRedo:=FRedo;
    Model:=OriginalProject.Snapshot; OldIndex:=FPageIndex; OldSnap:=FSnap.Checked;
    FProject:=TComicProject.Create; FUndo:=TList<string>.Create; FRedo:=TList<string>.Create;
    PNG:=TPngImage.Create; Reference:=TBitmap.Create;
    try
      FProject.Initialize('Geometry fixture','1'); FPageIndex:=0; FPanelIndex:=-1; FBalloonIndex:=-1;
      ImageID:=FProject.ImportImage(TPath.Combine(Folder,'reference.bmp'),'').ID;
      RefreshUI; FModeButtons[1].Click; FSnap.Checked:=False; Capture('geometry-empty');
      Points:=[TPointF.Create(100,100),TPointF.Create(1100,100),TPointF.Create(1100,1600),TPointF.Create(100,1600)];
      Check(ValidPolygon(Points) and ConvexPolygon(Points),'rectangle is a valid convex polygon');
      Check(BandEndpoints(Points,TPointF.Create(100,700),TPointF.Create(1100,700),TPointF.Create(100,740),C,D) and
        SplitPolygonBand(Points,TPointF.Create(100,700),TPointF.Create(1100,700),C,One,Two),
        'horizontal strip produces two valid polygons');
      Check(Abs(PolygonArea(One)+PolygonArea(Two)-1460000)<1,'horizontal strip removes exactly its 40px gutter');
      Check(BandEndpoints(Points,TPointF.Create(500,100),TPointF.Create(500,1600),TPointF.Create(540,100),C,D) and
        SplitPolygonBand(Points,TPointF.Create(500,100),TPointF.Create(500,1600),C,One,Two),
        'vertical strip works in either winding direction');
      Check(BandEndpoints(Points,TPointF.Create(100,500),TPointF.Create(1100,1100),TPointF.Create(100,550),C,D) and
        SplitPolygonBand(Points,TPointF.Create(100,500),TPointF.Create(1100,1100),C,One,Two),
        'diagonal strip produces two convex clipped polygons');
      Check(not BandEndpoints(Points,TPointF.Create(100,700),TPointF.Create(1100,700),TPointF.Create(100,702),C,D),
        'strip rejects a width below four output pixels');
      Check(not SplitPolygonBand(Points,TPointF.Create(150,700),TPointF.Create(1100,700),TPointF.Create(100,740),One,Two),
        'strip rejects an endpoint away from the owner boundary');
      Check(not ValidPolygon([TPointF.Create(100,100),TPointF.Create(1100,1600),TPointF.Create(100,1600),TPointF.Create(1100,100)]),
        'self crossing polygon is rejected');
      Check(not ValidPolygon([TPointF.Create(100,100),TPointF.Create(100,100),TPointF.Create(1100,1600)]),
        'duplicate adjacent vertex is rejected');
      Check(not ValidPolygon([TPointF.Create(100,100),TPointF.Create(600,100),TPointF.Create(300,100),TPointF.Create(600,800),TPointF.Create(100,800)]),
        'overlapping adjacent edges are rejected');
      Check(not ValidPolygon([TPointF.Create(NaN,100),TPointF.Create(1100,100),TPointF.Create(1100,1600)]),
        'nonfinite polygon coordinate is rejected');
      Points:=[TPointF.Create(100,100),TPointF.Create(1100,100),TPointF.Create(600,700),TPointF.Create(1100,1600),TPointF.Create(100,1600)];
      Check(ValidPolygon(Points) and not ConvexPolygon(Points),'concave polygon remains editable but cannot use convex splitting');

      SelectTool(8); Before:=FProject.Snapshot; UndoCount:=FUndo.Count;
      Click(100,100); Click(1100,100); Click(1100,1500);
      Check((Page.Panels.Count=0) and (FProject.Snapshot=Before) and (FUndo.Count=UndoCount),
        'polygon pending clicks do not modify saved content or history');
      MouseDown(FCanvas,mbRight,[],PX,PY);
      Check(FGeometryPoints.Count=2,'polygon right click removes only the last pending vertex');
      Click(1100,1500); Click(100,100);
      Check((Page.Panels.Count=1) and (Page.Panels[0].Shape=3) and (Length(Page.Panels[0].Vertices)=3),
        'real VCL clicks close and create a polygon');
      Panel:=Page.Panels[0]; Panel.ImageID:=ImageID; OwnerID:=Panel.ID;
      Check((HitPanel(TPointF.Create(150,1400))=-1) and (HitPanel(TPointF.Create(900,600))=0),
        'polygon hit testing excludes empty bounding-box corners');
      Check(Pos('"version":3',FProject.Snapshot)>0,'polygon project advertises current version three');
      RoundTrip('polygon vertices image UID and bounds survive save and reload');
      FSnap.Checked:=True; Q:=SnapCreationPoint(TPointF.Create(61,62));
      Check((Q.X=60) and (Q.Y=60),'creation snaps to the page frame');
      Q:=SnapCreationPoint(TPointF.Create(102,103));
      Check((Q.X=Panel.Vertices[0].X) and (Q.Y=Panel.Vertices[0].Y),'creation snaps to existing vertices');
      Q:=SnapCreationPoint(TPointF.Create(102,103),Panel.ID);
      Check((Q.X=102) and (Q.Y=103),'vertex drag excludes its own moving panel from snap targets');
      SnapOrderChecks;
      SelectTool(8); Click(64,65,True);
      Check((Abs(FGeometryPoints[0].X-60)>1) or (Abs(FGeometryPoints[0].Y-60)>1),'Alt bypasses creation snapping');
      KeyValue:=VK_ESCAPE; ActiveControl:=FView; Key(Self,KeyValue,[]);
      Check(FGeometryPoints.Count=0,'Esc cancels pending polygon points');
      FSnap.Checked:=False;
      Layout:=TComicLayout.Create; LayoutCopy:=TComicLayout.Create; Reloaded:=TComicProject.Create;
      try
        Layout.Name:='Polygon fixture'; Layout.Capture(FProject,Page);
        J:=Layout.Json; try LayoutCopy.Read(J); finally J.Free; end;
        Reloaded.Pages.Add(TComicPage.Create); LayoutCopy.Apply(Reloaded.Pages[0],600,850);
        Check((Reloaded.Pages[0].Panels[0].Shape=3) and
          (Abs(Reloaded.Pages[0].Panels[0].Vertices[1].X-Panel.Vertices[1].X/2)<0.001) and
          (Reloaded.Pages[0].Panels[0].ImageID=''),'polygon template roundtrip scales vertices and excludes images');
        // Real clicks are rounded to view pixels. Restore the actual vertex,
        // rather than assuming its page coordinate was exactly 100.
        Points:=Panel.Outline;
        Panel.Vertices[0].X:=Points[0].X+5;
        Check(Layout.Panels[0].Vertices[0].X<>Panel.Vertices[0].X,'template capture owns an independent vertex array');
        Panel.SetVertices(Points);
        Check(Panel.Bounds=PolygonBounds(Panel.Vertices),'template independence check restores consistent actual click coordinates');
      finally Reloaded.Free; LayoutCopy.Free; Layout.Free; end;
      B.SetSize(600,850); FRenderer.Draw(B.Canvas,FProject,Page,Rect(0,0,600,850),False);
      Check((B.Canvas.Pixels[80,650]=clWhite) and (B.Canvas.Pixels[450,300]<>clWhite),
        'polygon image clipping follows the outline');
      PNG.Assign(B); PNG.SaveToFile(TPath.Combine(Folder,'polygon-render.png'));
      SelectTool(0); FPanelIndex:=0; Capture('geometry-polygon');
      OldBounds:=Panel.Bounds; Before:=FProject.Snapshot;
      PX:=FPageRect.Left+Round(OldBounds.Right*FScale); PY:=FPageRect.Top+Round(OldBounds.Bottom*FScale);
      MouseDown(FCanvas,mbLeft,[],PX,PY); MouseMove(FCanvas,[ssLeft],PX-25,PY-25); MouseUp(FCanvas,mbLeft,[],PX-25,PY-25);
      Check((Page.Panels[0].Bounds<>OldBounds) and ValidPolygon(Page.Panels[0].Vertices),'polygon handle resize transforms valid vertices');
      Undo(nil); Check(Page.Panels[0].Bounds=OldBounds,'polygon resize undo restores outline bounds');
      Redo(nil); RoundTrip('polygon resized outline survives redo and save reload');
      Undo(nil);

      Page.Panels.Clear; Page.Balloons.Clear; FUndo.Clear; FRedo.Clear;
      Thin:=TComicPanel.Create;
      Thin.SetVertices([TPointF.Create(100,100),TPointF.Create(1100,1100),TPointF.Create(1097,1098)]);
      Page.Panels.Add(Thin); Before:=FProject.Snapshot; OldBounds:=Thin.Bounds;
      Failed:=False; try Thin.SetBounds(TRectF.Create(100,100,130,130)); except Failed:=True; end;
      Check(Failed and (FProject.Snapshot=Before),'thin triangle resize validates candidate atomically before mutation');
      Checkpoint; Thin.SetBounds(TRectF.Create(100,100,600,600)); Changed;
      Check(ValidPolygon(Thin.Vertices),'thin triangle valid shrink remains readable');
      Undo(nil); Check(Page.Panels[0].Bounds=OldBounds,'thin triangle shrink undo restores original');
      Redo(nil); RoundTrip('thin triangle valid shrink redo and saved reload');
      SelectTool(0); FPanelIndex:=0; Capture('geometry-thin'); Before:=FProject.Snapshot; UndoCount:=FUndo.Count;
      OldBounds:=Page.Panels[0].Bounds; PX:=FPageRect.Left+Round(OldBounds.Right*FScale); PY:=FPageRect.Top+Round(OldBounds.Bottom*FScale);
      MouseDown(FCanvas,mbLeft,[],PX,PY); MouseMove(FCanvas,[ssLeft],PX-10000,PY-10000); MouseUp(FCanvas,mbLeft,[],PX-10000,PY-10000);
      Check((FProject.Snapshot=Before) and (FUndo.Count=UndoCount),'UI rejects extreme thin-triangle shrink without an undo entry');
      RoundTrip('rejected thin-triangle shrink leaves a loadable project');

      Page.Panels.Clear; Page.Balloons.Clear; FUndo.Clear; FRedo.Clear;
      Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(100,100,1100,1600); Panel.ImageID:=ImageID;
      Panel.Zoom:=1.7; Panel.PanX:=52; Panel.PanY:=-33; Page.Panels.Add(Panel); OwnerID:=Panel.ID;
      Balloon:=TComicBalloon.Create; Balloon.Bounds:=TRectF.Create(400,1100,700,1300);
      Balloon.PanelID:=OwnerID; Balloon.Text:='分割後も保持'; Page.Balloons.Add(Balloon);
      ImageRect:=FRenderer.ImageBounds(FProject,Panel); RefreshUI; Capture('geometry-before-split');
      Reference.SetSize(600,850); FRenderer.Draw(Reference.Canvas,FProject,Page,Rect(0,0,600,850),False);
      SelectTool(9); Before:=FProject.Snapshot; UndoCount:=FUndo.Count;
      Click(100,700); Click(1100,700); Click(100,740);
      Check((FSplitStage=3) and (FProject.Snapshot=Before) and (FUndo.Count=UndoCount),
        'first three split clicks only preview and do not change project history');
      Click(500,1400);
      Check((FSplitStage=3) and (Page.Panels.Count=1),'incorrect fourth split point cannot commit');
      Click(FSplitD.X,FSplitD.Y);
      Check((Page.Panels.Count=2) and (FSplitStage=0) and (Page.Panels[0].ID=OwnerID) and
        (Page.Panels[1].ID<>OwnerID) and (Page.Panels[0].ImageID=ImageID) and (Page.Panels[1].ImageID=ImageID),
        'four VCL split clicks create two panels with stable original UID and shared image');
      SameImage('split preserves global image placement');
      Check((Page.Balloons[0].Text='分割後も保持') and
        PolygonContains(Page.Panels[1].Vertices,Page.Balloons[0].Bounds.CenterPoint) and
        (Page.Balloons[0].PanelID=Page.Panels[1].ID),'split reassigns balloon owner while preserving its text and position');
      Check(HitPanel(TPointF.Create(600,720))=-1,'split gutter is not selectable');
      RoundTrip('split polygon project save and reload');
      Check(ExportSequence(FProject,FRenderer,False)=1,'split polygon exports to sequential PNG');
      Check(ExportSequence(FProject,FRenderer,False)=0,'unchanged polygon export uses content cache');
      Capture('geometry-after-split'); FRenderer.ExportPage(FProject,Page,TPath.Combine(Folder,'split-page.png'));
      B.SetSize(600,850); FRenderer.Draw(B.Canvas,FProject,Page,Rect(0,0,600,850),False);
      Check(B.Canvas.Pixels[300,360]=clWhite,'split gutter exports white without editing guides');
      SamePixels:=True;
      for X:=70 to 530 do if X mod 23=0 then
        for Y:=70 to 780 do if Y mod 31=0 then begin
          Q:=TPointF.Create(X*2,Y*2);
          if (HitPanel(Q)<0) or Page.Balloons[0].Bounds.Contains(Q) then Continue;
          if NearestEdgePoint(Page.Panels[HitPanel(Q)].Vertices,Q,C)<20 then Continue;
          if B.Canvas.Pixels[X,Y]<>Reference.Canvas.Pixels[X,Y] then SamePixels:=False;
        end;
      Check(SamePixels,'split preserves rendered image pixels outside borders gutters and balloon');
      Undo(nil);
      Check((Page.Panels.Count=1) and (Page.Panels[0].Shape=0) and (Page.Panels[0].ID=OwnerID) and
        (Page.Balloons[0].PanelID=OwnerID),'one undo restores the original unsplit panel and balloon owner');
      Redo(nil); Check(Page.Panels.Count=2,'split redo reconstructs both polygon panels'); SameImage('split redo preserves image placement');
      RoundTrip('split redo saves and reloads');
      SelectTool(9); SplitClick(Page.Panels[0].Vertices[0]); KeyValue:=VK_ESCAPE; ActiveControl:=FView; Key(Self,KeyValue,[]);
      Check(FSplitStage=0,'Esc cancels pending split input');
      Page.Panels.Clear; Page.Balloons.Clear; FUndo.Clear; FRedo.Clear;
      Panel:=TComicPanel.Create;
      Panel.SetVertices([TPointF.Create(60,800),TPointF.Create(600,60),TPointF.Create(1140,800),TPointF.Create(600,1640)]);
      Panel.ImageID:=ImageID; Panel.Zoom:=1.3; Panel.PanX:=-45; Panel.PanY:=25; Page.Panels.Add(Panel);
      ImageRect:=FRenderer.ImageBounds(FProject,Panel); OwnerID:=Panel.ID; RefreshUI; Capture('geometry-diamond-before');
      SelectTool(9); Click(60,800); Click(1140,800); Click(600,900);
      Check(FSplitStage=3,'convex polygon can preview a split band');
      Click(FSplitD.X,FSplitD.Y);
      Check((Page.Panels.Count=2) and ConvexPolygon(Page.Panels[0].Vertices) and ConvexPolygon(Page.Panels[1].Vertices),
        'four-click splitting also accepts an existing convex polygon');
      SameImage('convex polygon split preserves image placement');
      RoundTrip('convex polygon split saves and reloads'); Capture('geometry-diamond-split');
      Undo(nil); Check((Page.Panels.Count=1) and (Page.Panels[0].ID=OwnerID) and (Length(Page.Panels[0].Vertices)=4),
        'convex polygon split undo restores original vertices');
      Redo(nil); Check(Page.Panels.Count=2,'convex polygon split redo restores result');
      Page.Panels.Clear; Page.Balloons.Clear; FUndo.Clear; FRedo.Clear;
      Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(100,100,1100,1600); Panel.ImageID:=ImageID;
      Panel.Zoom:=1.6; Panel.PanX:=48; Panel.PanY:=-27; Page.Panels.Add(Panel); OwnerID:=Panel.ID;
      Balloon:=TComicBalloon.Create; Balloon.PanelID:=OwnerID; Balloon.Text:='頂点編集';
      Balloon.Bounds:=TRectF.Create(400,900,700,1100); Page.Balloons.Add(Balloon);
      ImageRect:=FRenderer.ImageBounds(FProject,Panel); RefreshUI; SelectTool(0); FPanelIndex:=0; FSnap.Checked:=False;
      Capture('geometry-vertex-before'); Points:=VertexHandles(Panel); Q:=Points[0];
      PX:=FPageRect.Left+Round(Q.X*FScale); PY:=FPageRect.Top+Round(Q.Y*FScale);
      FCanvas.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(PX,PY));
      Check(FDragVertex=0,'inside vertex handle is distinct from outer resize handles');
      MouseMove(FCanvas,[ssLeft],PX+35,PY+20); FCanvas.Perform(WM_LBUTTONUP,0,MakeLParam(PX+35,PY+20));
      Check((Page.Panels[0].Shape=3) and (Page.Panels[0].Vertices[0].X>100) and (Page.Panels[0].Vertices[0].Y>100),
        'vertex drag converts rectangle into a valid independent polygon');
      SameImage('vertex drag preserves image placement');
      Check((Page.Panels[0].ID=OwnerID) and (Page.Balloons[0].PanelID=OwnerID) and (Page.Balloons[0].Text='頂点編集'),
        'vertex drag preserves panel identity and balloon ownership');
      Undo(nil); Check((Page.Panels[0].Shape=0) and (Page.Panels[0].Bounds=TRectF.Create(100,100,1100,1600)),
        'vertex drag undo restores original rectangle');
      Redo(nil); Check((Page.Panels[0].Shape=3) and (Length(Page.Panels[0].Vertices)=4),'vertex drag redo restores edited polygon');
      RoundTrip('vertex edited polygon saves and reloads');
      FPanelIndex:=0; Capture('geometry-vertex-after'); Before:=FProject.Snapshot; UndoCount:=FUndo.Count;
      Panel:=Page.Panels[0]; Q:=VertexHandles(Panel)[1];
      PX:=FPageRect.Left+Round(Q.X*FScale); PY:=FPageRect.Top+Round(Q.Y*FScale);
      MouseDown(FCanvas,mbLeft,[],PX,PY);
      Check(FDragVertex=1,'polygon vertex handle starts a vertex edit');
      MouseMove(FCanvas,[ssLeft],PX,PY+Round((Panel.Vertices[2].Y-Panel.Vertices[1].Y)*FScale));
      MouseUp(FCanvas,mbLeft,[],PX,PY);
      Check((FProject.Snapshot=Before) and (FUndo.Count=UndoCount),'duplicate-vertex drag is rejected without mutation or history');
      Q:=VertexHandles(Page.Panels[0])[1]; PX:=FPageRect.Left+Round(Q.X*FScale); PY:=FPageRect.Top+Round(Q.Y*FScale);
      MouseDown(FCanvas,mbLeft,[],PX,PY); MouseMove(FCanvas,[ssLeft],PX-20,PY+20);
      KeyValue:=VK_ESCAPE; ActiveControl:=FView; Key(Self,KeyValue,[]);
      Check((FProject.Snapshot=Before) and (FUndo.Count=UndoCount) and not FDragging,'Esc cancels vertex drag and restores valid outline');
      FPanelIndex:=0; Capture('geometry-vertex-restored'); Panel:=Page.Panels[0]; Q:=VertexHandles(Panel)[0];
      PX:=FPageRect.Left+Round(Q.X*FScale); PY:=FPageRect.Top+Round(Q.Y*FScale);
      FCanvas.Perform(WM_RBUTTONDOWN,MK_RBUTTON,MakeLParam(PX,PY)); FCanvas.Perform(WM_RBUTTONUP,0,MakeLParam(PX,PY));
      Check((Length(Page.Panels[0].Vertices)=3) and ValidPolygon(Page.Panels[0].Vertices),'right click deletes a vertex from selected polygon');
      SameImage('vertex deletion preserves image placement'); Undo(nil);
      Check(Length(Page.Panels[0].Vertices)=4,'vertex deletion undo restores exact vertex count'); Redo(nil);
      FPanelIndex:=0; Capture('geometry-triangle'); Before:=FProject.Snapshot; UndoCount:=FUndo.Count;
      Q:=VertexHandles(Page.Panels[0])[0]; PX:=FPageRect.Left+Round(Q.X*FScale); PY:=FPageRect.Top+Round(Q.Y*FScale);
      MouseDown(FCanvas,mbRight,[],PX,PY);
      Check((FProject.Snapshot=Before) and (FUndo.Count=UndoCount),'triangle refuses vertex deletion and keeps history');
      Panel:=Page.Panels[0]; Q:=TPointF.Create((Panel.Vertices[0].X+Panel.Vertices[1].X)/2,
        (Panel.Vertices[0].Y+Panel.Vertices[1].Y)/2);
      PX:=FPageRect.Left+Round(Q.X*FScale); PY:=FPageRect.Top+Round(Q.Y*FScale);
      FCanvas.Perform(WM_RBUTTONDOWN,MK_RBUTTON,MakeLParam(PX,PY)); FCanvas.Perform(WM_RBUTTONUP,0,MakeLParam(PX,PY));
      Check((Length(Page.Panels[0].Vertices)=4) and ValidPolygon(Page.Panels[0].Vertices),'right click on edge adds a valid projected vertex');
      SameImage('vertex insertion preserves image placement'); RoundTrip('inserted collinear vertex saves and reloads');
      Panel:=Page.Panels[0]; Q:=VertexHandles(Panel)[1]; PX:=FPageRect.Left+Round(Q.X*FScale); PY:=FPageRect.Top+Round(Q.Y*FScale);
      MouseDown(FCanvas,mbLeft,[],PX,PY); Check(FDragVertex=1,'added collinear vertex has an accessible inside handle');
      MouseMove(FCanvas,[ssLeft],PX-20,PY); MouseUp(FCanvas,mbLeft,[],PX-20,PY);
      Check(ValidPolygon(Page.Panels[0].Vertices) and not Page.Panels[0].CanSplit,'inward vertex edit creates a valid concave polygon');
      Capture('geometry-vertex-concave'); RoundTrip('concave vertex edited polygon saves and reloads');
      Undo(nil); Undo(nil); Check(Length(Page.Panels[0].Vertices)=3,'vertex insertion and drag each undo as one operation');
      Redo(nil); Redo(nil); Check(Length(Page.Panels[0].Vertices)=4,'vertex insertion and drag redo without losing topology');
      Panel:=Page.Panels[0];
      Points:=[TPointF.Create(100,100),TPointF.Create(70000,100),TPointF.Create(1100,1600),TPointF.Create(100,1600)];
      Panel.SetVertices(Points); PreservePanelImage(Panel,ImageRect);
      Check(Panel.Zoom<0.1,'large vertex expansion supports relative image scale below ten percent');
      SameImage('large vertex expansion preserves original global image rectangle');
      B.SetSize(600,850); FRenderer.Draw(B.Canvas,FProject,Page,Rect(0,0,600,850),False);
      RoundTrip('large vertex expansion saves and reloads its image scale');
      VertexDPI(96); VertexDPI(144);
    finally
      Reference.Free; PNG.Free; ResetGeometryInput; FDragging:=False; FFirst:=False;
      FProject.Free; FUndo.Free; FRedo.Free; FProject:=OriginalProject; FUndo:=OriginalUndo; FRedo:=OriginalRedo;
      FPageIndex:=OldIndex; FPanelIndex:=-1; FBalloonIndex:=-1; FTool:=0; FSnap.Checked:=OldSnap; RefreshUI;
      Check(FProject.Snapshot=Model,'isolated geometry tests preserve the main fixture project');
    end;
  end;
  procedure IconChecks;
  var OriginalPPI,OriginalW,OriginalH: Integer; OriginalScaled: Boolean; Model: string; Button,Probe: TComicIconButton;
    KeyValue: Word; NormalColor,HoverColor,SelectedColor,PressedColor,DisabledColor: TColor;
    PNG: TPngImage; RectA,RectB: TRect;
    function Find(Role: TComicButtonRole; Tag: Integer; Context: Integer=-1): TComicIconButton;
    var Candidate: TComicIconButton;
    begin
      Result:=nil; for Candidate in FIconButtons do
        if (Candidate.Role=Role) and (Candidate.Tag=Tag) and (Candidate.Context=Context) then Exit(Candidate);
      if Result=nil then raise Exception.Create('Icon command not found.');
    end;
    procedure SaveUI(const Name: string);
    begin
      UpdateIconState; HandleNeeded; B.SetSize(ClientWidth,ClientHeight); PaintTo(B.Canvas,0,0);
      PNG.Assign(B); PNG.SaveToFile(TPath.Combine(Folder,Name+'.png'));
    end;
    procedure CheckLayout(PPI,W,H: Integer; const Name: string);
    var Mode,PX,PY,Category: Integer; AllFit,NoOverlap: Boolean; First,Second: TComicIconButton; Scroll: TScrollBox;
    begin
      Scaled:=True; ScaleForPPI(PPI);
      // The hidden HWND stays on the host monitor. Use VCL's scaled control PPI
      // for offscreen validation instead of asking Windows for that HWND's DPI.
      Scaled:=False; Width:=MulDiv(W,PPI,96); Height:=MulDiv(H,PPI,96); Realign;
      Check((PixelsPerInch=PPI) and (CurrentPPI=PPI),Name+' applies requested VCL PPI '+IntToStr(PPI));
      for Mode:=0 to High(FModeButtons) do begin
        FModeButtons[Mode].Click;
        if Mode in [1,3] then TScrollBox(FTabs.ActivePage.Controls[0]).VertScrollBar.Position:=0;
        SaveUI(Name+'-mode'+IntToStr(Mode)); AllFit:=True; NoOverlap:=True;
        for First in FIconButtons do begin
          if (First.Left<0) or (First.Left+First.Width>First.Parent.ClientWidth) then AllFit:=False;
          for Second in FIconButtons do if (First<>Second) and (First.Parent=Second.Parent) then begin
            RectA:=First.BoundsRect; RectB:=Second.BoundsRect;
            if IntersectRect(RectA,RectA,RectB) then NoOverlap:=False;
          end;
        end;
        Check(AllFit and NoOverlap,Name+' mode '+IntToStr(Mode)+' icon bounds fit without overlap');
        Check((FModeTitle.Caption=FTabs.ActivePage.Caption) and FModeButtons[Mode].Selected,
          Name+' mode '+IntToStr(Mode)+' keeps selected icon and readable mode title');
        if Mode=1 then begin
          Scroll:=TScrollBox(FTabs.ActivePage.Controls[0]); Second:=nil;
          for First in FIconButtons do if (First.Role=brRegister) and (First.Parent=Scroll) then Second:=First;
          Check(Second<>nil,Name+' panel register command exists');
          Scroll.ScrollInView(Second); ActiveControl:=Second;
          Check((Second.Top>=0) and (Second.Top+Second.Height<=Scroll.ClientHeight),
            Name+' panel bottom action remains reachable by scrolling and focus');
          SaveUI(Name+'-mode1-scrolled');
        end;
        if Mode=3 then begin
          PX:=FPageRect.Left+Round(Page.Balloons[0].Bounds.CenterPoint.X*FScale);
          PY:=FPageRect.Top+Round(Page.Balloons[0].Bounds.CenterPoint.Y*FScale);
          FCanvas.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(PX,PY));
          FCanvas.Perform(WM_LBUTTONUP,0,MakeLParam(PX,PY));
          Scroll:=TScrollBox(FText.Parent); Second:=Find(brDeleteBalloon,1);
          Scroll.ScrollInView(Second); ActiveControl:=Second;
          Check((Second.Top>=0) and (Second.Top+Second.Height<=Scroll.ClientHeight),
            Name+' bottom actions remain reachable by scrolling and keyboard focus');
          SaveUI(Name+'-mode3-scrolled');
        end;
        if Mode=4 then begin
          for Category:=0 to 2 do begin
            FEffectCategory.ItemIndex:=Category; EffectCategoryChanged(nil); SaveUI(Name+'-mode4-category'+IntToStr(Category));
            Check((FEffectCategory.Left>=0) and (FEffectCategory.Top>=0) and
              (FEffectCategory.Left+FEffectCategory.Width<=FEffectCategory.Parent.ClientWidth) and
              (FEffectList.ItemHeight>0),Name+' effect category remains reachable '+IntToStr(Category));
            if Category>0 then begin
              Second:=Find(brDeleteEffect,Category); Scroll:=TScrollBox(Second.Parent); Scroll.ScrollInView(Second);
              if Second.Enabled then ActiveControl:=Second;
              Check((Second.Top>=0) and (Second.Top+Second.Height<=Scroll.ClientHeight),
                Name+' effect removal remains reachable by scrolling '+IntToStr(Category));
              SaveUI(Name+'-mode4-category'+IntToStr(Category)+'-scrolled');
            end;
          end;
          FEffectCategory.ItemIndex:=0; EffectCategoryChanged(nil);
        end;
      end;
      Check(not Visible,Name+' UI validation stays hidden');
    end;
    procedure SelectionStateChecks;
    var PX,PY,UndoCount: Integer; Bounds: TRectF; EmptyPanel: TComicPanel;
      procedure RenderGeometry;
      begin
        // Deliberately do not call Capture/SaveUI/UpdateIconState here.
        B.SetSize(ClientWidth,ClientHeight); PaintTo(B.Canvas,0,0);
      end;
      procedure ClickPage(X,Y: Single);
      begin
        PX:=FPageRect.Left+Round(X*FScale); PY:=FPageRect.Top+Round(Y*FScale);
        FCanvas.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(PX,PY));
        FCanvas.Perform(WM_LBUTTONUP,0,MakeLParam(PX,PY));
      end;
    begin
      UndoCount:=FUndo.Count; FModeButtons[1].Click; RenderGeometry; Bounds:=Page.Panels[0].Bounds;
      ClickPage((Bounds.Left+Bounds.Right)/2,(Bounds.Top+Bounds.Bottom)/2);
      Check(Find(brDeletePanel,0).Enabled,'normal panel selection enables panel actions');
      ClickPage(FProject.Width-30,FProject.Height-30);
      Check((FPanelIndex=-1) and not Find(brDeletePanel,0).Enabled and not Find(brDetachImage,0).Enabled and not FZoom.Enabled,
        'blank canvas click immediately disables panel actions without screenshot resync');
      FModeButtons[3].Click; RenderGeometry; Bounds:=Page.Balloons[0].Bounds;
      ClickPage((Bounds.Left+Bounds.Right)/2,(Bounds.Top+Bounds.Bottom)/2);
      Check(Find(brTail,7,3).Enabled and Find(brDeleteBalloon,1).Enabled and Find(brApplyText,0).Enabled,
        'normal balloon selection enables balloon actions');
      ClickPage(FProject.Width-30,FProject.Height-30);
      Check((FBalloonIndex=-1) and not Find(brTail,7,3).Enabled and not Find(brDeleteBalloon,1).Enabled and not Find(brApplyText,0).Enabled,
        'blank canvas click immediately disables balloon actions without screenshot resync');
      EmptyPanel:=TComicPanel.Create; EmptyPanel.Bounds:=TRectF.Create(950,600,1140,1640); Page.Panels.Add(EmptyPanel);
      try
        FModeButtons[2].Click; FImages.ItemIndex:=0; ImageSelectionChanged(FImages); RenderGeometry;
        Bounds:=Page.Panels[0].Bounds; ClickPage((Bounds.Left+Bounds.Right)/2,(Bounds.Top+Bounds.Bottom)/2);
        Check(Find(brDetachImage,0).Enabled and FZoom.Enabled,'assigned image selection enables image actions');
        ClickPage(1040,1200);
        Check((FPanelIndex=1) and Find(brAssignImage,0).Enabled and not Find(brDetachImage,0).Enabled and not FZoom.Enabled,
          'unassigned panel selection immediately updates image actions on early return');
      finally Page.Panels.Delete(Page.Panels.Count-1); FPanelIndex:=-1; end;
      Check(FUndo.Count=UndoCount,'selection-state events do not add undo history');
      Check(FProject.Snapshot=Model,'selection-state events preserve project data');
    end;
  begin
    Model:=FProject.Snapshot; OriginalPPI:=CurrentPPI; OriginalW:=Width; OriginalH:=Height; OriginalScaled:=Scaled;
    PNG:=TPngImage.Create;
    try
      Check(FIconButtons.Count>=30,'switching and editing commands use consistent icon controls');
      for Button in FIconButtons do Check((Button.Caption<>'') and (Button.Hint<>'') and Button.ShowHint and Button.TabStop,
        'icon keeps operation name, hint and tab stop: '+Button.Caption);
      FModeButtons[1].Click;
      Button:=Find(brTool,1,1); ActiveControl:=Button;
      Button.Perform(CM_DIALOGKEY,VK_SPACE,0);
      Check((FTool=1) and Button.Selected,'Space selects the rectangle tool and its selected state');
      KeyValue:=Ord('3'); Key(Self,KeyValue,[ssCtrl]);
      Check((FTabs.ActivePageIndex=2) and (KeyValue=0),'Ctrl+3 selects image placement');
      KeyValue:=VK_TAB; Key(Self,KeyValue,[ssCtrl]);
      Check(FTabs.ActivePageIndex=3,'Ctrl+Tab cycles screen modes');
      KeyValue:=VK_TAB; Key(Self,KeyValue,[ssCtrl,ssShift]);
      Check(FTabs.ActivePageIndex=2,'Ctrl+Shift+Tab cycles screen modes backwards');
      FModeButtons[0].Click; ActiveControl:=FModeButtons[0];
      FModeButtons[0].Perform(WM_KEYDOWN,VK_RIGHT,0);
      Check((FTabs.ActivePageIndex=1) and (ActiveControl=FModeButtons[1]),'arrow key switches mode and focus');
      Button:=Find(brTool,0,1); ActiveControl:=Button; Button.Perform(WM_KEYDOWN,VK_RIGHT,0);
      Check((FTool=1) and (ActiveControl=Find(brTool,1,1)),'arrow key switches edit tool and focus');
      Button.Perform(CM_MOUSEENTER,0,0);
      Check(Button.Hovered and (FStatus.SimpleText=Button.Hint),'hover highlights icon and exposes status help');
      Button.Perform(CM_MOUSELEAVE,0,0); Check(not Button.Hovered,'mouse leave clears hover');
      SelectionStateChecks;
      Probe:=TComicIconButton.Create(Self);
      try
        Probe.Parent:=FView; Probe.SetBounds(4,4,44,44); Probe.Icon:=ciRectangle; Probe.Caption:='test';
        Probe.ControlStyle:=Probe.ControlStyle-[csCaptureMouse]; Probe.OnClick:=IconTestClick;
        ActiveControl:=Probe; FIconTestClicks:=0;
        Probe.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(20,20));
        Probe.Perform(WM_LBUTTONUP,0,MakeLParam(20,20));
        Check(FIconTestClicks=1,'native mouse messages invoke an icon command exactly once');
        FIconTestClicks:=0; Probe.Perform(WM_KEYDOWN,VK_SPACE,0); Probe.Perform(WM_CHAR,VK_SPACE,0); Probe.Perform(WM_KEYUP,VK_SPACE,0);
        Check(FIconTestClicks=1,'Space invokes an icon command exactly once');
        FIconTestClicks:=0; Probe.Perform(CM_DIALOGKEY,VK_RETURN,0); Probe.Perform(WM_CHAR,VK_RETURN,0); Probe.Perform(WM_KEYUP,VK_RETURN,0);
        Check(FIconTestClicks=1,'Enter invokes an icon command exactly once');
        Probe.Enabled:=False; FIconTestClicks:=0; Probe.Click; Probe.Perform(WM_KEYDOWN,VK_SPACE,0);
        Check(FIconTestClicks=0,'disabled icon cannot invoke an action'); Probe.Enabled:=True;
        FView.Enabled:=False; Probe.Click; Probe.Perform(WM_KEYDOWN,VK_SPACE,0);
        Check(FIconTestClicks=0,'disabled parent prevents icon action'); FView.Enabled:=True;
        B.SetSize(220,44); Probe.Perform(CM_MOUSELEAVE,0,0); Probe.Selected:=False;
        Probe.RenderTo(B.Canvas,Rect(0,0,44,44)); NormalColor:=B.Canvas.Pixels[8,8];
        Probe.Perform(CM_MOUSEENTER,0,0); Probe.RenderTo(B.Canvas,Rect(44,0,88,44)); HoverColor:=B.Canvas.Pixels[52,8];
        Probe.Selected:=True; Probe.Perform(CM_MOUSELEAVE,0,0); Probe.RenderTo(B.Canvas,Rect(88,0,132,44)); SelectedColor:=B.Canvas.Pixels[96,8];
        Probe.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(20,20)); Probe.RenderTo(B.Canvas,Rect(132,0,176,44)); PressedColor:=B.Canvas.Pixels[140,8];
        Probe.Perform(WM_LBUTTONUP,0,MakeLParam(20,20)); Probe.Enabled:=False;
        Probe.RenderTo(B.Canvas,Rect(176,0,220,44)); DisabledColor:=B.Canvas.Pixels[184,8];
        PNG.Assign(B); PNG.SaveToFile(TPath.Combine(Folder,'icon-states.png'));
        Check((NormalColor<>HoverColor) and (NormalColor<>SelectedColor) and (NormalColor<>PressedColor) and
          (NormalColor<>DisabledColor),'normal, hover, selected, pressed and disabled appearance are distinct');
      finally ActiveControl:=nil; Probe.Free; FView.Enabled:=True; end;
      CheckLayout(96,1420,920,'ui-96');
      CheckLayout(96,940,660,'ui-96-narrow');
      CheckLayout(144,1200,820,'ui-144');
      CheckLayout(144,940,660,'ui-144-narrow');
      Check(FProject.Snapshot=Model,'icon switching, keyboard and DPI layout preserve project data');
    finally
      PNG.Free; Scaled:=True; ScaleForPPI(OriginalPPI); Width:=OriginalW; Height:=OriginalH; Scaled:=OriginalScaled;
      FTabs.ActivePageIndex:=0; TabChanged(nil); ActiveControl:=nil; Realign;
    end;
  end;
begin
  if (GetEnvironmentVariable('MANGAMAKER_DATA_ROOT')='') or
    not TPath.GetFullPath(DataRoot).StartsWith(IncludeTrailingPathDelimiter(TPath.GetFullPath(Folder)),True) then
    raise Exception.Create('Self-test data must be isolated under its output folder.');
  ForceDirectories(Folder); B:=TBitmap.Create; Lines:=TStringList.Create;
  try
    Check(not HasCharacter,'empty library blocks production');
    B.SetSize(700,440); B.Canvas.Brush.Color:=$E9C193; B.Canvas.FillRect(Rect(0,0,700,440));
    B.Canvas.Brush.Color:=$997752; B.Canvas.Ellipse(120,50,500,430); B.SaveToFile(TPath.Combine(Folder,'reference.bmp'));
    A:=TComicAsset.Create; A.Name:='テスト人物'; A.FileName:='reference.bmp'; FCharacters.Add(A);
    ForceDirectories(TPath.Combine(DataRoot,'Characters'));
    TFile.Copy(TPath.Combine(Folder,'reference.bmp'),TPath.Combine(DataRoot,'Characters\reference.bmp'),True);
    Check(HasCharacter,'character name and reference enable production');
    WriteAssets(FCharacters,TPath.Combine(DataRoot,'Characters\Library.json'));
    SafetyChecks;
    FProject:=TComicProject.Create; FProject.Initialize('保存テスト・日本語','第1話'); FPageIndex:=0;
    A:=FProject.ImportImage(TPath.Combine(Folder,'reference.bmp'),''); A.Name:='場面画像'; AssetID:=A.ID;
    P:=TComicPanel.Create; P.Bounds:=TRectF.Create(60,60,1140,1100); P.ImageID:=AssetID; P.Zoom:=1.5; P.PanX:=42; Page.Panels.Add(P);
    Balloon:=TComicBalloon.Create; Balloon.Text:='漫画を作ろう！'; Balloon.HasTail:=True; Balloon.PanelID:=P.ID;
    Balloon.TailX:=480; Balloon.TailY:=540; Page.Balloons.Add(Balloon);
    FProject.Save; Snapshot:=FProject.Snapshot;
    Loaded:=TComicProject.Create;
    try
      Loaded.Load(TPath.Combine(FProject.Folder,'Project.json'));
      Check(Loaded.Snapshot=Snapshot,'UTF-8 project save and load roundtrip');
      Check(Loaded.Pages[0].Panels[0].ImageID=AssetID,'stable image UID after loading');
    finally Loaded.Free; end;
    Checkpoint; Page.Panels[0].Bounds.Right:=900; Changed; Undo(nil);
    Check(Page.Panels[0].Bounds.Right=1140,'panel undo'); Redo(nil);
    Check(Page.Panels[0].Bounds.Right=900,'panel redo');
    RenderChecks;
    EditingChecks;
    TextSessionChecks;
    TextNavigationChecks;
    TextLayoutChecks;
    PageBasisChecks;
    PanelGroupChecks;
    LayoutManagementChecks;
    FontStyleChecks;
    CreatedPanelSelectionChecks;
    TailChecks;
    BalloonContourChecks;
    TextPlacementChecks;
    TextScaledWrappingChecks;
    GenerationPresetChecks;
    BridgeChecks;
    CharacterGroupChecks;
    SceneGenerationChecks;
    EffectChecks;
    DragCommandChecks;
    BlurScaleChecks;
    RecentProjectChecks;
    GapSnapChecks;
    PanelTransformSnapChecks;
    ExportReviewChecks;
    BulkDataChecks;
    IconChecks;
    Layout:=TComicLayout.Create; Layout.Name:='楕円のテスト・共通';
    Page.Panels[0].Shape:=1; Layout.Capture(FProject,Page); FLayouts.Add(Layout);
    J:=Layout.Json;
    try Check((Pos('imageId',J.ToJSON)=0) and (Pos('balloons',J.ToJSON)=0) and (Pos(AssetID,J.ToJSON)=0),
      'layout contains geometry only'); finally J.Free; end;
    SaveLayouts(FLayouts,TPath.Combine(DataRoot,'Presets\Layouts.json'));
    LibraryCopy:=TObjectList<TComicLayout>.Create;
    try
      SeedLayouts(LibraryCopy); LoadLayouts(LibraryCopy,TPath.Combine(DataRoot,'Presets\Layouts.json'));
      Check((LibraryCopy.Count=6) and (LibraryCopy.Last.ID=Layout.ID) and (LibraryCopy.Last.Name=Layout.Name),
        'shared custom layout persists with stable ID and Japanese name');
      Loaded:=TComicProject.Create;
      try
        Loaded.Pages.Add(TComicPage.Create); LibraryCopy.Last.Apply(Loaded.Pages[0],600,850);
        Check((Loaded.Pages[0].Panels[0].Bounds.Right=450) and (Loaded.Pages[0].Panels[0].Shape=1),
          'layout scales to a different page resolution');
        Check((Loaded.Pages[0].Panels[0].ID<>Page.Panels[0].ID) and (Loaded.Pages[0].Panels[0].ImageID=''),
          'layout creates new panels without image assignments');
      finally Loaded.Free; end;
      AtomicWrite(TPath.Combine(Folder,'bad-layouts.json'),'{"version":1,"layouts":[{"id":"broken","name":"bad","width":1200,"height":1700,"panels":[{"x":0,"y":0,"w":-1,"h":100}]}]}');
      Failed:=False;
      try LoadLayouts(LibraryCopy,TPath.Combine(Folder,'bad-layouts.json')); except Failed:=True; end;
      Check(Failed and (LibraryCopy.Count=6),'invalid library preserves existing layouts');
    finally LibraryCopy.Free; end;
    FLayoutList.Items.AddObject(Layout.Name,Layout);
    RefreshUI; FirstID:=Page.ID;
    ApplyLayout(FLayouts[3],-1);
    Check((Page.Panels.Count=4) and (Page.Balloons.Count=0),'template replacement clears old panel content');
    Undo(nil);
    Check((Page.Panels.Count=1) and (Page.Panels[0].ImageID=AssetID) and
      (Page.Panels[0].Zoom=1.5) and (Page.Panels[0].PanX=42) and
      (Page.Balloons.Count=1) and (Page.Balloons[0].Text='漫画を作ろう！') and
      (Page.Balloons[0].TailX=480),'template undo restores image placement and whole balloon');
    Redo(nil); Check(Page.Panels.Count=4,'template redo');
    FLayoutList.ItemIndex:=1; R:=FPages.ItemRect(0);
    PagesDragDrop(FPages,FLayoutList,8,R.Bottom-1);
    SecondID:=Page.ID;
    Check((FProject.Pages.Count=2) and (FProject.Pages[0].ID=FirstID) and (Page.Panels.Count=2),
      'drop layout between pages inserts and selects a new page');
    Undo(nil); Check((FProject.Pages.Count=1) and (FProject.Pages[0].ID=FirstID),'insert undo restores page sequence');
    Redo(nil); Check((FProject.Pages.Count=2) and (FProject.Pages[1].ID=SecondID),'insert redo keeps new page UID');
    SelectOnly(1); AddPage(nil); ThirdID:=Page.ID; AddPage(nil); FourthID:=Page.ID;
    FPages.ItemIndex:=0; FPages.Selected[0]:=True; FPages.Selected[1]:=False;
    FPages.Selected[2]:=True; FPages.Selected[3]:=False; PageSelect(nil);
    R:=FPages.ItemRect(3); PagesDragDrop(FPages,FPages,8,R.Bottom-1);
    Check((FProject.Pages[0].ID=SecondID) and (FProject.Pages[1].ID=FourthID) and
      (FProject.Pages[2].ID=FirstID) and (FProject.Pages[3].ID=ThirdID),
      'multi-page drag preserves relative order');
    Check(FPages.Selected[2] and FPages.Selected[3] and (FPages.SelCount=2),'selection follows moved page UIDs');
    Undo(nil); Check((FProject.Pages[0].ID=FirstID) and (FProject.Pages[2].ID=ThirdID),'multi-page move undo');
    Redo(nil); Check(FProject.Pages[2].ID=FirstID,'multi-page move redo');
    SelectOnly(2); FImages.ItemIndex:=0; FPanelIndex:=0; AssignImage(nil);
    FProject.Pages[0].Panels[0].ImageID:=AssetID;
    FProject.Pages[0].Panels[1].ImageID:=AssetID;
    FPanelIndex:=0; DetachImage(nil);
    Check((Page.Panels[0].ImageID='') and (FProject.Asset(AssetID)<>nil),'detach preserves project image');
    Undo(nil); Check(Page.Panels[0].ImageID=AssetID,'detach undo restores image assignment');
    RefreshUI; FTabs.ActivePageIndex:=0; TabChanged(nil); Capture('window-layouts');
    Check(not Visible,'UI capture keeps main window hidden');
    FTabs.ActivePageIndex:=2; TabChanged(nil); Capture('window-images');
    DragOver(FCanvas,FImages,-1,-1,dsDragMove,Accept); Check(not Accept,'image drop outside page is rejected');
    R:=FPageRect; DragOver(FCanvas,FImages,R.Left+Round(800*FScale),R.Top+Round(400*FScale),dsDragMove,Accept);
    Check(Accept,'image thumbnail can be dropped on a panel');
    DragOver(FCanvas,FImages,R.Left+Round(600*FScale),R.Top+Round(850*FScale),dsDragMove,Accept);
    Check(not Accept,'image drop in gutter is rejected');
    FRenderer.ExportPage(FProject,Page,TPath.Combine(Folder,'page.png'));
    N:=ExportSequence(FProject,FRenderer,False); Check(N=4,'first PNG export renders every page');
    Check(ExportSequence(FProject,FRenderer,False)=0,'unchanged export reuses PNG cache');
    CacheFile:=TPath.Combine(FProject.Folder,'Output\.cache\'+FirstID+'.png');
    Snapshot:=THashSHA2.GetHashStringFromFile(CacheFile);
    FProject.Pages.Move(2,0); FPageIndex:=0; Changed(False);
    Check(ExportSequence(FProject,FRenderer,False)=0,'page reorder copies cached PNG without rerendering');
    Check(THashSHA2.GetHashStringFromFile(TPath.Combine(FProject.Folder,'Output\0001.png'))=Snapshot,
      'sequential filename follows reordered page UID');
    Checkpoint; Page.Panels[0].PanX:=222; Changed;
    SignatureLock:=CreateFile(PChar(CacheFile+'.signature'),GENERIC_READ,FILE_SHARE_READ or FILE_SHARE_WRITE,
      nil,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,0);
    if SignatureLock=INVALID_HANDLE_VALUE then RaiseLastOSError;
    try
      Failed:=False;
      try ExportSequence(FProject,FRenderer,False); except Failed:=True; end;
      Check(Failed,'locked signature injects export publication failure');
      Check(THashSHA2.GetHashStringFromFile(CacheFile)=Snapshot,'signature invalidation failure keeps previous cached PNG');
    finally CloseHandle(SignatureLock); end;
    Undo(nil); Check(ExportSequence(FProject,FRenderer,False)=0,'undo after locked-signature failure reuses valid old cache');
    Check(THashSHA2.GetHashStringFromFile(TPath.Combine(FProject.Folder,'Output\0001.png'))=Snapshot,
      'undo after signature failure exports the correct previous image');
    Checkpoint; Page.Panels[0].PanX:=333; Changed;
    SignatureLock:=CreateFile(PChar(CacheFile+'.signature.tmp'),GENERIC_READ or GENERIC_WRITE,FILE_SHARE_READ,
      nil,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,0);
    if SignatureLock=INVALID_HANDLE_VALUE then RaiseLastOSError;
    try
      Failed:=False;
      try ExportSequence(FProject,FRenderer,False); except Failed:=True; end;
      Check(Failed and not FileExists(CacheFile+'.signature'),
        'signature write failure leaves no stale signature beside replaced PNG');
    finally CloseHandle(SignatureLock); end;
    Undo(nil); Check(ExportSequence(FProject,FRenderer,False)=1,'undo after signature write failure rerenders safely');
    Check(THashSHA2.GetHashStringFromFile(TPath.Combine(FProject.Folder,'Output\0001.png'))=Snapshot,
      'signature write failure recovery restores the correct previous image');
    Checkpoint; Page.Panels[0].PanX:=123; Changed;
    Check(ExportSequence(FProject,FRenderer,False)=1,'single-page edit rerenders only that page');
    Undo(nil); Check(ExportSequence(FProject,FRenderer,False)=1,'undo after export cannot reuse stale content');
    Checkpoint; Page.Panels[0].PanX:=321; Changed;
    Check(ExportSequence(FProject,FRenderer,False)=1,'new edit after undo cannot collide with old revision');
    B.SetSize(700,440); B.Canvas.Brush.Color:=$4466AA; B.Canvas.FillRect(Rect(0,0,700,440));
    B.SaveToFile(FProject.ImagePath(AssetID));
    Check(ExportSequence(FProject,FRenderer,False)=2,'same-path image replacement rerenders referencing pages only');
    Check(ExportSequence(FProject,FRenderer,False)=0,'updated image export becomes stable');
    A2:=FProject.ImportImage(TPath.Combine(Folder,'reference.bmp'),''); A2.Name:='別の場面';
    Check(ExportSequence(FProject,FRenderer,False)=0,'unused image import does not rerender pages');
    FProject.Width:=600; FProject.Height:=850;
    Check(ExportSequence(FProject,FRenderer,False)=4,'resolution change invalidates every page');
    Check(ExportSequence(FProject,FRenderer,True)=4,'all-pages export forces rerender');
    P:=FProject.Pages[1].Panels[0]; BeforeOutput:=FProject.Pages[1].OutputRevision;
    P.ImageID:=A2.ID; Inc(FProject.Pages[1].Revision);
    TFile.WriteAllText(FProject.ImagePath(A2.ID),'not an image',TEncoding.UTF8);
    Failed:=False;
    try ExportSequence(FProject,FRenderer,False); except Failed:=True; end;
    Check(Failed and (FProject.Pages[1].OutputRevision=BeforeOutput),'failed page is not recorded as exported');
    TFile.Copy(TPath.Combine(Folder,'reference.bmp'),FProject.ImagePath(A2.ID),True);
    Check(ExportSequence(FProject,FRenderer,False)=1,'failed export can be retried successfully');
    Checkpoint; FProject.Pages.Delete(3); Changed(False);
    Check(ExportSequence(FProject,FRenderer,False)=0,'page deletion does not rerender surviving pages');
    Check(not FileExists(TPath.Combine(FProject.Folder,'Output\0004.png')),'page deletion removes stale sequence file');
    Undo(nil); Check(ExportSequence(FProject,FRenderer,False)=0,'undo deletion reuses removed page cache');
    Check(FileExists(TPath.Combine(FProject.Folder,'Output\0004.png')),'undo deletion restores fourth sequential output');
    Redo(nil); Check(ExportSequence(FProject,FRenderer,False)=0,'redo deletion reuses surviving page caches');
    Check(not FileExists(TPath.Combine(FProject.Folder,'Output\0004.png')),'redo deletion cleans sequence using actual export history');
    Snapshot:=FProject.Snapshot; SecondID:=FProject.Pages[1].ID; SelectOnly(0); FPages.Selected[2]:=True;
    RemoveSelectedPages(False);
    Check((FProject.Pages.Count=1) and (FProject.Pages[0].ID=SecondID),'multi-page deletion removes exactly the selection');
    Undo(nil);
    Check((FProject.Pages.Count=3) and (FProject.Pages[1].ID=SecondID),'multi-page deletion undo restores contents and order');
    Redo(nil); Check(FProject.Pages.Count=1,'multi-page deletion redo'); Undo(nil);
    SelectOnly(0); FPages.SelectAll; RemoveSelectedPages(False);
    Check((FProject.Pages.Count=0) and (Page=nil),'all-pages deletion leaves a valid empty project');
    Undo(nil); Check(FProject.Pages.Count=3,'all-pages deletion undo');
    FProject.Width:=1200; FProject.Height:=1700; FPageIndex:=0; RefreshUI;
    GeometryChecks;
    FTabs.ActivePageIndex:=0; TabChanged(nil); Capture('window-final');
    Dialog:=TAssetDialog.CreateManager(Self,FCharacters,nil,True);
    try
      Dialog.HandleNeeded; B.SetSize(Dialog.ClientWidth,Dialog.ClientHeight); Dialog.PaintTo(B.Canvas,0,0);
      B.SaveToFile(TPath.Combine(Folder,'window-characters.bmp'));
    finally Dialog.Free; end;
    FProject.Save; FDirty:=False;
    ViewportChecks;
    Lines.Add('PASS: hidden VCL captures, no external generation or transmission.');
    TFile.WriteAllText(TPath.Combine(Folder,'result.txt'),Lines.Text,TEncoding.UTF8);
  finally Lines.Free; B.Free; end;
end;

end.
