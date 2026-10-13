unit ComicLayouts;

interface

uses System.SysUtils, System.Types, System.Math, System.JSON, System.IOUtils,
  System.Generics.Collections, ComicModel, ComicGeometry;

type
  TLayoutPanel = record
    Bounds: TRectF;
    Shape, Number: Integer;
    Vertices: TArray<TPointF>;
  end;
  TComicLayout = class
  public
    ID, Name: string;
    Width, Height: Integer;
    BuiltIn: Boolean;
    Panels: TList<TLayoutPanel>;
    constructor Create;
    destructor Destroy; override;
    procedure Capture(Project: TComicProject; Page: TComicPage);
    procedure Apply(Page: TComicPage; PageWidth, PageHeight: Integer);
    function Json: TJSONObject;
    procedure Read(J: TJSONObject);
  end;

procedure SeedLayouts(List: TObjectList<TComicLayout>);
procedure LoadLayouts(List: TObjectList<TComicLayout>; const FileName: string);
procedure SaveLayouts(List: TObjectList<TComicLayout>; const FileName: string);

implementation

constructor TComicLayout.Create;
begin
  inherited; ID:=NewUID; Width:=1200; Height:=1700;
  Panels:=TList<TLayoutPanel>.Create;
end;
destructor TComicLayout.Destroy;
begin Panels.Free; inherited; end;
procedure TComicLayout.Capture(Project: TComicProject; Page: TComicPage);
var P: TComicPanel; Item: TLayoutPanel;
begin
  Width:=Project.Width; Height:=Project.Height; Panels.Clear;
  for P in Page.Panels do begin
    Item.Bounds:=P.Bounds; Item.Shape:=P.Shape; Item.Number:=P.Number;
    Item.Vertices:=Copy(P.Vertices,0,Length(P.Vertices)); Panels.Add(Item);
  end;
end;
procedure TComicLayout.Apply(Page: TComicPage; PageWidth, PageHeight: Integer);
var Item: TLayoutPanel; P: TComicPanel; Prepared: TObjectList<TComicPanel>; Vertices: TArray<TPointF>; I: Integer;
begin
  // Prepare before replacing. A template never contains image IDs or balloons.
  Prepared:=TObjectList<TComicPanel>.Create;
  try
    for Item in Panels do begin
      P:=TComicPanel.Create; Prepared.Add(P); P.Shape:=Item.Shape; P.Number:=Item.Number;
      P.Bounds:=TRectF.Create(Item.Bounds.Left*PageWidth/Width,Item.Bounds.Top*PageHeight/Height,
        Item.Bounds.Right*PageWidth/Width,Item.Bounds.Bottom*PageHeight/Height);
      if Item.Shape=3 then begin
        SetLength(Vertices,Length(Item.Vertices));
        for I:=0 to High(Vertices) do Vertices[I]:=TPointF.Create(Item.Vertices[I].X*PageWidth/Width,Item.Vertices[I].Y*PageHeight/Height);
        P.SetVertices(Vertices);
      end;
    end;
    Page.Panels.Clear; Page.Balloons.Clear;
    while Prepared.Count>0 do Page.Panels.Add(Prepared.Extract(Prepared[0]));
  finally Prepared.Free; end;
end;
function TComicLayout.Json: TJSONObject;
var A: TJSONArray; J: TJSONObject; Item: TLayoutPanel;
begin
  Result:=TJSONObject.Create; Result.AddPair('id',ID); Result.AddPair('name',Name);
  Result.AddPair('width',TJSONNumber.Create(Width)); Result.AddPair('height',TJSONNumber.Create(Height));
  A:=TJSONArray.Create; Result.AddPair('panels',A);
  for Item in Panels do begin
    J:=TJSONObject.Create; A.AddElement(J);
    J.AddPair('x',TJSONNumber.Create(Item.Bounds.Left)); J.AddPair('y',TJSONNumber.Create(Item.Bounds.Top));
    J.AddPair('w',TJSONNumber.Create(Item.Bounds.Width)); J.AddPair('h',TJSONNumber.Create(Item.Bounds.Height));
    J.AddPair('shape',TJSONNumber.Create(Item.Shape)); J.AddPair('number',TJSONNumber.Create(Item.Number));
    if Item.Shape=3 then J.AddPair('vertices',PointsJson(Item.Vertices));
  end;
