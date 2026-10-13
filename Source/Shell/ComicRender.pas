unit ComicRender;
interface
uses Winapi.Windows, System.SysUtils, System.Types, System.Math,
  System.Generics.Collections, Vcl.Graphics, Vcl.Imaging.pngimage,
  Vcl.Imaging.jpeg, ComicModel;
type
  TComicRenderer = class
  private
    FCache: TObjectDictionary<string,TBitmap>;
    function Image(const FileName: string): TBitmap;
  public
    constructor Create;
    destructor Destroy; override;
    procedure ClearCache;
    procedure DrawImage(C: TCanvas; const FileName: string; const Target: TRect);
    function ImageBounds(Project: TComicProject; Panel: TComicPanel): TRectF;
    procedure Draw(C: TCanvas; Project: TComicProject; Page: TComicPage;
      const Target: TRect; Guides: Boolean);
    procedure ExportPage(Project: TComicProject; Page: TComicPage; const FileName: string);
  end;
function ShapeRegion(const R: TRect; Shape: Integer): HRGN;
function PanelRegion(Panel: TComicPanel; const Origin: TPoint; Scale: Double; DeviceCanvas: TCanvas=nil): HRGN;
implementation
function PanelRegion(Panel: TComicPanel; const Origin: TPoint; Scale: Double; DeviceCanvas: TCanvas): HRGN;
var R: TRect; Points: TArray<TPoint>; I: Integer; Bounds: array[0..1] of TPoint;
begin
  if Panel.Shape=3 then begin
    SetLength(Points,Length(Panel.Vertices));
    for I:=0 to High(Points) do Points[I]:=Point(Origin.X+Round(Panel.Vertices[I].X*Scale),Origin.Y+Round(Panel.Vertices[I].Y*Scale));
    if DeviceCanvas<>nil then if not LPtoDP(DeviceCanvas.Handle,Points[0],Length(Points)) then RaiseLastOSError;
    Result:=CreatePolygonRgn(Points[0],Length(Points),WINDING);
  end else begin
    Bounds[0]:=Point(Origin.X+Round(Panel.Bounds.Left*Scale),Origin.Y+Round(Panel.Bounds.Top*Scale));
    Bounds[1]:=Point(Origin.X+Round(Panel.Bounds.Right*Scale),Origin.Y+Round(Panel.Bounds.Bottom*Scale));
    if DeviceCanvas<>nil then if not LPtoDP(DeviceCanvas.Handle,Bounds[0],2) then RaiseLastOSError;
    R:=Rect(Bounds[0].X,Bounds[0].Y,Bounds[1].X,Bounds[1].Y); Result:=ShapeRegion(R,Panel.Shape);
  end;
end;
procedure ClipPanel(C: TCanvas; Panel: TComicPanel; const Origin: TPoint; Scale: Double);
var G: HRGN;
begin
  G:=PanelRegion(Panel,Origin,Scale,C);
  try ExtSelectClipRgn(C.Handle,G,RGN_AND); finally DeleteObject(G); end;
end;
function ShapeRegion(const R: TRect; Shape: Integer): HRGN;
begin
  case Shape of
    1: Result:=CreateEllipticRgn(R.Left,R.Top,R.Right,R.Bottom);
    2: Result:=CreateRoundRectRgn(R.Left,R.Top,R.Right,R.Bottom,Max(8,R.Width div 8),Max(8,R.Width div 8));
  else Result:=CreateRectRgn(R.Left,R.Top,R.Right,R.Bottom); end;
end;
procedure ClipShape(C: TCanvas; const R: TRect; Shape: Integer);
var Points: array[0..1] of TPoint; G: HRGN;
begin
  // Clip regions use device coordinates, unlike FillRgn/FrameRgn and normal drawing.
  // PaintTo and child controls can have a nonzero DC viewport origin.
  Points[0]:=R.TopLeft; Points[1]:=R.BottomRight;
  if not LPtoDP(C.Handle,Points[0],2) then RaiseLastOSError;
  G:=ShapeRegion(Rect(Points[0].X,Points[0].Y,Points[1].X,Points[1].Y),Shape);
  try ExtSelectClipRgn(C.Handle,G,RGN_AND); finally DeleteObject(G); end;
