unit ComicPageRefreshTests;

// 責務：実際の一覧メッセージ・無効化要求・縮小描画回数から、ページ単位の更新と履歴の整合を検証する。
interface
uses ComicTestSupport;
procedure RunPageRefreshChecks(Host: TComicTestForm);
implementation
uses Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.Types, System.Math,
  System.IOUtils, System.DateUtils, System.Hash, Vcl.Controls, Vcl.Graphics, Vcl.Imaging.pngimage,
  ComicModel, ComicRender, ComicPageThumbnails;
type
  TPageRefreshProbe = class(TComicTestForm);
  TListMessages = class
  private
    FControl: TWinControl;
    FPrevious: TWndMethod;
    procedure Message(var Message: TMessage);
  public
    Resets,RedrawToggles: Integer;
    constructor Create(Control: TWinControl);
    destructor Destroy; override;
    procedure Reset;
  end;
  TPageRefreshCase = class
  private
    FHost: TComicTestForm;
    FProbe: TPageRefreshProbe;
    FPages,FImages: TListMessages;
    FShot: Vcl.Graphics.TBitmap;
    FPNG: TPngImage;
    FHashes: TArray<string>;
    FWidth,FHeight,FTop: Integer;
    function PageHash(Index: Integer): string;
    procedure Check(Value: Boolean; const Message: string);
    procedure Prime;
    procedure Clean;
    procedure UnchangedLists;
  public
    constructor Create(Host: TComicTestForm);
    destructor Destroy; override;
    procedure Setup(PPI: Integer);
    procedure EditChecks;
    procedure HistoryChecks;
    procedure OffscreenAndTextChecks;
    procedure SharedImageChecks;
    procedure StructureChecks;
  end;
constructor TListMessages.Create(Control: TWinControl);
begin inherited Create; FControl:=Control; FPrevious:=Control.WindowProc; Control.WindowProc:=Message; end;
destructor TListMessages.Destroy;
begin FControl.WindowProc:=FPrevious; inherited; end;
procedure TListMessages.Reset;
begin Resets:=0; RedrawToggles:=0; end;
procedure TListMessages.Message(var Message: TMessage);
begin
  if Message.Msg=LB_RESETCONTENT then Inc(Resets);
  if Message.Msg=WM_SETREDRAW then Inc(RedrawToggles);
  FPrevious(Message);
end;
constructor TPageRefreshCase.Create(Host: TComicTestForm);
begin inherited Create; FHost:=Host; FProbe:=TPageRefreshProbe.Create(nil); FShot:=Vcl.Graphics.TBitmap.Create; FPNG:=TPngImage.Create; end;
destructor TPageRefreshCase.Destroy;
begin FPages.Free; FImages.Free; FProbe.Free; FShot.Free; FPNG.Free; inherited; end;
procedure TPageRefreshCase.Check(Value: Boolean; const Message: string);
begin FHost.Check(Value,Message); end;
function TPageRefreshCase.PageHash(Index: Integer): string;
var Stream: TMemoryStream;
begin
  Stream:=TMemoryStream.Create;
  try
    FProbe.FPages.Thumbnail(FProbe.FProject,FProbe.FRenderer,Index,FWidth,FHeight).SaveToStream(Stream);
    Stream.Position:=0; Result:=THashSHA2.GetHashString(Stream);
  finally Stream.Free; end;
end;
procedure TPageRefreshCase.Prime;
var I: Integer;
begin for I:=0 to FProbe.FProject.Pages.Count-1 do PageHash(I); end;
procedure TPageRefreshCase.Clean;
begin
  ValidateRect(FProbe.FPages.Handle,nil); ValidateRect(FProbe.FImages.Handle,nil);
  FPages.Reset; FImages.Reset;
end;
procedure TPageRefreshCase.UnchangedLists;
begin
  Check((FPages.Resets=0) and (FPages.RedrawToggles=0),'content refresh never resets or globally suspends the page list');
  Check((FImages.Resets=0) and (FImages.RedrawToggles=0),'content refresh keeps the image list intact');
  Check((FProbe.FPages.TopIndex=FTop) and FProbe.FPages.Selected[3] and FProbe.FPages.Selected[4] and
    (FProbe.FPages.SelCount=2),'content refresh retains scroll position and multiple page selections');
