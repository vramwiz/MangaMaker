unit MangaMakerMainForm;

interface

uses Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math,
  System.IOUtils, System.Generics.Collections, System.JSON, System.Hash, Vcl.Controls, Vcl.Forms,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Menus, Vcl.Dialogs,
  Vcl.Graphics, Vcl.Imaging.pngimage, ComicModel, ComicRender, ComicAssetDialog, ComicLayouts, ComicExport, ComicEditing, ComicIconButton, ComicGeometry, ComicTextInput;

type
  TComicPaintBox = class(TPaintBox)
  public
    property MouseCapture;
    property ControlStyle;
  end;
  TComicView = class(TPanel)
  public
    property ImeMode;
  end;
  TMainForm = class(TForm)
  private
    FProject: TComicProject;
    FCharacters: TObjectList<TComicAsset>;
    FRenderer: TComicRenderer;
    FUndo,FRedo: TList<string>;
    FPages,FImages,FLayoutList: TListBox;
    FLayouts: TObjectList<TComicLayout>;
    FLayoutLibraryWritable: Boolean;
    FPageDropIndex: Integer;
    FCanvas: TComicPaintBox;
    FView: TComicView;
    FTabs: TPageControl;
    FStatus: TStatusBar;
    FText: TMemo;
    FVertical,FTransparent,FOverflow: TCheckBox;
    FFont,FZoom: TComboBox;
    FPageIndex,FPanelIndex,FBalloonIndex,FTool,FNumber: Integer;
    FFirst,FDragging,FDirty,FRefreshing: Boolean;
    FStart,FLast: TPointF;
    FDragBounds: TRectF;
    FPageRect: TRect;
    FScale: Double;
    FDragHandle: Integer;
    FDragSnapshot: string;
    FDragMoved: Boolean;
    FTesting: Boolean;
    FIconButtons: TList<TComicIconButton>;
    FModeButtons: array[0..3] of TComicIconButton;
    FModeTitle: TLabel;
    FDragZoom,FDragTailX,FDragTailY: Double;
    FIconTestClicks: Integer;
    FGeometryPoints: TList<TPointF>;
    FSnap: TCheckBox;
    FSplitStage: Integer;
    FSplitPanelID: string;
    FSplitA,FSplitB,FSplitC,FSplitD: TPointF;
    FDragVertices: TArray<TPointF>;
    FDragVertex: Integer;
    FDragImageBounds: TRectF;
    function VertexHandles(Panel: TComicPanel): TArray<TPointF>;
    function HitVertex(Panel: TComicPanel; const P: TPointF): Integer;
    procedure EditVertexContext(const P: TPointF);
    procedure PreservePanelImage(Panel: TComicPanel; const Original: TRectF);
    procedure ResetGeometryInput;
    function SnapCreationPoint(const P: TPointF; const ExcludePanelID: string=''): TPointF;
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
    function ToPage(X,Y: Integer): TPointF;
    function HitPanel(const P: TPointF): Integer;
    function HitBalloon(const P: TPointF): Integer;
    procedure DeleteObject(Sender: TObject);
    procedure AssignImage(Sender: TObject);
    procedure DragOver(Sender,Source: TObject; X,Y: Integer; State: TDragState; var Accept: Boolean); reintroduce;
    procedure DragDrop(Sender,Source: TObject; X,Y: Integer); reintroduce;
    procedure ApplyText(Sender: TObject);
    procedure TextInputDialog(Sender: TObject);
    procedure FinishTextDialog(Dialog: TComicTextDialog);
    procedure ImageZoom(Sender: TObject);
    procedure ImageSelectionChanged(Sender: TObject);
    procedure Tail(Sender: TObject);
    procedure CloseCheck(Sender: TObject; var CanClose: Boolean);
    procedure Key(Sender: TObject; var Key: Word; Shift: TShiftState);
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

constructor TMainForm.Create(AOwner: TComponent);
begin
  inherited; FPageIndex:=-1; FPanelIndex:=-1; FBalloonIndex:=-1; FDragVertex:=-1; FScale:=1;
  FTesting:=(ParamCount>0) and (ParamStr(1)='--self-test');
  FCharacters:=TObjectList<TComicAsset>.Create; FRenderer:=TComicRenderer.Create;
  FUndo:=TList<string>.Create; FRedo:=TList<string>.Create;
  FIconButtons:=TList<TComicIconButton>.Create;
  FGeometryPoints:=TList<TPointF>.Create;
  FLayouts:=TObjectList<TComicLayout>.Create; FLayoutLibraryWritable:=True; FPageDropIndex:=-1;
  SeedLayouts(FLayouts);
  try LoadLayouts(FLayouts,TPath.Combine(DataRoot,'Presets\Layouts.json'));
  except on E: Exception do begin FLayoutLibraryWritable:=False; ShowMessage('コマ割りライブラリを読み込めません。元ファイルは保持します。'+sLineBreak+E.Message); end; end;
  BuildUI;
  try ReadAssets(FCharacters,TPath.Combine(DataRoot,'Characters\Library.json'));
  except on E: Exception do ShowMessage(E.Message); end;
  RefreshUI;
