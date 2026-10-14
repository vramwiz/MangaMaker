unit ComicGapSnap;

// 責務：静止した近隣コマから再利用できる間隔を測り、選択中のコマを吸着先から除外する。

interface

uses System.Types, System.Generics.Collections, ComicModel;

type
  TComicGapSnap = record
    Point: TPointF;
    HasX,HasY: Boolean;
  end;

function FindGapSnap(Panels: TObjectList<TComicPanel>; const P: TPointF; Tolerance: Double; const ExcludeID: string): TComicGapSnap;

function SnapPanelBounds(Panels: TObjectList<TComicPanel>; const Bounds,Frame: TRectF;
  Tolerance: Double; Handle: Integer; const ExcludedIDs: TArray<string>;
  MinimumWidth,MinimumHeight: Double): TRectF;

implementation

uses System.Math;

function FindGapSnap(Panels: TObjectList<TComicPanel>; const P: TPointF; Tolerance: Double; const ExcludeID: string): TComicGapSnap;
var Horizontal,Vertical: TList<Single>; A,B: TComicPanel; Gap,RightGap,BottomGap,BestX,BestY,Distance: Double;
  function Eligible(Panel: TComicPanel): Boolean;
  begin Result:=(Panel.ID<>ExcludeID) and (Panel.Shape<>3); end;
  procedure CandidateX(X: Single);
  begin Distance:=Abs(Double(P.X)-X); if (Distance<=Tolerance) and ((Distance<BestX) or ((Distance=BestX) and (X<Result.Point.X))) then
    begin BestX:=Distance; Result.Point.X:=X; Result.HasX:=True; end; end;
  procedure CandidateY(Y: Single);
  begin Distance:=Abs(Double(P.Y)-Y); if (Distance<=Tolerance) and ((Distance<BestY) or ((Distance=BestY) and (Y<Result.Point.Y))) then
    begin BestY:=Distance; Result.Point.Y:=Y; Result.HasY:=True; end; end;
begin
  Result:=Default(TComicGapSnap); Result.Point:=P; BestX:=Tolerance+1; BestY:=Tolerance+1;
  Horizontal:=TList<Single>.Create; Vertical:=TList<Single>.Create;
  try
    // 重なる範囲を持つ最も近い隣だけを測り、無関係な遠いコマの隙間へ吸着させない。
    for A in Panels do if Eligible(A) then begin
      RightGap:=Infinity; BottomGap:=Infinity;
      for B in Panels do if (A<>B) and Eligible(B) then begin
        Gap:=B.Bounds.Left-A.Bounds.Right;
        if (Gap>0.01) and (Min(A.Bounds.Bottom,B.Bounds.Bottom)>Max(A.Bounds.Top,B.Bounds.Top)) then RightGap:=Min(RightGap,Gap);
        Gap:=B.Bounds.Top-A.Bounds.Bottom;
        if (Gap>0.01) and (Min(A.Bounds.Right,B.Bounds.Right)>Max(A.Bounds.Left,B.Bounds.Left)) then BottomGap:=Min(BottomGap,Gap);
      end;
      if not IsInfinite(RightGap) and not Horizontal.Contains(RightGap) then Horizontal.Add(RightGap);
      if not IsInfinite(BottomGap) and not Vertical.Contains(BottomGap) then Vertical.Add(BottomGap);
    end;
    for A in Panels do if Eligible(A) then begin
      if (P.Y>=A.Bounds.Top-Tolerance) and (P.Y<=A.Bounds.Bottom+Tolerance) then
        for Gap in Horizontal do begin CandidateX(A.Bounds.Right+Gap); CandidateX(A.Bounds.Left-Gap); end;
      if (P.X>=A.Bounds.Left-Tolerance) and (P.X<=A.Bounds.Right+Tolerance) then
        for Gap in Vertical do begin CandidateY(A.Bounds.Bottom+Gap); CandidateY(A.Bounds.Top-Gap); end;
    end;
  finally Vertical.Free; Horizontal.Free; end;
end;

function SnapPanelBounds(Panels: TObjectList<TComicPanel>; const Bounds,Frame: TRectF;
  Tolerance: Double; Handle: Integer; const ExcludedIDs: TArray<string>;
  MinimumWidth,MinimumHeight: Double): TRectF;
