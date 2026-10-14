unit ComicTextLayout;

interface

uses System.Types, System.Generics.Collections, Vcl.Graphics;

type
  TComicCaretStop = record
    Index,Line: Integer;
    Point: TPoint;
  end;
  TComicTextCell = record
    Index,Count,Line: Integer;
    Bounds: TRect;
    Rotate,TateChuYoko: Boolean;
  end;

  TComicTextLayout = class
  public
    Stops: TList<TComicCaretStop>;
    Cells: TList<TComicTextCell>;
    Step,LineCount: Integer;
    constructor Create;
    destructor Destroy; override;
    procedure Build(Canvas: TCanvas; const Text: string; const Area: TRect; Vertical: Boolean);
    function CaretStop(Index: Integer; Line: Integer=-1): TComicCaretStop;
    function HitTest(const P: TPoint; Vertical: Boolean): TComicCaretStop;
    function AtLine(Line,Along: Integer; Vertical: Boolean): TComicCaretStop;
    function Bounds: TRect;
    procedure Translate(DX,DY: Integer);
    procedure CenterIn(const Area: TRect);
  end;

procedure DrawComicTextCell(Canvas: TCanvas; const Text: string;
  const Cell: TComicTextCell; const Bounds: TRect; Vertical: Boolean);

implementation

uses Winapi.Windows, System.Math, System.SysUtils, ComicTextUnits
  {$IFDEF DEBUG}, ComicPerformance{$ENDIF};

function Opening(const Text: string): Boolean;
begin Result:=(Length(Text)=1) and (Pos(Text,'（［｛〔〈《「『【(')>0); end;
function Closing(const Text: string): Boolean;
begin Result:=(Length(Text)=1) and (Pos(Text,'、。，．）］｝〕〉》」』】！？ぁぃぅぇぉっゃゅょゎァィゥェォッャュョヮヵヶ)>')>0); end;
function Sideways(const Text: string): Boolean;
begin
  Result:=(Length(Text)=1) and (((Ord(Text[1])>=33) and (Ord(Text[1])<=126) and
    not CharInSet(Text[1],['0'..'9'])) or (Pos(Text,'ー―—…‥（［｛〔〈《「『【）］｝〕〉》」』】')>0));
end;

procedure DrawComicTextCell(Canvas: TCanvas; const Text: string;
  const Cell: TComicTextCell; const Bounds: TRect; Vertical: Boolean);
{$IFDEF DEBUG}var PerfScope: TComicPerfScope;{$ENDIF}
var X,Y,W,H,Saved: Integer; Transform: TXForm; Value: string;
begin
  {$IFDEF DEBUG}PerfScope.Start(cpTextDraw);{$ENDIF}
  Value:=Copy(Text,Cell.Index+1,Cell.Count); if Value='' then Exit;
  W:=Canvas.TextWidth(Value); H:=Canvas.TextHeight(Value);
  SetBkMode(Canvas.Handle,TRANSPARENT);
  if not Vertical then begin TextOutW(Canvas.Handle,Bounds.Left,Bounds.Top,PChar(Value),Length(Value)); Exit; end;
  X:=Bounds.Left+(Bounds.Width-W) div 2; Y:=Bounds.Top+(Bounds.Height-H) div 2;
  if Cell.Rotate then begin
    Saved:=SaveDC(Canvas.Handle);
    try
      SetGraphicsMode(Canvas.Handle,GM_ADVANCED); Transform:=Default(TXForm);
      Transform.eM12:=1; Transform.eM21:=-1;
      Transform.eDx:=Bounds.Left+(Bounds.Width+H)/2; Transform.eDy:=Bounds.Top+(Bounds.Height-W)/2;
      if not ModifyWorldTransform(Canvas.Handle,Transform,MWT_LEFTMULTIPLY) then RaiseLastOSError;
      TextOutW(Canvas.Handle,0,0,PChar(Value),Length(Value));
    finally RestoreDC(Canvas.Handle,Saved); end;
  end else begin
    if (Value='、') or (Value='。') or (Value='，') or (Value='．') then begin
      Inc(X,Bounds.Width div 2); Dec(Y,Bounds.Height div 2);
    end else if (Length(Value)=1) and (Pos(Value,'ぁぃぅぇぉっゃゅょゎァィゥェォッャュョヮヵヶ')>0) then begin
      Inc(X,Bounds.Width div 8); Dec(Y,Bounds.Height div 8);
    end;
    if not TextOutW(Canvas.Handle,X,Y,PChar(Value),Length(Value)) then RaiseLastOSError;
  end;
end;

constructor TComicTextLayout.Create;
begin inherited; Stops:=TList<TComicCaretStop>.Create; Cells:=TList<TComicTextCell>.Create; end;
destructor TComicTextLayout.Destroy;
begin Cells.Free; Stops.Free; inherited; end;
function TComicTextLayout.Bounds: TRect;
var Cell: TComicTextCell;
begin
  Result:=TRect.Empty; if Cells.Count=0 then Exit; Result:=Cells[0].Bounds;
  for Cell in Cells do begin Result.Left:=Min(Result.Left,Cell.Bounds.Left); Result.Top:=Min(Result.Top,Cell.Bounds.Top);
    Result.Right:=Max(Result.Right,Cell.Bounds.Right); Result.Bottom:=Max(Result.Bottom,Cell.Bounds.Bottom); end;