end;
constructor TComicRenderer.Create;
begin inherited; FCache:=TObjectDictionary<string,TBitmap>.Create([doOwnsValues]); end;
destructor TComicRenderer.Destroy;
begin FCache.Free; inherited; end;
procedure TComicRenderer.ClearCache;
begin FCache.Clear; end;
function TComicRenderer.ImageBounds(Project: TComicProject; Panel: TComicPanel): TRectF;
var B: TBitmap; Cover,W,H: Double;
begin
  Result:=TRectF.Empty;
  try B:=Image(Project.ImagePath(Panel.ImageID)); except Exit; end;
  if B=nil then Exit;
  Cover:=Max(Panel.Bounds.Width/B.Width,Panel.Bounds.Height/B.Height)*Max(0.1,Panel.Zoom);
  W:=B.Width*Cover; H:=B.Height*Cover;
  Result:=TRectF.Create((Panel.Bounds.Left+Panel.Bounds.Right-W)/2+Panel.PanX,
    (Panel.Bounds.Top+Panel.Bounds.Bottom-H)/2+Panel.PanY,0,0);
  Result.Right:=Result.Left+W; Result.Bottom:=Result.Top+H;
end;
procedure TComicRenderer.DrawImage(C: TCanvas; const FileName: string; const Target: TRect);
var B: TBitmap; Scale: Double; R: TRect;
begin
  C.Brush.Color:=$454545; C.FillRect(Target);
  try B:=Image(FileName); except B:=nil; end;
  if B=nil then begin C.TextOut(Target.Left+4,Target.Top+4,'No Image'); Exit; end;
  Scale:=Min(Target.Width/B.Width,Target.Height/B.Height);
  R:=Rect(Target.Left+(Target.Width-Round(B.Width*Scale)) div 2,
    Target.Top+(Target.Height-Round(B.Height*Scale)) div 2,0,0);
  R.Right:=R.Left+Round(B.Width*Scale); R.Bottom:=R.Top+Round(B.Height*Scale);
  SetStretchBltMode(C.Handle,HALFTONE); C.StretchDraw(R,B);
end;
function TComicRenderer.Image(const FileName: string): TBitmap;
var P: TPicture;
begin
  Result:=nil; if (FileName='') or not FileExists(FileName) then Exit;
  if FCache.TryGetValue(FileName,Result) then Exit;
  P:=TPicture.Create;
  try
    P.LoadFromFile(FileName); Result:=TBitmap.Create;
    Result.SetSize(P.Width,P.Height); Result.Canvas.Brush.Color:=clWhite;
    Result.Canvas.FillRect(Rect(0,0,P.Width,P.Height)); Result.Canvas.Draw(0,0,P.Graphic);
    FCache.Add(FileName,Result);
  finally P.Free; end;
end;
procedure TComicRenderer.Draw(C: TCanvas; Project: TComicProject; Page: TComicPage;
  const Target: TRect; Guides: Boolean);