end;
procedure TPageRefreshCase.Setup(PPI: Integer);
var Project: TComicProject; Panel: TComicPanel; Balloon: TComicBalloon; I: Integer; A,B: string;
begin
  Project:=CreateFixtureProject; Project.Initialize('ページ更新 fixture','1');
  A:=Project.ImportImage(TPath.Combine(FHost.TestFolder,'reference.bmp'),'').ID;
  B:=Project.ImportImage(TPath.Combine(FHost.TestFolder,'reference.bmp'),'').ID;
  while Project.Pages.Count<12 do Project.Pages.Add(TComicPage.Create);
  for I:=0 to 11 do begin
    Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(100,100,1100,1500); Panel.BorderWidth:=20;
    if I<2 then Panel.ImageID:=A else Panel.ImageID:=B;
    Project.Pages[I].Panels.Add(Panel);
  end;
  Balloon:=TComicBalloon.Create; Balloon.Text:='ページ管理'; Balloon.Bounds:=TRectF.Create(300,300,800,1200);
  Balloon.FontSize:=64; Project.Pages[3].Balloons.Add(Balloon); Project.Save; FProbe.AdoptProject(Project,False);
  FProbe.Scaled:=True; FProbe.ScaleForPPI(PPI); FProbe.Scaled:=False;
  FProbe.FTabs.ActivePageIndex:=2; FProbe.TabChanged(nil); FProbe.HandleNeeded;
  FProbe.FPageIndex:=3; FProbe.RefreshUI;
  for I:=0 to 11 do FProbe.FPages.Selected[I]:=I in [3,4];
  FProbe.FPages.ItemIndex:=3; FProbe.FPages.TopIndex:=2; FTop:=FProbe.FPages.TopIndex;
  FProbe.FImages.ItemIndex:=0; FWidth:=MulDiv(96,PPI,96); FHeight:=MulDiv(136,PPI,96);
  FShot.SetSize(FProbe.ClientWidth,FProbe.ClientHeight); FProbe.PaintTo(FShot.Canvas,0,0);
  SetLength(FHashes,12); for I:=0 to 11 do FHashes[I]:=PageHash(I);
  FPages:=TListMessages.Create(FProbe.FPages); FImages:=TListMessages.Create(FProbe.FImages); Clean;
end;
procedure TPageRefreshCase.EditChecks;
var Count,I: Integer; Updated,Expected,Visible: TRect;
begin
  Count:=FProbe.FPages.Thumbnails.BuildCount; FProbe.RefreshUI; UnchangedLists;
  Check(not GetUpdateRect(FProbe.FPages.Handle,Updated,False),'unchanged refresh does not invalidate page rows');
  Prime; Check(FProbe.FPages.Thumbnails.BuildCount=Count,'unchanged refresh reuses every thumbnail');
  Clean; FProbe.Checkpoint; FProbe.Page.Panels[0].BorderColor:=clRed; FProbe.Changed; UnchangedLists;
  Expected:=FProbe.FPages.ItemRect(3); IntersectRect(Visible,Expected,FProbe.FPages.ClientRect);
  Check((Length(FProbe.FPages.InvalidatedRects)=1) and (FProbe.FPages.InvalidatedRects[0]=Visible),
    'editing requests invalidation only for the current visible page row');
  Check(FProbe.FPages.Thumbnails.BuildCount=Count,'refresh invalidates thumbnails without rendering eagerly');
  for I:=0 to 11 do Check((PageHash(I)<>FHashes[I])=(I=3),'only the edited page changes its rendered pixels');
  Check(FProbe.FPages.Thumbnails.BuildCount=Count+1,'one page edit renders exactly one thumbnail');
  Count:=FProbe.FPages.Thumbnails.BuildCount; Inc(FProbe.Page.Revision); FProbe.Page.OutputRevision:=FProbe.Page.Revision;
  Clean; FProbe.RefreshUI; Prime;
  Check((FProbe.FPages.Thumbnails.BuildCount=Count) and not GetUpdateRect(FProbe.FPages.Handle,Updated,False),
    'revision/export bookkeeping alone never invalidates rendered thumbnails');
