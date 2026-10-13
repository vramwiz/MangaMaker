unit ComicModel;

interface

uses Winapi.Windows, System.SysUtils, System.Classes, System.Types, System.JSON,
  System.Generics.Collections, System.IOUtils, System.Math, ComicGeometry;

type
  TComicAsset = class
    ID, ParentID, Name, Notes, FileName: string;
    constructor Create;
    function Json: TJSONObject;
    procedure Read(J: TJSONObject);
  end;
  TComicPanel = class
    ID, ImageID: string;
    Bounds: TRectF;
    Shape, Number: Integer;
    Vertices: TArray<TPointF>;
    Zoom, PanX, PanY: Double;
    constructor Create;
    function Json: TJSONObject;
    procedure Read(J: TJSONObject);
    procedure SetVertices(const Points: TArray<TPointF>);
    procedure SetBounds(const Value: TRectF);
    function Outline: TArray<TPointF>;
    function CanSplit: Boolean;
  end;
  TComicBalloon = class
    ID, PanelID, Text: string;
    Bounds: TRectF;
    Shape, FontSize: Integer;
    Vertical, Transparent, Overflow, HasTail: Boolean;
    TailX, TailY: Double;
    constructor Create;
    function Json: TJSONObject;
    procedure Read(J: TJSONObject);
  end;
  TComicPage = class
    ID: string;
    Revision, OutputRevision: Integer;
    Panels: TObjectList<TComicPanel>;
    Balloons: TObjectList<TComicBalloon>;
    constructor Create;
    destructor Destroy; override;
    function Json: TJSONObject;
    procedure Read(J: TJSONObject);
  end;
  TComicProject = class
    ID, Title, Episode, Folder: string;
    Width, Height, ExportCount: Integer;
    Assets: TObjectList<TComicAsset>;
    Pages: TObjectList<TComicPage>;
    constructor Create;
    destructor Destroy; override;
    function Json: TJSONObject;
    function Snapshot: string;
    procedure Restore(const S: string);
    procedure Save;
    procedure SaveDraft;
    procedure Load(const FileName: string);
    procedure Initialize(const ATitle, AEpisode: string);
    function Asset(const UID: string): TComicAsset;
    function ImagePath(const UID: string): string;
    function ImportImage(const FileName, ParentID: string): TComicAsset;
  end;

function NewUID: string;
function DataRoot: string;
procedure AtomicWrite(const FileName, Text: string);
function JStr(J: TJSONObject; const Key, Default: string): string;
function JNum(J: TJSONObject; const Key: string; Default: Double): Double;
procedure WriteAssets(List: TObjectList<TComicAsset>; const FileName: string);
procedure ReadAssets(List: TObjectList<TComicAsset>; const FileName: string);
function SafeChild(const Root, Relative: string): string;
function PointsJson(const Points: TArray<TPointF>): TJSONArray;
function ReadPoints(J: TJSONObject): TArray<TPointF>;

implementation

function NewUID: string;
begin Result := TGUID.NewGuid.ToString.Replace('{','').Replace('}',''); end;
function DataRoot: string;
begin
  Result := GetEnvironmentVariable('MANGAMAKER_DATA_ROOT');
  if Result = '' then Result := TPath.Combine(TPath.GetDocumentsPath, 'MangaMaker');
end;
procedure AtomicWrite(const FileName, Text: string);
var Temp: string;
begin
  ForceDirectories(ExtractFilePath(FileName));
  Temp := FileName + '.tmp';
  TFile.WriteAllText(Temp, Text, TEncoding.UTF8);
  if not MoveFileEx(PChar(Temp),PChar(FileName),MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH) then RaiseLastOSError;
end;
function SafeChild(const Root, Relative: string): string;
var Base: string;
begin
  Base := IncludeTrailingPathDelimiter(TPath.GetFullPath(Root));
  Result := TPath.GetFullPath(TPath.Combine(Base, Relative));
  if not Result.StartsWith(Base, True) then
    raise Exception.Create('保存先の外を参照するパスは読み込めません。');
