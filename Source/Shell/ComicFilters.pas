unit ComicFilters;

interface

uses Vcl.Graphics;

procedure ApplyComicFilter(Bitmap: TBitmap; Kind,Strength: Integer);

implementation

uses System.SysUtils, System.Math;

type
  TPixel = packed record B,G,R: Byte; end;
  TPixelRow = array[0..$FFFFFF] of TPixel;
  PPixelRow = ^TPixelRow;

procedure BoxBlur(Bitmap: TBitmap; Radius: Integer);
var Temp: TBitmap; Row,Source: PPixelRow; X,Y,K,Count,Left,Right,SR,SG,SB: Integer;
begin
  Temp:=TBitmap.Create;
  try
    Temp.PixelFormat:=pf24bit; Temp.SetSize(Bitmap.Width,Bitmap.Height);
    for Y:=0 to Bitmap.Height-1 do begin
      Source:=Bitmap.ScanLine[Y]; Row:=Temp.ScanLine[Y]; SR:=0; SG:=0; SB:=0;
      for K:=0 to Min(Bitmap.Width-1,Radius) do begin Inc(SR,Source[K].R); Inc(SG,Source[K].G); Inc(SB,Source[K].B); end;
      for X:=0 to Bitmap.Width-1 do begin
        Left:=Max(0,X-Radius); Right:=Min(Bitmap.Width-1,X+Radius); Count:=Right-Left+1;
        Row[X].R:=SR div Count; Row[X].G:=SG div Count; Row[X].B:=SB div Count;
        if X-Radius>=0 then begin Dec(SR,Source[X-Radius].R); Dec(SG,Source[X-Radius].G); Dec(SB,Source[X-Radius].B); end;
        if X+Radius+1<Bitmap.Width then begin Inc(SR,Source[X+Radius+1].R); Inc(SG,Source[X+Radius+1].G); Inc(SB,Source[X+Radius+1].B); end;
      end;
    end;
    for X:=0 to Bitmap.Width-1 do begin
      SR:=0; SG:=0; SB:=0;
      for K:=0 to Min(Bitmap.Height-1,Radius) do begin Source:=Temp.ScanLine[K]; Inc(SR,Source[X].R); Inc(SG,Source[X].G); Inc(SB,Source[X].B); end;
      for Y:=0 to Bitmap.Height-1 do begin
        Row:=Bitmap.ScanLine[Y]; Count:=Min(Bitmap.Height-1,Y+Radius)-Max(0,Y-Radius)+1;
        Row[X].R:=SR div Count; Row[X].G:=SG div Count; Row[X].B:=SB div Count;
        if Y-Radius>=0 then begin Source:=Temp.ScanLine[Y-Radius]; Dec(SR,Source[X].R); Dec(SG,Source[X].G); Dec(SB,Source[X].B); end;
        if Y+Radius+1<Bitmap.Height then begin Source:=Temp.ScanLine[Y+Radius+1]; Inc(SR,Source[X].R); Inc(SG,Source[X].G); Inc(SB,Source[X].B); end;
      end;
    end;
  finally Temp.Free; end;
end;

procedure ApplyComicFilter(Bitmap: TBitmap; Kind,Strength: Integer);
var Row,BlurredRow: PPixelRow; X,Y,R,G,B,Gray,NR,NG,NB: Integer; Original: TBitmap;
  function Blend(Source,Target: Integer): Byte;
  begin Result:=EnsureRange((Source*(100-Strength)+Target*Strength+50) div 100,0,255); end;
begin
  if not (Kind in [0..4]) or not (Strength in [0..100]) then raise Exception.Create('フィルターの指定が不正です。');
  if (Kind=0) or (Strength=0) then Exit;
  Bitmap.PixelFormat:=pf24bit; Original:=nil;
  try
    if Kind=3 then begin Original:=TBitmap.Create; Original.Assign(Bitmap); BoxBlur(Bitmap,Max(1,Strength div 20+1)); end;
    for Y:=0 to Bitmap.Height-1 do begin
      Row:=Bitmap.ScanLine[Y]; BlurredRow:=nil; if Original<>nil then BlurredRow:=Original.ScanLine[Y];
      for X:=0 to Bitmap.Width-1 do begin
        R:=Row[X].R; G:=Row[X].G; B:=Row[X].B; NR:=R; NG:=G; NB:=B;
        case Kind of
          1: begin NR:=Min(255,(393*R+769*G+189*B) div 1000); NG:=Min(255,(349*R+686*G+168*B) div 1000); NB:=Min(255,(272*R+534*G+131*B) div 1000); end;
          2: begin Gray:=(77*R+150*G+29*B) div 256; NR:=Gray; NG:=Gray; NB:=Gray; end;
          3: begin R:=BlurredRow[X].R; G:=BlurredRow[X].G; B:=BlurredRow[X].B; end;
          4: begin NR:=(R+255) div 2; NG:=(G+240) div 2; NB:=(B+255) div 2; end;
        end;
        Row[X].R:=Blend(R,NR); Row[X].G:=Blend(G,NG); Row[X].B:=Blend(B,NB);
      end;
    end;
  finally Original.Free; end;
end;

end.