end;
destructor TMainForm.Destroy;
begin FProject.Free; FCharacters.Free; FRenderer.Free; FUndo.Free; FRedo.Free; FLayouts.Free; FIconButtons.Free; FGeometryPoints.Free; inherited; end;
procedure TMainForm.BuildUI;
var Menu: TMainMenu; M,N: TMenuItem; Top,Left,Right,Bar,P,Modes: TPanel; Layout: TComicLayout;
  Tab: TTabSheet; Body: TScrollBox; L: TLabel;
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
  Item('保存',SaveProject,ShortCut(Ord('S'),[ssCtrl])); Item('連番PNG出力...',ExportPNG);
  M:=TMenuItem.Create(Self); M.Caption:='編集'; Menu.Items.Add(M);
  Item('元に戻す',Undo,ShortCut(Ord('Z'),[ssCtrl])); Item('やり直す',Redo,ShortCut(Ord('Y'),[ssCtrl]));
  M:=TMenuItem.Create(Self); M.Caption:='設定・管理'; Menu.Items.Add(M);
  Item('キャラクター管理...',Characters); Item('画像管理...',Images);
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
  FModeTitle:=TLabel.Create(Self); FModeTitle.Parent:=Modes; FModeTitle.AutoSize:=False;
  FModeTitle.SetBounds(D(12),D(60),D(282),D(24)); FModeTitle.Font.Style:=[fsBold];
  FTabs:=TPageControl.Create(Self); FTabs.Parent:=Right; FTabs.Align:=alClient;
  Tab:=TabSheet('コマ割り管理');
  P:=TPanel.Create(Self); P.Parent:=Tab; P.Align:=alTop; P.Height:=D(144); P.BevelOuter:=bvNone;
  LabelAt(P,'中央：内容を置換（元に戻せます）'+sLineBreak+'左のページ間：新規ページに挿入',10,8);
  Icon(P,'現在のコマ割りを登録',10,56,270,36,ciRegister,0,brRegister,RegisterLayout,True);
  Icon(P,'選択に適用',10,100,132,36,ciApplyLayout,0,brApplyLayout,Template,True);
  Icon(P,'直下に挿入',148,100,132,36,ciInsertLayout,0,brInsertLayout,InsertLayout,True);
  FLayoutList:=TListBox.Create(Self); FLayoutList.Parent:=Tab; FLayoutList.Align:=alClient;
  FLayoutList.Style:=lbOwnerDrawFixed; FLayoutList.ItemHeight:=D(116); FLayoutList.DragMode:=dmAutomatic;
  FLayoutList.OnDrawItem:=DrawLayoutItem; FLayoutList.OnDblClick:=Template;
  for Layout in FLayouts do FLayoutList.Items.AddObject(Layout.Name,Layout);
  FLayoutList.ItemIndex:=0;
  Tab:=TabSheet('コマ編集'); Body:=Scrolling(Tab);
  LabelAt(Body,'青8点：拡縮／黄色：頂点移動'+sLineBreak+'頂点・辺を右クリック：削除・追加',12,10);
  Icon(Body,'選択・移動',12,62,44,44,ciSelect,0,brTool,Tool,False,1).Hint:='青の外周8点で拡縮、黄色の内側点で頂点移動。頂点を右クリックで削除、辺を右クリックで追加。';
  Icon(Body,'四角コマ：対角2点をクリック',68,62,44,44,ciRectangle,1,brTool,Tool,False,1);
  Icon(Body,'楕円コマ：対角2点をクリック',124,62,44,44,ciEllipse,2,brTool,Tool,False,1);
  Icon(Body,'角丸コマ：対角2点をクリック',180,62,44,44,ciRounded,3,brTool,Tool,False,1);
  Icon(Body,'読む順番にコマをクリック',236,62,44,44,ciOrder,4,brTool,Tool,False,1);
  LabelAt(Body,'選択  /  四角  /  楕円  /  角丸  /  順序',12,114,28);
  Icon(Body,'多角形コマ',12,150,132,44,ciPolygon,8,brTool,Tool,True,1).Hint:='頂点をクリックし、最初の点で閉じます。右クリックで最後の点を戻す。Escで中止。';
  Icon(Body,'4点分割',150,150,130,44,ciSplit,9,brTool,Tool,True,1).Hint:='四角・凸多角形の外周2点、帯の幅、対側交点をクリックして分割します。';
  FSnap:=TCheckBox.Create(Self); FSnap.Parent:=Body; FSnap.SetBounds(D(12),D(202),D(268),D(26));
  FSnap.Caption:='外枠・コマへのスナップ（Altで解除）'; FSnap.Checked:=True;
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
  Icon(Body,'選択・移動／ダブルクリックで文字再入力',12,12,44,44,ciSelect,0,brTool,Tool,False,3);
  Icon(Body,'楕円の吹き出し：対角2点をクリック',72,12,44,44,ciBalloonEllipse,5,brTool,Tool,False,3);
  Icon(Body,'角丸の吹き出し：対角2点をクリック',132,12,44,44,ciBalloonRounded,6,brTool,Tool,False,3);
  Icon(Body,'選択した吹き出しのしっぽ先端を指定',192,12,44,44,ciTail,7,brTail,Tail,False,3);
  LabelAt(Body,'選択 / 楕円 / 角丸 / しっぽ',12,64,28);
  LabelAt(Body,'選択中の吹き出しのセリフ',12,100,28);
  FText:=TMemo.Create(Self); FText.Parent:=Body; FText.SetBounds(D(12),D(132),D(270),D(100)); FText.ScrollBars:=ssVertical;
  FText.ImeMode:=imOpen;
  Icon(Body,'専用文字入力',12,238,270,32,ciApplyText,0,brApplyText,TextInputDialog,True).Hint:='IMEとUTF-16編集バッファを使う専用入力。確定で反映、取消で作品を維持。';
  FVertical:=TCheckBox.Create(Self); FVertical.Parent:=Body; FVertical.SetBounds(D(12),D(280),D(130),D(26)); FVertical.Caption:='縦書き';
  FTransparent:=TCheckBox.Create(Self); FTransparent.Parent:=Body; FTransparent.SetBounds(D(144),D(280),D(130),D(26)); FTransparent.Caption:='文字だけ表示';
  FOverflow:=TCheckBox.Create(Self); FOverflow.Parent:=Body; FOverflow.SetBounds(D(12),D(312),D(270),D(26)); FOverflow.Caption:='コマ枠からはみ出すことを許可'; FOverflow.Checked:=True;
  FFont:=TComboBox.Create(Self); FFont.Parent:=Body; FFont.SetBounds(D(12),D(354),D(92),D(28)); FFont.Style:=csDropDownList;
  FFont.Items.AddStrings(['24','32','40','48','64','80']); FFont.ItemIndex:=2;
  Icon(Body,'文字・設定を反映',114,348,168,40,ciApplyText,0,brApplyText,ApplyText,True);
  Icon(Body,'選択した吹き出しを削除',12,404,270,40,ciDelete,1,brDeleteBalloon,DeleteObject,True);
  Body.VertScrollBar.Range:=D(456);
  FView:=TComicView.Create(Self); FView.Parent:=Self; FView.Align:=alClient; FView.BevelOuter:=bvNone;
  FView.Color:=$302B28; FView.ParentBackground:=False; FView.DoubleBuffered:=True;
  FView.ImeMode:=imDisable; FView.TabStop:=True;
  FCanvas:=TComicPaintBox.Create(Self); FCanvas.Parent:=FView; FCanvas.Align:=alClient; FCanvas.OnPaint:=Paint;
  if FTesting then FCanvas.ControlStyle:=FCanvas.ControlStyle-[csCaptureMouse];
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
begin Result:=(FProject<>nil) and HasCharacter; if not Result then ShowMessage('参照画像付きのキャラを登録し、作品を作成または開いてください。'); end;
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
    FTabs.Enabled:=(FProject<>nil) and HasCharacter;
    if not HasCharacter then FStatus.SimpleText:='はじめに［キャラ管理］で人物名と参照画像を登録してください。'
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
        ((Button.Role in [brTool,brTail]) and (Next.Role in [brTool,brTail]))) then Candidates.Add(Next);
    Index:=Candidates.IndexOf(Button); if (Index<0) or (Candidates.Count<2) then Exit;
    if Key in [VK_LEFT,VK_UP] then Step:=-1 else Step:=1;
    I:=(Index+Step+Candidates.Count) mod Candidates.Count; Next:=Candidates[I];
    ActiveControl:=Next; Next.Click; Key:=0;
  finally Candidates.Free; end;
