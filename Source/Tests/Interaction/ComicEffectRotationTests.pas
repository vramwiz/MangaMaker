unit ComicEffectRotationTests;

// 責務：効果の回転角、透明描画・クリップ・DC原点、実イベントと保存/Undoを隔離して検証する。
interface
uses ComicTestSupport;
procedure RunEffectRotationChecks(Host: TComicTestForm);
implementation
uses Winapi.Windows, System.SysUtils, System.Classes, System.Types, System.Math, System.IOUtils,
  System.JSON, Vcl.Controls, Vcl.Graphics, Vcl.Imaging.pngimage, ComicModel, ComicRender,
  ComicEditing, ComicEffects, ComicOverlayTransform, ComicExport, System.Hash;
type
  TRotationTestsHelper = class helper for TComicTestForm
    procedure GeometryChecks;
    procedure RotationPixels;
    procedure RotationExport;
    procedure RotationDragCase(PPI: Integer; Zoom,Initial: Double);
  end;
procedure TRotationTestsHelper.GeometryChecks;
var R,Resized: TRectF; P,Delta,Opposite: TPointF; Angle: Double; Handle: Integer;
  Points: TArray<TPointF>; Overlay,CopyOverlay: TComicOverlay; J: TJSONObject; Pair: TJSONPair; Rejected: Boolean;
begin
  R:=TRectF.Create(100,200,500,500);
  P:=RotateOverlayPoint(TPointF.Create(500,350),R.CenterPoint,90);
  Check(P.Distance(TPointF.Create(300,550))<0.001,'90-degree rotation uses the object center and clockwise page coordinates');
  Check((NormalizeOverlayAngle(181)=-179) and (NormalizeOverlayAngle(-181)=179),'angles crossing the half turn remain continuous modulo 360');
  Check(Abs(DragOverlayAngle(R,0,TPointF.Create(300,100),TPointF.Create(550,350),False)-90)<0.001,'handle drag from top to right rotates clockwise by 90 degrees');
  Check(Abs(DragOverlayAngle(R,0,TPointF.Create(300,100),TPointF.Create(50,350),False)+90)<0.001,'handle drag from top to left rotates counterclockwise');
  Check(Abs(DragOverlayAngle(R,0,TPointF.Create(300,100),TPointF.Create(360,100),True)-15)<0.001,'Shift rounds the resulting angle to 15-degree increments');
  for Angle in [0,37,90,170] do begin
    for Handle:=1 to 8 do begin
      Points:=OverlayEditHandles(R,Angle); Opposite:=Points[(Handle+3) mod 8];
      Check(HitOverlayHandle(R,Angle,Points[Handle-1],1,96)=Handle,'each rotated resize point can be selected');
      Delta:=RotateOverlayPoint(TPointF.Create(25,18),TPointF.Zero,Angle);
      Resized:=ResizeRotatedOverlay(R,Angle,Delta,Handle); Points:=OverlayEditHandles(Resized,Angle);
      Check((Abs(Resized.Width/Resized.Height-R.Width/R.Height)<0.0001) and
        (Points[(Handle+3) mod 8].Distance(Opposite)<0.001),'rotated scaling preserves aspect and its opposite world-space anchor');
    end;
    P:=OverlayRotationHandle(R,Angle,0.5,144);
    Check(HitOverlayHandle(R,Angle,P,0.5,144)=9,'rotation point remains independently hittable at a scaled DPI and zoom');
  end;
  Check(OverlayContains(R,90,TPointF.Create(300,530)) and not OverlayContains(R,90,TPointF.Create(110,350)),
    'selection tests the rotated rectangle rather than the original axis-aligned bounds');
  Overlay:=TComicOverlay.Create; CopyOverlay:=TComicOverlay.Create;
  try
    Overlay.MaterialID:='rotation-test'; Overlay.Rotation:=-47.5; J:=Overlay.Json;
    try
      CopyOverlay.Read(J); Check(CopyOverlay.Rotation=-47.5,'fractional signed rotation survives JSON roundtrip');
      Pair:=J.RemovePair('rotation'); Pair.Free; CopyOverlay.Rotation:=60; CopyOverlay.Read(J);
      Check(CopyOverlay.Rotation=0,'legacy overlays without a rotation field remain unrotated');
      J.AddPair('rotation',TJSONNumber.Create(361)); Rejected:=False;
      try CopyOverlay.Read(J); except Rejected:=True; end; Check(Rejected,'invalid stored rotation is rejected');
    finally J.Free; end;
  finally Overlay.Free; CopyOverlay.Free; end;
