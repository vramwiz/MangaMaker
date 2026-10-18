unit ComicDragDropTests;

// 責務：短い手ぶれの抑止と意図した移動、素材D&Dの原寸/比率維持縮小を実イベントで検証する。
interface
uses ComicTestSupport;
procedure RunDragDropChecks(Host: TComicTestForm);
implementation
uses Winapi.Windows, System.SysUtils, System.Classes, System.Types, System.Math, System.IOUtils,
  System.Hash, Vcl.Controls, Vcl.Graphics, Vcl.Imaging.pngimage, ComicModel, ComicEffects,
  ComicDragIntent, ComicRender;
type
  TDragDropTestsHelper = class helper for TComicTestForm
    procedure MoveIntentCase(Mode,PPI: Integer; Zoom: Double; Group: Boolean);
    procedure MaterialSizeCase(W,H,ExpectedW,ExpectedH,PPI: Integer; Zoom: Double);
  end;
procedure TDragDropTestsHelper.MoveIntentCase(Mode,PPI: Integer; Zoom: Double; Group: Boolean);
var Probe: TComicTestForm; Project: TComicProject; Panel: TComicPanel; I,History,Redo: Integer;
  Before,After,Draft: string; At: TPoint; R: TRectF; WasDirty: Boolean; Delta: Double; Shot: TBitmap;
  procedure Select;
  begin
    Probe.CancelDrag; Probe.FTabs.ActivePageIndex:=Mode; Probe.TabChanged(nil); Probe.SelectSinglePanel(0);
    if Group then Probe.FSelectedPanels.Add(Probe.Page.Panels[1].ID);
    Probe.FPanelIndex:=0; Probe.FBalloonIndex:=-1; Probe.FTool:=0; Probe.ActiveControl:=Probe.FView;
    Probe.HandleNeeded; Shot.SetSize(Probe.ClientWidth,Probe.ClientHeight); Probe.PaintTo(Shot.Canvas,0,0);
  end;
  procedure Down;
  begin
    Select; R:=Probe.Page.Panels[0].Bounds;
    if Mode=2 then R:=Probe.FRenderer.ImageBounds(Project,Probe.Page.Panels[0]);
    At:=Point(Probe.FPageRect.Left+Round(R.CenterPoint.X*Probe.FScale),Probe.FPageRect.Top+Round(R.CenterPoint.Y*Probe.FScale));
    Probe.MouseDown(Probe.FCanvas,mbLeft,[],At.X,At.Y); Probe.FDragStartedTick:=GetTickCount64;
    Check(Probe.FDragging and (Probe.FDragHandle=0),Format('object body press starts a pending move: mode=%d DPI=%d zoom=%.2f group=%s handle=%d dragging=%s pan=%s scale=%.4f',
      [Mode,PPI,Zoom,BoolToStr(Group,True),Probe.FDragHandle,BoolToStr(Probe.FDragging,True),BoolToStr(Probe.FViewPanning,True),Probe.FScale]));
  end;
  procedure Release(DX,DY: Integer);
  begin Probe.MouseUp(Probe.FCanvas,mbLeft,[],At.X+DX,At.Y+DY); end;
