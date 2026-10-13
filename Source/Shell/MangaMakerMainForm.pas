unit MangaMakerMainForm;

interface

uses Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, System.SysUtils, System.Classes, System.Types, System.UITypes, System.Math,
  System.IOUtils, System.Generics.Collections, System.JSON, System.Hash, Vcl.Controls, Vcl.Forms,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Menus, Vcl.Dialogs,
  Vcl.Graphics, Vcl.Imaging.pngimage, ComicModel, ComicRender, ComicAssetDialog, ComicLayouts, ComicExport, ComicEditing, ComicIconButton;

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
  inherited; FPageIndex:=-1; FPanelIndex:=-1; FBalloonIndex:=-1; FScale:=1;
  FTesting:=(ParamCount>0) and (ParamStr(1)='--self-test');
  FCharacters:=TObjectList<TComicAsset>.Create; FRenderer:=TComicRenderer.Create;
  FUndo:=TList<string>.Create; FRedo:=TList<string>.Create;
  FIconButtons:=TList<TComicIconButton>.Create;
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
begin FProject.Free; FCharacters.Free; FRenderer.Free; FUndo.Free; FRedo.Free; FLayouts.Free; FIconButtons.Free; inherited; end;
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
  LabelAt(Body,'対角2点でコマを作成。選択後は移動と外周8点のサイズ変更。',12,10);
  Icon(Body,'選択・移動',12,62,44,44,ciSelect,0,brTool,Tool,False,1);
  Icon(Body,'四角コマ：対角2点をクリック',68,62,44,44,ciRectangle,1,brTool,Tool,False,1);
  Icon(Body,'楕円コマ：対角2点をクリック',124,62,44,44,ciEllipse,2,brTool,Tool,False,1);
  Icon(Body,'角丸コマ：対角2点をクリック',180,62,44,44,ciRounded,3,brTool,Tool,False,1);
  Icon(Body,'読む順番にコマをクリック',236,62,44,44,ciOrder,4,brTool,Tool,False,1);
  LabelAt(Body,'選択  /  四角  /  楕円  /  角丸  /  順序',12,114,28);
  Icon(Body,'選択コマを削除',12,158,268,40,ciDelete,0,brDeletePanel,DeleteObject,True);
  Icon(Body,'現在のコマ割りを登録',12,208,268,40,ciRegister,0,brRegister,RegisterLayout,True);
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
  FText:=TMemo.Create(Self); FText.Parent:=Body; FText.SetBounds(D(12),D(132),D(270),D(136)); FText.ScrollBars:=ssVertical;
  FText.ImeMode:=imOpen;
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
begin if FRefreshing then Exit; CancelDrag; FPageIndex:=FPages.ItemIndex; FPanelIndex:=-1; FBalloonIndex:=-1; FFirst:=False; ShowPageStatus; UpdateIconState; FCanvas.Invalidate; end;
procedure TMainForm.TabChanged(Sender: TObject);
begin CancelDrag; FTool:=0; FFirst:=False; if FTabs.ActivePageIndex<>3 then FBalloonIndex:=-1; UpdateIconState; FCanvas.Invalidate; end;
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
procedure TMainForm.Tool(Sender: TObject);
begin
  CancelDrag;
  FTool:=TButton(Sender).Tag; FFirst:=False; FNumber:=1;
  if FTool in [1,2,3,5,6] then FStatus.SimpleText:='対角の1点目、2点目をクリックしてください。Escで中止。'
  else if FTool=4 then FStatus.SimpleText:='読む順番にコマをクリックしてください。'
  else FStatus.SimpleText:='対象をクリックして選択。ドラッグで移動、外周8点でサイズ変更。';
  UpdateIconState;