end;
function JStr(J: TJSONObject; const Key, Default: string): string;
var V: TJSONValue;
begin V := J.GetValue(Key); if V = nil then Result := Default else Result := V.Value; end;
function JNum(J: TJSONObject; const Key: string; Default: Double): Double;
var V: TJSONValue;
begin
  V := J.GetValue(Key); Result := Default;
  if V is TJSONNumber then Result := TJSONNumber(V).AsDouble;
end;
procedure Put(J: TJSONObject; const Key: string; N: Double); overload;
begin J.AddPair(Key, TJSONNumber.Create(N)); end;
procedure Put(J: TJSONObject; const Key: string; B: Boolean); overload;
begin J.AddPair(Key, TJSONBool.Create(B)); end;
function Flag(J: TJSONObject; const Key: string; Default: Boolean): Boolean;
begin Result := SameText(JStr(J, Key, BoolToStr(Default, True)), 'true'); end;
procedure PutRect(J: TJSONObject; const R: TRectF);
begin Put(J,'x',R.Left); Put(J,'y',R.Top); Put(J,'w',R.Width); Put(J,'h',R.Height); end;
function ReadRect(J: TJSONObject): TRectF;
begin
  Result := TRectF.Create(JNum(J,'x',80),JNum(J,'y',80),0,0);
  Result.Right := Result.Left + JNum(J,'w',400);
  Result.Bottom := Result.Top + JNum(J,'h',400);
end;
function PointsJson(const Points: TArray<TPointF>): TJSONArray;
var P: TPointF; J: TJSONObject;
begin
  Result:=TJSONArray.Create;
  for P in Points do begin J:=TJSONObject.Create; Put(J,'x',P.X); Put(J,'y',P.Y); Result.AddElement(J); end;
end;
function ReadPoints(J: TJSONObject): TArray<TPointF>;
var A: TJSONArray; I: Integer; V: TJSONValue;
begin
  A:=J.GetValue<TJSONArray>('vertices'); if (A=nil) or (A.Count<3) or (A.Count>256) then
    raise Exception.Create('Invalid polygon vertices.');
  SetLength(Result,A.Count);
  for I:=0 to A.Count-1 do begin
    V:=A.Items[I]; if not (V is TJSONObject) then raise Exception.Create('Invalid polygon vertex.');
    Result[I]:=TPointF.Create(JNum(TJSONObject(V),'x',NaN),JNum(TJSONObject(V),'y',NaN));
  end;
  if not ValidPolygon(Result) then raise Exception.Create('Invalid polygon geometry.');
end;

constructor TComicAsset.Create;
begin inherited; ID := NewUID; end;
function TComicAsset.Json: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id',ID); Result.AddPair('parentId',ParentID);
  Result.AddPair('name',Name); Result.AddPair('notes',Notes); Result.AddPair('file',FileName);
end;
procedure TComicAsset.Read(J: TJSONObject);
begin
  ID:=JStr(J,'id',ID); ParentID:=JStr(J,'parentId',''); Name:=JStr(J,'name','');
  Notes:=JStr(J,'notes',''); FileName:=JStr(J,'file','');
end;
constructor TComicPanel.Create;
begin inherited; ID:=NewUID; Zoom:=1; Number:=1; Bounds:=TRectF.Create(80,80,1120,1620); end;
function TComicPanel.Json: TJSONObject;
begin
  Result:=TJSONObject.Create; Result.AddPair('id',ID); Result.AddPair('imageId',ImageID);
  PutRect(Result,Bounds); Put(Result,'shape',Shape); Put(Result,'number',Number);
  Put(Result,'zoom',Zoom); Put(Result,'panX',PanX); Put(Result,'panY',PanY);
  if Shape=3 then Result.AddPair('vertices',PointsJson(Vertices));
