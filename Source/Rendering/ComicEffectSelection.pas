unit ComicEffectSelection;

// 責務：効果素材の回転した選択枠と、線・丸・曲線矢印の回転ハンドルを編集画面へ重ねる。
interface
uses System.Types, Vcl.Graphics;
procedure DrawEffectSelection(Canvas: TCanvas; const Bounds: TRectF; Angle: Double;
  const Origin: TPoint; Scale: Double; PPI: Integer);
implementation
uses Winapi.Windows, System.Math, ComicOverlayTransform;
procedure DrawEffectSelection(Canvas: TCanvas; const Bounds: TRectF; Angle: Double;
  const Origin: TPoint; Scale: Double; PPI: Integer);
var Points: TArray<TPointF>; P,H: TPoint; Corners: array[0..4] of TPoint;
  I,Saved,Radius,Size,Arrow: Integer;
  function Map(const P: TPointF): TPoint;
  begin Result:=Point(Origin.X+Round(P.X*Scale),Origin.Y+Round(P.Y*Scale)); end;
begin
  if Bounds.IsEmpty then Exit; Saved:=SaveDC(Canvas.Handle);
  try
    Points:=OverlayEditHandles(Bounds,Angle);
    for I:=0 to 3 do Corners[I]:=Map(Points[I*2]); Corners[4]:=Corners[0];
    Canvas.Pen.Color:=$E5B45B; Canvas.Pen.Width:=Max(1,MulDiv(2,PPI,96)); Canvas.Brush.Style:=bsClear;
    Winapi.Windows.Polyline(Canvas.Handle,Corners[0],Length(Corners));
    Canvas.Brush.Style:=bsSolid; Canvas.Brush.Color:=$E5B45B; Size:=Max(3,MulDiv(4,PPI,96));
    for I:=0 to High(Points) do begin P:=Map(Points[I]); Canvas.FillRect(Rect(P.X-Size,P.Y-Size,P.X+Size+1,P.Y+Size+1)); end;
    H:=Map(OverlayRotationHandle(Bounds,Angle,Scale,PPI)); P:=Map(Points[1]);
    Canvas.MoveTo(P.X,P.Y); Canvas.LineTo(H.X,H.Y);
    Radius:=Max(5,MulDiv(7,PPI,96)); Canvas.Brush.Color:=$302B28;
    Canvas.Ellipse(H.X-Radius,H.Y-Radius,H.X+Radius+1,H.Y+Radius+1);
    // 外周の曲線矢印も一定の画面サイズにし、表示倍率によって操作しにくくならないようにする。
    Radius:=MulDiv(12,PPI,96); Arrow:=Max(3,MulDiv(4,PPI,96)); Canvas.Brush.Style:=bsClear;
    SetArcDirection(Canvas.Handle,AD_CLOCKWISE);
    Arc(Canvas.Handle,H.X-Radius,H.Y-Radius,H.X+Radius+1,H.Y+Radius+1,
      H.X+Radius,H.Y,H.X,H.Y-Radius);
    Canvas.MoveTo(H.X,H.Y-Radius); Canvas.LineTo(H.X-Arrow,H.Y-Radius-Arrow);
    Canvas.MoveTo(H.X,H.Y-Radius); Canvas.LineTo(H.X-Arrow,H.Y-Radius+Arrow);
  finally RestoreDC(Canvas.Handle,Saved); Canvas.Refresh; end;
end;
end.
