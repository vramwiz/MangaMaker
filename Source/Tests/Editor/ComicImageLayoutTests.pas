unit ComicImageLayoutTests;

// 責務：枠と画像の独立した変形、所属コマへの吸着、編集専用ガイドの寿命を検証する。
interface
uses ComicTestSupport;
procedure RunImageLayoutChecks(Host: TComicTestForm);
implementation
uses Winapi.Windows, System.SysUtils, System.Classes, System.Types, System.Math, System.IOUtils,
  Vcl.Controls, Vcl.Graphics, ComicModel, ComicEditing, ComicImageSnap, ComicDragIntent;
type
  TComicImageLayoutTests = class helper for TComicTestForm
    procedure ImageLayoutChecks;
  end;

procedure TComicImageLayoutTests.ImageLayoutChecks;
var Probe: TComicTestForm; Project,Reloaded: TComicProject; Panel: TComicPanel;
  Original,Actual,Frame,Image,OtherImage: TRectF;
  Before,After,ImageID,Base: string; K,Direction,Shape,ZoomLevel,X,Y,TX,TY,I: Integer; P: TPointF;
  function SameRect(const A,B: TRectF): Boolean;
  begin Result:=(Abs(A.Left-B.Left)<0.002) and (Abs(A.Top-B.Top)<0.002) and
    (Abs(A.Right-B.Right)<0.002) and (Abs(A.Bottom-B.Bottom)<0.002); end;
  procedure PaintProbe;
  begin Probe.HandleNeeded; B.SetSize(Probe.ClientWidth,Probe.ClientHeight); Probe.PaintTo(B.Canvas,0,0); end;
  procedure Start(Mode,Handle: Integer);
  begin
    Probe.FTabs.ActivePageIndex:=Mode; Probe.TabChanged(nil); Probe.SelectSinglePanel(0); PaintProbe;
    Original:=Probe.Page.Panels[0].Bounds;
    if Mode=2 then Original:=Probe.FRenderer.ImageBounds(Project,Probe.Page.Panels[0]);
    P:=Original.CenterPoint; if Handle>0 then P:=EditHandles(Original)[Handle-1];
    X:=Probe.FPageRect.Left+Round(P.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(P.Y*Probe.FScale);
    Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y);
    // この回帰は意図した移動の吸着を扱うため、長押し済みとして微調整も有効にする。
    if Handle=0 then Probe.FDragStartedTick:=GetTickCount64-ComicMoveHoldMilliseconds;
    Check(Probe.FDragging and (Probe.FDragHandle=Handle),'image layout starts mode '+IntToStr(Mode)+' handle '+IntToStr(Handle));
  end;
  procedure Move(DX,DY: Double; Alt: Boolean=False);
  begin
    TX:=X+Round(DX*Probe.FScale); TY:=Y+Round(DY*Probe.FScale);
    if Alt then Probe.MouseMove(Probe.FCanvas,[ssLeft,ssAlt],TX,TY)
    else Probe.MouseMove(Probe.FCanvas,[ssLeft],TX,TY);
  end;
  procedure Finish;
  begin Probe.MouseUp(Probe.FCanvas,mbLeft,[],TX,TY); end;
  procedure RoundTrip;
  begin
    Project.Save; Reloaded:=CreateFixtureProject;
    try Reloaded.Load(TPath.Combine(Project.Folder,'Project.json'));
      Check(Reloaded.Snapshot=Project.Snapshot,'image layout saves and reloads zoom pan and geometry');
    finally Reloaded.Free; end;
  end;
  procedure ImageSnapMath;
  var R,F,C: TRectF; Result: TComicImageSnap; Handle: Integer; Delta: TPointF;
  begin
    F:=TRectF.Create(100,100,700,600); R:=TRectF.Create(202,203,602,503);
    Result:=SnapImageBounds(R,R,F,0,8,0.1);
    Check(Result.HasX and Result.HasY and (Result.X=400) and (Result.Y=350) and
      SameRect(Result.Bounds,TRectF.Create(200,200,600,500)), 'image movement snaps its own center to panel center');
    for Handle:=1 to 8 do begin
      R:=TRectF.Create(200,200,600,500); Delta:=TPointF.Create(0,0);
      if Handle in [1,7,8] then Delta.X:=-98 else if Handle in [3,4,5] then Delta.X:=98;
      if Handle in [1,2,3] then Delta.Y:=-98 else if Handle in [5,6,7] then Delta.Y:=98;
      if Handle in [1,3,5,7] then begin Delta.X:=Sign(Delta.X)*96; Delta.Y:=Sign(Delta.Y)*72; end;
      C:=ResizeImageRect(R,Delta,Handle,0.1); Result:=SnapImageBounds(R,C,F,Handle,8,0.1);
      Check((Result.HasX or Result.HasY) and (Abs(Result.Bounds.Width/Result.Bounds.Height-R.Width/R.Height)<0.0001),
        'image resize preserves ratio while snapping handle '+IntToStr(Handle));
      Check(((not (Handle in [1,7,8])) or (Result.Bounds.Right=R.Right)) and
        ((not (Handle in [3,4,5])) or (Result.Bounds.Left=R.Left)) and
        ((not (Handle in [1,2,3])) or (Result.Bounds.Bottom=R.Bottom)) and
        ((not (Handle in [5,6,7])) or (Result.Bounds.Top=R.Top)), 'image snap keeps opposite resize anchor '+IntToStr(Handle));
    end;
    R:=TRectF.Create(102,103,902,803); Result:=SnapImageBounds(R,R,F,0,8,0.1);
    Check(Result.HasX and Result.HasY and (Result.Bounds.Left=100) and (Result.Bounds.Top=100), 'image left and top snap to corresponding panel edges');
    R:=TRectF.Create(-102,-103,698,597); Result:=SnapImageBounds(R,R,F,0,8,0.1);
    Check(Result.HasX and Result.HasY and (Result.Bounds.Right=700) and (Result.Bounds.Bottom=600), 'image right and bottom snap to corresponding panel edges');
    R:=TRectF.Create(220,220,520,420); Result:=SnapImageBounds(R,R,F,0,8,0.1);
    Check(not Result.HasX and not Result.HasY and (Result.Bounds=R), 'image outside tolerance has no guides or correction');
    R:=TRectF.Create(100,100,500,400); C:=ResizeImageRect(R,TPointF.Create(196,147),5,0.1);
    Result:=SnapImageBounds(R,C,F,5,8,0.1);
    Check(Result.HasX and (Result.X=400) and (Result.Bounds.CenterPoint.X=400),'image resizing can align its moving center');
    R:=TRectF.Create(100,100,1100,1100); C:=ResizeImageRect(R,TPointF.Create(-999,-999),5,0.1);
    Result:=SnapImageBounds(R,C,TRectF.Create(100,100,195,195),5,8,0.1);
    Check((Result.Bounds.Width>=100) and not Result.HasX and not Result.HasY,'image snapping cannot cross minimum zoom');
  end;