begin
  Probe:=TComicTestForm.Create(nil); Shot:=TBitmap.Create;
  try
    Project:=CreateFixtureProject; Project.Initialize('移動意図 fixture','1'); Probe.AdoptProject(Project,False);
    for I:=0 to 1 do begin
      Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(100+I*550,200,500+I*550,800);
      Panel.ImageID:=Project.ImportImage(TPath.Combine(TestFolder,'reference.bmp'),'').ID; Panel.Zoom:=1.2; Probe.Page.Panels.Add(Panel);
    end;
    Project.Save; Probe.RefreshUI; Probe.Scaled:=True; Probe.ScaleForPPI(PPI); Probe.Scaled:=False; Probe.FViewZoom:=Zoom;
    Down; Before:=Project.Snapshot; History:=Probe.FUndo.Count; Redo:=Probe.FRedo.Count; WasDirty:=Probe.FDirty;
    Draft:=TFile.ReadAllText(TPath.Combine(Project.Folder,'Draft.json'),TEncoding.UTF8); Probe.FSnap.Checked:=True;
    Probe.MouseMove(Probe.FCanvas,[ssLeft],At.X+3,At.Y+2);
    Check(not Probe.FDragMoved and (Project.Snapshot=Before),'short tiny movement cannot trigger object motion or snap corrections'); Release(3,2);
    Check((Project.Snapshot=Before) and (Probe.FUndo.Count=History) and (Probe.FRedo.Count=Redo) and (Probe.FDirty=WasDirty) and
      (TFile.ReadAllText(TPath.Combine(Project.Folder,'Draft.json'),TEncoding.UTF8)=Draft),'accidental release preserves geometry, draft, dirty and undo/redo');
    Probe.FSnap.Checked:=False; Down; Probe.FDragStartedTick:=GetTickCount64-ComicMoveHoldMilliseconds;
    Probe.MouseMove(Probe.FCanvas,[ssLeft],At.X+2,At.Y+1); Delta:=2/Probe.FScale; Release(2,1);
    Check((Project.Snapshot<>Before) and (Probe.FUndo.Count=History+1),'holding deliberately permits a fine move and records one undo');
    if Mode=1 then Check(Abs(Probe.Page.Panels[0].Bounds.Left-(100+Delta))<0.001,'panel fine movement is measured in page coordinates')
    else Check(Abs(Probe.Page.Panels[0].PanX-Delta)<0.001,'image fine movement adjusts the crop without moving its panel');
    Probe.Undo(nil); Check(Project.Snapshot=Before,'fine movement undo restores the exact scene');
    Down; Redo:=Probe.FRedo.Count; Probe.MouseMove(Probe.FCanvas,[ssLeft],At.X+1,At.Y); Release(1,0);
    Check((Project.Snapshot=Before) and (Probe.FRedo.Count=Redo),'ignored hand jitter retains a pending redo');
    Down; Probe.MouseMove(Probe.FCanvas,[ssLeft],At.X+20,At.Y+9);
    Probe.MouseMove(Probe.FCanvas,[ssLeft],At.X+1,At.Y); Release(1,0); After:=Project.Snapshot;
    Check((After<>Before) and (Probe.FUndo.Count=History+1),'crossing the distance threshold keeps an intentional gesture active when it returns near the start'); Probe.Undo(nil);
    Down; Probe.MouseMove(Probe.FCanvas,[ssLeft],At.X+1,At.Y);
    Probe.FDragStartedTick:=GetTickCount64-ComicMoveHoldMilliseconds; Release(1,0);
    Check((Project.Snapshot<>Before) and (Probe.FUndo.Count=History+1),'a long hold after a small move is recognized on release even without another mouse move'); Probe.Undo(nil);
    Down; Release(20,8); Check((Project.Snapshot<>Before) and (Probe.FUndo.Count=History+1),'release consumes a deliberate final position when mouse move events were coalesced'); Probe.Undo(nil);
    Select; R:=Probe.Page.Panels[0].Bounds; if Mode=2 then R:=Probe.FRenderer.ImageBounds(Project,Probe.Page.Panels[0]);
    At:=Point(Probe.FPageRect.Left+Round(R.Left*Probe.FScale),Probe.FPageRect.Top+Round(R.Top*Probe.FScale));
    Probe.MouseDown(Probe.FCanvas,mbLeft,[],At.X,At.Y); Probe.MouseMove(Probe.FCanvas,[ssLeft],At.X+3,At.Y+2); Release(3,2);
    Check(Project.Snapshot<>Before,'small resize-handle edits remain immediate'); Probe.Undo(nil);
  finally Probe.Free; Shot.Free; end;
end;
procedure TDragDropTestsHelper.MaterialSizeCase(W,H,ExpectedW,ExpectedH,PPI: Integer; Zoom: Double);
var Probe: TComicTestForm; Project,Loaded: TComicProject; Panel: TComicPanel; Material: TComicEffectMaterial;
  PNG: TPngImage; At: TPoint; R: TRectF; Before,After,SourceHash,Source: string; History: Integer; Accept: Boolean; Shot: TBitmap;