end;
procedure TMainForm.UpdateIconState;
var Button: TComicIconButton; CanEdit,HasPage,HasPanel,HasBalloon: Boolean;
begin
  if FTabs=nil then Exit; CanEdit:=(FProject<>nil) and HasCharacter; HasPage:=CanEdit and (Page<>nil);
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
      brTool: Button.Enabled:=HasPage and ((Button.Tag=0) or (FImages.Count>0));
      brDeletePanel: Button.Enabled:=HasPanel;
      brAssignImage: Button.Enabled:=HasPanel and (FImages.ItemIndex>=0);
      brDetachImage: Button.Enabled:=HasPanel and (Page.Panels[FPanelIndex].ImageID<>'');
      brTail,brApplyText,brDeleteBalloon: Button.Enabled:=HasBalloon;
    end;
    if (Button.Role=brTool) and (Button.Tag=9) then
      Button.Enabled:=HasPage and (Page.Panels.Count>0) and ((not HasPanel) or Page.Panels[FPanelIndex].CanSplit);
    Button.Selected:=((Button.Role=brMode) and (Button.Tag=FTabs.ActivePageIndex)) or
      ((Button.Role in [brTool,brTail]) and (Button.Context=FTabs.ActivePageIndex) and (Button.Tag=FTool));
  end;
  FModeTitle.Caption:=FTabs.ActivePage.Caption;
  FZoom.Enabled:=HasPanel and (Page.Panels[FPanelIndex].ImageID<>'');
end;
procedure TMainForm.ShowPageStatus;
var P: TComicPanel; IDs: TDictionary<string,Boolean>; Missing,Duplicate,Outside: Integer;
begin
  if FProject=nil then Exit; Missing:=0; Duplicate:=0; Outside:=0;
  IDs:=TDictionary<string,Boolean>.Create;
  try
    if Page<>nil then for P in Page.Panels do begin
      if (P.ImageID='') or not FileExists(FProject.ImagePath(P.ImageID)) then Inc(Missing);
      if P.ImageID<>'' then begin
        if IDs.ContainsKey(P.ImageID) then Inc(Duplicate) else IDs.Add(P.ImageID,True);
      end;
      if (P.Bounds.Left<60) or (P.Bounds.Top<60) or (P.Bounds.Right>FProject.Width-60) or
        (P.Bounds.Bottom>FProject.Height-60) then Inc(Outside);
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
  FreeAndNil(FProject); FProject:=P; FPageIndex:=0; FPanelIndex:=-1; FBalloonIndex:=-1; FDirty:=False;
  FUndo.Clear; FRedo.Clear; FRenderer.ClearCache; RefreshUI; Images(nil);