end;
procedure TComicPanel.Read(J: TJSONObject);
begin
  ID:=JStr(J,'id',ID); ImageID:=JStr(J,'imageId',''); Bounds:=ReadRect(J);
  Shape:=Round(JNum(J,'shape',0)); Number:=Round(JNum(J,'number',1));
  Zoom:=JNum(J,'zoom',1); PanX:=JNum(J,'panX',0); PanY:=JNum(J,'panY',0);
  Vertices:=nil;
  if not (Shape in [0,1,2,3]) then raise Exception.Create('Unsupported panel shape.');
  if Shape=3 then SetVertices(ReadPoints(J));
end;
procedure TComicPanel.SetVertices(const Points: TArray<TPointF>);
begin
  if not ValidPolygon(Points) then raise Exception.Create('Invalid polygon geometry.');
  Vertices:=Copy(Points,0,Length(Points)); Shape:=3; Bounds:=PolygonBounds(Vertices);
end;
procedure TComicPanel.SetBounds(const Value: TRectF);
var I: Integer;
begin
  if Shape=3 then begin
    if (Bounds.Width<=0) or (Bounds.Height<=0) or (Value.Width<=0) or (Value.Height<=0) then
      raise Exception.Create('Invalid polygon bounds.');
    for I:=0 to High(Vertices) do Vertices[I]:=TPointF.Create(
      Value.Left+(Vertices[I].X-Bounds.Left)*Value.Width/Bounds.Width,
      Value.Top+(Vertices[I].Y-Bounds.Top)*Value.Height/Bounds.Height);
  end;
  Bounds:=Value;
end;
function TComicPanel.Outline: TArray<TPointF>;
begin
  if Shape=3 then Result:=Copy(Vertices,0,Length(Vertices))
  else Result:=[Bounds.TopLeft,TPointF.Create(Bounds.Right,Bounds.Top),Bounds.BottomRight,TPointF.Create(Bounds.Left,Bounds.Bottom)];
end;
function TComicPanel.CanSplit: Boolean;
begin Result:=(Shape in [0,3]) and ConvexPolygon(Outline); end;
constructor TComicBalloon.Create;
begin
  inherited; ID:=NewUID; Text:='セリフ'; FontSize:=40; Shape:=1; Overflow:=True;
  Bounds:=TRectF.Create(100,100,350,420);
end;
function TComicBalloon.Json: TJSONObject;
begin
  Result:=TJSONObject.Create; Result.AddPair('id',ID); Result.AddPair('panelId',PanelID);
  Result.AddPair('text',Text); PutRect(Result,Bounds); Put(Result,'shape',Shape);
  Put(Result,'fontSize',FontSize); Put(Result,'vertical',Vertical);
  Put(Result,'transparent',Transparent); Put(Result,'overflow',Overflow);
  Put(Result,'hasTail',HasTail); Put(Result,'tailX',TailX); Put(Result,'tailY',TailY);
end;
procedure TComicBalloon.Read(J: TJSONObject);
begin
  ID:=JStr(J,'id',ID); PanelID:=JStr(J,'panelId',''); Text:=JStr(J,'text',''); Bounds:=ReadRect(J);
  Shape:=Round(JNum(J,'shape',1)); FontSize:=Round(JNum(J,'fontSize',40));
  Vertical:=Flag(J,'vertical',False); Transparent:=Flag(J,'transparent',False);
  Overflow:=Flag(J,'overflow',True); HasTail:=Flag(J,'hasTail',False);
  TailX:=JNum(J,'tailX',0); TailY:=JNum(J,'tailY',0);
end;
constructor TComicPage.Create;
begin
  inherited; ID:=NewUID; Revision:=1; OutputRevision:=-1;
  Panels:=TObjectList<TComicPanel>.Create; Balloons:=TObjectList<TComicBalloon>.Create;