begin
  Probe:=TComicTestForm.Create(nil); Material:=TComicEffectMaterial.Create; PNG:=TPngImage.CreateBlank(COLOR_RGB,8,W,H); Shot:=TBitmap.Create;
  try
    Material.Name:='原寸と縮小の試験'; Material.FileName:=Material.ID+'.png'; Source:=EffectMaterialPath(Material);
    ForceDirectories(ExtractFilePath(Source)); PNG.Canvas.Brush.Color:=clBlue; PNG.Canvas.FillRect(Rect(0,0,W,H)); PNG.SaveToFile(Source);
    SourceHash:=THashSHA2.GetHashStringFromFile(Source); Project:=CreateFixtureProject; Project.Initialize('D&Dサイズ fixture','1'); Probe.AdoptProject(Project,False);
    Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(100,150,500,750); Probe.Page.Panels.Add(Panel); Probe.RefreshUI;
    Probe.FModeButtons[4].Click; Probe.FEffectList.Items.AddObject(Material.Name,Material); Probe.FEffectList.ItemIndex:=Probe.FEffectList.Count-1;
    Probe.Scaled:=True; Probe.ScaleForPPI(PPI); Probe.Scaled:=False; Probe.FViewZoom:=Zoom; Probe.HandleNeeded;
    Shot.SetSize(Probe.ClientWidth,Probe.ClientHeight); Probe.PaintTo(Shot.Canvas,0,0);
    At:=Point(Probe.FPageRect.Left+Round(Panel.Bounds.CenterPoint.X*Probe.FScale),Probe.FPageRect.Top+Round(Panel.Bounds.CenterPoint.Y*Probe.FScale));
    Before:=Project.Snapshot; History:=Probe.FUndo.Count;
    Probe.DragOver(Probe.FCanvas,Probe.FEffectList,At.X,At.Y,dsDragMove,Accept); Check(Accept,'material D&D accepts a panel at the current DPI and zoom');
    Probe.DragDrop(Probe.FCanvas,Probe.FEffectList,At.X,At.Y);
    Check((Panel.Overlays.Count=1) and (Probe.FUndo.Count=History+1),'material drop creates one independently placed overlay and one undo');
    R:=OverlayBounds(Panel,Panel.Overlays[0]);
    Check((Abs(R.Width-ExpectedW)<0.01) and (Abs(R.Height-ExpectedH)<0.01) and (R.CenterPoint.Distance(Panel.Bounds.CenterPoint)<0.01),
      'small PNGs keep native dimensions and large PNGs fit the centered panel without upscaling');
    Check((Abs(R.Width/R.Height-W/H)<0.0001) and (R.Left>=Panel.Bounds.Left-0.01) and (R.Right<=Panel.Bounds.Right+0.01) and
      (R.Top>=Panel.Bounds.Top-0.01) and (R.Bottom<=Panel.Bounds.Bottom+0.01),'fitted material preserves its source aspect and stays inside the panel bounds');
    Check(THashSHA2.GetHashStringFromFile(SafeChild(Project.Folder,Panel.Overlays[0].FileName))=SourceHash,'fit changes placement only and preserves the original PNG bytes');
    if (W=800) and (PPI=144) and (Zoom=0.75) then begin
      Probe.PaintTo(Shot.Canvas,0,0); PNG.Assign(Shot); PNG.SaveToFile(TPath.Combine(TestFolder,'material-fit-wide.png'));
    end;
    After:=Project.Snapshot; Project.Save; Loaded:=CreateFixtureProject;
    try Loaded.Load(TPath.Combine(Project.Folder,'Project.json')); Check(Loaded.Snapshot=After,'native or fitted material dimensions survive save and reload'); finally Loaded.Free; end;
    Probe.Undo(nil); Check(Project.Snapshot=Before,'material placement undo restores the exact previous page'); Probe.Redo(nil);
    Check(Project.Snapshot=After,'material placement redo restores size and identity');
  finally Probe.Free; Material.Free; PNG.Free; Shot.Free; end;
end;
procedure RunDragDropChecks(Host: TComicTestForm);
const Zooms: array[0..1] of Double = (0.75,1.5);
var PPI,Mode: Integer; Zoom: Double; Start: TPoint;
begin
  Start:=Point(100,100);
  for PPI in [96,144] do begin
    Host.Check(not ObjectMoveReady(Start,Point(100+MulDiv(6,PPI,96)-1,100),249,PPI),'short movement below the DPI-scaled distance boundary is ignored');
    Host.Check(ObjectMoveReady(Start,Point(101,100),250,PPI),'holding reaches the intentional movement time boundary');
    Host.Check(ObjectMoveReady(Start,Point(100+MulDiv(6,PPI,96),100),0,PPI),'quick movement reaches the intentional distance boundary');
    for Zoom in Zooms do begin
      for Mode in [1,2] do Host.MoveIntentCase(Mode,PPI,Zoom,False);
      Host.MoveIntentCase(1,PPI,Zoom,True);
      Host.MaterialSizeCase(100,80,100,80,PPI,Zoom); Host.MaterialSizeCase(800,200,400,100,PPI,Zoom);
      Host.MaterialSizeCase(200,1200,100,600,PPI,Zoom); Host.MaterialSizeCase(1200,1200,400,400,PPI,Zoom);
      Host.MaterialSizeCase(400,600,400,600,PPI,Zoom);
    end;
  end;
end;
end.