end;
procedure TRotationTestsHelper.RotationPixels;
var PNG: TPngImage; Renderer: TComicRenderer; Reference,Shifted: TBitmap; X,Y,Saved: Integer;
  Path: string; Region: HRGN; Same,Clipped: Boolean; Color: TColor; FileLock: THandle;
begin
  PNG:=TPngImage.CreateBlank(COLOR_RGB,8,64,32); Renderer:=TComicRenderer.Create;
  Reference:=TBitmap.Create; Shifted:=TBitmap.Create;
  try
    PNG.Canvas.Brush.Color:=clRed; PNG.Canvas.FillRect(Rect(0,0,64,32)); PNG.CreateAlpha;
    for Y:=0 to 31 do for X:=0 to 63 do if X<32 then PNG.AlphaScanline[Y]^[X]:=128 else PNG.AlphaScanline[Y]^[X]:=0;
    Path:=TPath.Combine(TestFolder,'rotation-alpha.png'); PNG.SaveToFile(Path);
    Reference.SetSize(320,240); Shifted.SetSize(400,310);
    Reference.Canvas.Brush.Color:=clWhite; Reference.Canvas.FillRect(Rect(0,0,320,240));
    Renderer.DrawOverlay(Reference.Canvas,Path,Rect(80,60,240,140),90);
    Color:=Reference.Canvas.Pixels[160,60];
    Check((GetRValue(Color)>245) and (GetGValue(Color)>100) and (GetGValue(Color)<160),
      'rotated PNG keeps semitransparent ink and blends with the underlying page');
    Check((Reference.Canvas.Pixels[160,140]=clWhite) and (Reference.Canvas.Pixels[100,100]=clWhite),
      'rotated transparent half and pixels outside the rotated image preserve the background');
    Reference.Canvas.FillRect(Rect(0,0,320,240)); Shifted.Canvas.Brush.Color:=clWhite; Shifted.Canvas.FillRect(Rect(0,0,400,310));
    Region:=CreateEllipticRgn(110,30,210,170); Saved:=SaveDC(Reference.Canvas.Handle);
    try SelectClipRgn(Reference.Canvas.Handle,Region); Renderer.DrawOverlay(Reference.Canvas,Path,Rect(80,60,240,140),37);
    finally RestoreDC(Reference.Canvas.Handle,Saved); Reference.Canvas.Refresh; Winapi.Windows.DeleteObject(Region); end;
    Region:=CreateEllipticRgn(165,65,265,205); Saved:=SaveDC(Shifted.Canvas.Handle);
    try
      SetViewportOrgEx(Shifted.Canvas.Handle,55,35,nil); SelectClipRgn(Shifted.Canvas.Handle,Region);
      Renderer.DrawOverlay(Shifted.Canvas,Path,Rect(80,60,240,140),37);
    finally RestoreDC(Shifted.Canvas.Handle,Saved); Shifted.Canvas.Refresh; Winapi.Windows.DeleteObject(Region); end;
    Same:=True; Clipped:=True; Region:=CreateEllipticRgn(110,30,210,170);
    try for Y:=0 to 239 do for X:=0 to 319 do begin
      if Reference.Canvas.Pixels[X,Y]<>Shifted.Canvas.Pixels[X+55,Y+35] then Same:=False;
      if not PtInRegion(Region,X,Y) and (Reference.Canvas.Pixels[X,Y]<>clWhite) then Clipped:=False;
    end; finally Winapi.Windows.DeleteObject(Region); end;
    PNG.Assign(Reference); PNG.SaveToFile(TPath.Combine(TestFolder,'rotation-clip-reference.png'));
    PNG.Assign(Shifted); PNG.SaveToFile(TPath.Combine(TestFolder,'rotation-clip-shifted.png'));
    Check(Same,'rotated alpha rendering respects translated PaintTo DC coordinates');
    Check(Clipped,'rotated alpha rendering cannot escape the nonrectangular owner clip');
    PNG.Assign(Reference); PNG.SaveToFile(TPath.Combine(TestFolder,'rotation-alpha-clip.png'));
    // キャッシュが画像を保持していても、原本を排他オープンできることを確認する。
    FileLock:=CreateFile(PChar(Path),GENERIC_READ or GENERIC_WRITE,0,nil,OPEN_EXISTING,0,0);
    Check(FileLock<>INVALID_HANDLE_VALUE,'rotation cache keeps no lock on the source PNG');
    if FileLock<>INVALID_HANDLE_VALUE then CloseHandle(FileLock);
  finally PNG.Free; Renderer.Free; Reference.Free; Shifted.Free; end;
