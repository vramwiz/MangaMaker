unit ComicWorkspaceGeometry;

// 責務：コマの作成・頂点編集・帯分割を扱い、不正な形を確定させない。
interface
uses MangaMakerMainForm, System.Types, System.Classes, ComicModel;
procedure RunWorkspacePlacementDown(Form: TMainForm; const P: TPointF; Shift: TShiftState);
procedure RunWorkspacePlacementUp(Form: TMainForm; const P: TPointF; Shift: TShiftState);
function RunWorkspaceVertexHandles(Form: TMainForm; Panel: TComicPanel): TArray<TPointF>;
function RunWorkspaceHitVertex(Form: TMainForm; Panel: TComicPanel; const P: TPointF): Integer;
procedure RunWorkspaceEditVertexContext(Form: TMainForm; const P: TPointF);
procedure RunWorkspacePreservePanelImage(Form: TMainForm; Panel: TComicPanel; const Original: TRectF);
procedure RunWorkspaceResetGeometryInput(Form: TMainForm);
function RunWorkspaceSnapCreationPoint(Form: TMainForm; const P: TPointF; const ExcludePanelID: string): TPointF;
function RunWorkspaceSnapPanelDragBounds(Form: TMainForm; const Bounds: TRectF): TRectF;
function WorkspaceSnapTolerance(Form: TMainForm): Double;
procedure RunWorkspaceDrawImageSnapGuides(Form: TMainForm);
procedure RunWorkspacePolygonClick(Form: TMainForm; const P: TPointF);
procedure RunWorkspaceSplitClick(Form: TMainForm; const P: TPointF);
procedure RunWorkspaceCommitSplit(Form: TMainForm; Index: Integer);
implementation
uses Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, Winapi.Imm, System.SysUtils, System.UITypes, System.Math, System.IOUtils, System.Generics.Collections, System.JSON, System.Hash, System.DateUtils, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Menus, Vcl.Dialogs, Vcl.Graphics, Vcl.Imaging.pngimage, ComicGeometry, ComicEffects, ComicGapSnap;
type
  TComicWorkspaceGeometryHelper = class helper for TMainForm
    function ExecuteVertexHandles(Panel: TComicPanel): TArray<TPointF>;
    function ExecuteHitVertex(Panel: TComicPanel; const P: TPointF): Integer;
    procedure ExecuteEditVertexContext(const P: TPointF);
    procedure ExecutePreservePanelImage(Panel: TComicPanel; const Original: TRectF);
    procedure ExecuteResetGeometryInput;
    function ExecuteSnapCreationPoint(const P: TPointF; const ExcludePanelID: string): TPointF;
    function ExecuteSnapPanelDragBounds(const Bounds: TRectF): TRectF;
    procedure ExecutePolygonClick(const P: TPointF);
    procedure ExecuteSplitClick(const P: TPointF);
    procedure ExecuteCommitSplit(Index: Integer);
    function SnapTolerance: Double;
    procedure DrawImageSnapGuides;
    function PlacementPoint(const P: TPointF; Shift: TShiftState): TPointF;
    procedure CommitPlacement(const P: TPointF);
    procedure PlacementDown(const P: TPointF; Shift: TShiftState);
    procedure PlacementUp(const P: TPointF; Shift: TShiftState);
  end;
function TComicWorkspaceGeometryHelper.PlacementPoint(const P: TPointF; Shift: TShiftState): TPointF;
begin
  Result:=P; if (FTool in [1,2,3]) and not (ssAlt in Shift) then Result:=SnapCreationPoint(P);
end;
procedure TComicWorkspaceGeometryHelper.CommitPlacement(const P: TPointF);
var R: TRectF; Balloon: TComicBalloon; Panel: TComicPanel; OwnerIndex: Integer;
begin
  if Hypot(P.X-FStart.X,P.Y-FStart.Y)*FScale<MulDiv(6,CurrentPPI,96) then begin FFirst:=False; Exit; end;
  if FTool in [7,11] then begin TailClick(P); FFirst:=False; Exit; end;
  R:=TRectF.Create(Min(P.X,FStart.X),Min(P.Y,FStart.Y),Max(P.X,FStart.X),Max(P.Y,FStart.Y));
  FFirst:=False; if (R.Width<30) or (R.Height<30) then Exit;
  Checkpoint;
  if FTool in [1,2,3] then begin
    Panel:=TComicPanel.Create; Panel.Bounds:=R; Panel.Shape:=FTool-1; Panel.Number:=Page.Panels.Count+1;
    Page.Panels.Add(Panel); SelectSinglePanel(Page.Panels.Count-1);
  end else begin
    Balloon:=TComicBalloon.Create; Balloon.Bounds:=R; Balloon.Contour:=TComicBalloonContour(Max(0,FContour.ItemIndex));
    Balloon.FontFamily:=FLastFontFamily; Balloon.FontSize:=FFontHistory.LastSize;
    if FTool=10 then Balloon.Shape:=0 else Balloon.Shape:=FTool-4;
    OwnerIndex:=HitPanel(FStart); if OwnerIndex>=0 then Balloon.PanelID:=Page.Panels[OwnerIndex].ID;
    FPanelIndex:=-1;
    Page.Balloons.Add(Balloon); FBalloonIndex:=Page.Balloons.Count-1; LoadBalloonControls(Balloon);
  end;
  Changed;