begin
  Base:=FProject.Snapshot; ImageSnapMath; Probe:=TComicTestForm.Create(nil);
  try
    Project:=CreateFixtureProject; Project.Initialize('画像レイアウト回帰','1'); Probe.AdoptProject(Project,False);
    ImageID:=Project.ImportImage(TPath.Combine(TestFolder,'reference.bmp'),'').ID;
    Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(300,400,700,800); Panel.ImageID:=ImageID;
    Panel.Zoom:=1.7; Panel.PanX:=37; Panel.PanY:=-23; Probe.Page.Panels.Add(Panel);
    Probe.RefreshUI; Probe.FSnap.Checked:=False;
    for Shape:=0 to 3 do begin
      Panel:=Probe.Page.Panels[0]; Panel.Shape:=Shape;
      if Shape=3 then Panel.SetVertices([TPointF.Create(300,400),TPointF.Create(700,400),TPointF.Create(700,800),TPointF.Create(300,800)]);
      Before:=Project.Snapshot;
      for ZoomLevel:=1 to 2 do begin
        Probe.FViewZoom:=ZoomLevel;
        for K:=1 to 8 do for Direction:=0 to 1 do begin
          Image:=Probe.FRenderer.ImageBounds(Project,Probe.Page.Panels[0]); Start(1,K);
          Move((Direction*2-1)*40,(Direction*2-1)*35); Finish;
          Actual:=Probe.FRenderer.ImageBounds(Project,Probe.Page.Panels[0]);
          Check(SameRect(Image,Actual) and (Probe.Page.Panels[0].Bounds<>Original),
            Format('frame resize keeps image page position and manual scale shape %d zoom %d handle %d direction %d',[Shape,ZoomLevel,K,Direction]));
          After:=Project.Snapshot; Probe.Undo(nil); Check(Project.Snapshot=Before,'frame resize undo restores exact image and panel');
          Probe.Redo(nil); Check(Project.Snapshot=After,'frame resize redo restores exact image and panel'); Probe.Undo(nil);
        end;
      end;
      Start(1,5); Image:=Probe.FRenderer.ImageBounds(Project,Probe.Page.Panels[0]); Move(-1000,-1000); Finish;
      Check((Probe.Page.Panels[0].Bounds.Width>=30) and (Probe.Page.Panels[0].Bounds.Height>=30) and
        SameRect(Image,Probe.FRenderer.ImageBounds(Project,Probe.Page.Panels[0])),'minimum frame resize keeps image scale'); RoundTrip; Probe.Undo(nil);
    end;
    Probe.Page.Panels[0].Shape:=0; Probe.Page.Panels[0].Vertices:=nil;
    Probe.FSnap.Checked:=True; Before:=Project.Snapshot;
    for ZoomLevel:=1 to 2 do begin
      Probe.FViewZoom:=ZoomLevel; Start(2,0); Frame:=Probe.Page.Panels[0].Bounds;
      Move(Frame.CenterPoint.X-Original.CenterPoint.X+2/Probe.FScale,Frame.CenterPoint.Y-Original.CenterPoint.Y+2/Probe.FScale);
      Actual:=Probe.FRenderer.ImageBounds(Project,Probe.Page.Panels[0]);
      Check(Probe.FImageSnap.HasX and Probe.FImageSnap.HasY and (Abs(Actual.CenterPoint.X-Frame.CenterPoint.X)<0.002) and
        (Abs(Actual.CenterPoint.Y-Frame.CenterPoint.Y)<0.002),'VCL image movement snaps both centers at view zoom '+IntToStr(ZoomLevel));
      PaintProbe; B.SaveToFile(TPath.Combine(TestFolder,'image-snap-guide-'+IntToStr(ZoomLevel)+'.bmp'));
      Finish; Check(not Probe.FImageSnap.HasX and not Probe.FImageSnap.HasY,'mouse release clears image snap guides');
      RoundTrip; After:=Project.Snapshot; Probe.Undo(nil); Check(Project.Snapshot=Before,'snapped image undo restores manual zoom and pan');
      Probe.Redo(nil); Check(Project.Snapshot=After,'snapped image redo restores alignment'); Probe.Undo(nil);
      for I:=0 to 1 do begin
        Probe.FSnap.Checked:=I=0; Start(2,0);
        Move(Frame.CenterPoint.X-Original.CenterPoint.X+3/Probe.FScale,Frame.CenterPoint.Y-Original.CenterPoint.Y+3/Probe.FScale,I=0);
        Check(not Probe.FImageSnap.HasX and not Probe.FImageSnap.HasY and
          (Abs(Probe.FRenderer.ImageBounds(Project,Probe.Page.Panels[0]).CenterPoint.X-Frame.CenterPoint.X)>1), 'Alt or shared checkbox bypasses image snap');
        Probe.CancelDrag; Check(Project.Snapshot=Before,'cancel restores image placement');
      end;
      Probe.FSnap.Checked:=True;
    end;
    // 右端の吸着だけを試す。上下端の方が近い候補になる画像配置との競合を避ける。
    Probe.Page.Panels[0].PanY:=0; Before:=Project.Snapshot;
    Start(2,4); Frame:=Probe.Page.Panels[0].Bounds;
    Move(Frame.Right-Original.Right+2/Probe.FScale,0);
    Actual:=Probe.FRenderer.ImageBounds(Project,Probe.Page.Panels[0]);
    Check(Probe.FImageSnap.HasX and (Probe.FImageSnap.X=Frame.Right) and (Abs(Actual.Right-Frame.Right)<0.002) and
      (Abs(Actual.Width/Actual.Height-Original.Width/Original.Height)<0.0001), 'VCL image resize snaps panel edge without distorting image');
    Probe.ImageSelectionChanged(nil);
    Check(not Probe.FDragging and not Probe.FImageSnap.HasX and not Probe.FImageSnap.HasY and
      (Project.Snapshot=Before),'image selection change cancels drag and clears guides');
    // 複数選択でも各画像の絶対位置を保ち、枠の移動操作では従来どおり画像を連れて移動する。
    Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(760,400,1000,800); Panel.ImageID:=ImageID; Panel.Zoom:=1.3; Probe.Page.Panels.Add(Panel);
    Image:=Probe.FRenderer.ImageBounds(Project,Probe.Page.Panels[0]); OtherImage:=Probe.FRenderer.ImageBounds(Project,Panel);
    Probe.FTabs.ActivePageIndex:=1; Probe.TabChanged(nil); Probe.SelectSinglePanel(0); Probe.FSelectedPanels.Add(Panel.ID); PaintProbe;
    P:=EditHandles(Probe.SelectedPanelBounds)[4]; X:=Probe.FPageRect.Left+Round(P.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(P.Y*Probe.FScale);
    Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y); Move(55,35); Finish;
    Check(SameRect(Image,Probe.FRenderer.ImageBounds(Project,Probe.Page.Panels[0])) and
      SameRect(OtherImage,Probe.FRenderer.ImageBounds(Project,Probe.Page.Panels[1])),'group resize preserves every assigned image'); Probe.Undo(nil);
    Start(1,0); Image:=Probe.FRenderer.ImageBounds(Project,Probe.Page.Panels[0]); Move(45,27,True);
    P:=Probe.ToPage(TX,TY)-Probe.FStart; Image.Offset(P.X,P.Y); Finish;
    Check(SameRect(Image,Probe.FRenderer.ImageBounds(Project,Probe.Page.Panels[0])),'moving the panel still carries its assigned image'); Probe.Undo(nil);
    Check(FProject.Snapshot=Base,'image layout regression preserves host project');
  finally Probe.Free; end;
end;
procedure RunImageLayoutChecks(Host: TComicTestForm);
begin Host.ImageLayoutChecks; end;
end.
