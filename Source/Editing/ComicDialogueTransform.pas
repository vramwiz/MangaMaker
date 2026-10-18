unit ComicDialogueTransform;

// 責務：セリフ選択の移動・四隅拡縮・辺による間隔調整を押下時の状態から計算する。
interface
uses System.Types, ComicModel, ComicRender;
type
  TComicDialogueSnap = record
    Bounds: TRectF;
    HasX,HasY: Boolean;
  end;
function SnapDialogueCenter(const Candidate,Frame: TRectF; Tolerance: Double): TComicDialogueSnap;
function HitDialogueHandle(const Bounds: TRectF; const P: TPointF; Scale: Double): Integer;
function TransformDialogue(Balloon: TComicBalloon; Renderer: TComicRenderer;
  const Source: TComicBalloonTransform; const Original: TRectF;
  const Delta: TPointF; Handle: Integer): Boolean;
implementation
uses System.Math, ComicEditing;
function SnapDialogueCenter(const Candidate,Frame: TRectF; Tolerance: Double): TComicDialogueSnap;
var DX,DY: Double;
begin
  Result:=Default(TComicDialogueSnap); Result.Bounds:=Candidate;
  if Candidate.IsEmpty or Frame.IsEmpty then Exit;
  DX:=Frame.CenterPoint.X-Candidate.CenterPoint.X; DY:=Frame.CenterPoint.Y-Candidate.CenterPoint.Y;
  Result.HasX:=Abs(DX)<=Tolerance; Result.HasY:=Abs(DY)<=Tolerance;
  if not Result.HasX then DX:=0; if not Result.HasY then DY:=0;
  Result.Bounds.Offset(DX,DY);
end;
function HitDialogueHandle(const Bounds: TRectF; const P: TPointF; Scale: Double): Integer;
var Interior: TRectF; Handles: TArray<TPointF>; I: Integer; Best,Distance,Tolerance: Double;
begin
  // 小さい文字でも表示された編集点の間は移動・入力に使えるよう、余白判定より内側を優先する。
  Scale:=Max(0.001,Scale); Interior:=Bounds; Interior.Inflate(-4/Scale,-4/Scale);
  if not Interior.IsEmpty and Interior.Contains(P) then Exit(0);
  Result:=0; if Bounds.IsEmpty then Exit; Handles:=EditHandles(Bounds); Best:=MaxDouble; Tolerance:=9/Scale;
  for I:=0 to High(Handles) do
    if (Abs(P.X-Handles[I].X)<=Tolerance) and (Abs(P.Y-Handles[I].Y)<=Tolerance) then begin
      Distance:=Hypot(P.X-Handles[I].X,P.Y-Handles[I].Y);
      if Distance<Best then begin Best:=Distance; Result:=I+1; end;
    end;
end;
function TransformDialogue(Balloon: TComicBalloon; Renderer: TComicRenderer;
  const Source: TComicBalloonTransform; const Original: TRectF;
  const Delta: TPointF; Handle: Integer): Boolean;
var Probe: TComicBalloon; R,Actual: TRectF; Ratio: Double; Offset: TPointF;
begin
  Result:=False; if Original.IsEmpty then Exit; Probe:=TComicBalloon.Create;
  try
    Probe.Bounds:=Balloon.Bounds; Probe.Text:=Balloon.Text; Probe.Vertical:=Balloon.Vertical;
    Probe.FontFamily:=Balloon.FontFamily; Probe.FontStyle:=Balloon.FontStyle;
    Probe.AutoWrap:=Balloon.AutoWrap;
    Probe.FontSize:=Source.FontSize; Probe.TextOffset:=Source.TextOffset;
    Probe.TextLayoutSize:=Source.TextLayoutSize; Probe.TextLayoutFontSize:=Source.TextLayoutFontSize;
    Probe.CharacterSpacing:=Source.CharacterSpacing; Probe.LineSpacing:=Source.LineSpacing;
    Offset:=Source.TextOffset;
    if Handle=0 then Offset.Offset(Delta.X,Delta.Y)
    else begin
      if Handle in [1,3,5,7] then begin
        R:=ResizeImageRect(Original,Delta,Handle,1/Max(1,Source.FontSize));
        Probe.FontSize:=EnsureRange(Round(Source.FontSize*R.Width/Original.Width),1,1000);
        if Probe.TextLayoutFontSize=0 then begin
          Probe.TextLayoutSize:=TSizeF.Create(Max(1,Round(Source.Bounds.Right)-Round(Source.Bounds.Left)-36),
            Max(1,Round(Source.Bounds.Bottom)-Round(Source.Bounds.Top)-36));
          Probe.TextLayoutFontSize:=Source.FontSize;
        end;
      end else begin
        R:=ResizeRect(Original,Delta,Handle,1);
        if Handle in [2,6] then Ratio:=R.Height/Original.Height else Ratio:=R.Width/Original.Width;
        if (Balloon.Vertical and (Handle in [2,6])) or (not Balloon.Vertical and (Handle in [4,8])) then
          Probe.CharacterSpacing:=EnsureRange(Source.CharacterSpacing*Ratio,0.25,8.0)
        else Probe.LineSpacing:=EnsureRange(Source.LineSpacing*Ratio,0.25,8.0);
      end;
      Actual:=Renderer.BalloonTextBounds(Probe);
      if Handle in [1,7,8] then Offset.X:=Offset.X+Original.Right-Actual.Right
      else if Handle in [3,4,5] then Offset.X:=Offset.X+Original.Left-Actual.Left;
      if Handle in [1,2,3] then Offset.Y:=Offset.Y+Original.Bottom-Actual.Bottom
      else if Handle in [5,6,7] then Offset.Y:=Offset.Y+Original.Top-Actual.Top;
    end;
    if IsNan(Offset.X) or IsInfinite(Offset.X) or IsNan(Offset.Y) or IsInfinite(Offset.Y) or
      (Abs(Offset.X)>80000) or (Abs(Offset.Y)>80000) then Exit;
    Balloon.TextOffset:=Offset; Balloon.FontSize:=Probe.FontSize;
    Balloon.TextLayoutSize:=Probe.TextLayoutSize; Balloon.TextLayoutFontSize:=Probe.TextLayoutFontSize;
    Balloon.CharacterSpacing:=Probe.CharacterSpacing; Balloon.LineSpacing:=Probe.LineSpacing; Result:=True;
  finally Probe.Free; end;
end;
end.
