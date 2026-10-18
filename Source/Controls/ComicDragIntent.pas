unit ComicDragIntent;

// 責務：クリック時の短い手ぶれと意図した移動を、画面上の距離と押下時間で判別する。
interface
uses System.Types;
const
  ComicMoveHoldMilliseconds = 250;
  ComicMoveDistanceDIP = 6;
function ObjectMoveReady(const Start,Current: TPoint; Elapsed: UInt64; PPI: Integer): Boolean;
implementation
uses System.Math;
function ObjectMoveReady(const Start,Current: TPoint; Elapsed: UInt64; PPI: Integer): Boolean;
begin
  Result:=(Elapsed>=ComicMoveHoldMilliseconds) or
    (Hypot(Double(Current.X)-Start.X,Double(Current.Y)-Start.Y)>=ComicMoveDistanceDIP*Max(1,PPI)/96);
end;
end.