end;
destructor TComicPage.Destroy;
begin Panels.Free; Balloons.Free; inherited; end;
function TComicPage.Json: TJSONObject;
var A: TJSONArray; P: TComicPanel; B: TComicBalloon;
begin
  Result:=TJSONObject.Create; Result.AddPair('id',ID);
  Put(Result,'revision',Revision); Put(Result,'outputRevision',OutputRevision);
  A:=TJSONArray.Create; Result.AddPair('panels',A); for P in Panels do A.AddElement(P.Json);
  A:=TJSONArray.Create; Result.AddPair('balloons',A); for B in Balloons do A.AddElement(B.Json);
end;
procedure TComicPage.Read(J: TJSONObject);
var V: TJSONValue; A: TJSONArray; P: TComicPanel; B: TComicBalloon;
begin
  ID:=JStr(J,'id',ID); Revision:=Round(JNum(J,'revision',1)); OutputRevision:=Round(JNum(J,'outputRevision',-1));
  Panels.Clear; Balloons.Clear;
  A:=J.GetValue<TJSONArray>('panels'); if A<>nil then for V in A do begin
    if not (V is TJSONObject) then raise Exception.Create('コマデータが不正です。');
    P:=TComicPanel.Create; Panels.Add(P); P.Read(TJSONObject(V)); end;
  A:=J.GetValue<TJSONArray>('balloons'); if A<>nil then for V in A do begin
    if not (V is TJSONObject) then raise Exception.Create('吹き出しデータが不正です。');
    B:=TComicBalloon.Create; Balloons.Add(B); B.Read(TJSONObject(V)); end;
end;
constructor TComicProject.Create;
begin inherited; Width:=1200; Height:=1700; Assets:=TObjectList<TComicAsset>.Create; Pages:=TObjectList<TComicPage>.Create; end;
destructor TComicProject.Destroy;
begin Assets.Free; Pages.Free; inherited; end;
function TComicProject.Json: TJSONObject;
var A: TJSONArray; P: TComicPage; I: TComicAsset; Panel: TComicPanel; Version: Integer;
begin
  Version:=1; for P in Pages do for Panel in P.Panels do if Panel.Shape=3 then Version:=2;
  Result:=TJSONObject.Create; Put(Result,'version',Version); Result.AddPair('id',ID);
  Result.AddPair('title',Title); Result.AddPair('episode',Episode);
  Put(Result,'width',Width); Put(Result,'height',Height); Put(Result,'exportCount',ExportCount);
  A:=TJSONArray.Create; Result.AddPair('assets',A); for I in Assets do A.AddElement(I.Json);
  A:=TJSONArray.Create; Result.AddPair('pages',A); for P in Pages do A.AddElement(P.Json);
end;
function TComicProject.Snapshot: string;
var J: TJSONObject;
begin J:=Json; try Result:=J.ToJSON; finally J.Free; end; end;
procedure TComicProject.Restore(const S: string);
var J: TJSONObject; V: TJSONValue; A: TJSONArray; P: TComicPage; I: TComicAsset;
begin
  V:=TJSONObject.ParseJSONValue(S);
  if not (V is TJSONObject) then begin V.Free; raise Exception.Create('JSONを読み込めません。'); end;
  J:=TJSONObject(V);
  try
    if not (Round(JNum(J,'version',0)) in [1,2]) then raise Exception.Create('未対応のプロジェクト形式です。');
    ID:=JStr(J,'id',''); Title:=JStr(J,'title',''); Episode:=JStr(J,'episode','');
    Width:=Round(JNum(J,'width',1200)); Height:=Round(JNum(J,'height',1700));
    if (Width<100) or (Width>8000) or (Height<100) or (Height>8000) then raise Exception.Create('出力解像度が不正です。');
    ExportCount:=Round(JNum(J,'exportCount',0)); Assets.Clear; Pages.Clear;
    A:=J.GetValue<TJSONArray>('assets'); if A<>nil then for V in A do begin
      if not (V is TJSONObject) then raise Exception.Create('画像データが不正です。');
      I:=TComicAsset.Create; Assets.Add(I); I.Read(TJSONObject(V));
      if I.FileName<>'' then SafeChild(Folder,I.FileName);
    end;
    A:=J.GetValue<TJSONArray>('pages'); if A<>nil then for V in A do begin
      if not (V is TJSONObject) then raise Exception.Create('ページデータが不正です。');
      P:=TComicPage.Create; Pages.Add(P); P.Read(TJSONObject(V));
      if (P.ID='') or (P.ID<>ExtractFileName(P.ID)) or P.ID.Contains('..') then raise Exception.Create('ページIDが不正です。');
    end;
  finally J.Free; end;