end;
procedure TComicTextLayout.Translate(DX,DY: Integer);
var I: Integer; Cell: TComicTextCell; Stop: TComicCaretStop;
begin
  for I:=0 to Cells.Count-1 do begin Cell:=Cells[I]; Cell.Bounds.Offset(DX,DY); Cells[I]:=Cell; end;
  for I:=0 to Stops.Count-1 do begin Stop:=Stops[I]; Stop.Point.Offset(DX,DY); Stops[I]:=Stop; end;
end;
procedure TComicTextLayout.CenterIn(const Area: TRect);
var TextBounds: TRect;
begin
  TextBounds:=Bounds; if TextBounds.IsEmpty then Exit;
  Translate((Area.Left+Area.Right-TextBounds.Left-TextBounds.Right) div 2,
    (Area.Top+Area.Bottom-TextBounds.Top-TextBounds.Bottom) div 2);
end;

procedure TComicTextLayout.Build(Canvas: TCanvas; const Text: string; const Area: TRect; Vertical: Boolean);
{$IFDEF DEBUG}var PerfScope: TComicPerfScope;{$ENDIF}
var At,Count,X,Y,W,Line,NextCount,NextW: Integer; Cell: TComicTextCell; Stop: TComicCaretStop; Value,Next: string;
  procedure AddStop(Index: Integer);
  begin Stop.Index:=Index; Stop.Line:=Line; Stop.Point:=Point(X,Y); Stops.Add(Stop); end;
  procedure NextLine;
  begin
    Inc(Line);
    if Vertical then begin Dec(X,Step); Y:=Area.Top; end else begin X:=Area.Left; Inc(Y,Step); end;
  end;
begin
  {$IFDEF DEBUG}PerfScope.Start(cpTextLayout);{$ENDIF}
  Stops.Clear; Cells.Clear; Step:=Max(8,Canvas.TextHeight('漢')+4); Line:=0;
  X:=Area.Left; if Vertical then X:=Area.Right-Step;
  Y:=Area.Top; AddStop(0); At:=0;
  while At<Length(Text) do begin
    Count:=ComicTextUnitLength(Text,At+1);
    Cell.TateChuYoko:=False; Value:=Copy(Text,At+1,Count);
    if Vertical and (Count=1) and CharInSet(Text[At+1],['0'..'9']) and
      ((At=0) or not CharInSet(Text[At],['0'..'9'])) then begin
      if (At+1<Length(Text)) and CharInSet(Text[At+2],['0'..'9']) and
        ((At+2=Length(Text)) or not CharInSet(Text[At+3],['0'..'9'])) then begin Count:=2; Value:=Copy(Text,At+1,Count); end;
      Cell.TateChuYoko:=Count=2;
    end;
    if CharInSet(Text[At+1],[#13,#10]) then NextLine
    else begin
      if Vertical then W:=Step else W:=Max(2,Canvas.TextWidth(Copy(Text,At+1,Count)));
      NextW:=0;
      if Opening(Value) and (At+Count<Length(Text)) then begin
        NextCount:=ComicTextUnitLength(Text,At+Count+1); Next:=Copy(Text,At+Count+1,NextCount);
        if not CharInSet(Next[1],[#13,#10]) then if Vertical then NextW:=Step else NextW:=Canvas.TextWidth(Next);
      end;
      if ((not Vertical and (X>Area.Left) and (X+W+NextW>Area.Right)) or
        (Vertical and (Y>Area.Top) and (Y+Step+NextW>Area.Bottom))) and not Closing(Value) then begin NextLine; AddStop(At); end;
      Cell.Index:=At; Cell.Count:=Count; Cell.Line:=Line; Cell.Rotate:=Vertical and Sideways(Value);
      Cell.Bounds:=Rect(X,Y,X+W,Y+Step); Cells.Add(Cell);
      if Cell.TateChuYoko then begin Stop.Index:=At+1; Stop.Line:=Line; Stop.Point:=Point(X,Y+Step div 2); Stops.Add(Stop); end;
      if Vertical then Inc(Y,Step) else Inc(X,W);
    end;
    Inc(At,Count); AddStop(At);
  end;
  LineCount:=Line+1;
end;

function TComicTextLayout.CaretStop(Index,Line: Integer): TComicCaretStop;
var Stop: TComicCaretStop;
begin
  Result:=Default(TComicCaretStop);
  for Stop in Stops do if Stop.Index=Index then begin Result:=Stop; if Stop.Line=Line then Exit; end;
end;

function TComicTextLayout.AtLine(Line,Along: Integer; Vertical: Boolean): TComicCaretStop;
var Stop: TComicCaretStop; Distance,Best,Position: Integer;
begin
  Result:=Default(TComicCaretStop); Best:=MaxInt; Line:=EnsureRange(Line,0,Max(0,LineCount-1));
  for Stop in Stops do if Stop.Line=Line then begin
    if Vertical then Position:=Stop.Point.Y else Position:=Stop.Point.X;
    Distance:=Abs(Position-Along); if Distance<Best then begin Best:=Distance; Result:=Stop; end;
  end;
end;

function TComicTextLayout.HitTest(const P: TPoint; Vertical: Boolean): TComicCaretStop;
var Stop: TComicCaretStop; Distance,Best,Line,Along: Integer;
begin
  Line:=0; Best:=MaxInt;
  for Stop in Stops do begin
    if Vertical then Distance:=Abs(Stop.Point.X+Step div 2-P.X)
    else Distance:=Abs(Stop.Point.Y+Step div 2-P.Y);
    if Distance<Best then begin Best:=Distance; Line:=Stop.Line; end;
  end;
  if Vertical then Along:=P.Y else Along:=P.X;
  Result:=AtLine(Line,Along,Vertical);
end;

end.
