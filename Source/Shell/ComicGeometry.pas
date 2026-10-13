unit ComicGeometry;

interface

uses System.SysUtils, System.Types, System.Math, System.Generics.Collections;

function PolygonArea(const Points: TArray<TPointF>): Double;
function PolygonBounds(const Points: TArray<TPointF>): TRectF;
function ValidPolygon(const Points: TArray<TPointF>): Boolean;
function ConvexPolygon(const Points: TArray<TPointF>): Boolean;
function PolygonContains(const Points: TArray<TPointF>; const P: TPointF): Boolean;
function NearestEdgePoint(const Points: TArray<TPointF>; const P: TPointF; out Closest: TPointF): Double;
function BandEndpoints(const Points: TArray<TPointF>; const A,B,WidthPoint: TPointF;
  out C,D: TPointF): Boolean;
function SplitPolygonBand(const Points: TArray<TPointF>; const A,B,C: TPointF;
  out First,Second: TArray<TPointF>): Boolean;

implementation

const Epsilon=0.0001;

function Cross(const A,B,C: TPointF): Double;
begin Result:=(Double(B.X)-A.X)*(C.Y-A.Y)-(Double(B.Y)-A.Y)*(C.X-A.X); end;
function Distance(const A,B: TPointF): Double;
begin Result:=Hypot(Double(A.X)-B.X,Double(A.Y)-B.Y); end;
function OnSegment(const A,B,P: TPointF): Boolean;
begin
  Result:=(Abs(Cross(A,B,P))<Epsilon) and
    (P.X>=Min(A.X,B.X)-Epsilon) and (P.X<=Max(A.X,B.X)+Epsilon) and
    (P.Y>=Min(A.Y,B.Y)-Epsilon) and (P.Y<=Max(A.Y,B.Y)+Epsilon);
end;
function SegmentsTouch(const A,B,C,D: TPointF): Boolean;
var C1,C2,C3,C4: Double;
begin
  C1:=Cross(A,B,C); C2:=Cross(A,B,D); C3:=Cross(C,D,A); C4:=Cross(C,D,B);
  Result:=((C1*C2<0) and (C3*C4<0)) or OnSegment(A,B,C) or OnSegment(A,B,D) or OnSegment(C,D,A) or OnSegment(C,D,B);
end;
function PolygonArea(const Points: TArray<TPointF>): Double;
var I,J: Integer;
begin
  Result:=0; if Length(Points)<3 then Exit;
  J:=High(Points);
  for I:=0 to High(Points) do begin Result:=Result+Double(Points[J].X)*Points[I].Y-Double(Points[I].X)*Points[J].Y; J:=I; end;
  Result:=Abs(Result)/2;
end;
function PolygonBounds(const Points: TArray<TPointF>): TRectF;
var P: TPointF;
begin
  Result:=TRectF.Empty; if Length(Points)=0 then Exit;
  Result:=TRectF.Create(Points[0],Points[0]);
  for P in Points do begin Result.Left:=Min(Result.Left,P.X); Result.Top:=Min(Result.Top,P.Y);
    Result.Right:=Max(Result.Right,P.X); Result.Bottom:=Max(Result.Bottom,P.Y); end;
end;
function ValidPolygon(const Points: TArray<TPointF>): Boolean;
var I,J,N: Integer; P: TPointF;
begin
  Result:=False; N:=Length(Points); if (N<3) or (N>256) then Exit;
  for P in Points do if IsNan(P.X) or IsNan(P.Y) or IsInfinite(P.X) or IsInfinite(P.Y) or
    (Abs(P.X)>80000) or (Abs(P.Y)>80000) then Exit;
  if PolygonArea(Points)<1 then Exit;
  for I:=0 to N-1 do begin
    if Distance(Points[I],Points[(I+1) mod N])<Epsilon then Exit;
    if OnSegment(Points[I],Points[(I+1) mod N],Points[(I+2) mod N]) or
      OnSegment(Points[(I+1) mod N],Points[(I+2) mod N],Points[I]) then Exit;
    for J:=I+1 to N-1 do begin
      if (J=I+1) or ((I=0) and (J=N-1)) then Continue;
      if SegmentsTouch(Points[I],Points[(I+1) mod N],Points[J],Points[(J+1) mod N]) then Exit;
    end;
  end;
  Result:=True;
end;
function ConvexPolygon(const Points: TArray<TPointF>): Boolean;
var I,N,Sign: Integer; Value: Double;
begin
  Result:=False; if not ValidPolygon(Points) then Exit; N:=Length(Points); Sign:=0;
  for I:=0 to N-1 do begin
    Value:=Cross(Points[I],Points[(I+1) mod N],Points[(I+2) mod N]);
    if Abs(Value)<=Epsilon then Continue;
    if Sign=0 then begin if Value>0 then Sign:=1 else Sign:=-1; end
    else if Value*Sign<0 then Exit;
  end;
  Result:=Sign<>0;
end;
function PolygonContains(const Points: TArray<TPointF>; const P: TPointF): Boolean;
var I,J: Integer;
begin
  Result:=False; if Length(Points)<3 then Exit; J:=High(Points);
  for I:=0 to High(Points) do begin
    if OnSegment(Points[J],Points[I],P) then Exit(True);
    if ((Points[I].Y>P.Y)<>(Points[J].Y>P.Y)) and
      (P.X<(Double(Points[J].X)-Points[I].X)*(P.Y-Points[I].Y)/(Points[J].Y-Points[I].Y)+Points[I].X) then Result:=not Result;
    J:=I;
  end;