var S: Double; P: TComicPanel; B: TComicBalloon; R,D,TextR: TRect;
  G,TailG: HRGN; Saved, PageDC,X,Y,Step: Integer; Img: TBitmap;
  Cover,W,H: Double; Points: array[0..2] of TPoint;
  function Map(const A: TRectF): TRect;
  begin Result:=Rect(Target.Left+Round(A.Left*S),Target.Top+Round(A.Top*S),
    Target.Left+Round(A.Right*S),Target.Top+Round(A.Bottom*S)); end;
  procedure Balloon(A: TComicBalloon);
  var Owner,Candidate: TComicPanel; Ch: Char;
  begin
    Saved:=SaveDC(C.Handle);
    try
      if not A.Overflow then begin
        Owner:=nil; for Candidate in Page.Panels do if Candidate.ID=A.PanelID then begin Owner:=Candidate; Break; end;
        if Owner=nil then Exit;
        ClipPanel(C,Owner,Target.TopLeft,S);
      end;
      R:=Map(A.Bounds);
      if not A.Transparent then begin
        G:=ShapeRegion(R,A.Shape);
        try
          if A.HasTail then begin
            Points[0]:=Point(R.Left+R.Width div 2-Max(4,R.Width div 12),R.Top+R.Height div 2);
            Points[1]:=Point(R.Left+R.Width div 2+Max(4,R.Width div 12),R.Top+R.Height div 2);
            Points[2]:=Point(Target.Left+Round(A.TailX*S),Target.Top+Round(A.TailY*S));
            TailG:=CreatePolygonRgn(Points,3,WINDING);
            CombineRgn(G,G,TailG,RGN_OR); DeleteObject(TailG);
          end;
          C.Brush.Color:=clWhite; FillRgn(C.Handle,G,C.Brush.Handle);
          C.Brush.Color:=clBlack; FrameRgn(C.Handle,G,C.Brush.Handle,Max(1,Round(3*S)),Max(1,Round(3*S)));
        finally DeleteObject(G); end;
      end;
      C.Font.Name:='Yu Gothic'; C.Font.Height:=-Max(5,Round(A.FontSize*S)); C.Font.Color:=clBlack;
      C.Brush.Style:=bsClear; TextR:=R; InflateRect(TextR,-Max(2,Round(18*S)),-Max(2,Round(18*S)));
      if A.Vertical then begin
        Step:=Max(6,Round(A.FontSize*S*1.18)); X:=TextR.Right-Step; Y:=TextR.Top;
        for Ch in A.Text do begin
          if Ch=#13 then Continue;
          if (Ch=#10) or (Y+Step>TextR.Bottom) then begin Dec(X,Step); Y:=TextR.Top; if Ch=#10 then Continue; end;
          C.TextOut(X,Y,Ch); Inc(Y,Step);
        end;
      end else DrawText(C.Handle,PChar(A.Text),Length(A.Text),TextR,DT_CENTER or DT_WORDBREAK or DT_NOPREFIX);
      C.Brush.Style:=bsSolid;
    finally RestoreDC(C.Handle,Saved); C.Refresh; end;
  end;
begin
  S:=Target.Width/Project.Width; PageDC:=SaveDC(C.Handle);
  try
    IntersectClipRect(C.Handle,Target.Left,Target.Top,Target.Right,Target.Bottom);
    C.Brush.Color:=clWhite; C.FillRect(Target);
    for P in Page.Panels do begin
      R:=Map(P.Bounds); Saved:=SaveDC(C.Handle);
      try
        ClipPanel(C,P,Target.TopLeft,S); C.Brush.Color:=$F5F2EF; C.FillRect(R);
        Img:=Image(Project.ImagePath(P.ImageID));
        if Img<>nil then begin
          Cover:=Max(P.Bounds.Width/Img.Width,P.Bounds.Height/Img.Height)*Max(0.1,P.Zoom);
          W:=Img.Width*Cover*S; H:=Img.Height*Cover*S;
          D:=Rect(R.Left+Round((R.Width-W)/2+P.PanX*S),R.Top+Round((R.Height-H)/2+P.PanY*S),0,0);
          D.Right:=D.Left+Round(W); D.Bottom:=D.Top+Round(H);
          SetStretchBltMode(C.Handle,HALFTONE); C.StretchDraw(D,Img);
        end;
      finally RestoreDC(C.Handle,Saved); C.Refresh; end;
      G:=PanelRegion(P,Target.TopLeft,S); C.Brush.Color:=clBlack;
      FrameRgn(C.Handle,G,C.Brush.Handle,Max(1,Round(4*S)),Max(1,Round(4*S))); DeleteObject(G);
      if Guides then begin
        C.Font.Name:='Segoe UI'; C.Font.Height:=-Max(11,Round(30*S)); C.Font.Color:=$878787;
        C.Brush.Style:=bsClear; C.TextOut(R.Left+8,R.Top+6,IntToStr(P.Number)); C.Brush.Style:=bsSolid;
        if P.ImageID='' then begin
          C.Font.Height:=-12; C.TextOut(R.Left+8,R.Top+28,'画像未配置');
        end;
      end;
    end;
    for B in Page.Balloons do if not B.Overflow then Balloon(B);
    for B in Page.Balloons do if B.Overflow then Balloon(B);
    if Guides then begin
      C.Pen.Color:=$C5A26C; C.Pen.Style:=psDot; C.Pen.Width:=1; C.Brush.Style:=bsClear;
      C.Rectangle(Map(TRectF.Create(60,60,Project.Width-60,Project.Height-60)));
      C.Pen.Style:=psSolid; C.Brush.Style:=bsSolid;
    end;
  finally RestoreDC(C.Handle,PageDC); C.Refresh; end;
end;
procedure TComicRenderer.ExportPage(Project: TComicProject; Page: TComicPage; const FileName: string);
var B: TBitmap; PNG: TPngImage;
begin
  B:=TBitmap.Create; PNG:=TPngImage.Create;
  try
    B.PixelFormat:=pf24bit; B.SetSize(Project.Width,Project.Height);
    Draw(B.Canvas,Project,Page,Rect(0,0,B.Width,B.Height),False);
    PNG.Assign(B); PNG.SaveToFile(FileName);
  finally PNG.Free; B.Free; end;
end;
end.
