unit ComicOverlayTransform;

// 責務：効果素材の回転・編集点・当たり判定を共通化し、拡縮の反対側の固定点を保つ。
interface
uses System.Types;
function RotateOverlayPoint(const P,Center: TPointF; Degrees: Double): TPointF;
function NormalizeOverlayAngle(Degrees: Double): Double;
function OverlayEditHandles(const Bounds: TRectF; Angle: Double): TArray<TPointF>;
function OverlayRotationHandle(const Bounds: TRectF; Angle,Scale: Double; PPI: Integer): TPointF;
function HitOverlayHandle(const Bounds: TRectF; Angle: Double; const P: TPointF; Scale: Double; PPI: Integer): Integer;
function OverlayContains(const Bounds: TRectF; Angle: Double; const P: TPointF): Boolean;
function DragOverlayAngle(const Bounds: TRectF; InitialAngle: Double; const Start,Finish: TPointF; Snap: Boolean): Double;
function ResizeRotatedOverlay(const Bounds: TRectF; Angle: Double; const Delta: TPointF; Handle: Integer): TRectF;
implementation
uses System.Math, ComicEditing;
function RotateOverlayPoint(const P,Center: TPointF; Degrees: Double): TPointF;
var S,C,X,Y: Double;
begin
  SinCos(DegToRad(Degrees),S,C); X:=P.X-Center.X; Y:=P.Y-Center.Y;
  Result:=TPointF.Create(Center.X+X*C-Y*S,Center.Y+X*S+Y*C);
end;
function NormalizeOverlayAngle(Degrees: Double): Double;
begin Result:=Degrees-360*Floor((Degrees+180)/360); end;
function OverlayEditHandles(const Bounds: TRectF; Angle: Double): TArray<TPointF>;
var I: Integer;
begin
  Result:=EditHandles(Bounds);
  for I:=0 to High(Result) do Result[I]:=RotateOverlayPoint(Result[I],Bounds.CenterPoint,Angle);
end;
function OverlayRotationHandle(const Bounds: TRectF; Angle,Scale: Double; PPI: Integer): TPointF;
begin
  Result:=RotateOverlayPoint(TPointF.Create(Bounds.CenterPoint.X,Bounds.Top-36*PPI/96/Max(0.001,Scale)),Bounds.CenterPoint,Angle);
end;
function HitOverlayHandle(const Bounds: TRectF; Angle: Double; const P: TPointF; Scale: Double; PPI: Integer): Integer;
var Points: TArray<TPointF>; I: Integer; Distance,Best: Double;
begin
  Result:=0; if Bounds.IsEmpty then Exit;
  if P.Distance(OverlayRotationHandle(Bounds,Angle,Scale,PPI))*Scale<=18*PPI/96 then Exit(9);
  Points:=OverlayEditHandles(Bounds,Angle); Best:=9*PPI/96/Max(0.001,Scale);
  for I:=0 to High(Points) do begin
    Distance:=P.Distance(Points[I]); if Distance<=Best then begin Result:=I+1; Best:=Distance; end;
  end;
end;
function OverlayContains(const Bounds: TRectF; Angle: Double; const P: TPointF): Boolean;
begin Result:=Bounds.Contains(RotateOverlayPoint(P,Bounds.CenterPoint,-Angle)); end;
function DragOverlayAngle(const Bounds: TRectF; InitialAngle: Double; const Start,Finish: TPointF; Snap: Boolean): Double;
var A,B: TPointF;
begin
  Result:=InitialAngle; A:=Start-Bounds.CenterPoint; B:=Finish-Bounds.CenterPoint;
  if (A.Distance(TPointF.Zero)<0.001) or (B.Distance(TPointF.Zero)<0.001) then Exit;
  Result:=InitialAngle+RadToDeg(ArcTan2(B.Y,B.X)-ArcTan2(A.Y,A.X));
  if Snap then Result:=Round(Result/15)*15;
  Result:=NormalizeOverlayAngle(Result);
end;
function ResizeRotatedOverlay(const Bounds: TRectF; Angle: Double; const Delta: TPointF; Handle: Integer): TRectF;
var Local,Center: TPointF;
begin
  Local:=RotateOverlayPoint(Delta,TPointF.Zero,-Angle);
  Result:=ResizeImageRect(Bounds,Local,Handle,0.01);
  Center:=RotateOverlayPoint(Result.CenterPoint,Bounds.CenterPoint,Angle);
  Result.Offset(Center.X-Result.CenterPoint.X,Center.Y-Result.CenterPoint.Y);
end;
end.