end;
function NearestEdgePoint(const Points: TArray<TPointF>; const P: TPointF; out Closest: TPointF): Double;
var I: Integer; A,B,Q: TPointF; T,LengthSquared,Dist: Double;
begin
  Result:=MaxDouble; Closest:=P;
  for I:=0 to High(Points) do begin
    A:=Points[I]; B:=Points[(I+1) mod Length(Points)]; LengthSquared:=Sqr(Double(B.X)-A.X)+Sqr(Double(B.Y)-A.Y);
    if LengthSquared<Epsilon then Continue;
    T:=EnsureRange(((Double(P.X)-A.X)*(B.X-A.X)+(Double(P.Y)-A.Y)*(B.Y-A.Y))/LengthSquared,0.0,1.0);
    Q:=TPointF.Create(A.X+(B.X-A.X)*T,A.Y+(B.Y-A.Y)*T); Dist:=Distance(P,Q);
    if Dist<Result then begin Result:=Dist; Closest:=Q; end;
  end;
end;
function Normal(const A,B: TPointF; out N: TPointF): Boolean;
var L: Double;
begin L:=Distance(A,B); Result:=L>1; if Result then N:=TPointF.Create(-(B.Y-A.Y)/L,(B.X-A.X)/L); end;
function SignedDistance(const P,A,N: TPointF): Double;
begin Result:=(Double(P.X)-A.X)*N.X+(Double(P.Y)-A.Y)*N.Y; end;
function BandEndpoints(const Points: TArray<TPointF>; const A,B,WidthPoint: TPointF; out C,D: TPointF): Boolean;
var N,U,V,Q: TPointF; Width,FU,FV,T: Double; I,K: Integer; Hits: TList<TPointF>; Duplicate: Boolean;
begin
  Result:=False; if not ConvexPolygon(Points) or not Normal(A,B,N) then Exit;
  Width:=SignedDistance(WidthPoint,A,N); if Abs(Width)<4 then Exit;
  Hits:=TList<TPointF>.Create;
  try
    for I:=0 to High(Points) do begin
      U:=Points[I]; V:=Points[(I+1) mod Length(Points)]; FU:=SignedDistance(U,A,N)-Width; FV:=SignedDistance(V,A,N)-Width;
      if Abs(FU)<Epsilon then Q:=U
      else if FU*FV<0 then begin T:=FU/(FU-FV); Q:=TPointF.Create(U.X+(V.X-U.X)*T,U.Y+(V.Y-U.Y)*T); end
      else Continue;
      Duplicate:=False; for K:=0 to Hits.Count-1 do if Distance(Q,Hits[K])<0.01 then Duplicate:=True;
      if not Duplicate then Hits.Add(Q);
    end;
    if Hits.Count<>2 then Exit;
    if Distance(WidthPoint,Hits[0])<=Distance(WidthPoint,Hits[1]) then begin C:=Hits[0]; D:=Hits[1]; end
    else begin C:=Hits[1]; D:=Hits[0]; end;
    Result:=Distance(C,D)>1;
  finally Hits.Free; end;
end;
function Clip(const Points: TArray<TPointF>; const A,N: TPointF; Offset: Double; Greater: Boolean): TArray<TPointF>;
var List: TList<TPointF>; Previous,Current,Q: TPointF; DP,DC,T: Double; InP,InC: Boolean;
  procedure Add(const P: TPointF);
  begin if (List.Count=0) or (Distance(List.Last,P)>0.001) then List.Add(P); end;
begin
  List:=TList<TPointF>.Create;
  try
    Previous:=Points[High(Points)]; DP:=SignedDistance(Previous,A,N)-Offset;
    if Greater then InP:=DP>=-Epsilon else InP:=DP<=Epsilon;
    for Current in Points do begin
      DC:=SignedDistance(Current,A,N)-Offset;
      if Greater then InC:=DC>=-Epsilon else InC:=DC<=Epsilon;
      if InP<>InC then begin
        T:=DP/(DP-DC); Q:=TPointF.Create(Previous.X+(Current.X-Previous.X)*T,Previous.Y+(Current.Y-Previous.Y)*T); Add(Q);
      end;
      if InC then Add(Current);
      Previous:=Current; DP:=DC; InP:=InC;
    end;
    if (List.Count>1) and (Distance(List[0],List.Last)<0.001) then List.Delete(List.Count-1);
    Result:=List.ToArray;
  finally List.Free; end;
end;
function SplitPolygonBand(const Points: TArray<TPointF>; const A,B,C: TPointF; out First,Second: TArray<TPointF>): Boolean;
var N,Closest: TPointF; Width: Double;
begin
  Result:=False; First:=nil; Second:=nil;
  if not ConvexPolygon(Points) or not Normal(A,B,N) then Exit;
  if (NearestEdgePoint(Points,A,Closest)>0.05) or (NearestEdgePoint(Points,B,Closest)>0.05) then Exit;
  Width:=SignedDistance(C,A,N); if Abs(Width)<4 then Exit;
  First:=Clip(Points,A,N,Min(0.0,Width),False); Second:=Clip(Points,A,N,Max(0.0,Width),True);
  Result:=ValidPolygon(First) and ValidPolygon(Second) and (PolygonArea(First)>=25) and (PolygonArea(Second)>=25);
  if not Result then begin First:=nil; Second:=nil; end;
end;

end.