end;
procedure TPageRefreshCase.HistoryChecks;
var Count: Integer; Red,Blue: string;
begin
  Red:=PageHash(3); Count:=FProbe.FPages.Thumbnails.BuildCount; Clean; FProbe.Undo(nil); UnchangedLists;
  Check(PageHash(3)=FHashes[3],'undo displays the restored content even when revisions move backward'); Prime;
  Check(FProbe.FPages.Thumbnails.BuildCount=Count+1,'undo regenerates only the changed page');
  Check(FProbe.FImages.Items.Objects[0]=FProbe.FProject.Assets[0],'undo refresh replaces image object references without rebuilding the list');
  Count:=FProbe.FPages.Thumbnails.BuildCount; Clean; FProbe.Redo(nil); Prime; UnchangedLists;
  Check((PageHash(3)=Red) and (FProbe.FPages.Thumbnails.BuildCount=Count+1),'redo regenerates only the restored page');
  FProbe.Undo(nil); Prime; Count:=FProbe.FPages.Thumbnails.BuildCount;
  FProbe.Checkpoint; FProbe.Page.Panels[0].BorderColor:=clBlue; FProbe.Changed; Blue:=PageHash(3);
  Check((Blue<>Red) and (Blue<>FHashes[3]) and (FProbe.FPages.Thumbnails.BuildCount=Count+1),
    'a new branch with a reused revision cannot show the previous branch thumbnail');
  // 捕捉喪失によるドラッグ取消と同様、未確定の描画を経て同じ作品へ戻っても古い予告を残さない。
  FProbe.Page.Panels[0].BorderColor:=clLime; PageHash(3); FProbe.Page.Panels[0].BorderColor:=clBlue; FProbe.RefreshUI;
  Check(PageHash(3)=Blue,'restoring a temporary edit cannot retain its preview in the thumbnail cache');
end;
procedure TPageRefreshCase.OffscreenAndTextChecks;
var Count: Integer; R: TRect;
begin
  Prime; Count:=FProbe.FPages.Thumbnails.BuildCount; Clean;
  FProbe.FProject.Pages[11].Panels[0].BorderColor:=clRed; FProbe.Changed;
  Check((Length(FProbe.FPages.InvalidatedRects)=0) and not GetUpdateRect(FProbe.FPages.Handle,R,False),
    'offscreen edits do not invalidate visible page rows');
  Check(FProbe.FPages.Thumbnails.BuildCount=Count,'offscreen edits remain lazy until a thumbnail is requested');
  Check((PageHash(11)<>FHashes[11]) and (FProbe.FPages.Thumbnails.BuildCount=Count+1),'offscreen thumbnail refreshes when it is needed');
  Count:=FProbe.FPages.Thumbnails.BuildCount; Clean;
  FProbe.FTabs.ActivePageIndex:=3; FProbe.TabChanged(nil); FProbe.FBalloonIndex:=0; FProbe.LoadBalloonControls(FProbe.Page.Balloons[0]);
  FProbe.FText.Text:='編集中のセリフ'; Prime; UnchangedLists;
  Check(FProbe.FPages.Thumbnails.BuildCount=Count+1,'live dialogue memo editing regenerates only its page thumbnail');
  FProbe.PaintTo(FShot.Canvas,0,0); FPNG.Assign(FShot);
  FPNG.SaveToFile(TPath.Combine(FHost.TestFolder,'page-refresh-'+IntToStr(FProbe.CurrentPPI)+'.png'));
end;
procedure TPageRefreshCase.SharedImageChecks;
var Count,I: Integer; Before: TArray<string>; Path: string; FileBitmap: Vcl.Graphics.TBitmap;
begin
  SetLength(Before,12); for I:=0 to 11 do Before[I]:=PageHash(I); Count:=FProbe.FPages.Thumbnails.BuildCount;
  Path:=FProbe.FProject.ImagePath(FProbe.FProject.Assets[0].ID); FileBitmap:=Vcl.Graphics.TBitmap.Create;
  try FileBitmap.SetSize(700,440); FileBitmap.Canvas.Brush.Color:=clLime; FileBitmap.Canvas.FillRect(Rect(0,0,700,440)); FileBitmap.SaveToFile(Path);
  finally FileBitmap.Free; end;
  TFile.SetLastWriteTimeUtc(Path,IncSecond(TFile.GetLastWriteTimeUtc(Path),2)); Clean; FProbe.RefreshUI; UnchangedLists;
  for I:=0 to 11 do Check((PageHash(I)<>Before[I])=(I<2),'shared image updates refresh only pages that reference the changed file');
  Check(FProbe.FPages.Thumbnails.BuildCount=Count+2,'two pages sharing one updated image regenerate two thumbnails');
  Count:=FProbe.FPages.Thumbnails.BuildCount;
  FProbe.FProject.Title:='名前だけ変更'; FProbe.FProject.Assets[0].Notes:='描画に関係しないメモ'; FProbe.RefreshUI; Prime;
  Check(FProbe.FPages.Thumbnails.BuildCount=Count,'project title and image notes do not regenerate thumbnails');