end;
procedure TComicWorkspaceGeometryHelper.PlacementDown(const P: TPointF; Shift: TShiftState);
var Q: TPointF;
begin
  Q:=PlacementPoint(P,Shift);
  if FFirst then CommitPlacement(Q)
  else begin
    if FTool in [7,11] then TailClick(Q)
    else begin FStart:=Q; FLast:=Q; FFirst:=True; end;
    FPlacementDragging:=FDragPlacementMenu.Checked and FFirst;
    if FPlacementDragging and not FTesting then FCanvas.MouseCapture:=True;
    if FFirst then begin
      if FPlacementDragging then FStatus.SimpleText:='ドラッグして離すと配置。Escで取消。設定・管理で2点クリックへ切替。'
      else FStatus.SimpleText:='2点目をクリックして配置。Escで取消。設定・管理でドラッグへ切替。';
    end;
  end;
  FCanvas.Invalidate;
end;
procedure TComicWorkspaceGeometryHelper.PlacementUp(const P: TPointF; Shift: TShiftState);
begin
  if not FPlacementDragging then Exit;
  FPlacementDragging:=False; FCanvas.MouseCapture:=False;
  CommitPlacement(PlacementPoint(P,Shift)); FFirst:=False; FCanvas.Invalidate;
end;
procedure RunWorkspacePlacementDown(Form: TMainForm; const P: TPointF; Shift: TShiftState);
begin Form.PlacementDown(P,Shift); end;
procedure RunWorkspacePlacementUp(Form: TMainForm; const P: TPointF; Shift: TShiftState);
begin Form.PlacementUp(P,Shift); end;
function TComicWorkspaceGeometryHelper.SnapTolerance: Double;
begin Result:=MulDiv(8,CurrentPPI,96)/Max(FScale,0.001); end;
function WorkspaceSnapTolerance(Form: TMainForm): Double;
begin Result:=Form.SnapTolerance; end;

procedure TComicWorkspaceGeometryHelper.DrawImageSnapGuides;
var C: TCanvas; Frame,Image: TRectF; Saved,OldWidth: Integer; OldStyle: TPenStyle; OldColor: TColor;
  procedure Line(AX,AY,BX,BY: Single);
  begin
    C.MoveTo(FPageRect.Left+Round(AX*FScale),FPageRect.Top+Round(AY*FScale));
    C.LineTo(FPageRect.Left+Round(BX*FScale),FPageRect.Top+Round(BY*FScale));
  end;
begin
  if not FDragging or (FTabs.ActivePageIndex<>2) or not FSnap.Checked or
    (FPanelIndex<0) or (FPanelIndex>=Page.Panels.Count) or not (FImageSnap.HasX or FImageSnap.HasY) then Exit;
  Frame:=Page.Panels[FPanelIndex].Bounds; Image:=FImageSnap.Bounds;
  C:=FCanvas.Canvas; Saved:=SaveDC(C.Handle); OldWidth:=C.Pen.Width; OldStyle:=C.Pen.Style; OldColor:=C.Pen.Color;
  try
    // 編集キャンバスだけに描き、ページ外・サムネイル・PNG出力へガイドを残さない。
    IntersectClipRect(C.Handle,FPageRect.Left,FPageRect.Top,FPageRect.Right,FPageRect.Bottom);
    C.Pen.Color:=$E060E0; C.Pen.Width:=1; C.Pen.Style:=psDot;
    if FImageSnap.HasX then Line(FImageSnap.X,Min(Frame.Top,Image.Top),FImageSnap.X,Max(Frame.Bottom,Image.Bottom));
    if FImageSnap.HasY then Line(Min(Frame.Left,Image.Left),FImageSnap.Y,Max(Frame.Right,Image.Right),FImageSnap.Y);
  finally C.Pen.Color:=OldColor; C.Pen.Width:=OldWidth; C.Pen.Style:=OldStyle; RestoreDC(C.Handle,Saved); end;