end;
procedure TRotationTestsHelper.RotationExport;
var Project: TComicProject; Panel: TComicPanel; Overlay: TComicOverlay; Renderer: TComicRenderer;
  PNG: TPngImage; Path,Before: string; Color: TColor;
begin
  Project:=CreateFixtureProject; Renderer:=TComicRenderer.Create; PNG:=TPngImage.Create;
  try
    Project.Initialize('回転PNG出力 fixture','1'); Panel:=TComicPanel.Create;
    Panel.Bounds:=TRectF.Create(100,100,900,1300); Project.Pages[0].Panels.Add(Panel);
    Overlay:=TComicOverlay.Create; Overlay.MaterialID:='rotation-test'; Overlay.FileName:='Effects\rotation.png';
    Overlay.Bounds:=TRectF.Create(0.2,0.1,0.8,0.4); Panel.Overlays.Add(Overlay);
    ForceDirectories(TPath.Combine(Project.Folder,'Effects')); TFile.Copy(TPath.Combine(TestFolder,'rotation-alpha.png'),SafeChild(Project.Folder,Overlay.FileName),True);
    Check(ExportSequence(Project,Renderer,False)=1,'initial effect sequence produces a PNG');
    Path:=TPath.Combine(Project.Folder,'Output\0001.png'); Before:=THashSHA2.GetHashStringFromFile(Path);
    Check(ExportSequence(Project,Renderer,False)=0,'unchanged effect export reuses its cache'); Overlay.Rotation:=90;
    Check((ExportSequence(Project,Renderer,False)=1) and (Before<>THashSHA2.GetHashStringFromFile(Path)),
      'rotation alone invalidates the export signature and changes the completed PNG');
    PNG.LoadFromFile(Path); Color:=PNG.Canvas.Pixels[500,280];
    Check((GetRValue(Color)>240) and (GetGValue(Color)<180) and (PNG.Canvas.Pixels[500,520]=$F5F2EF),
      'exported ink and transparent areas follow the rotated geometry');
    Check(ExportSequence(Project,Renderer,False)=0,'rotated effect export also reuses its completed cache');
  finally Project.Free; Renderer.Free; PNG.Free; end;
end;
procedure TRotationTestsHelper.RotationDragCase(PPI: Integer; Zoom,Initial: Double);
var Probe: TComicTestForm; Project,Reloaded: TComicProject; Panel: TComicPanel; Overlay: TComicOverlay;
  Shot: TBitmap; PNG: TPngImage; R: TRectF; A,Z: TPoint; Finish: TPointF; Before,After: string; History: Integer; Key: Word;
  procedure Paint;
  begin Probe.HandleNeeded; Shot.SetSize(Probe.ClientWidth,Probe.ClientHeight); Probe.PaintTo(Shot.Canvas,0,0); end;
  function Screen(const P: TPointF): TPoint;
  begin Result:=Point(Probe.FPageRect.Left+Round(P.X*Probe.FScale),Probe.FPageRect.Top+Round(P.Y*Probe.FScale)); end;
  procedure Select;
  begin Probe.FPanelIndex:=0; Probe.FEffectIndex:=0; Probe.FBalloonIndex:=-1; Probe.FTool:=0; Probe.ActiveControl:=Probe.FView; end;