end;
procedure TPageRefreshCase.StructureChecks;
var Count,I: Integer; Current,Selected,First: string;
begin
  Count:=FProbe.FPages.Thumbnails.BuildCount; Current:=FProbe.Page.ID; Selected:=FProbe.FProject.Pages[4].ID;
  FProbe.FProject.Pages.Move(0,11); FProbe.FPageIndex:=2; Clean; FProbe.RefreshUI; Prime;
  Check((FPages.Resets=1) and (FProbe.FPages.Items[2]=Current) and (FProbe.FPages.Items[3]=Selected) and
    FProbe.FPages.Selected[2] and FProbe.FPages.Selected[3],'page reordering rebuilds the list once and preserves selection by ID');
  Check(FProbe.FPages.Thumbnails.BuildCount=Count,'page reordering reuses thumbnails by stable page ID');
  FProbe.FProject.Pages.Add(TComicPage.Create); FProbe.RefreshUI; Prime;
  Check((FProbe.FPages.Count=13) and (FProbe.FPages.Thumbnails.BuildCount=Count+1),'page insertion generates only the new thumbnail');
  FProbe.FProject.Pages.Delete(12); FProbe.RefreshUI;
  Check((FProbe.FPages.Count=12) and (FProbe.FPages.Thumbnails.BitmapCount=12),'page deletion releases the removed thumbnail');
  First:=FProbe.FProject.Assets[0].ID; FProbe.FImages.ItemIndex:=0;
  FProbe.FProject.ImportImage(TPath.Combine(FHost.TestFolder,'reference.bmp'),''); FProbe.RefreshUI; Prime;
  Check((FProbe.FImages.Count=3) and (TComicAsset(FProbe.FImages.Items.Objects[FProbe.FImages.ItemIndex]).ID=First) and
    (FProbe.FPages.Thumbnails.BuildCount=Count+1),'adding an unused image preserves selection and cached pages');
  Count:=FProbe.FPages.Thumbnails.BuildCount; FProbe.FProject.Width:=1300; FProbe.RefreshUI; Prime;
  Check(FProbe.FPages.Thumbnails.BuildCount=Count+12,'page resolution changes invalidate every page thumbnail');
  for I:=0 to FProbe.FProject.Pages.Count-1 do FProbe.FProject.Pages[I].OutputRevision:=999;
  Count:=FProbe.FPages.Thumbnails.BuildCount; FProbe.RefreshUI; Prime;
  Check(FProbe.FPages.Thumbnails.BuildCount=Count,'export metadata does not invalidate the resized thumbnails');
end;
procedure CheckCacheLimit(Host: TComicTestForm);
var Project: TComicProject; Cache: TComicPageThumbnails; Renderer: TComicRenderer; I,Count: Integer;
begin
  Project:=CreateFixtureProject; Cache:=TComicPageThumbnails.Create; Renderer:=TComicRenderer.Create;
  try
    Project.ID:='cache-limit'; Project.Folder:=Host.TestFolder; while Project.Pages.Count<70 do Project.Pages.Add(TComicPage.Create);
    Cache.Synchronize(Project,Renderer);
    for I:=0 to 69 do Cache.GetBitmap(Project,Renderer,I,24,34);
    Host.Check(Cache.BitmapCount=64,'thumbnail LRU retains at most 64 rendered bitmaps'); Count:=Cache.BuildCount;
    Cache.GetBitmap(Project,Renderer,69,24,34); Host.Check(Cache.BuildCount=Count,'recent thumbnails are reused after eviction');
    Cache.GetBitmap(Project,Renderer,0,24,34); Host.Check(Cache.BuildCount=Count+1,'evicted thumbnails regenerate on demand');
    for I:=0 to 9 do Cache.GetBitmap(Project,Renderer,I,1024,1024);
    Host.Check((Cache.CachedBytes<=32*1024*1024) and (Cache.BitmapCount<=8),'large DPI thumbnails also obey the 32 MiB memory limit');
    Cache.Synchronize(nil,Renderer); Host.Check((Cache.CachedBytes=0) and (Cache.BitmapCount=0),'clearing the project releases thumbnail memory');
  finally Renderer.Free; Cache.Free; Project.Free; end;
end;
procedure RunPageRefreshChecks(Host: TComicTestForm);
var PPI: Integer; Test: TPageRefreshCase;
begin
  for PPI in [96,144] do begin
    Test:=TPageRefreshCase.Create(Host);
    try Test.Setup(PPI); Test.EditChecks; Test.HistoryChecks; Test.OffscreenAndTextChecks; Test.SharedImageChecks; Test.StructureChecks;
    finally Test.Free; end;
  end;
  CheckCacheLimit(Host);
end;
end.