end;
procedure TComicLayout.Read(J: TJSONObject);
var V: TJSONValue; A: TJSONArray; Item: TLayoutPanel; X,Y,W,H: Double;
begin
  ID:=JStr(J,'id',''); Name:=Trim(JStr(J,'name',''));
  Width:=Round(JNum(J,'width',0)); Height:=Round(JNum(J,'height',0));
  if (ID='') or (Name='') or (Width<100) or (Width>8000) or (Height<100) or (Height>8000) then
    raise Exception.Create('Invalid layout name or page size.');
  A:=J.GetValue<TJSONArray>('panels');
  if (A=nil) or (A.Count=0) or (A.Count>500) then raise Exception.Create('Invalid layout panels.');
  Panels.Clear;
  for V in A do begin
    if not (V is TJSONObject) then raise Exception.Create('Invalid layout panel.');
    X:=JNum(TJSONObject(V),'x',NaN); Y:=JNum(TJSONObject(V),'y',NaN);
    W:=JNum(TJSONObject(V),'w',NaN); H:=JNum(TJSONObject(V),'h',NaN);
    if IsNan(X) or IsNan(Y) or IsNan(W) or IsNan(H) or
      IsInfinite(X) or IsInfinite(Y) or IsInfinite(W) or IsInfinite(H) or
      (W<=0) or (H<=0) or (Abs(X)>80000) or (Abs(Y)>80000) or (W>80000) or (H>80000) then
      raise Exception.Create('Invalid layout geometry.');
    Item.Bounds:=TRectF.Create(X,Y,X+W,Y+H);
    Item.Shape:=Round(JNum(TJSONObject(V),'shape',0)); Item.Number:=Round(JNum(TJSONObject(V),'number',1));
    if not (Item.Shape in [0,1,2,3]) then raise Exception.Create('Unsupported layout shape.');
    if (Item.Shape<>3) and ((W<1) or (H<1)) then raise Exception.Create('Invalid layout geometry.');
    Item.Vertices:=nil;
    if Item.Shape=3 then begin Item.Vertices:=ReadPoints(TJSONObject(V)); Item.Bounds:=PolygonBounds(Item.Vertices); end;
    Panels.Add(Item);
  end;
end;
procedure SeedLayouts(List: TObjectList<TComicLayout>);
var L: TComicLayout; Kind: Integer;
  procedure Add(X,Y,R,B: Single);
  var Item: TLayoutPanel;
  begin Item.Bounds:=TRectF.Create(X,Y,R,B); Item.Shape:=0; Item.Number:=L.Panels.Count+1; L.Panels.Add(Item); end;
begin
  for Kind:=1 to 5 do begin
    L:=TComicLayout.Create; L.BuiltIn:=True; L.ID:='builtin-'+IntToStr(Kind); List.Add(L);
    case Kind of
      1: begin L.Name:='全面・1コマ'; Add(60,60,1140,1640); end;
      2: begin L.Name:='上下・2コマ'; Add(60,60,1140,838); Add(60,862,1140,1640); end;
      3: begin L.Name:='縦・2コマ'; Add(612,60,1140,1640); Add(60,60,588,1640); end;
      4: begin L.Name:='標準・4コマ'; Add(612,60,1140,838); Add(60,60,588,838);
        Add(612,862,1140,1640); Add(60,862,588,1640); end;
      5: begin L.Name:='大コマ＋2コマ'; Add(60,60,1140,974); Add(612,998,1140,1640); Add(60,998,588,1640); end;
    end;
  end;
end;
procedure SaveLayouts(List: TObjectList<TComicLayout>; const FileName: string);
var J: TJSONObject; A: TJSONArray; L: TComicLayout; Panel: TLayoutPanel; Version: Integer;
begin
  J:=TJSONObject.Create;
  try
    Version:=1; for L in List do for Panel in L.Panels do if Panel.Shape=3 then Version:=2;
    J.AddPair('version',TJSONNumber.Create(Version)); A:=TJSONArray.Create; J.AddPair('layouts',A);
    for L in List do if not L.BuiltIn then A.AddElement(L.Json);
    AtomicWrite(FileName,J.ToJSON);
  finally J.Free; end;
end;
procedure LoadLayouts(List: TObjectList<TComicLayout>; const FileName: string);
var J,V: TJSONValue; A: TJSONArray; L: TComicLayout; Prepared: TObjectList<TComicLayout>;
  IDs: TDictionary<string,Boolean>;
begin
  if not FileExists(FileName) then Exit;
  Prepared:=TObjectList<TComicLayout>.Create; IDs:=TDictionary<string,Boolean>.Create;
  J:=TJSONObject.ParseJSONValue(TFile.ReadAllText(FileName,TEncoding.UTF8));
  try
    if not (J is TJSONObject) then raise Exception.Create('Invalid layout library.');
    if not (Round(JNum(TJSONObject(J),'version',0)) in [1,2]) then raise Exception.Create('Unsupported layout library version.');
    A:=TJSONObject(J).GetValue<TJSONArray>('layouts');
    if A=nil then raise Exception.Create('Invalid layout library.');
    for L in List do IDs.Add(L.ID,True);
    for V in A do begin
      if not (V is TJSONObject) then raise Exception.Create('Invalid layout.');
      L:=TComicLayout.Create; Prepared.Add(L); L.Read(TJSONObject(V));
      if IDs.ContainsKey(L.ID) then raise Exception.Create('Duplicate layout ID.'); IDs.Add(L.ID,True);
    end;
    while Prepared.Count>0 do List.Add(Prepared.Extract(Prepared[0]));
  finally J.Free; IDs.Free; Prepared.Free; end;
end;
end.
