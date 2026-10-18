unit ComicPlacementPreview;

// 責務：作品を変更せず吹き出しの完成描画用モデルを作り、コマの配置だけを点線で予告する。
interface
uses System.Types, Vcl.Graphics, ComicModel;
function CreateBalloonPlacementPreview(Tool: Integer; const Start,Finish: TPointF;
  Owner: TComicBalloon; Contour: TComicBalloonContour): TComicBalloon;
procedure DrawPanelPlacementPreview(Canvas: TCanvas; const Origin: TPoint; Scale: Double;
  const Clip: TRect; Tool: Integer; const Start,Finish: TPointF);
implementation
uses Winapi.Windows, System.Math, System.JSON, ComicRender;
function CreateBalloonPlacementPreview(Tool: Integer; const Start,Finish: TPointF;
  Owner: TComicBalloon; Contour: TComicBalloonContour): TComicBalloon;
var Bounds: TRectF; J: TJSONObject; Tail: TComicTail;
begin
  Result:=nil; if not (Tool in [5,6,7,10,11]) then Exit;
  Bounds:=TRectF.Create(Min(Start.X,Finish.X),Min(Start.Y,Finish.Y),Max(Start.X,Finish.X),Max(Start.Y,Finish.Y));
  if Tool in [7,11] then begin
    if (Owner=nil) or (Owner.Tails.Count>=64) then Exit;
    Tail:=TComicTail.Create; Tail.Root:=Start; Tail.Tip:=Finish;
    Tail.Width:=Min(2000,Max(8,Owner.Bounds.Width/6));
    if Tool=7 then Tail.Width:=Min(2000,2*Tail.Width) else Tail.Kind:=ctThought;
    if not Tail.Valid then begin Tail.Free; Exit; end;
    try
      Result:=TComicBalloon.Create;
      try
        J:=Owner.Json; try Result.Read(J); finally J.Free; end;
        Result.Tails.Add(Tail); Tail:=nil;
      except Result.Free; Result:=nil; raise; end;
    finally Tail.Free; end;
  end else begin
    if (Bounds.Width<1) or (Bounds.Height<1) then Exit;
    Result:=TComicBalloon.Create; Result.Bounds:=Bounds; Result.Contour:=Contour;
    if Tool=10 then Result.Shape:=0 else Result.Shape:=Tool-4;
  end;
end;
function PreviewRegion(const Origin: TPoint; Scale: Double; Tool: Integer;
  const Start,Finish: TPointF): HRGN;
var Bounds: TRectF; R: TRect;
begin
  Bounds:=TRectF.Create(Min(Start.X,Finish.X),Min(Start.Y,Finish.Y),Max(Start.X,Finish.X),Max(Start.Y,Finish.Y));
  R:=Rect(Origin.X+Round(Bounds.Left*Scale),Origin.Y+Round(Bounds.Top*Scale),
    Origin.X+Round(Bounds.Right*Scale),Origin.Y+Round(Bounds.Bottom*Scale));
  Result:=ShapeRegion(R,Tool-1);
end;
procedure DrawPanelPlacementPreview(Canvas: TCanvas; const Origin: TPoint; Scale: Double;
  const Clip: TRect; Tool: Integer; const Start,Finish: TPointF);
var Pattern: Vcl.Graphics.TBitmap; Brush: HBRUSH; Region: HRGN; X,Y,Saved: Integer;
begin
  if not (Tool in [1,2,3]) then Exit;
  Pattern:=Vcl.Graphics.TBitmap.Create; Region:=0; Brush:=0; Saved:=SaveDC(Canvas.Handle);
  try
    Pattern.SetSize(8,8);
    for Y:=0 to 7 do for X:=0 to 7 do
      if Odd((X+Y) div 4) then Pattern.Canvas.Pixels[X,Y]:=clWhite else Pattern.Canvas.Pixels[X,Y]:=clBlack;
    Brush:=CreatePatternBrush(Pattern.Handle); Region:=PreviewRegion(Origin,Scale,Tool,Start,Finish);
    IntersectClipRect(Canvas.Handle,Clip.Left,Clip.Top,Clip.Right,Clip.Bottom);
    FrameRgn(Canvas.Handle,Region,Brush,2,2);
  finally
    if Region<>0 then DeleteObject(Region); if Brush<>0 then DeleteObject(Brush);
    RestoreDC(Canvas.Handle,Saved); Pattern.Free;
  end;
end;
end.
