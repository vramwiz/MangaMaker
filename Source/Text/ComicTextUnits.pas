unit ComicTextUnits;

// 責務：移動・削除する文字単位を判定し、サロゲートや結合文字を途中で分割しない。

interface

// 編集位置は0始まりのUTF-16挿入位置で共有し、表示上の文字単位と混同しない。
function ComicTextUnitLength(const Text: string; Index: Integer): Integer;
function NextComicTextBoundary(const Text: string; Position: Integer): Integer;
function PreviousComicTextBoundary(const Text: string; Position: Integer): Integer;
function ComicTextWordBoundary(const Text: string; Position,Direction: Integer): Integer;

implementation

uses System.SysUtils, System.Math, System.Character;

function CodePoint(const Text: string; Index: Integer; out Count: Integer): Cardinal;
begin
  Count:=1; Result:=Ord(Text[Index]);
  if (Result>=$D800) and (Result<=$DBFF) and (Index<Length(Text)) and
    (Ord(Text[Index+1])>=$DC00) and (Ord(Text[Index+1])<=$DFFF) then begin
    Result:=$10000+(Result-$D800)*$400+Ord(Text[Index+1])-$DC00; Count:=2;
  end;
end;

function ExtendsCluster(Value: Cardinal): Boolean;
var Category: TUnicodeCategory;
begin
  Category:=Char.GetUnicodeCategory(UCS4Char(Value));
  Result:=(Category in [TUnicodeCategory.ucCombiningMark,TUnicodeCategory.ucEnclosingMark,
    TUnicodeCategory.ucNonSpacingMark]) or ((Value>=$FE00) and (Value<=$FE0F)) or
    ((Value>=$E0100) and (Value<=$E01EF)) or ((Value>=$1F3FB) and (Value<=$1F3FF));
end;

function ComicTextUnitLength(const Text: string; Index: Integer): Integer;
var Value,First: Cardinal; Count,At: Integer; JoinNext: Boolean;
begin
  Result:=0; if (Index<1) or (Index>Length(Text)) then Exit;
  First:=CodePoint(Text,Index,Count); Result:=Count;
  if First=13 then begin
    if (Index<Length(Text)) and (Text[Index+1]=#10) then Result:=2; Exit;
  end;
  if First=10 then Exit;
  At:=Index+Result; JoinNext:=False;
  while At<=Length(Text) do begin
    Value:=CodePoint(Text,At,Count);
    if (Value=13) or (Value=10) then Break;
    if not JoinNext and not ExtendsCluster(Value) and (Value<>$200D) and
      not ((First>=$1F1E6) and (First<=$1F1FF) and (Value>=$1F1E6) and (Value<=$1F1FF) and
        (Result=2)) then Break;
    JoinNext:=Value=$200D; Inc(Result,Count); Inc(At,Count);
  end;
end;

function NextComicTextBoundary(const Text: string; Position: Integer): Integer;
begin
  Position:=EnsureRange(Position,0,Length(Text));
  Result:=Position+ComicTextUnitLength(Text,Position+1);
end;

function PreviousComicTextBoundary(const Text: string; Position: Integer): Integer;
var At,Next: Integer;
begin
  Position:=EnsureRange(Position,0,Length(Text)); At:=0; Result:=0;
  while At<Position do begin
    Next:=NextComicTextBoundary(Text,At); if Next>=Position then Exit(At);
    At:=Next;
  end;
end;

function WordClass(const Text: string; Position: Integer): Integer;
var Value: Cardinal; Count: Integer;
begin
  if (Position<0) or (Position>=Length(Text)) then Exit(0);
  Value:=CodePoint(Text,Position+1,Count);
  if Char.IsWhiteSpace(UCS4Char(Value)) then Result:=0
  else if Char.IsLetterOrDigit(UCS4Char(Value)) or (Value=Ord('_')) then Result:=1 else Result:=2;
end;

function ComicTextWordBoundary(const Text: string; Position,Direction: Integer): Integer;
var Kind,Next: Integer;
begin
  Result:=EnsureRange(Position,0,Length(Text));
  if Direction<0 then begin
    while Result>0 do begin Next:=PreviousComicTextBoundary(Text,Result); if WordClass(Text,Next)<>0 then Break; Result:=Next; end;
    if Result=0 then Exit;
    Next:=PreviousComicTextBoundary(Text,Result); Kind:=WordClass(Text,Next); Result:=Next;
    while Result>0 do begin Next:=PreviousComicTextBoundary(Text,Result); if WordClass(Text,Next)<>Kind then Break; Result:=Next; end;
  end else begin
    Kind:=WordClass(Text,Result);
    while (Result<Length(Text)) and (WordClass(Text,Result)=Kind) do Result:=NextComicTextBoundary(Text,Result);
    while (Result<Length(Text)) and (WordClass(Text,Result)=0) do Result:=NextComicTextBoundary(Text,Result);
  end;
end;

end.