end;
procedure TComicProject.Save;
begin AtomicWrite(TPath.Combine(Folder,'Project.json'),Snapshot); SaveDraft; end;
procedure TComicProject.SaveDraft;
var P: TComicPage; J: TJSONObject;
begin
  if Folder='' then Exit;
  AtomicWrite(TPath.Combine(Folder,'Draft.json'),Snapshot);
  for P in Pages do begin J:=P.Json; try AtomicWrite(SafeChild(Folder,'Pages\'+P.ID+'.json'),J.ToJSON); finally J.Free; end; end;
end;
procedure TComicProject.Load(const FileName: string);
begin Folder:=ExtractFilePath(TPath.GetFullPath(FileName)); Restore(TFile.ReadAllText(FileName,TEncoding.UTF8)); end;
procedure TComicProject.Initialize(const ATitle, AEpisode: string);
begin
  ID:=NewUID; Title:=ATitle; Episode:=AEpisode;
  Folder:=TPath.Combine(DataRoot,'Projects\'+ID);
  ForceDirectories(TPath.Combine(Folder,'Images')); ForceDirectories(TPath.Combine(Folder,'Pages'));
  ForceDirectories(TPath.Combine(Folder,'Output')); Pages.Add(TComicPage.Create); Save;
end;
function TComicProject.Asset(const UID: string): TComicAsset;
var A: TComicAsset;
begin Result:=nil; for A in Assets do if A.ID=UID then Exit(A); end;
function TComicProject.ImagePath(const UID: string): string;
var A: TComicAsset;
begin Result:=''; A:=Asset(UID); if (A<>nil) and (A.FileName<>'') then Result:=SafeChild(Folder,A.FileName); end;
function TComicProject.ImportImage(const FileName, ParentID: string): TComicAsset;
begin
  Result:=TComicAsset.Create;
  try
    Result.ParentID:=ParentID; Result.Name:=TPath.GetFileNameWithoutExtension(FileName);
    Result.FileName:='Images\'+Result.ID+LowerCase(ExtractFileExt(FileName));
    TFile.Copy(FileName,SafeChild(Folder,Result.FileName),False); Assets.Add(Result);
  except Result.Free; raise; end;
end;
procedure WriteAssets(List: TObjectList<TComicAsset>; const FileName: string);
var A: TJSONArray; I: TComicAsset;
begin A:=TJSONArray.Create; try for I in List do A.AddElement(I.Json); AtomicWrite(FileName,A.ToJSON); finally A.Free; end; end;
procedure ReadAssets(List: TObjectList<TComicAsset>; const FileName: string);
var J,V: TJSONValue; I: TComicAsset;
begin
  if not TFile.Exists(FileName) then Exit;
  J:=TJSONObject.ParseJSONValue(TFile.ReadAllText(FileName,TEncoding.UTF8));
  try
    if not (J is TJSONArray) then raise Exception.Create('キャラ情報を読み込めません。');
    for V in TJSONArray(J) do begin
      if not (V is TJSONObject) then raise Exception.Create('キャラ情報が不正です。');
      I:=TComicAsset.Create; List.Add(I); I.Read(TJSONObject(V));
      if I.FileName<>'' then SafeChild(TPath.Combine(DataRoot,'Characters'),I.FileName);
    end;
  finally J.Free; end;
end;
end.
