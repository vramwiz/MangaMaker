unit ComicRender;
interface
uses Winapi.Windows, System.SysUtils, System.Types, System.Math,
  System.Generics.Collections, System.IOUtils, Vcl.Graphics, Vcl.Imaging.pngimage,
  Vcl.Imaging.jpeg, ComicModel, ComicTextLayout, ComicEffects, ComicFilters;
type
  TComicRenderer = class
  private
    FCache: TObjectDictionary<string,TBitmap>;
    FOverlayCache: TObjectDictionary<string,TPngImage>;
    FFilteredCache: TObjectDictionary<string,TBitmap>;
    FFilteredBytes: UInt64;
    function Image(const FileName: string): TBitmap;
    function FilteredPanel(Project: TComicProject; Panel: TComicPanel; Img: TBitmap; out Crop: TRect; out Owned: Boolean): TBitmap;
  public
    procedure DrawOverlay(Canvas: TCanvas; const FileName: string; const Target: TRect);
    constructor Create;
    destructor Destroy; override;
    procedure ClearCache;
    procedure DrawImage(C: TCanvas; const FileName: string; const Target: TRect);
    function ImageBounds(Project: TComicProject; Panel: TComicPanel): TRectF;
    function BalloonTextBounds(Balloon: TComicBalloon): TRectF;
    procedure Draw(C: TCanvas; Project: TComicProject; Page: TComicPage;
      const Target: TRect; Guides: Boolean);
    procedure ExportPage(Project: TComicProject; Page: TComicPage; const FileName: string);
  end;
function ShapeRegion(const R: TRect; Shape: Integer): HRGN;
function PanelRegion(Panel: TComicPanel; const Origin: TPoint; Scale: Double; DeviceCanvas: TCanvas=nil): HRGN;
function TailRegion(Tail: TComicTail; const Origin: TPoint; Scale: Double): HRGN;
function BalloonRegion(Balloon: TComicBalloon; const Origin: TPoint; Scale: Double): HRGN;
function BuildBalloonTextLayout(Canvas: TCanvas; Balloon: TComicBalloon; Layout: TComicTextLayout): Double;
implementation
function TailRegion(Tail: TComicTail; const Origin: TPoint; Scale: Double): HRGN;
var Handles: TArray<TPointF>; Points: array[0..2] of TPoint; I,X,Y,Radius: Integer; T: Double; Circle: HRGN;
  function Map(const P: TPointF): TPoint;
  begin Result:=Point(Origin.X+Round(P.X*Scale),Origin.Y+Round(P.Y*Scale)); end;
begin
  Result:=CreateRectRgn(0,0,0,0); if not Tail.Valid then Exit;
  if Tail.Kind=ctTriangle then begin
    Handles:=Tail.Handles; Points[0]:=Map(Handles[1]);
    Points[1]:=Map(TPointF.Create(2*Tail.Root.X-Handles[1].X,2*Tail.Root.Y-Handles[1].Y)); Points[2]:=Map(Tail.Tip);
    DeleteObject(Result); Result:=CreatePolygonRgn(Points,3,WINDING);
  end else for I:=1 to 3 do begin
    T:=I/3; X:=Origin.X+Round((Tail.Root.X+(Tail.Tip.X-Tail.Root.X)*T)*Scale);
    Y:=Origin.Y+Round((Tail.Root.Y+(Tail.Tip.Y-Tail.Root.Y)*T)*Scale);
    Radius:=Max(1,Round(Tail.Width/2*(1-0.65*T)*Scale)); Circle:=CreateEllipticRgn(X-Radius,Y-Radius,X+Radius+1,Y+Radius+1);
    try CombineRgn(Result,Result,Circle,RGN_OR); finally DeleteObject(Circle); end;
  end;
end;
function BalloonRegion(Balloon: TComicBalloon; const Origin: TPoint; Scale: Double): HRGN;
var Tail: TComicTail; TailShape: HRGN; R: TRect;
begin
  R:=Rect(Origin.X+Round(Balloon.Bounds.Left*Scale),Origin.Y+Round(Balloon.Bounds.Top*Scale),
    Origin.X+Round(Balloon.Bounds.Right*Scale),Origin.Y+Round(Balloon.Bounds.Bottom*Scale));
  Result:=ShapeRegion(R,Balloon.Shape);
  for Tail in Balloon.Tails do begin TailShape:=TailRegion(Tail,Origin,Scale);
    try CombineRgn(Result,Result,TailShape,RGN_OR); finally DeleteObject(TailShape); end;
  end;
end;
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
begin inherited; FCache:=TObjectDictionary<string,TBitmap>.Create([doOwnsValues]); FOverlayCache:=TObjectDictionary<string,TPngImage>.Create([doOwnsValues]);
  FFilteredCache:=TObjectDictionary<string,TBitmap>.Create([doOwnsValues]); end;
