unit ComicPageResizeTests;

// 責務：ページ中心での相似変換、画像の切抜き、文字組版、全ページUndoと失敗時の保持を検証する。
interface
uses ComicTestSupport;
procedure RunPageResizeChecks(Host: TComicTestForm);
implementation
uses Winapi.Windows, System.SysUtils, System.Classes, System.Types, System.Math, System.IOUtils,
  System.JSON, System.Hash, Vcl.Graphics, Vcl.Imaging.pngimage, ComicModel, ComicRender,
  ComicEffects, ComicTextLayout, ComicPageResize, ComicExport;
type
  TPageResizeTestsHelper = class helper for TComicTestForm
    procedure ResizeCase(Width,Height: Integer);
    procedure ResizeFailureChecks;
  end;
procedure AddFixture(Project: TComicProject; const ImageID,EffectPath: string);
var Page: TComicPage; Panel: TComicPanel; Balloon: TComicBalloon; Overlay: TComicOverlay; Tail: TComicTail;
  I,J: Integer; X,Y: Single;
begin
  Project.Pages.Add(TComicPage.Create);
  ForceDirectories(TPath.Combine(Project.Folder,'Effects')); TFile.Copy(EffectPath,TPath.Combine(Project.Folder,'Effects\resize.png'),True);
  for Page in Project.Pages do begin
    for I:=0 to 3 do begin
      Panel:=TComicPanel.Create; X:=100+(I mod 2)*500; Y:=100+(I div 2)*650;
      Panel.Bounds:=TRectF.Create(X,Y,X+400,Y+500); Panel.ImageID:=ImageID; Panel.Shape:=I;
      if I=3 then Panel.SetVertices([TPointF.Create(X,Y),TPointF.Create(X+400,Y+10),TPointF.Create(X+340,Y+500),TPointF.Create(X+50,Y+450)]);
      Panel.Zoom:=1.7; Panel.PanX:=17; Panel.PanY:=-23; Panel.FrameKind:=1;
      Overlay:=TComicOverlay.Create; Overlay.MaterialID:='page-resize'; Overlay.FileName:='Effects\resize.png';
      Overlay.Bounds:=TRectF.Create(0.1,0.15,0.85,0.9); Overlay.Rotation:=37; Panel.Overlays.Add(Overlay); Page.Panels.Add(Panel);
    end;
    for I:=0 to 1 do begin
      Balloon:=TComicBalloon.Create; Balloon.Bounds:=TRectF.Create(100+I*450,160+I*500,310+I*450,560+I*500);
      Balloon.Text:='天地玄黄宇宙洪荒日月盈昃'+#13#10+'列と行を維持する'; Balloon.Vertical:=I=0; Balloon.AutoWrap:=I=0;
      Balloon.FontSize:=47-I*15; Balloon.TextOffset:=TPointF.Create(17,-19); Balloon.CharacterSpacing:=1.1; Balloon.LineSpacing:=1.25;
      Balloon.Overflow:=I=1; Balloon.Transparent:=I=1; Balloon.PanelID:=Page.Panels[0].ID;
      if I=1 then begin Balloon.TextLayoutSize:=TSizeF.Create(150,80); Balloon.TextLayoutFontSize:=36; end;
      for J:=0 to 1 do begin
        Tail:=TComicTail.Create; Tail.Root:=Balloon.Bounds.CenterPoint; Tail.Tip:=Tail.Root+TPointF.Create(200,280);
        Tail.Width:=24+J*12; if J=1 then Tail.Kind:=ctThought; Balloon.Tails.Add(Tail);
      end;
      Page.Balloons.Add(Balloon);
    end;
  end;