end;
procedure RunWorkspaceDrawImageSnapGuides(Form: TMainForm);
begin Form.DrawImageSnapGuides; end;

function TComicWorkspaceGeometryHelper.ExecuteVertexHandles(Panel: TComicPanel): TArray<TPointF>;
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

function RunWorkspaceVertexHandles(Form: TMainForm; Panel: TComicPanel): TArray<TPointF>;
begin Result:=Form.ExecuteVertexHandles(Panel); end;
function TComicWorkspaceGeometryHelper.ExecuteHitVertex(Panel: TComicPanel; const P: TPointF): Integer;
var Points: TArray<TPointF>; I: Integer; Distance,Best: Double;
begin
  Result:=-1; Best:=MulDiv(7,CurrentPPI,96)/Max(FScale,0.001); Points:=VertexHandles(Panel);
  for I:=0 to High(Points) do begin
    Distance:=Hypot(Double(P.X)-Points[I].X,Double(P.Y)-Points[I].Y);
    if Distance<=Best then begin Best:=Distance; Result:=I; end;
  end;
end;

function RunWorkspaceHitVertex(Form: TMainForm; Panel: TComicPanel; const P: TPointF): Integer;
begin Result:=Form.ExecuteHitVertex(Panel,P); end;
procedure TComicWorkspaceGeometryHelper.ExecuteEditVertexContext(const P: TPointF);
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

procedure RunWorkspaceEditVertexContext(Form: TMainForm; const P: TPointF);
begin Form.ExecuteEditVertexContext(P); end;
procedure TComicWorkspaceGeometryHelper.ExecutePreservePanelImage(Panel: TComicPanel; const Original: TRectF);
var Current: TRectF;
begin
  if Original.IsEmpty then Exit;
  Current:=FRenderer.ImageBounds(FProject,Panel); if Current.IsEmpty then Exit;
  Panel.Zoom:=Panel.Zoom*Original.Width/Current.Width;
  Panel.PanX:=Original.CenterPoint.X-Panel.Bounds.CenterPoint.X;
  Panel.PanY:=Original.CenterPoint.Y-Panel.Bounds.CenterPoint.Y;
end;

procedure RunWorkspacePreservePanelImage(Form: TMainForm; Panel: TComicPanel; const Original: TRectF);
begin Form.ExecutePreservePanelImage(Panel,Original); end;
procedure TComicWorkspaceGeometryHelper.ExecuteResetGeometryInput;
begin
  if FGeometryPoints<>nil then FGeometryPoints.Clear;
  FSplitStage:=0; FSplitPanelID:='';
  FTailIndex:=-1; FDragTailHandle:=0;
end;

procedure RunWorkspaceResetGeometryInput(Form: TMainForm);
begin Form.ExecuteResetGeometryInput; end;
function TComicWorkspaceGeometryHelper.ExecuteSnapCreationPoint(const P: TPointF; const ExcludePanelID: string): TPointF;
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
  Tolerance:=SnapTolerance; DX:=Tolerance+1; DY:=Tolerance+1; Best:=Tolerance+1; BestEdge:=Tolerance+1;
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

function RunWorkspaceSnapCreationPoint(Form: TMainForm; const P: TPointF; const ExcludePanelID: string): TPointF;
begin Result:=Form.ExecuteSnapCreationPoint(P,ExcludePanelID); end;
function TComicWorkspaceGeometryHelper.ExecuteSnapPanelDragBounds(const Bounds: TRectF): TRectF;
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
  Result:=SnapPanelBounds(Page.Panels,Bounds,Frame,SnapTolerance,FDragHandle,IDs,MinimumWidth,MinimumHeight);
end;

function RunWorkspaceSnapPanelDragBounds(Form: TMainForm; const Bounds: TRectF): TRectF;
begin Result:=Form.ExecuteSnapPanelDragBounds(Bounds); end;
procedure TComicWorkspaceGeometryHelper.ExecutePolygonClick(const P: TPointF);
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

procedure RunWorkspacePolygonClick(Form: TMainForm; const P: TPointF);
begin Form.ExecutePolygonClick(P); end;
procedure TComicWorkspaceGeometryHelper.ExecuteSplitClick(const P: TPointF);
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

procedure RunWorkspaceSplitClick(Form: TMainForm; const P: TPointF);
begin Form.ExecuteSplitClick(P); end;
procedure TComicWorkspaceGeometryHelper.ExecuteCommitSplit(Index: Integer);
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

procedure RunWorkspaceCommitSplit(Form: TMainForm; Index: Integer);
begin Form.ExecuteCommitSplit(Index); end;
end.
