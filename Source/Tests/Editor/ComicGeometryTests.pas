unit ComicGeometryTests;

// 責務：形状編集と吸着の回帰を検証し、丸め誤差を不正形拒否の緩和で隠さない。
interface
uses ComicTestSupport;
procedure RunGeometryChecks(Host: TComicTestForm);
procedure RunGapSnapChecks(Host: TComicTestForm);
procedure RunPanelTransformSnapChecks(Host: TComicTestForm);
implementation
uses Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, Winapi.Imm,
  System.SysUtils, System.Classes, System.Types, System.UITypes,
  System.Math, System.IOUtils, System.Generics.Collections, System.JSON,
  System.Hash, System.DateUtils, Vcl.Controls, Vcl.Forms,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Menus,
  Vcl.Dialogs, Vcl.Graphics, Vcl.Imaging.pngimage, ComicModel,
  ComicLayouts, ComicExport, ComicEditing, ComicIconButton,
  ComicDragIntent, ComicGeometry, ComicGapSnap;
type
  TComicGeometryTestsHelper = class helper for TComicTestForm
    procedure GeometryChecks;
    procedure GapSnapChecks;
    procedure PanelTransformSnapChecks;
  end;
procedure TComicGeometryTestsHelper.GeometryChecks;
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
      FProject.Save; Reloaded:=CreateFixtureProject;
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
    FProject:=CreateFixtureProject; FUndo:=TList<string>.Create; FRedo:=TList<string>.Create;
    PNG:=TPngImage.Create; Reference:=TBitmap.Create;
    try
      FProject.Initialize('Geometry fixture','1'); FPageIndex:=0; FPanelIndex:=-1; FBalloonIndex:=-1;
      ImageID:=FProject.ImportImage(TPath.Combine(TestFolder,'reference.bmp'),'').ID;
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
      Layout:=TComicLayout.Create; LayoutCopy:=TComicLayout.Create; Reloaded:=CreateFixtureProject;
      try
        Layout.Name:='Polygon fixture'; Layout.Capture(FProject,Page);
        J:=Layout.Json; try LayoutCopy.Read(J); finally J.Free; end;
        Reloaded.Pages.Add(TComicPage.Create); LayoutCopy.Apply(Reloaded.Pages[0],600,850);
        Check((Reloaded.Pages[0].Panels[0].Shape=3) and
          (Abs(Reloaded.Pages[0].Panels[0].Vertices[1].X-Panel.Vertices[1].X/2)<0.001) and
          (Reloaded.Pages[0].Panels[0].ImageID=''),'polygon template roundtrip scales vertices and excludes images');
        // 画面クリックの丸めを考慮し、固定値100ではなく実際の頂点を復元して後続検証を壊さない。
        Points:=Panel.Outline;
        Panel.Vertices[0].X:=Points[0].X+5;
        Check(Layout.Panels[0].Vertices[0].X<>Panel.Vertices[0].X,'template capture owns an independent vertex array');
        Panel.SetVertices(Points);
        Check(Panel.Bounds=PolygonBounds(Panel.Vertices),'template independence check restores consistent actual click coordinates');
      finally Reloaded.Free; LayoutCopy.Free; Layout.Free; end;
      B.SetSize(600,850); FRenderer.Draw(B.Canvas,FProject,Page,Rect(0,0,600,850),False);
      Check((B.Canvas.Pixels[80,650]=clWhite) and (B.Canvas.Pixels[450,300]<>clWhite),
        'polygon image clipping follows the outline');
      PNG.Assign(B); PNG.SaveToFile(TPath.Combine(TestFolder,'polygon-render.png'));
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
      Capture('geometry-after-split'); FRenderer.ExportPage(FProject,Page,TPath.Combine(TestFolder,'split-page.png'));
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
      // 表示倍率による丸めで重複点の入力がずれないよう、整数画素で正確に指定できる倍率を使う。
      FViewZoom:=0.25/Min(Max(1,FCanvas.Width-2*MulDiv(24,CurrentPPI,96))/FProject.Width,
        Max(1,FCanvas.Height-2*MulDiv(24,CurrentPPI,96))/FProject.Height); UpdateViewport;
      Check(FScale=0.25,'duplicate-vertex regression uses exact quarter-scale coordinates');
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

procedure RunGeometryChecks(Host: TComicTestForm);
begin Host.GeometryChecks; end;
procedure TComicGeometryTestsHelper.GapSnapChecks;
  var Probe: TComicTestForm; Project,Reloaded: TComicProject; Panel: TComicPanel; Snap: TComicGapSnap; PointA: TPointF;
    Before,Original: string; X,Y,PPI: Integer; KeyValue: Word;
    procedure Add(L,T,R,B: Single);
    begin Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(L,T,R,B); Probe.Page.Panels.Add(Panel); end;
    procedure Click(PX,PY: Single; Shift: TShiftState);
    begin X:=Probe.FPageRect.Left+Round(PX*Probe.FScale); Y:=Probe.FPageRect.Top+Round(PY*Probe.FScale); Probe.MouseDown(Probe.FCanvas,mbLeft,Shift,X,Y); Probe.MouseUp(Probe.FCanvas,mbLeft,Shift,X,Y); end;
  begin
    Original:=FProject.Snapshot; Probe:=TComicTestForm.Create(nil); Probe.FDragPlacementMenu.Checked:=False;
    try
      Project:=CreateFixtureProject; Project.Initialize('間隔スナップ fixture','1'); Probe.AdoptProject(Project,False); Project.ImportImage(TPath.Combine(TestFolder,'reference.bmp'),'');
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
        Project.Save; Reloaded:=CreateFixtureProject;
        try Reloaded.Load(TPath.Combine(Project.Folder,'Project.json')); Check(Reloaded.Snapshot=Project.Snapshot,'gap-created panel saves and reloads '+IntToStr(PPI)); finally Reloaded.Free; end;
        Probe.Undo(nil); Check(Project.Snapshot=Before,'gap-created panel undo restores exact source spacing '+IntToStr(PPI));
        Probe.FSnap.Checked:=False; PointA:=Probe.SnapCreationPoint(TPointF.Create(538,200)); Check(PointA.X=538,'gap setting disables all snapping '+IntToStr(PPI)); Probe.FSnap.Checked:=True;
        Probe.FTool:=1; Click(538,200,[ssAlt]); Check(Abs(Probe.FStart.X-540)>0.5,'Alt bypasses repeated gap on creation '+IntToStr(PPI));
        KeyValue:=VK_ESCAPE; Probe.Key(Probe,KeyValue,[]); Check(Project.Snapshot=Before,'cancelled gap creation preserves history data '+IntToStr(PPI));
      end;
      Check(FProject.Snapshot=Original,'gap snap fixtures preserve the active project');
    finally Probe.Free; end;
  end;

