unit ComicEditing;

interface

uses System.Types, System.Math;

function EditHandles(const R: TRectF): TArray<TPointF>;
function HitHandle(const R: TRectF; const P: TPointF; Tolerance: Single): Integer;
function ResizeRect(const R: TRectF; const Delta: TPointF; Handle: Integer; Minimum: Single): TRectF;
function ResizeImageRect(const R: TRectF; const Delta: TPointF; Handle: Integer; MinimumScale: Double): TRectF;

implementation

function EditHandles(const R: TRectF): TArray<TPointF>;
var X,Y: Single;
begin
  X:=(R.Left+R.Right)/2; Y:=(R.Top+R.Bottom)/2;
  Result:=[TPointF.Create(R.Left,R.Top),TPointF.Create(X,R.Top),TPointF.Create(R.Right,R.Top),
    TPointF.Create(R.Right,Y),TPointF.Create(R.Right,R.Bottom),TPointF.Create(X,R.Bottom),
    TPointF.Create(R.Left,R.Bottom),TPointF.Create(R.Left,Y)];
end;
function HitHandle(const R: TRectF; const P: TPointF; Tolerance: Single): Integer;
var Handles: TArray<TPointF>; I: Integer;
begin
  Result:=0; if R.IsEmpty then Exit; Handles:=EditHandles(R);
  for I:=0 to High(Handles) do
    if (Abs(P.X-Handles[I].X)<=Tolerance) and (Abs(P.Y-Handles[I].Y)<=Tolerance) then Exit(I+1);
end;
function ResizeRect(const R: TRectF; const Delta: TPointF; Handle: Integer; Minimum: Single): TRectF;
begin
  Result:=R;
  if Handle in [1,7,8] then Result.Left:=Min(R.Right-Minimum,R.Left+Delta.X);
  if Handle in [3,4,5] then Result.Right:=Max(R.Left+Minimum,R.Right+Delta.X);
  if Handle in [1,2,3] then Result.Top:=Min(R.Bottom-Minimum,R.Top+Delta.Y);
  if Handle in [5,6,7] then Result.Bottom:=Max(R.Top+Minimum,R.Bottom+Delta.Y);
end;
function ResizeImageRect(const R: TRectF; const Delta: TPointF; Handle: Integer; MinimumScale: Double): TRectF;
var W,H,Scale,X,Y: Double; Horizontal,Vertical: Integer;
begin
  Result:=R; if R.IsEmpty or not (Handle in [1..8]) then Exit;
  Horizontal:=0; Vertical:=0;
  if Handle in [1,7,8] then Horizontal:=-1;
  if Handle in [3,4,5] then Horizontal:=1;
  if Handle in [1,2,3] then Vertical:=-1;
  if Handle in [5,6,7] then Vertical:=1;
  W:=R.Width+Delta.X*Horizontal; H:=R.Height+Delta.Y*Vertical;
  if Horizontal=0 then Scale:=H/R.Height
  else if Vertical=0 then Scale:=W/R.Width
  else Scale:=(W*R.Width+H*R.Height)/(Sqr(R.Width)+Sqr(R.Height));
  Scale:=Max(MinimumScale,Scale); W:=R.Width*Scale; H:=R.Height*Scale;
  X:=(R.Left+R.Right-W)/2; Y:=(R.Top+R.Bottom-H)/2;
  if Horizontal<0 then X:=R.Right-W else if Horizontal>0 then X:=R.Left;
  if Vertical<0 then Y:=R.Bottom-H else if Vertical>0 then Y:=R.Top;
  Result:=TRectF.Create(X,Y,X+W,Y+H);
end;

end.