end;
procedure TMainForm.Paint(Sender: TObject);
var C: TCanvas; R: TRect; B: TRectF; HandlePoint: TPointF; HX,HY: Integer;
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
  if FFirst then begin C.Pen.Color:=clRed; C.MoveTo(FPageRect.Left+Round(FStart.X*FScale)-6,FPageRect.Top+Round(FStart.Y*FScale));
    C.LineTo(FPageRect.Left+Round(FStart.X*FScale)+6,FPageRect.Top+Round(FStart.Y*FScale)); end;
end;
function TMainForm.ToPage(X,Y: Integer): TPointF;
begin Result:=TPointF.Create((X-FPageRect.Left)/FScale,(Y-FPageRect.Top)/FScale); end;
function TMainForm.HitPanel(const P: TPointF): Integer;
var I: Integer; G: HRGN; R: TRectF;
begin
  Result:=-1; if Page=nil then Exit;
  for I:=Page.Panels.Count-1 downto 0 do begin
    R:=Page.Panels[I].Bounds; if not R.Contains(P) then Continue;
    G:=ShapeRegion(Rect(Round(R.Left),Round(R.Top),Round(R.Right),Round(R.Bottom)),Page.Panels[I].Shape);
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
  if (Page=nil) or not HasCharacter or (Button<>mbLeft) then Exit; P:=ToPage(X,Y);
  ActiveControl:=FView;
  Handle:=0; Selected:=TRectF.Empty;
  if FTool=0 then begin
    if (FTabs.ActivePageIndex=3) and (FBalloonIndex>=0) and (FBalloonIndex<Page.Balloons.Count) then
      Selected:=Page.Balloons[FBalloonIndex].Bounds
    else if (FPanelIndex>=0) and (FPanelIndex<Page.Panels.Count) then begin
      Selected:=Page.Panels[FPanelIndex].Bounds;
      if FTabs.ActivePageIndex=2 then Selected:=FRenderer.ImageBounds(FProject,Page.Panels[FPanelIndex]);
    end;
    Handle:=HitHandle(Selected,P,9/FScale);
  end;
  if (Handle=0) and not FPageRect.Contains(Point(X,Y)) then Exit;
  if FTool=7 then begin
    if FBalloonIndex<0 then Exit; Checkpoint; Balloon:=Page.Balloons[FBalloonIndex];
    Balloon.HasTail:=True; Balloon.TailX:=P.X; Balloon.TailY:=P.Y; FTool:=0; Changed; Exit;
  end;
  if FTool in [1,2,3,5,6] then begin
    if FImages.Count=0 then begin ShowMessage('画像管理で画像を登録してください。'); Exit; end;
    if not FFirst then begin FStart:=P; FFirst:=True; FStatus.SimpleText:='2点目をクリックしてください。'; FCanvas.Invalidate; Exit; end;
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
  if Handle=0 then begin
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
var P,Delta: TPointF; R: TRectF; Panel: TComicPanel;
begin
  if not FDragging or (Page=nil) then Exit; P:=ToPage(X,Y);
  if not (ssLeft in Shift) then begin CancelDrag; Exit; end;
  Delta:=TPointF.Create(P.X-FStart.X,P.Y-FStart.Y);
  if not FDragMoved and (Abs(Delta.X)*FScale<1) and (Abs(Delta.Y)*FScale<1) then Exit;
  FDragMoved:=True; R:=FDragBounds;
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
    end else if FPanelIndex>=0 then Page.Panels[FPanelIndex].Bounds:=R;
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
end;
procedure TMainForm.DeleteObject(Sender: TObject);
var I: Integer; UID: string;
begin
  if Page=nil then Exit;
  if TButton(Sender).Tag=1 then begin
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
  if Key=VK_ESCAPE then begin CancelDrag; FFirst:=False; FTool:=0; UpdateIconState; FCanvas.Invalidate; Key:=0; end;
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
    finally Warm.Free; Shifted.Free; Reference.Free; Clone.Free; end;
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
        FModeButtons[Mode].Click; SaveUI(Name+'-mode'+IntToStr(Mode)); AllFit:=True; NoOverlap:=True;
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