procedure RunGapSnapChecks(Host: TComicTestForm);
begin Host.GapSnapChecks; end;
procedure TComicGeometryTestsHelper.PanelTransformSnapChecks;
  var Probe: TComicTestForm; Project,Reloaded: TComicProject; Panels: TObjectList<TComicPanel>; Panel: TComicPanel;
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
      // Alt状態は検証イベントへ直接渡し、ユーザーの実キー状態やフォーカスを変更しない。
      if Alt then Probe.MouseMove(Probe.FCanvas,[ssLeft,ssAlt],TX,TY)
      else Probe.FCanvas.Perform(WM_MOUSEMOVE,Flags,MakeLParam(TX,TY));
    end;
    procedure Finish;
    begin Probe.FCanvas.Perform(WM_LBUTTONUP,0,MakeLParam(TX,TY)); end;
  begin
    Original:=FProject.Snapshot; Panels:=TObjectList<TComicPanel>.Create;
    Probe:=TComicTestForm.Create(nil); PNG:=TPngImage.Create;
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
      Project:=CreateFixtureProject; Project.Initialize('コマ全体スナップ fixture','1'); Probe.AdoptProject(Project,False);
      ImageID:=Project.ImportImage(TPath.Combine(TestFolder,'reference.bmp'),'').ID;
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
        After:=Project.Snapshot; Project.Save; Reloaded:=CreateFixtureProject;
        try Reloaded.Load(TPath.Combine(Project.Folder,'Project.json')); Check(Reloaded.Snapshot=After,'snapped panel saves and reloads at PPI '+IntToStr(PPI)); finally Reloaded.Free; end;
        Probe.Undo(nil); Check(Project.Snapshot=Before,'snapped movement undo restores exact source data '+IntToStr(PPI));
        Probe.Redo(nil); Check(Project.Snapshot=After,'snapped movement redo restores all geometry '+IntToStr(PPI)); Probe.Undo(nil);
        StartPanelDrag(2,0); MoveTo(TPointF.Create(PointA.X-162,PointA.Y),True); Finish;
        Check(Abs(Probe.Page.Panels[2].Bounds.Left-540)>0.5,'Alt bypasses whole-panel movement snap '+IntToStr(PPI)); Probe.Undo(nil);
        Probe.FSnap.Checked:=False; StartPanelDrag(2,0); MoveTo(TPointF.Create(PointA.X-162,PointA.Y)); Finish;
        Check(Abs(Probe.Page.Panels[2].Bounds.Left-540)>0.5,'disabled checkbox bypasses whole-panel snap '+IntToStr(PPI)); Probe.Undo(nil); Probe.FSnap.Checked:=True;
        StartPanelDrag(2,0); History:=Probe.FUndo.Count; MoveTo(TPointF.Create(PointA.X-162,PointA.Y)); KeyValue:=VK_ESCAPE; Probe.Key(Probe,KeyValue,[]);
        Check((Project.Snapshot=Before) and (Probe.FUndo.Count=History) and not Probe.FDragging,'escape cancels snapped movement without an undo entry '+IntToStr(PPI));
        // 吸着量が累積しないことを、押下時の範囲から繰返し更新して確認する。
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
      // 混在形状を外接範囲で変形し、内部の比率と非選択コマを保つことを確認する。
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
        PaintProbe; PNG.Assign(B); PNG.SaveToFile(TPath.Combine(TestFolder,'panel-transform-snap-'+IntToStr(PPI)+'.png'));
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
        // 長押し後の小移動でも、選択コマ自身へ吸着して元位置へ引き戻さないことを確認する。
        Probe.FSelectedPanels.Clear; Probe.FSelectedPanels.Add(Probe.Page.Panels[0].ID); Probe.FSelectedPanels.Add(Probe.Page.Panels[1].ID); Probe.FPanelIndex:=0; PaintProbe;
        Bounds:=Probe.SelectedPanelBounds; PointA:=Bounds.CenterPoint; X:=Probe.FPageRect.Left+Round(PointA.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(PointA.Y*Probe.FScale);
        Probe.FCanvas.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(X,Y));
        Probe.FDragStartedTick:=GetTickCount64-ComicMoveHoldMilliseconds; MoveTo(TPointF.Create(PointA.X+5,PointA.Y));
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

procedure RunPanelTransformSnapChecks(Host: TComicTestForm);
begin Host.PanelTransformSnapChecks; end;
end.
