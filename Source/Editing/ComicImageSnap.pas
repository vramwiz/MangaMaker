unit ComicImageSnap;

// 責務：所属コマの端・中央への画像吸着を計算し、比率とリサイズの固定点を保つ。
interface
uses System.Types;
type
  TComicImageSnap = record
    Bounds: TRectF;
    HasX,HasY: Boolean;
    X,Y: Single;
  end;
function SnapImageBounds(const Original,Candidate,Frame: TRectF; Handle: Integer;
  Tolerance,MinimumScale: Double): TComicImageSnap;
implementation
uses System.Math, ComicEditing;

function SnapImageBounds(const Original,Candidate,Frame: TRectF; Handle: Integer;
  Tolerance,MinimumScale: Double): TComicImageSnap;
var BestX,BestY,BestScale,BestDistance,DX,DY: Double; H,V,K,Axis: Integer;
  Anchor,Offset,Target,Current,Distance,Scale: Double; Delta: TPointF;
  function Feature(const R: TRectF; Axis,Kind: Integer): Double;
  begin
    if Axis=0 then case Kind of
      0: Result:=R.CenterPoint.X; 1: Result:=R.Left; else Result:=R.Right;
    end else case Kind of
      0: Result:=R.CenterPoint.Y; 1: Result:=R.Top; else Result:=R.Bottom;
    end;
  end;
  function FixedAxis(Axis: Integer): Double;
  begin
    if Axis=0 then begin
      Result:=Original.CenterPoint.X;
      if H<0 then Result:=Original.Right else if H>0 then Result:=Original.Left;
    end else begin
      Result:=Original.CenterPoint.Y;
      if V<0 then Result:=Original.Bottom else if V>0 then Result:=Original.Top;
    end;
  end;
begin
  Result:=Default(TComicImageSnap); Result.Bounds:=Candidate;
  if Original.IsEmpty or Candidate.IsEmpty or Frame.IsEmpty then Exit;
  H:=0; V:=0;
  if Handle in [1,7,8] then H:=-1 else if Handle in [3,4,5] then H:=1;
  if Handle in [1,2,3] then V:=-1 else if Handle in [5,6,7] then V:=1;
  BestX:=Tolerance+1; BestY:=Tolerance+1; BestDistance:=Tolerance+1; BestScale:=0;
  DX:=0; DY:=0;
  // 同距離なら中央を優先する。端は同じ側同士を比較し、別コマへ吸着させない。
  for Axis:=0 to 1 do for K:=0 to 2 do begin
    Target:=Feature(Frame,Axis,K); Current:=Feature(Candidate,Axis,K); Distance:=Abs(Target-Current);
    if Distance>Tolerance then Continue;
    if Handle=0 then begin
      if (Axis=0) and (Distance<BestX) then begin BestX:=Distance; DX:=Target-Current; Result.HasX:=True; Result.X:=Target; end;
      if (Axis=1) and (Distance<BestY) then begin BestY:=Distance; DY:=Target-Current; Result.HasY:=True; Result.Y:=Target; end;
    end else begin
      Anchor:=FixedAxis(Axis); Offset:=Feature(Original,Axis,K)-Anchor;
      // 固定辺・固定された中央は吸着候補にせず、ドラッグで動く位置だけを補正する。
      if Abs(Offset)<0.000001 then Continue;
      Scale:=(Target-Anchor)/Offset;
      if (Scale>=MinimumScale) and (Distance<BestDistance) then begin BestDistance:=Distance; BestScale:=Scale; end;
    end;
  end;
  if Handle=0 then begin
    Result.Bounds.Offset(DX,DY);
  end else if BestScale>0 then begin
    Delta:=TPointF.Create(Original.Width*(BestScale-1)*H,Original.Height*(BestScale-1)*V);
    Result.Bounds:=ResizeImageRect(Original,Delta,Handle,MinimumScale);
    // 比率維持で同時に一致した軸だけを通知し、未吸着の軸にガイドを出さない。
    for Axis:=0 to 1 do for K:=0 to 2 do begin
      Target:=Feature(Frame,Axis,K);
      if (Abs(Feature(Original,Axis,K)-FixedAxis(Axis))<0.000001) or
        (Abs(Feature(Candidate,Axis,K)-Target)>Tolerance) or
        (Abs(Feature(Result.Bounds,Axis,K)-Target)>0.001) then Continue;
      if (Axis=0) and not Result.HasX then begin Result.HasX:=True; Result.X:=Target; end;
      if (Axis=1) and not Result.HasY then begin Result.HasY:=True; Result.Y:=Target; end;
    end;
  end;
end;
end.