end;
procedure TPageResizeTestsHelper.ResizeCase(Width,Height: Integer);
var Probe: TComicTestForm; Project,Original,Reloaded: TComicProject; Basis: TComicPageBasis;
  Reference,Completed: TBitmap; PNG: TPngImage; Layout: TComicTextLayout; I,J,K,Lines,History,X,Y: Integer;
  Scale: Double; Before,After,ImageID,ImageHash: string; OldPanel,Panel: TComicPanel; OldBalloon,Balloon: TComicBalloon;
  Expected,R: TRectF; P: TPointF; Same: Boolean; OldRow,NewRow: PCardinal;
  CurrentJson,ExpectedJson: TJSONObject;
  function Map(const Point: TPointF): TPointF;
  begin Result:=TPointF.Create(Width/2+(Point.X-600)*Scale,Height/2+(Point.Y-850)*Scale); end;
  function MapRect(const Rect: TRectF): TRectF;
  begin Result:=TRectF.Create(Map(Rect.TopLeft),Map(Rect.BottomRight)); end;
  function Near(const A,B: TRectF): Boolean;
  begin Result:=(A.TopLeft.Distance(B.TopLeft)<0.01) and (A.BottomRight.Distance(B.BottomRight)<0.01); end;
begin
  Probe:=TComicTestForm.Create(nil); Original:=CreateFixtureProject; Reference:=TBitmap.Create; Completed:=TBitmap.Create;
  PNG:=TPngImage.Create; Layout:=TComicTextLayout.Create;
  try
    Project:=CreateFixtureProject; Project.Initialize('ページ相似拡縮 fixture','1'); Probe.AdoptProject(Project,False);
    ImageID:=Project.ImportImage(TPath.Combine(TestFolder,'reference.bmp'),'').ID;
    AddFixture(Project,ImageID,TPath.Combine(TestFolder,'resize-effect.png')); Project.Save; Probe.RefreshUI;
    Original.Folder:=Project.Folder; Before:=Project.Snapshot; Original.Restore(Before); History:=Probe.FUndo.Count;
    ImageHash:=THashSHA2.GetHashStringFromFile(Project.ImagePath(ImageID));
    Reference.PixelFormat:=pf32bit; Reference.SetSize(240,340); Probe.FRenderer.Draw(Reference.Canvas,Project,Probe.Page,Rect(0,0,240,340),False);
    Basis:=Project.PageBasis; Basis.Width:=Width; Basis.Height:=Height; Basis.Left:=10; Basis.Top:=11; Basis.Right:=12; Basis.Bottom:=13;
    Scale:=Min(Width/1200,Height/1700); Probe.ApplyPageBasis(Basis);
    Check(Project.PageBasis.Same(Basis) and (Project.Pages.Count=2) and (Probe.FUndo.Count=History+1),'resolution and all page transforms form one undo entry');
    for I:=0 to 1 do begin
      Check((Project.Pages[I].Revision=Original.Pages[I].Revision+1) and (Project.Pages[I].OutputRevision=-1),'every resized page invalidates its content revision and completed output');
      for J:=0 to 3 do begin
        OldPanel:=Original.Pages[I].Panels[J]; Panel:=Project.Pages[I].Panels[J];
        Check(Near(Panel.Bounds,MapRect(OldPanel.Bounds)) and (Panel.Shape=OldPanel.Shape) and (Panel.ID=OldPanel.ID),
          'all panel shapes scale uniformly around the old and new page centers');
        Expected:=MapRect(Probe.FRenderer.ImageBounds(Original,OldPanel)); R:=Probe.FRenderer.ImageBounds(Project,Panel);
        Check(Near(R,Expected) and (Panel.Zoom=OldPanel.Zoom),'image crop, zoom and pan follow their panel without aspect distortion');
        Check((Abs(Panel.BorderWidth-OldPanel.BorderWidth*Scale)<0.0001) and (Abs(Panel.FrameGap-8*Scale)<0.0001),'frame thickness and double-frame spacing use the same page scale');
        for K:=0 to High(OldPanel.Vertices) do Check(Panel.Vertices[K].Distance(Map(OldPanel.Vertices[K]))<0.01,'polygon vertices follow the page similarity transform');
        Check(Near(OverlayBounds(Panel,Panel.Overlays[0]),MapRect(OverlayBounds(OldPanel,OldPanel.Overlays[0]))) and
          (Panel.Overlays[0].Rotation=37) and (Panel.Overlays[0].Bounds=OldPanel.Overlays[0].Bounds),'relative effect placement retains its aspect and rotation');
      end;
      for J:=0 to 1 do begin
        OldBalloon:=Original.Pages[I].Balloons[J]; Balloon:=Project.Pages[I].Balloons[J];
        Check(Near(Balloon.Bounds,MapRect(OldBalloon.Bounds)) and (Balloon.PanelID=OldBalloon.PanelID) and
          (Balloon.Overflow=OldBalloon.Overflow) and (Balloon.Transparent=OldBalloon.Transparent),'attached and floating text balloons keep their shape and owner semantics');
        Check((Balloon.FontSize=EnsureRange(Round(OldBalloon.FontSize*Scale),1,1000)) and
          (Balloon.Text=OldBalloon.Text) and (Balloon.Vertical=OldBalloon.Vertical),'font sizes choose the nearest supported integer while preserving dialogue and direction');
        P:=TPointF.Create(OldBalloon.TextOffset.X*Scale,OldBalloon.TextOffset.Y*Scale);
        Check((Balloon.TextOffset.Distance(P)<0.001) and (Balloon.CharacterSpacing=OldBalloon.CharacterSpacing) and
          (Balloon.LineSpacing=OldBalloon.LineSpacing),'relative text position scales while spacing ratios remain unchanged');
        BuildBalloonTextLayout(Reference.Canvas,OldBalloon,Layout); Lines:=Layout.LineCount;
        BuildBalloonTextLayout(Reference.Canvas,Balloon,Layout);
        Check((Layout.LineCount=Lines) and (Balloon.AutoWrap=OldBalloon.AutoWrap),'resolution changes preserve existing manual and automatic line breaks');
        for K:=0 to 1 do Check((Balloon.Tails[K].Root.Distance(Map(OldBalloon.Tails[K].Root))<0.01) and
          (Balloon.Tails[K].Tip.Distance(Map(OldBalloon.Tails[K].Tip))<0.01) and (Abs(Balloon.Tails[K].Width-OldBalloon.Tails[K].Width*Scale)<0.001),
          'triangular and thought tails scale root, tip and width together');
      end;
    end;
    Check(THashSHA2.GetHashStringFromFile(Project.ImagePath(ImageID))=ImageHash,'resolution changes keep the original image pixels intact');
    Completed.PixelFormat:=pf32bit; Completed.SetSize(240,340); Probe.FRenderer.Draw(Completed.Canvas,Project,Probe.Page,Rect(0,0,240,340),False);
    if (Width=2400) and (Height=3400) then begin
      Same:=True; for Y:=0 to 339 do begin OldRow:=Reference.ScanLine[Y]; NewRow:=Completed.ScanLine[Y];
        for X:=0 to 239 do begin if (OldRow^ and $FFFFFF)<>(NewRow^ and $FFFFFF) then Same:=False; Inc(OldRow); Inc(NewRow); end;
      end;
      Check(Same,'doubling resolution preserves completed-page appearance at the same display size');
    end;
    if (Width=1600) and (Height=900) then begin PNG.Assign(Completed); PNG.SaveToFile(TPath.Combine(TestFolder,'page-resize-landscape.png')); end;
    After:=Project.Snapshot; Project.Save; Reloaded:=CreateFixtureProject;
    try Reloaded.Load(TPath.Combine(Project.Folder,'Project.json')); Check(Reloaded.Snapshot=After,'all resized geometry and text settings survive save and reload'); finally Reloaded.Free; end;
    Probe.Undo(nil); Check(Project.Snapshot=Before,'one undo restores every original page and object'); Probe.Redo(nil); Check(Project.Snapshot=After,'redo restores the whole resized project');
    Before:=Project.Snapshot; History:=Probe.FUndo.Count; Probe.ApplyPageBasis(Basis); Check((Project.Snapshot=Before) and (Probe.FUndo.Count=History),'same page basis does not scale twice or add undo');
    Original.Restore(After); Inc(Basis.Left); Probe.ApplyPageBasis(Basis);
    for I:=0 to 1 do begin
      CurrentJson:=Project.Pages[I].Json; ExpectedJson:=Original.Pages[I].Json;
      try Check(CurrentJson.ToJSON=ExpectedJson.ToJSON,'margin-only changes keep every page object and output revision untouched');
      finally CurrentJson.Free; ExpectedJson.Free; end;
    end;
  finally Probe.Free; Original.Free; Reference.Free; Completed.Free; PNG.Free; Layout.Free; end;