end;
procedure TMainForm.OpenProject(Sender: TObject);
var D: TOpenDialog; P: TComicProject; Draft: string;
begin
  if not HasCharacter then begin Characters(nil); if not HasCharacter then Exit; end;
  if not ConfirmLeave then Exit; D:=TOpenDialog.Create(Self);
  try
    D.Filter:='作品ファイル (Project.json)|Project.json|JSON (*.json)|*.json'; D.InitialDir:=TPath.Combine(DataRoot,'Projects');
    D.Options:=[ofFileMustExist,ofEnableSizing]; if not D.Execute then Exit;
    P:=TComicProject.Create;
    try
      P.Load(D.FileName); Draft:=TPath.Combine(P.Folder,'Draft.json');
      if FileExists(Draft) and (TFile.ReadAllText(Draft,TEncoding.UTF8)<>P.Snapshot) then
        if MessageDlg('前回の作業データを復元しますか？',mtConfirmation,[mbYes,mbNo],0)=mrYes then P.Load(Draft);
    except P.Free; raise; end;
    FreeAndNil(FProject); FProject:=P; FPageIndex:=0; FPanelIndex:=-1; FBalloonIndex:=-1;
    FDirty:=P.Snapshot<>TFile.ReadAllText(D.FileName,TEncoding.UTF8);
    FUndo.Clear; FRedo.Clear; FRenderer.ClearCache; RefreshUI;
  finally D.Free; end;
end;
procedure TMainForm.SaveProject(Sender: TObject);
begin CancelDrag; if not NeedProject then Exit; FProject.Save; FDirty:=False; RefreshUI; FStatus.SimpleText:='保存しました：'+FProject.Folder; end;
procedure TMainForm.Characters(Sender: TObject);
var D: TAssetDialog;
begin D:=TAssetDialog.CreateManager(Self,FCharacters,nil,True); try D.ShowModal; finally D.Free; end; RefreshUI; end;
procedure TMainForm.Images(Sender: TObject);
var D: TAssetDialog; Before: string;
begin
  if not NeedProject then Exit; Before:=FProject.Snapshot;
  D:=TAssetDialog.CreateManager(Self,FProject.Assets,FProject,False);
  try D.ShowModal; finally D.Free; end;
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
begin if FRefreshing then Exit; CancelDrag; ResetGeometryInput; FPageIndex:=FPages.ItemIndex; FPanelIndex:=-1; FBalloonIndex:=-1; FFirst:=False; ShowPageStatus; UpdateIconState; FCanvas.Invalidate; end;
procedure TMainForm.TabChanged(Sender: TObject);
begin CancelDrag; ResetGeometryInput; FTool:=0; FFirst:=False; if FTabs.ActivePageIndex<>3 then FBalloonIndex:=-1; UpdateIconState; FCanvas.Invalidate; end;
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
  if FImages.Count=0 then begin ShowMessage('先に画像管理で使用する画像を登録してください。'); Exit; end;
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
  if (Page=nil) or (Page.Panels.Count=0) then begin ShowMessage('コマを作成してから登録してください。'); Exit; end;
  if not FLayoutLibraryWritable then begin ShowMessage('既存ライブラリの読み込みエラーを解決してから登録してください。'); Exit; end;
  Name:='自作コマ割り'; if not InputQuery('コマ割りを共通登録','テンプレート名',Name) or (Trim(Name)='') then Exit;
  L:=TComicLayout.Create; L.Name:=Trim(Name); L.Capture(FProject,Page); FLayouts.Add(L);
  try SaveLayouts(FLayouts,TPath.Combine(DataRoot,'Presets\Layouts.json'));
  except FLayouts.Remove(L); raise; end;
  FLayoutList.Items.AddObject(L.Name,L); FLayoutList.ItemIndex:=FLayoutList.Count-1;
  FStatus.SimpleText:='コマ割りを登録しました。他の作品でも利用できます。画像と吹き出しは含みません。';
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
end;
function TMainForm.SnapCreationPoint(const P: TPointF; const ExcludePanelID: string): TPointF;
var Tolerance,Best,BestEdge,DX,DY,Distance: Double; Panel: TComicPanel; Point,Q,EdgePoint,VertexPoint,AxisPoint: TPointF; Values: TArray<TPointF>;
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
  Axis(60,60); Axis(FProject.Width-60,FProject.Height-60);
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
  if Best<=Tolerance then Result:=VertexPoint
  else if BestEdge<=Tolerance then Result:=EdgePoint
  else Result:=AxisPoint;
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
    Checkpoint; Panel.Number:=Page.Panels.Count+1; Page.Panels.Add(Panel); FPanelIndex:=Page.Panels.Count-1;
    FBalloonIndex:=-1; FGeometryPoints.Clear; Changed; FStatus.SimpleText:='多角形コマを作成しました。画像サムネイルから配置できます。'; Exit;
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
    ResetGeometryInput; FPanelIndex:=Index; FBalloonIndex:=-1; Changed;
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
  else if FTool in [1,2,3,5,6] then FStatus.SimpleText:='対角の1点目、2点目をクリックしてください。Escで中止。'
  else if FTool=4 then FStatus.SimpleText:='読む順番にコマをクリックしてください。'
  else FStatus.SimpleText:='対象を選択。ドラッグで移動、青8点で拡縮、黄色で頂点移動。頂点／辺を右クリックで削除／追加。';
  UpdateIconState;