destructor TComicRenderer.Destroy;
begin FFilteredCache.Free; FOverlayCache.Free; FCache.Free; inherited; end;
procedure TComicRenderer.ClearCache;
begin FCache.Clear; FOverlayCache.Clear; FFilteredCache.Clear; FFilteredBytes:=0; end;
function TComicRenderer.FilteredPanel(Project: TComicProject; Panel: TComicPanel; Img: TBitmap; out Crop: TRect; out Owned: Boolean): TBitmap;
const CacheLimit=48*1024*1024;
var Key: string; ImageRect,PanelRect: TRect; Bounds: TRectF; Bytes: UInt64;
begin
  Result:=nil; Owned:=False; PanelRect:=Rect(Round(Panel.Bounds.Left),Round(Panel.Bounds.Top),Round(Panel.Bounds.Right),Round(Panel.Bounds.Bottom));
  if not IntersectRect(Crop,PanelRect,Rect(0,0,Project.Width,Project.Height)) then Exit;
  Key:=Project.Folder+'|'+Panel.ID+'|'+Panel.ImageID+'|'+IntToStr(Project.Width)+'x'+IntToStr(Project.Height)+'|'+
    IntToStr(Panel.FilterKind)+':'+IntToStr(Panel.FilterStrength)+'|'+FloatToStr(Panel.Bounds.Left)+'|'+FloatToStr(Panel.Bounds.Top)+'|'+
    FloatToStr(Panel.Bounds.Right)+'|'+FloatToStr(Panel.Bounds.Bottom)+'|'+FloatToStr(Panel.Zoom)+'|'+FloatToStr(Panel.PanX)+'|'+FloatToStr(Panel.PanY);
  if FFilteredCache.TryGetValue(Key,Result) then Exit;
  Result:=TBitmap.Create; Owned:=True;
  try
    Result.PixelFormat:=pf24bit; Result.SetSize(Crop.Width,Crop.Height); Result.Canvas.Brush.Color:=$F5F2EF;
    Result.Canvas.FillRect(Rect(0,0,Result.Width,Result.Height));
    if Img<>nil then begin Bounds:=ImageBounds(Project,Panel); ImageRect:=Rect(Round(Bounds.Left)-Crop.Left,Round(Bounds.Top)-Crop.Top,
      Round(Bounds.Right)-Crop.Left,Round(Bounds.Bottom)-Crop.Top);
      SetStretchBltMode(Result.Canvas.Handle,HALFTONE); Result.Canvas.StretchDraw(ImageRect,Img); end;
    // Filters are computed in output pixels once, then the same raster is scaled for every preview.
    ApplyComicFilter(Result,Panel.FilterKind,Panel.FilterStrength); Bytes:=UInt64(Result.Width)*UInt64(Result.Height)*3;
    if Bytes<=CacheLimit then begin
      if FFilteredBytes+Bytes>CacheLimit then begin FFilteredCache.Clear; FFilteredBytes:=0; end;
      FFilteredCache.Add(Key,Result); Inc(FFilteredBytes,Bytes); Owned:=False;
    end;
  except Result.Free; Result:=nil; Owned:=False; raise; end;
end;
procedure TComicRenderer.DrawOverlay(Canvas: TCanvas; const FileName: string; const Target: TRect);
var PNG: TPngImage;
begin
  if not FileExists(FileName) then Exit;
  if not FOverlayCache.TryGetValue(FileName,PNG) then begin PNG:=TPngImage.Create;
    try PNG.LoadFromFile(FileName); FOverlayCache.Add(FileName,PNG); except PNG.Free; raise; end;
  end;
  Canvas.StretchDraw(Target,PNG);
end;
function TComicRenderer.ImageBounds(Project: TComicProject; Panel: TComicPanel): TRectF;
var B: TBitmap; Cover,W,H: Double;
begin
  Result:=TRectF.Empty;
  try B:=Image(Project.ImagePath(Panel.ImageID)); except Exit; end;
  if B=nil then Exit;
  Cover:=Max(Panel.Bounds.Width/B.Width,Panel.Bounds.Height/B.Height)*Max(0.000001,Panel.Zoom);
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
function TComicRenderer.BalloonTextBounds(Balloon: TComicBalloon): TRectF;
var Bitmap: TBitmap; Layout: TComicTextLayout; TextBounds: TRect; Scale: Double; Center: TPointF;
begin
  Result:=TRectF.Empty; if Balloon.Text='' then Exit;
  Bitmap:=TBitmap.Create; Layout:=TComicTextLayout.Create;
  try
    Bitmap.SetSize(1,1); Scale:=BuildBalloonTextLayout(Bitmap.Canvas,Balloon,Layout); TextBounds:=Layout.Bounds;
    Center:=Balloon.Bounds.CenterPoint; Center.Offset(Balloon.TextOffset.X,Balloon.TextOffset.Y);
    Result:=TRectF.Create(Center.X+TextBounds.Left*Scale,Center.Y+TextBounds.Top*Scale,
      Center.X+TextBounds.Right*Scale,Center.Y+TextBounds.Bottom*Scale);
  finally Layout.Free; Bitmap.Free; end;
