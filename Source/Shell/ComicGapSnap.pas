unit ComicGapSnap;

interface

uses System.Types, System.Generics.Collections, ComicModel;

type
  TComicGapSnap = record
    Point: TPointF;
    HasX,HasY: Boolean;
  end;

function FindGapSnap(Panels: TObjectList<TComicPanel>; const P: TPointF; Tolerance: Double; const ExcludeID: string): TComicGapSnap;

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
    // For each axis, measure only the nearest neighbour with an overlapping span.
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

end.