end;
procedure TMainForm.Paint(Sender: TObject);
var C: TCanvas; R: TRect; B: TRectF; HandlePoint: TPointF; HX,HY,I: Integer;
  function ScreenPoint(const P: TPointF): TPoint;
  begin Result:=Point(FPageRect.Left+Round(P.X*FScale),FPageRect.Top+Round(P.Y*FScale)); end;
  procedure GuideLine(const A,B: TPointF);
  var P,Q: TPoint;
  begin P:=ScreenPoint(A); Q:=ScreenPoint(B); C.MoveTo(P.X,P.Y); C.LineTo(Q.X,Q.Y); end;
begin
  C:=FCanvas.Canvas; C.Brush.Color:=$302B28; C.FillRect(FCanvas.ClientRect);
  if (Page=nil) or not HasCharacter then begin
    C.Font.Name:='Yu Gothic UI'; C.Font.Size:=15; C.Font.Color:=$D9D9D9; C.Brush.Style:=bsClear;
    if not HasCharacter then C.TextOut(36,80,'1. キャラ管理で人物と参照画像を登録')
    else C.TextOut(36,80,'2. 新規作品を作成、または作品を開く');
    C.Brush.Style:=bsSolid; Exit;
  end;
  FScale:=Min((FCanvas.Width-48)/FProject.Width,(FCanvas.Height-48)/FProject.Height);
  if FScale<=0 then Exit;
  FPageRect:=Rect((FCanvas.Width-Round(FProject.Width*FScale)) div 2,24,0,0);
  FPageRect.Right:=FPageRect.Left+Round(FProject.Width*FScale); FPageRect.Bottom:=24+Round(FProject.Height*FScale);
  FRenderer.Draw(C,FProject,Page,FPageRect,True);
  B:=TRectF.Empty;
  if (FPanelIndex>=0) and (FPanelIndex<Page.Panels.Count) then begin
    B:=Page.Panels[FPanelIndex].Bounds;
    if FTabs.ActivePageIndex=2 then B:=FRenderer.ImageBounds(FProject,Page.Panels[FPanelIndex]);
  end;
  if (FBalloonIndex>=0) and (FBalloonIndex<Page.Balloons.Count) then B:=Page.Balloons[FBalloonIndex].Bounds;
  if not B.IsEmpty then begin
    R:=Rect(FPageRect.Left+Round(B.Left*FScale),FPageRect.Top+Round(B.Top*FScale),FPageRect.Left+Round(B.Right*FScale),FPageRect.Top+Round(B.Bottom*FScale));
    C.Brush.Style:=bsClear; C.Pen.Color:=$E5B45B; C.Pen.Width:=2; C.Rectangle(R);
    C.Brush.Style:=bsSolid; C.Brush.Color:=$E5B45B;
    for HandlePoint in EditHandles(B) do begin
      HX:=FPageRect.Left+Round(HandlePoint.X*FScale); HY:=FPageRect.Top+Round(HandlePoint.Y*FScale);
      C.FillRect(Rect(HX-4,HY-4,HX+5,HY+5));
    end;
    C.Pen.Width:=1;
  end;
  if (FTabs.ActivePageIndex=1) and (FTool=0) and (FPanelIndex>=0) and (FPanelIndex<Page.Panels.Count) then begin
    C.Brush.Color:=$60D6FF; C.Pen.Color:=$202020; C.Brush.Style:=bsSolid;
    for HandlePoint in VertexHandles(Page.Panels[FPanelIndex]) do begin
      HX:=ScreenPoint(HandlePoint).X; HY:=ScreenPoint(HandlePoint).Y;
      C.Rectangle(HX-4,HY-4,HX+5,HY+5);
    end;
  end;
  if FFirst then begin C.Pen.Color:=clRed; C.MoveTo(FPageRect.Left+Round(FStart.X*FScale)-6,FPageRect.Top+Round(FStart.Y*FScale));
    C.LineTo(FPageRect.Left+Round(FStart.X*FScale)+6,FPageRect.Top+Round(FStart.Y*FScale)); end;
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
function TMainForm.ToPage(X,Y: Integer): TPointF;
begin Result:=TPointF.Create((X-FPageRect.Left)/FScale,(Y-FPageRect.Top)/FScale); end;
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
    G:=ShapeRegion(Rect(Round(R.Left),Round(R.Top),Round(R.Right),Round(R.Bottom)),Page.Balloons[I].Shape);
    try if PtInRegion(G,Round(P.X),Round(P.Y)) then Exit(I); finally Winapi.Windows.DeleteObject(G); end;
  end;
end;
procedure TMainForm.CancelDrag;
begin
  if not FDragging then Exit;
  FDragging:=False; FCanvas.MouseCapture:=False;
  FDragVertex:=-1;
  if FDragMoved then begin FProject.Restore(FDragSnapshot); RefreshUI; end;
  FDragMoved:=False; FDragSnapshot:=''; FCanvas.Invalidate;
end;
procedure TMainForm.EditBalloonText(Sender: TObject);
begin
  if (FTabs.ActivePageIndex<>3) or (FBalloonIndex<0) or (FTool<>0) then Exit;
  CancelDrag; FText.Text:=Page.Balloons[FBalloonIndex].Text;
  ActiveControl:=FText;
  FText.SelectAll;