end;
function BuildBalloonTextLayout(Canvas: TCanvas; Balloon: TComicBalloon; Layout: TComicTextLayout): Double;
var Area,Bounds: TRect; BaseFont: Integer;
begin
  BaseFont:=Balloon.TextLayoutFontSize;
  if BaseFont=0 then begin BaseFont:=Max(1,Balloon.FontSize);
    Area:=Rect(0,0,Max(1,Round(Balloon.Bounds.Right)-Round(Balloon.Bounds.Left)-36),
      Max(1,Round(Balloon.Bounds.Bottom)-Round(Balloon.Bounds.Top)-36));
  end else Area:=Rect(0,0,Round(Balloon.TextLayoutSize.cx),Round(Balloon.TextLayoutSize.cy));
  Canvas.Font.Name:=Balloon.FontFamily; Canvas.Font.Height:=-BaseFont; Canvas.Font.Style:=Balloon.FontStyle; Canvas.Font.Color:=Balloon.FontColor;
  Layout.Build(Canvas,Balloon.Text,Area,Balloon.Vertical); Bounds:=Layout.Bounds;
  Layout.Translate(-(Bounds.Left+Bounds.Right) div 2,-(Bounds.Top+Bounds.Bottom) div 2);
  Result:=Balloon.FontSize/BaseFont;
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
var S: Double; P: TComicPanel; B: TComicBalloon; R,D: TRect;
  G: HRGN; Saved, PageDC: Integer; Img: TBitmap; Overlay: TComicOverlay; FileName: string;
  function Map(const A: TRectF): TRect;
  begin Result:=Rect(Target.Left+Round(A.Left*S),Target.Top+Round(A.Top*S),
    Target.Left+Round(A.Right*S),Target.Top+Round(A.Bottom*S)); end;
  procedure PanelImage;
  var Bitmap: TBitmap; Crop,Dest: TRect; Owned: Boolean;
  begin
    C.Brush.Color:=$F5F2EF; C.FillRect(R);
    if (P.FilterKind=0) or (P.FilterStrength=0) then begin
      if Img<>nil then begin SetStretchBltMode(C.Handle,HALFTONE); C.StretchDraw(D,Img); end; Exit;
    end;
    Bitmap:=FilteredPanel(Project,P,Img,Crop,Owned); if Bitmap=nil then Exit;
    try
      Dest:=Rect(Target.Left+Round(Crop.Left*S),Target.Top+Round(Crop.Top*S),Target.Left+Round(Crop.Right*S),Target.Top+Round(Crop.Bottom*S));
      SetStretchBltMode(C.Handle,HALFTONE); C.StretchDraw(Dest,Bitmap);
    finally if Owned then Bitmap.Free; end;
  end;
  procedure PanelFrame;
  var Inner,Shifted: HRGN; Insets: TPoint; Distance,I: Integer; Points: TArray<TPoint>; Vertex: TPointF;
    Directions: array[0..7] of TPoint; Pen: HPEN; Brush: TLogBrush; FrameDC: Integer;
  begin
    if P.BorderWidth=0 then Exit; G:=PanelRegion(P,Target.TopLeft,S);
    try
      C.Brush.Color:=P.BorderColor;
      if P.FrameKind=2 then begin
        Brush:=Default(TLogBrush); Brush.lbStyle:=BS_SOLID; Brush.lbColor:=ColorToRGB(P.BorderColor);
        Pen:=ExtCreatePen(PS_GEOMETRIC or PS_DASH or PS_ENDCAP_FLAT or PS_JOIN_MITER,Max(1,Round(P.BorderWidth*S)),Brush,0,nil);
        if Pen=0 then RaiseLastOSError; FrameDC:=SaveDC(C.Handle);
        try
          SelectObject(C.Handle,Pen); SelectObject(C.Handle,GetStockObject(HOLLOW_BRUSH)); SetBkMode(C.Handle,TRANSPARENT);
          case P.Shape of
            0: Winapi.Windows.Rectangle(C.Handle,R.Left,R.Top,R.Right,R.Bottom);
            1: Winapi.Windows.Ellipse(C.Handle,R.Left,R.Top,R.Right,R.Bottom);
            2: Winapi.Windows.RoundRect(C.Handle,R.Left,R.Top,R.Right,R.Bottom,Max(8,R.Width div 8),Max(8,R.Width div 8));
            3: begin SetLength(Points,Length(P.Vertices)+1); I:=0;
              for Vertex in P.Vertices do begin Points[I]:=Point(Target.Left+Round(Vertex.X*S),Target.Top+Round(Vertex.Y*S)); Inc(I); end;
              Points[I]:=Points[0]; Winapi.Windows.Polyline(C.Handle,Points[0],Length(Points)); end;
          end;
        finally RestoreDC(C.Handle,FrameDC); DeleteObject(Pen); end;
      end else begin
        FrameRgn(C.Handle,G,C.Brush.Handle,Max(1,Round(P.BorderWidth*S)),Max(1,Round(P.BorderWidth*S)));
        if P.FrameKind=1 then begin
          Inner:=CreateRectRgn(0,0,0,0); Shifted:=CreateRectRgn(0,0,0,0);
          try
            CombineRgn(Inner,G,0,RGN_COPY); Distance:=Max(2,Round((P.BorderWidth+8)*S));
            Directions[0]:=Point(Distance,0); Directions[1]:=Point(-Distance,0); Directions[2]:=Point(0,Distance); Directions[3]:=Point(0,-Distance);
            Directions[4]:=Point(Distance,Distance); Directions[5]:=Point(-Distance,Distance); Directions[6]:=Point(Distance,-Distance); Directions[7]:=Point(-Distance,-Distance);
            for Insets in Directions do begin CombineRgn(Shifted,G,0,RGN_COPY); OffsetRgn(Shifted,Insets.X,Insets.Y); CombineRgn(Inner,Inner,Shifted,RGN_AND); end;
            FrameRgn(C.Handle,Inner,C.Brush.Handle,Max(1,Round(P.BorderWidth*S/2)),Max(1,Round(P.BorderWidth*S/2)));
          finally DeleteObject(Shifted); DeleteObject(Inner); end;
        end;
      end;
    finally DeleteObject(G); end;
  end;
  procedure Balloon(A: TComicBalloon);
  var Owner,Candidate: TComicPanel; Layout: TComicTextLayout; Cell: TComicTextCell; TextScale,CX,CY: Double; CellBounds: TRect;
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
        G:=BalloonRegion(A,Target.TopLeft,S);
        try
          C.Brush.Color:=A.FillColor; FillRgn(C.Handle,G,C.Brush.Handle);
          if A.BorderWidth>0 then begin C.Brush.Color:=A.BorderColor;
            FrameRgn(C.Handle,G,C.Brush.Handle,Max(1,Round(A.BorderWidth*S)),Max(1,Round(A.BorderWidth*S))); end;
        finally DeleteObject(G); end;
      end else if Guides then begin
        C.Pen.Color:=$C5A26C; C.Pen.Style:=psDot; C.Pen.Width:=1; C.Brush.Style:=bsClear; C.Rectangle(R); C.Pen.Style:=psSolid;
      end;
      C.Brush.Style:=bsClear;
      Layout:=TComicTextLayout.Create;
      try
        TextScale:=BuildBalloonTextLayout(C,A,Layout)*S;
        CX:=Target.Left+(A.Bounds.CenterPoint.X+A.TextOffset.X)*S;
        CY:=Target.Top+(A.Bounds.CenterPoint.Y+A.TextOffset.Y)*S;
        C.Font.Height:=-Max(1,Round(A.FontSize*S));
        for Cell in Layout.Cells do begin
          CellBounds:=Rect(Round(CX+Cell.Bounds.Left*TextScale),Round(CY+Cell.Bounds.Top*TextScale),
            Round(CX+Cell.Bounds.Right*TextScale),Round(CY+Cell.Bounds.Bottom*TextScale));
          DrawComicTextCell(C,A.Text,Cell,CellBounds,A.Vertical);
        end;
      finally Layout.Free; end;
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
        ClipPanel(C,P,Target.TopLeft,S);
        Img:=Image(Project.ImagePath(P.ImageID));
        D:=Map(ImageBounds(Project,P)); PanelImage;
        for Overlay in P.Overlays do begin
          if Overlay.FileName='' then FileName:=SafeChild(TPath.Combine(DataRoot,'Effects'),Overlay.MaterialID+'.png')
          else FileName:=SafeChild(Project.Folder,Overlay.FileName);
          DrawOverlay(C,FileName,Map(OverlayBounds(P,Overlay)));
        end;
      finally RestoreDC(C.Handle,Saved); C.Refresh; end;
      PanelFrame;
      if Guides then begin
        C.Font.Name:='Segoe UI'; C.Font.Height:=-Max(11,Round(30*S)); C.Font.Color:=$878787;
        C.Font.Style:=[];
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
      C.Rectangle(Map(Project.PageBasis.Frame));
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