var A,B: TComicPanel; Horizontal,Vertical: TList<Single>; Stationary: TList<TComicPanel>; Point: TPointF;
  Gap,RightGap,BottomGap,BestX,BestY,ShiftX,ShiftY: Double; PriorityX,PriorityY: Integer;
  function Selected(Panel: TComicPanel): Boolean;
  var ID: string;
  begin
    Result:=False; for ID in ExcludedIDs do if Panel.ID=ID then Exit(True);
  end;
  procedure CandidateX(Target,Anchor: Double; Priority: Integer);
  var Offset,Distance,Width: Double;
  begin
    Offset:=Target-Anchor; Distance:=Abs(Offset); Width:=Bounds.Width;
    if Handle in [1,7,8] then Width:=Width-Offset else if Handle in [3,4,5] then Width:=Width+Offset;
    if (Distance>Tolerance) or ((Handle<>0) and (Width<MinimumWidth-0.0001)) then Exit;
    if (Distance<BestX) or ((Distance=BestX) and ((Priority<PriorityX) or ((Priority=PriorityX) and (Offset<ShiftX)))) then begin
      BestX:=Distance; ShiftX:=Offset; PriorityX:=Priority;
    end;
  end;
  procedure CandidateY(Target,Anchor: Double; Priority: Integer);
  var Offset,Distance,Height: Double;
  begin
    Offset:=Target-Anchor; Distance:=Abs(Offset); Height:=Bounds.Height;
    if Handle in [1,2,3] then Height:=Height-Offset else if Handle in [5,6,7] then Height:=Height+Offset;
    if (Distance>Tolerance) or ((Handle<>0) and (Height<MinimumHeight-0.0001)) then Exit;
    if (Distance<BestY) or ((Distance=BestY) and ((Priority<PriorityY) or ((Priority=PriorityY) and (Offset<ShiftY)))) then begin
      BestY:=Distance; ShiftY:=Offset; PriorityY:=Priority;
    end;
  end;
  procedure Axis(X,Y: Double);
  begin
    if (Handle=0) or (Handle in [1,7,8]) then CandidateX(X,Bounds.Left,0);
    if (Handle=0) or (Handle in [3,4,5]) then CandidateX(X,Bounds.Right,0);
    if (Handle=0) or (Handle in [1,2,3]) then CandidateY(Y,Bounds.Top,0);
    if (Handle=0) or (Handle in [5,6,7]) then CandidateY(Y,Bounds.Bottom,0);
  end;
begin
  Result:=Bounds;
  if Bounds.IsEmpty or (Tolerance<0) or not (Handle in [0..8]) then Exit;
  BestX:=Tolerance+1; BestY:=Tolerance+1; ShiftX:=0; ShiftY:=0; PriorityX:=MaxInt; PriorityY:=MaxInt;
  Axis(Frame.Left,Frame.Top); Axis(Frame.Right,Frame.Bottom);
  Horizontal:=TList<Single>.Create; Vertical:=TList<Single>.Create; Stationary:=TList<TComicPanel>.Create;
  try
    for A in Panels do if not Selected(A) then Stationary.Add(A);
    for A in Stationary do begin
      Axis(A.Bounds.Left,A.Bounds.Top); Axis(A.Bounds.Right,A.Bounds.Bottom);
      if A.Shape=3 then for Point in A.Vertices do Axis(Point.X,Point.Y);
      // 静止した隣だけから間隔を測り、選択中のコマ同士で吸着先を変化させない。
      if A.Shape=3 then Continue;
      RightGap:=Infinity; BottomGap:=Infinity;
      for B in Stationary do if (A<>B) and (B.Shape<>3) then begin
        Gap:=B.Bounds.Left-A.Bounds.Right;
        if (Gap>0.01) and (Min(A.Bounds.Bottom,B.Bounds.Bottom)>Max(A.Bounds.Top,B.Bounds.Top)) then RightGap:=Min(RightGap,Gap);
        Gap:=B.Bounds.Top-A.Bounds.Bottom;
        if (Gap>0.01) and (Min(A.Bounds.Right,B.Bounds.Right)>Max(A.Bounds.Left,B.Bounds.Left)) then BottomGap:=Min(BottomGap,Gap);
      end;
      if not IsInfinite(RightGap) and not Horizontal.Contains(RightGap) then Horizontal.Add(RightGap);
      if not IsInfinite(BottomGap) and not Vertical.Contains(BottomGap) then Vertical.Add(BottomGap);
    end;
    for A in Stationary do if A.Shape<>3 then begin
      if Min(Bounds.Bottom,A.Bounds.Bottom)>Max(Bounds.Top,A.Bounds.Top) then
        for Gap in Horizontal do begin
          if (Handle=0) or (Handle in [1,7,8]) then CandidateX(A.Bounds.Right+Gap,Bounds.Left,1);
          if (Handle=0) or (Handle in [3,4,5]) then CandidateX(A.Bounds.Left-Gap,Bounds.Right,1);
        end;
      if Min(Bounds.Right,A.Bounds.Right)>Max(Bounds.Left,A.Bounds.Left) then
        for Gap in Vertical do begin
          if (Handle=0) or (Handle in [1,2,3]) then CandidateY(A.Bounds.Bottom+Gap,Bounds.Top,1);
          if (Handle=0) or (Handle in [5,6,7]) then CandidateY(A.Bounds.Top-Gap,Bounds.Bottom,1);
        end;
    end;
  finally Stationary.Free; Vertical.Free; Horizontal.Free; end;
  if Handle=0 then Result.Offset(ShiftX,ShiftY)
  else begin
    if Handle in [1,7,8] then Result.Left:=Result.Left+ShiftX;
    if Handle in [3,4,5] then Result.Right:=Result.Right+ShiftX;
    if Handle in [1,2,3] then Result.Top:=Result.Top+ShiftY;
    if Handle in [5,6,7] then Result.Bottom:=Result.Bottom+ShiftY;
  end;
end;

end.