end;
procedure TMainForm.MouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X,Y: Integer);
var P: TPointF; R,Selected: TRectF; Panel: TComicPanel; Balloon: TComicBalloon; Handle: Integer;
begin
  // VCL dispatches DblClick before its trailing MouseDown(ssDouble).
  // Do not restart a drag or steal the text editor's focus after that event.
  if ssDouble in Shift then Exit;
  if (Page=nil) or not HasCharacter then Exit;
  if (Button=mbRight) and (FTool=0) and (FTabs.ActivePageIndex=1) then begin
    CancelDrag; EditVertexContext(ToPage(X,Y)); Exit;
  end;
  if (Button=mbRight) and (FTool in [8,9]) then begin
    if (FTool=8) and (FGeometryPoints.Count>0) then FGeometryPoints.Delete(FGeometryPoints.Count-1);
    if (FTool=9) and (FSplitStage>0) then Dec(FSplitStage);
    FCanvas.Invalidate; FStatus.SimpleText:='直前の指定へ戻りました。Escで全体を中止できます。'; Exit;
  end;
  if Button<>mbLeft then Exit; P:=ToPage(X,Y);
  ActiveControl:=FView;
  Handle:=0; FDragVertex:=-1; Selected:=TRectF.Empty;
  if FTool=0 then begin
    if (FTabs.ActivePageIndex=3) and (FBalloonIndex>=0) and (FBalloonIndex<Page.Balloons.Count) then
      Selected:=Page.Balloons[FBalloonIndex].Bounds
    else if (FPanelIndex>=0) and (FPanelIndex<Page.Panels.Count) then begin
      Selected:=Page.Panels[FPanelIndex].Bounds;
      if FTabs.ActivePageIndex=2 then Selected:=FRenderer.ImageBounds(FProject,Page.Panels[FPanelIndex]);
    end;
    Handle:=HitHandle(Selected,P,9/FScale);
    if (Handle=0) and (FTabs.ActivePageIndex=1) and (FPanelIndex>=0) and (FPanelIndex<Page.Panels.Count) then
      FDragVertex:=HitVertex(Page.Panels[FPanelIndex],P);
  end;
  if (Handle=0) and not FPageRect.Contains(Point(X,Y)) and not (FTool in [8,9]) then Exit;
  if FTool=9 then begin SplitClick(P); Exit; end;
  if FTool=8 then begin
    if FImages.Count=0 then Exit;
    if not (ssAlt in Shift) then P:=SnapCreationPoint(P); PolygonClick(P); Exit;
  end;
  if FTool=7 then begin
    if FBalloonIndex<0 then Exit; Checkpoint; Balloon:=Page.Balloons[FBalloonIndex];
    Balloon.HasTail:=True; Balloon.TailX:=P.X; Balloon.TailY:=P.Y; FTool:=0; Changed; Exit;
  end;
  if FTool in [1,2,3,5,6] then begin
    if FImages.Count=0 then begin ShowMessage('画像管理で画像を登録してください。'); Exit; end;
    if (FTool in [1,2,3]) and not (ssAlt in Shift) then P:=SnapCreationPoint(P);
    if not FFirst then begin FStart:=P; FLast:=P; FFirst:=True; FStatus.SimpleText:='2点目をクリックしてください。'; FCanvas.Invalidate; Exit; end;
    R:=TRectF.Create(Min(P.X,FStart.X),Min(P.Y,FStart.Y),Max(P.X,FStart.X),Max(P.Y,FStart.Y));
    if (R.Width<30) or (R.Height<30) then Exit; Checkpoint; FFirst:=False;
    if FTool<5 then begin Panel:=TComicPanel.Create; Panel.Bounds:=R; Panel.Shape:=FTool-1; Panel.Number:=Page.Panels.Count+1;
      Page.Panels.Add(Panel); FPanelIndex:=Page.Panels.Count-1; FBalloonIndex:=-1; end
    else begin Balloon:=TComicBalloon.Create; Balloon.Bounds:=R; Balloon.Shape:=FTool-4;
      FPanelIndex:=HitPanel(FStart); if FPanelIndex>=0 then Balloon.PanelID:=Page.Panels[FPanelIndex].ID;
      Page.Balloons.Add(Balloon); FBalloonIndex:=Page.Balloons.Count-1; FText.Text:=Balloon.Text;
      FVertical.Checked:=Balloon.Vertical; FTransparent.Checked:=Balloon.Transparent; FOverflow.Checked:=Balloon.Overflow;
      FFont.ItemIndex:=FFont.Items.IndexOf(IntToStr(Balloon.FontSize)); end;
    Changed; Exit;
  end;
  if FTool=4 then begin
    FPanelIndex:=HitPanel(P); if FPanelIndex>=0 then begin Checkpoint; Page.Panels[FPanelIndex].Number:=FNumber; Inc(FNumber); Changed; end;
    UpdateIconState; FCanvas.Invalidate; Exit;
  end;
  if (Handle=0) and (FDragVertex<0) then begin
    FBalloonIndex:=-1; if FTabs.ActivePageIndex=3 then FBalloonIndex:=HitBalloon(P);
    FPanelIndex:=HitPanel(P);
  end;
  if FBalloonIndex>=0 then begin
    Balloon:=Page.Balloons[FBalloonIndex]; FDragBounds:=Balloon.Bounds; FText.Text:=Balloon.Text;
    FVertical.Checked:=Balloon.Vertical; FTransparent.Checked:=Balloon.Transparent; FOverflow.Checked:=Balloon.Overflow;
    FFont.ItemIndex:=FFont.Items.IndexOf(IntToStr(Balloon.FontSize));
    FDragTailX:=Balloon.TailX; FDragTailY:=Balloon.TailY;
  end else if FPanelIndex>=0 then begin
    Panel:=Page.Panels[FPanelIndex]; FDragBounds:=Panel.Bounds; FDragZoom:=Panel.Zoom;
    FDragVertices:=Copy(Panel.Vertices,0,Length(Panel.Vertices));
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
var P,Delta: TPointF; R: TRectF; Panel: TComicPanel; Candidate: TArray<TPointF>; I: Integer;
begin
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
  if not FDragMoved and (Abs(Delta.X)*FScale<1) and (Abs(Delta.Y)*FScale<1) then Exit;
  FDragMoved:=True; R:=FDragBounds;
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
    if FBalloonIndex>=0 then begin
      with Page.Balloons[FBalloonIndex] do begin
        if HasTail then begin
          TailX:=R.Left+(FDragTailX-FDragBounds.Left)*R.Width/FDragBounds.Width;
          TailY:=R.Top+(FDragTailY-FDragBounds.Top)*R.Height/FDragBounds.Height;
        end;
        Bounds:=R;
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
  if not FDragging or (Button<>mbLeft) then Exit;
  FDragging:=False; FCanvas.MouseCapture:=False;
  if FDragMoved and (FProject.Snapshot<>FDragSnapshot) then begin
    FUndo.Add(FDragSnapshot); FRedo.Clear; if FUndo.Count>40 then FUndo.Delete(0); Changed;
  end;
  FDragSnapshot:=''; FDragMoved:=False;
  FDragVertex:=-1;