begin
  Probe:=TComicTestForm.Create(nil); Shot:=TBitmap.Create; PNG:=TPngImage.Create;
  try
    Project:=CreateFixtureProject; Project.Initialize('回転 fixture','1'); Probe.AdoptProject(Project,False);
    Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(200,300,1000,1400); Probe.Page.Panels.Add(Panel);
    Overlay:=TComicOverlay.Create; Overlay.MaterialID:='rotation-test'; Overlay.FileName:='Effects\rotation.png';
    Overlay.Bounds:=TRectF.Create(0.2,0,0.8,0.45); Overlay.Rotation:=Initial; Panel.Overlays.Add(Overlay);
    ForceDirectories(TPath.Combine(Project.Folder,'Effects')); TFile.Copy(TPath.Combine(TestFolder,'rotation-alpha.png'),SafeChild(Project.Folder,Overlay.FileName),True);
    Probe.RefreshUI; Probe.FTabs.ActivePageIndex:=4; Probe.FEffectCategory.ItemIndex:=0;
    Probe.Scaled:=True; Probe.ScaleForPPI(PPI); Probe.Scaled:=False; Probe.FViewZoom:=Zoom; Select; Paint;
    R:=OverlayBounds(Panel,Overlay); A:=Screen(OverlayRotationHandle(R,Initial,Probe.FScale,PPI));
    Before:=Project.Snapshot; History:=Probe.FUndo.Count;
    Probe.MouseMove(Probe.FCanvas,[],A.X,A.Y); Check(Probe.FCanvas.Cursor=crHandPoint,'rotation handle hover uses an actionable cursor');
    Probe.MouseDown(Probe.FCanvas,mbLeft,[],A.X,A.Y);
    Check(Probe.FDragging and (Probe.FDragHandle=9) and not Probe.FViewPanning,'rotation handle starts rotation even above the owner panel');
    Finish:=RotateOverlayPoint(Probe.FStart,R.CenterPoint,90); Z:=Screen(Finish);
    Probe.MouseMove(Probe.FCanvas,[ssLeft],Z.X,Z.Y);
    Check((Abs(NormalizeOverlayAngle(Overlay.Rotation-Initial-90))<1) and (OverlayBounds(Panel,Overlay)=R) and
      (Probe.FUndo.Count=History),'rotation preview changes angle only and defers undo until release');
    if (PPI=144) and (Initial=33) and (Zoom=0.75) then begin Paint; PNG.Assign(Shot); PNG.SaveToFile(TPath.Combine(TestFolder,'effect-rotation-handles.png')); end;
    Probe.MouseUp(Probe.FCanvas,mbLeft,[],Z.X,Z.Y); After:=Project.Snapshot;
    Check((Probe.FUndo.Count=History+1) and (After<>Before),'release commits one rotation');
    Project.Save; Reloaded:=CreateFixtureProject;
    try Reloaded.Load(TPath.Combine(Project.Folder,'Project.json')); Check(Reloaded.Snapshot=After,'rotated effect survives project save and reload'); finally Reloaded.Free; end;
    Probe.Undo(nil); Check(Project.Snapshot=Before,'one undo restores the exact original effect angle'); Probe.Redo(nil);
    Check(Project.Snapshot=After,'redo restores the rotated effect without changing its PNG'); Select;
    Overlay:=Probe.Page.Panels[0].Overlays[0]; R:=OverlayBounds(Probe.Page.Panels[0],Overlay);
    A:=Screen(OverlayRotationHandle(R,Overlay.Rotation,Probe.FScale,PPI)); Probe.MouseDown(Probe.FCanvas,mbLeft,[],A.X,A.Y);
    Probe.MouseMove(Probe.FCanvas,[ssLeft],A.X+24,A.Y+16); Key:=VK_ESCAPE; Probe.Key(Probe,Key,[]);
    Check((Project.Snapshot=After) and (Probe.FUndo.Count=History+1),'Esc cancels a pending rotation without another undo entry'); Select;
    Overlay:=Probe.Page.Panels[0].Overlays[0]; A:=Screen(OverlayRotationHandle(R,Overlay.Rotation,Probe.FScale,PPI));
    Probe.MouseDown(Probe.FCanvas,mbLeft,[],A.X,A.Y); Probe.MouseUp(Probe.FCanvas,mbLeft,[],A.X,A.Y);
    Check((Project.Snapshot=After) and (Probe.FUndo.Count=History+1),'clicking the rotation point without dragging creates no edit');
  finally Probe.Free; Shot.Free; PNG.Free; end;
end;
procedure RunEffectRotationChecks(Host: TComicTestForm);
const Zooms: array[0..1] of Double = (0.75,1.5);
var PPI: Integer; Zoom,Initial: Double;
begin
  Host.GeometryChecks; Host.RotationPixels; Host.RotationExport;
  for PPI in [96,144] do for Zoom in Zooms do for Initial in [0,33,170] do Host.RotationDragCase(PPI,Zoom,Initial);
end;
end.
