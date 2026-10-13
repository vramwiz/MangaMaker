unit ComicPanelTransform;

interface

uses System.Types, ComicModel;

type
  TComicPanelTransform = record
    ID: string;
    Bounds: TRectF;
    Vertices: TArray<TPointF>;
    PanX,PanY: Double;
  end;

function CapturePanelTransforms(Page: TComicPage; const IDs: TArray<string>): TArray<TComicPanelTransform>;
function PanelGroupBounds(const Items: TArray<TComicPanelTransform>): TRectF;
function ResizePanelGroup(const Items: TArray<TComicPanelTransform>; const Bounds: TRectF;
  const Delta: TPointF; Handle: Integer): TRectF;
function ApplyPanelGroupTransform(Page: TComicPage; const Items: TArray<TComicPanelTransform>;
  const Original,Target: TRectF): Boolean;

implementation

uses System.Math, System.Generics.Collections, ComicEditing, ComicGeometry;

function CapturePanelTransforms(Page: TComicPage; const IDs: TArray<string>): TArray<TComicPanelTransform>;
var Panel: TComicPanel; ID: string; Item: TComicPanelTransform; List: TList<TComicPanelTransform>;
begin
  List:=TList<TComicPanelTransform>.Create;
  try
    for Panel in Page.Panels do for ID in IDs do if Panel.ID=ID then begin
      Item.ID:=Panel.ID; Item.Bounds:=Panel.Bounds; Item.Vertices:=Copy(Panel.Vertices,0,Length(Panel.Vertices));
      Item.PanX:=Panel.PanX; Item.PanY:=Panel.PanY; List.Add(Item); Break;
    end;
    Result:=List.ToArray;
  finally List.Free; end;
end;
function PanelGroupBounds(const Items: TArray<TComicPanelTransform>): TRectF;
var Item: TComicPanelTransform;
begin
  Result:=TRectF.Empty; if Length(Items)=0 then Exit; Result:=Items[0].Bounds;
  for Item in Items do begin
    Result.Left:=Min(Result.Left,Item.Bounds.Left); Result.Top:=Min(Result.Top,Item.Bounds.Top);
    Result.Right:=Max(Result.Right,Item.Bounds.Right); Result.Bottom:=Max(Result.Bottom,Item.Bounds.Bottom);
  end;
end;
function ResizePanelGroup(const Items: TArray<TComicPanelTransform>; const Bounds: TRectF;
  const Delta: TPointF; Handle: Integer): TRectF;
var Item: TComicPanelTransform; MinimumX,MinimumY: Single;
begin
  MinimumX:=1; MinimumY:=1;
  for Item in Items do begin
    MinimumX:=Max(MinimumX,Bounds.Width*Min(1,30/Max(0.001,Item.Bounds.Width)));
    MinimumY:=Max(MinimumY,Bounds.Height*Min(1,30/Max(0.001,Item.Bounds.Height)));
  end;
  Result:=ResizeRect(Bounds,Delta,Handle,1);
  if Result.Width<MinimumX then
    if Handle in [1,7,8] then Result.Left:=Result.Right-MinimumX else Result.Right:=Result.Left+MinimumX;
  if Result.Height<MinimumY then
    if Handle in [1,2,3] then Result.Top:=Result.Bottom-MinimumY else Result.Bottom:=Result.Top+MinimumY;
end;
function ApplyPanelGroupTransform(Page: TComicPage; const Items: TArray<TComicPanelTransform>;
  const Original,Target: TRectF): Boolean;
var Prepared: TArray<TComicPanelTransform>; Panels: TArray<TComicPanel>; Panel: TComicPanel;
  I,K: Integer; ScaleX,ScaleY: Double; Bounds: TRectF;
  function Map(const P: TPointF): TPointF;
  begin Result:=TPointF.Create(Target.Left+(P.X-Original.Left)*ScaleX,Target.Top+(P.Y-Original.Top)*ScaleY); end;
begin
  Result:=False;
  if Original.IsEmpty or Target.IsEmpty or (Length(Items)=0) then Exit;
  ScaleX:=Target.Width/Original.Width; ScaleY:=Target.Height/Original.Height;
  SetLength(Prepared,Length(Items)); SetLength(Panels,Length(Items));
  for I:=0 to High(Items) do begin
    Panels[I]:=nil; for Panel in Page.Panels do if Panel.ID=Items[I].ID then begin Panels[I]:=Panel; Break; end;
    if Panels[I]=nil then Exit;
    Prepared[I]:=Items[I]; Bounds:=TRectF.Create(Map(Items[I].Bounds.TopLeft),Map(Items[I].Bounds.BottomRight));
    if IsNan(Bounds.Left) or IsInfinite(Bounds.Left) or IsNan(Bounds.Top) or IsInfinite(Bounds.Top) or
      IsNan(Bounds.Right) or IsInfinite(Bounds.Right) or IsNan(Bounds.Bottom) or IsInfinite(Bounds.Bottom) or
      (Abs(Bounds.Left)>80000) or (Abs(Bounds.Top)>80000) or (Abs(Bounds.Right)>80000) or (Abs(Bounds.Bottom)>80000) or Bounds.IsEmpty then Exit;
    if Length(Items[I].Vertices)>0 then begin
      Prepared[I].Vertices:=nil;
      SetLength(Prepared[I].Vertices,Length(Items[I].Vertices));
      for K:=0 to High(Items[I].Vertices) do Prepared[I].Vertices[K]:=Map(Items[I].Vertices[K]);
      if not ValidPolygon(Prepared[I].Vertices) then Exit;
      Bounds:=PolygonBounds(Prepared[I].Vertices);
    end;
    Prepared[I].Bounds:=Bounds; Prepared[I].PanX:=Items[I].PanX*ScaleX; Prepared[I].PanY:=Items[I].PanY*ScaleY;
  end;
  // Publish only when every selected shape is valid. A rejected member must
  // not leave the earlier members at partially transformed coordinates.
  for I:=0 to High(Prepared) do begin
    Panels[I].Bounds:=Prepared[I].Bounds; Panels[I].Vertices:=Prepared[I].Vertices;
    Panels[I].PanX:=Prepared[I].PanX; Panels[I].PanY:=Prepared[I].PanY;
  end;
  Result:=True;
end;

end.