end;
procedure TMainForm.DeleteObject(Sender: TObject);
var I: Integer; UID: string;
begin
  if Page=nil then Exit;
  if TControl(Sender).Tag=1 then begin
    if FBalloonIndex<0 then Exit; Checkpoint; Page.Balloons.Delete(FBalloonIndex); FBalloonIndex:=-1;
  end else begin
    if FPanelIndex<0 then Exit; Checkpoint; UID:=Page.Panels[FPanelIndex].ID;
    for I:=Page.Balloons.Count-1 downto 0 do if Page.Balloons[I].PanelID=UID then Page.Balloons.Delete(I);
    Page.Panels.Delete(FPanelIndex); FPanelIndex:=-1; FBalloonIndex:=-1;
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
     ((Source=FLayoutList) and (FLayoutList.ItemIndex>=0)));
end;
procedure TMainForm.DragDrop(Sender,Source: TObject; X,Y: Integer);
begin
  if (Page=nil) or not FPageRect.Contains(Point(X,Y)) then Exit;
  if Source=FLayoutList then begin Template(nil); Exit; end;
  if Source<>FImages then Exit; FPanelIndex:=HitPanel(ToPage(X,Y)); AssignImage(nil);
end;
procedure TMainForm.ImageZoom(Sender: TObject);
begin
  if (Page=nil) or (FPanelIndex<0) then Exit; Checkpoint;
  Page.Panels[FPanelIndex].Zoom:=StrToIntDef(StringReplace(FZoom.Text,'%','',[rfReplaceAll]),100)/100; Changed;
end;
procedure TMainForm.ApplyText(Sender: TObject);
var B: TComicBalloon;
begin
  if (Page=nil) or (FBalloonIndex<0) then Exit; Checkpoint; B:=Page.Balloons[FBalloonIndex];
  B.Text:=FText.Text; B.Vertical:=FVertical.Checked; B.Transparent:=FTransparent.Checked;
  B.Overflow:=FOverflow.Checked; B.FontSize:=StrToIntDef(FFont.Text,40); Changed;
end;
procedure TMainForm.TextInputDialog(Sender: TObject);
var Dialog: TComicTextDialog;
begin
  if (Page=nil) or (FBalloonIndex<0) or (FBalloonIndex>=Page.Balloons.Count) then Exit;
  CancelDrag; Dialog:=TComicTextDialog.CreateEditor(Self,FText.Text,FVertical.Checked,FTesting);
  try
    Dialog.ShowModal; FinishTextDialog(Dialog);
  finally Dialog.Free; end;
end;
procedure TMainForm.FinishTextDialog(Dialog: TComicTextDialog);
begin
  if Dialog.ModalResult=mrOK then begin FText.Text:=Dialog.Editor.Text; ApplyText(nil); end;
end;
procedure TMainForm.Tail(Sender: TObject);
begin
  if FBalloonIndex<0 then begin ShowMessage('先に吹き出しを選択してください。'); Exit; end;
  FTool:=7; FFirst:=False; UpdateIconState; FStatus.SimpleText:='しっぽの先端位置をクリックしてください。';
end;
procedure TMainForm.ExportPNG(Sender: TObject);
var All: Boolean; N,Missing: Integer; P: TComicPage; Panel: TComicPanel;
  Output: string; D: TForm; Radio: TRadioGroup; L: TLabel; B: TButton;