end;
procedure TPageResizeTestsHelper.ResizeFailureChecks;
var Probe: TComicTestForm; Project: TComicProject; Panel: TComicPanel; Balloon: TComicBalloon; Tail: TComicTail;
  Basis: TComicPageBasis; Before,Draft,Path: string; History: Integer; Rejected: Boolean; Lock: THandle; CopyPanel: TComicPanel; J: TJSONObject; Pair: TJSONPair;
begin
  Probe:=TComicTestForm.Create(nil);
  try
    Project:=CreateFixtureProject; Project.Initialize('ページ拡縮拒否 fixture','1'); Probe.AdoptProject(Project,False);
    Panel:=TComicPanel.Create; Project.Pages[0].Panels.Add(Panel); Balloon:=TComicBalloon.Create; Project.Pages[0].Balloons.Add(Balloon);
    Tail:=TComicTail.Create; Tail.Width:=1; Tail.Root:=Balloon.Bounds.CenterPoint; Tail.Tip:=Tail.Root+TPointF.Create(50,70); Balloon.Tails.Add(Tail);
    Project.Save; Probe.RefreshUI; Before:=Project.Snapshot; History:=Probe.FUndo.Count; Basis:=Project.PageBasis; Basis.Width:=600; Basis.Height:=850;
    Rejected:=False; try Probe.ApplyPageBasis(Basis); except Rejected:=True; end;
    Check(Rejected and (Project.Snapshot=Before) and (Probe.FUndo.Count=History),'unrepresentable tiny tails reject the whole transformation before changing content or undo');
    Project.Pages[0].Balloons[0].Tails.Clear; Project.Save; Before:=Project.Snapshot;
    Path:=TPath.Combine(Project.Folder,'Draft.json'); Draft:=TFile.ReadAllText(Path,TEncoding.UTF8);
    Lock:=CreateFile(PChar(Path),GENERIC_READ,FILE_SHARE_READ,nil,OPEN_EXISTING,0,0);
    try Rejected:=False; try Probe.ApplyPageBasis(Basis); except Rejected:=True; end;
      Check(Rejected and (Project.Snapshot=Before) and (Probe.FUndo.Count=History) and
        (TFile.ReadAllText(Path,TEncoding.UTF8)=Draft) and not Probe.FDirty,'failed draft save rolls back geometry, page basis, undo and dirty state');
    finally CloseHandle(Lock); end;
    J:=Project.Pages[0].Panels[0].Json; CopyPanel:=TComicPanel.Create;
    try Pair:=J.RemovePair('frameGap'); Pair.Free; CopyPanel.Read(J); Check(CopyPanel.FrameGap=8,'legacy panels keep the historical double-frame gap');
    finally J.Free; CopyPanel.Free; end;
  finally Probe.Free; end;
end;
procedure RunPageResizeChecks(Host: TComicTestForm);
var PNG: TPngImage;
begin
  PNG:=TPngImage.CreateBlank(COLOR_RGB,8,64,64);
  try PNG.Canvas.Brush.Color:=clRed; PNG.Canvas.FillRect(Rect(0,0,64,64));
    PNG.SaveToFile(TPath.Combine(Host.TestFolder,'resize-effect.png'));
  finally PNG.Free; end;
  Host.ResizeCase(2400,3400); Host.ResizeCase(600,850); Host.ResizeCase(2400,1700);
  Host.ResizeCase(1200,3400); Host.ResizeCase(1600,900); Host.ResizeCase(777,1111); Host.ResizeCase(300,420);
  Host.ResizeFailureChecks;
end;
end.