begin
  if not NeedProject then Exit; Missing:=0;
  for P in FProject.Pages do for Panel in P.Panels do if (Panel.ImageID='') or not FileExists(FProject.ImagePath(Panel.ImageID)) then Inc(Missing);
  if (Missing>0) and (MessageDlg(Format('画像未配置／参照切れのコマが %d 個あります。出力しますか？',[Missing]),mtWarning,[mbYes,mbNo],0)<>mrYes) then Exit;
  Output:=TPath.Combine(FProject.Folder,'Output'); ForceDirectories(Output);
  D:=TForm.CreateNew(Self);
  try
    D.Caption:='連番PNG出力'; D.Position:=poOwnerFormCenter; D.ClientWidth:=600; D.ClientHeight:=230; D.BorderStyle:=bsDialog;
    L:=TLabel.Create(D); L.Parent:=D; L.AutoSize:=False; L.SetBounds(16,16,568,50); L.WordWrap:=True; L.Caption:='出力先：'+Output;
    Radio:=TRadioGroup.Create(D); Radio.Parent:=D; Radio.SetBounds(16,72,568,96); Radio.Caption:='出力対象';
    Radio.Items.Add('変更されたページのみ'); Radio.Items.Add('すべてのページ'); Radio.ItemIndex:=0;
    B:=TButton.Create(D); B.Parent:=D; B.SetBounds(366,186,100,30); B.Caption:='出力'; B.ModalResult:=mrOK;
    B:=TButton.Create(D); B.Parent:=D; B.SetBounds(478,186,100,30); B.Caption:='キャンセル'; B.ModalResult:=mrCancel;
    B:=TButton.Create(D); B.Parent:=D; B.SetBounds(16,186,220,30); B.Caption:='出力フォルダーを開く'; B.OnClick:=OpenOutput;
    if D.ShowModal<>mrOK then Exit; All:=Radio.ItemIndex=1;
  finally D.Free; end;
  Screen.Cursor:=crHourGlass;
  try
    N:=ExportSequence(FProject,FRenderer,All); FDirty:=True; RefreshUI;
    ShowMessage(Format('%d ページを出力しました（再描画 %d ページ）。',[FProject.Pages.Count,N])+sLineBreak+Output);
  finally Screen.Cursor:=crDefault; end;
end;
procedure TMainForm.CloseCheck(Sender: TObject; var CanClose: Boolean);
begin CancelDrag; CanClose:=ConfirmLeave; end;
procedure TMainForm.OpenOutput(Sender: TObject);
begin if FProject<>nil then ShellExecute(Handle,'open',PChar(TPath.Combine(FProject.Folder,'Output')),nil,nil,SW_SHOWNORMAL); end;
procedure TMainForm.Key(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (ssCtrl in Shift) and FTabs.Enabled then begin
    if Key=VK_TAB then begin
      if ssShift in Shift then FModeButtons[(FTabs.ActivePageIndex+3) mod 4].Click
      else FModeButtons[(FTabs.ActivePageIndex+1) mod 4].Click;
      Key:=0; Exit;
    end;
    if (Key>=Ord('1')) and (Key<=Ord('4')) then begin FModeButtons[Key-Ord('1')].Click; Key:=0; Exit; end;
  end;
  if ActiveControl=FText then Exit;
  if Key=VK_ESCAPE then begin CancelDrag; ResetGeometryInput; FFirst:=False; FTool:=0; UpdateIconState; FCanvas.Invalidate; Key:=0; end;
end;

procedure TMainForm.SmokeTest(const Folder: string);
var B: TBitmap; A,A2: TComicAsset; P: TComicPanel; Balloon: TComicBalloon;
  Loaded: TComicProject; Snapshot,AssetID,FirstID,SecondID,ThirdID,FourthID,CacheFile: string;
  Dialog: TAssetDialog; Layout: TComicLayout; LibraryCopy: TObjectList<TComicLayout>;
  J: TJSONObject; R: TRect; Accept,Failed: Boolean; N,BeforeOutput: Integer; Lines: TStringList;
  SignatureLock: THandle;
  procedure Check(Condition: Boolean; const Message: string);
  begin if not Condition then raise Exception.Create(Message); Lines.Add('PASS: '+Message); end;
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
      Check(Pos('"version":2',FProject.Snapshot)>0,'polygon project advertises version two');
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
        Panel.Vertices[0].X:=105;
        Check(Layout.Panels[0].Vertices[0].X<>Panel.Vertices[0].X,'template capture owns an independent vertex array');
        Panel.Vertices[0].X:=100;
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
    var Mode,PX,PY: Integer; AllFit,NoOverlap: Boolean; First,Second: TComicIconButton; Scroll: TScrollBox;
    begin
      Scaled:=True; ScaleForPPI(PPI);
      // The hidden HWND stays on the host monitor. Use VCL's scaled control PPI
      // for offscreen validation instead of asking Windows for that HWND's DPI.
      Scaled:=False; Width:=MulDiv(W,PPI,96); Height:=MulDiv(H,PPI,96); Realign;
      Check((PixelsPerInch=PPI) and (CurrentPPI=PPI),Name+' applies requested VCL PPI '+IntToStr(PPI));
      for Mode:=0 to 3 do begin
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
    Lines.Add('PASS: hidden VCL captures, no external generation or transmission.');
    TFile.WriteAllText(TPath.Combine(Folder,'result.txt'),Lines.Text,TEncoding.UTF8);
  finally Lines.Free; B.Free; end;
end;

end.
