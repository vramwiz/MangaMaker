unit ComicModel;

// 責務：作品・素材・コマ・吹き出しの永続モデルを持ち、検証と保存の整合を守る。

interface

uses Winapi.Windows, System.SysUtils, System.Classes, System.Types, System.UITypes, System.JSON,
  System.Generics.Collections, System.IOUtils, System.Math, ComicGeometry;

type
  TComicPageBasis = record
    Width,Height,Left,Top,Right,Bottom: Integer;
    function Valid: Boolean;
    function Same(const Other: TComicPageBasis): Boolean;
    function Frame: TRectF;
  end;
  TComicAsset = class
    ID, ParentID, Name, Notes, FileName: string;
    CharacterID,CharacterName,CharacterNotes,StateName: string;
    SourceID,SceneID,TitleText,EpisodeText: string;
    CharacterRefs: TArray<string>;
    TitleImage: Boolean;
    constructor Create;
    function Json: TJSONObject;
    procedure Read(J: TJSONObject);
  end;
  TComicOverlay = class
    ID,MaterialID,FileName: string;
    Bounds: TRectF;
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
    FilterKind,FilterStrength,FrameKind: Integer;
    BorderWidth: Double;
    BorderColor: TColor;
    Overlays: TObjectList<TComicOverlay>;
    constructor Create;
    destructor Destroy; override;
    function Json: TJSONObject;
    procedure Read(J: TJSONObject);
    procedure SetVertices(const Points: TArray<TPointF>);
    procedure SetBounds(const Value: TRectF);
    function Outline: TArray<TPointF>;
    function CanSplit: Boolean;
  end;
  TComicTailKind = (ctTriangle,ctThought);
  TComicTail = class
    ID: string;
    Kind: TComicTailKind;
    Root,Tip: TPointF;
    Width: Double;
    constructor Create;
    function Valid: Boolean;
    function Json: TJSONObject;
    procedure Read(J: TJSONObject);
    function Handles: TArray<TPointF>;
  end;
  TComicTailState = record
    Root,Tip: TPointF;
    Width: Double;
  end;
  TComicBalloonTransform = record
    Bounds: TRectF;
    FontSize: Integer;
    TextOffset: TPointF;
    TextLayoutSize: TSizeF;
    TextLayoutFontSize: Integer;
    Tails: TArray<TComicTailState>;
  end;
  TComicBalloonContour = (bcPlain,bcJagged,bcWave,bcCloud);
  TComicBalloon = class
  private
    FTipX,FTipY: Double;
    function GetHasTail: Boolean;
    procedure SetHasTail(Value: Boolean);
    function GetTailX: Double;
    function GetTailY: Double;
    procedure SetTailX(Value: Double);
    procedure SetTailY(Value: Double);
  public
    ID, PanelID, Text: string;
    Bounds: TRectF;
    Shape, FontSize: Integer;
    Contour: TComicBalloonContour;
    FontFamily: string;
    FontColor: TColor;
    FontStyle: TFontStyles;
    BorderColor,FillColor: TColor;
    BorderWidth: Double;
    TextOffset: TPointF;
    TextLayoutSize: TSizeF;
    TextLayoutFontSize: Integer;
    Vertical, Transparent, Overflow: Boolean;
    Tails: TObjectList<TComicTail>;
    property HasTail: Boolean read GetHasTail write SetHasTail;
    property TailX: Double read GetTailX write SetTailX;
    property TailY: Double read GetTailY write SetTailY;
    constructor Create;
    destructor Destroy; override;
    function Json: TJSONObject;
    procedure Read(J: TJSONObject);
    function CaptureTransform: TComicBalloonTransform;
    procedure ResetTextLayout;
    function ApplyTransform(const Source: TComicBalloonTransform; const Target: TRectF): Boolean;
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
    GenerationPresetID,GenerationPresetName,GenerationInstructions: string;
    Width, Height, ExportCount: Integer;
    MarginLeft,MarginTop,MarginRight,MarginBottom: Integer;
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
    function PageBasis: TComicPageBasis;
    procedure SetPageBasis(const Value: TComicPageBasis);
  end;

function NewUID: string;
function DataRoot: string;
procedure AtomicWrite(const FileName, Text: string);
function JStr(J: TJSONObject; const Key, Default: string): string;
function JNum(J: TJSONObject; const Key: string; Default: Double): Double;
procedure WriteAssets(List: TObjectList<TComicAsset>; const FileName: string);
procedure ReadAssets(List: TObjectList<TComicAsset>; const FileName: string);
procedure ValidateAssetTree(List: TObjectList<TComicAsset>);
function SafeChild(const Root, Relative: string): string;
function PointsJson(const Points: TArray<TPointF>): TJSONArray;
function ReadPoints(J: TJSONObject): TArray<TPointF>;

implementation
{$IFDEF DEBUG}uses ComicPerformance;{$ENDIF}

function TComicPageBasis.Valid: Boolean;
begin
  Result:=(Width>=100) and (Width<=8000) and (Height>=100) and (Height<=8000) and
    (Left>=0) and (Top>=0) and (Right>=0) and (Bottom>=0) and
    (Left<Width) and (Right<Width-Left) and (Top<Height) and (Bottom<Height-Top);
end;
function TComicPageBasis.Same(const Other: TComicPageBasis): Boolean;
begin Result:=(Width=Other.Width) and (Height=Other.Height) and (Left=Other.Left) and
  (Top=Other.Top) and (Right=Other.Right) and (Bottom=Other.Bottom); end;
function TComicPageBasis.Frame: TRectF;
begin Result:=TRectF.Create(Left,Top,Width-Right,Height-Bottom); end;

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
  // 本体への途中書込を避け、完成した一時ファイルだけを置換する。置換失敗は呼出側へ返す。
  ForceDirectories(ExtractFilePath(FileName));
  Temp := FileName + '.tmp';
  TFile.WriteAllText(Temp, Text, TEncoding.UTF8);
  if not MoveFileEx(PChar(Temp),PChar(FileName),MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH) then RaiseLastOSError;
end;
function SafeChild(const Root, Relative: string): string;
var Base: string;
begin
  // 正規化後の保存先で境界を検証し、相対パスから作品フォルダー外を参照させない。
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
var References: TJSONArray; Ref: string;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id',ID); Result.AddPair('parentId',ParentID);
  Result.AddPair('name',Name); Result.AddPair('notes',Notes); Result.AddPair('file',FileName);
  Result.AddPair('characterId',CharacterID); Result.AddPair('characterName',CharacterName);
  Result.AddPair('characterNotes',CharacterNotes); Result.AddPair('stateName',StateName);
  Result.AddPair('sourceId',SourceID); Result.AddPair('sceneId',SceneID); Put(Result,'titleImage',TitleImage);
  Result.AddPair('titleText',TitleText); Result.AddPair('episodeText',EpisodeText);
  References:=TJSONArray.Create; Result.AddPair('characterIds',References); for Ref in CharacterRefs do References.Add(Ref);
end;
procedure TComicAsset.Read(J: TJSONObject);
var Value: TJSONValue; References: TJSONArray; IDs: TDictionary<string,Boolean>; I: Integer; Ref: string;
begin
  ID:=JStr(J,'id',ID); ParentID:=JStr(J,'parentId',''); Name:=JStr(J,'name','');
  Notes:=JStr(J,'notes',''); FileName:=JStr(J,'file','');
  CharacterID:=JStr(J,'characterId',''); CharacterName:=JStr(J,'characterName','');
  CharacterNotes:=JStr(J,'characterNotes',''); StateName:=JStr(J,'stateName','');
  SourceID:=JStr(J,'sourceId',''); SceneID:=JStr(J,'sceneId',''); TitleText:=JStr(J,'titleText',''); EpisodeText:=JStr(J,'episodeText','');
  TitleImage:=Flag(J,'titleImage',False); CharacterRefs:=nil; Value:=J.GetValue('characterIds');
  if Value<>nil then begin
    if not (Value is TJSONArray) then raise Exception.Create('参照人物の指定が不正です。');
    References:=TJSONArray(Value); if References.Count>256 then raise Exception.Create('参照人物が多すぎます。');
    IDs:=TDictionary<string,Boolean>.Create;
    try
      SetLength(CharacterRefs,References.Count);
      for I:=0 to References.Count-1 do begin
        if not (References[I] is TJSONString) then raise Exception.Create('参照人物IDが不正です。'); Ref:=References[I].Value;
        if (Ref='') or (Length(Ref)>200) or (Pos(#0,Ref)>0) or IDs.ContainsKey(Ref) then raise Exception.Create('参照人物IDが空か重複しています。');
        IDs.Add(Ref,True); CharacterRefs[I]:=Ref;
      end;
    finally IDs.Free; end;
  end;
  if (ID='') or (Length(ID)>200) or (Pos(#0,ID)>0) or (Pos('\',ID)>0) or (Pos('/',ID)>0) or
    (Length(ParentID)>200) or (Pos(#0,ParentID)>0) or (Length(Name)>200) or (Length(Notes)>65536) or
    (Length(CharacterID)>200) or (Length(CharacterName)>200) or (Length(StateName)>200) or (Length(CharacterNotes)>65536) then
    raise Exception.Create('素材のID・名前・補足情報が不正です。');
  if (Length(SourceID)>200) or (Length(SceneID)>200) or (Length(TitleText)>200) or (Length(EpisodeText)>200) then
    raise Exception.Create('場面やタイトルの情報が不正です。');
end;
constructor TComicOverlay.Create;
begin inherited; ID:=NewUID; Bounds:=TRectF.Create(0,0,1,1); end;
function TComicOverlay.Json: TJSONObject;
begin Result:=TJSONObject.Create; Result.AddPair('id',ID); Result.AddPair('materialId',MaterialID); Result.AddPair('file',FileName); PutRect(Result,Bounds); end;
procedure TComicOverlay.Read(J: TJSONObject);
begin
  ID:=JStr(J,'id',ID); MaterialID:=JStr(J,'materialId',''); FileName:=JStr(J,'file',''); Bounds:=ReadRect(J);
  if (ID='') or (Length(ID)>200) or (MaterialID='') or (Length(MaterialID)>200) or
    IsNan(Bounds.Left) or IsNan(Bounds.Top) or IsNan(Bounds.Width) or IsNan(Bounds.Height) or
    IsInfinite(Bounds.Left) or IsInfinite(Bounds.Top) or IsInfinite(Bounds.Width) or IsInfinite(Bounds.Height) or
    (Abs(Bounds.Left)>1000) or (Abs(Bounds.Top)>1000) or (Bounds.Width<=0) or (Bounds.Height<=0) or
    (Bounds.Width>1000) or (Bounds.Height>1000) then raise Exception.Create('効果素材の配置が不正です。');
end;
constructor TComicPanel.Create;
begin inherited; ID:=NewUID; Zoom:=1; Number:=1; Bounds:=TRectF.Create(80,80,1120,1620);
  Overlays:=TObjectList<TComicOverlay>.Create; BorderWidth:=4; FilterStrength:=100; end;
destructor TComicPanel.Destroy;
begin Overlays.Free; inherited; end;
function TComicPanel.Json: TJSONObject;
var Overlay: TComicOverlay; Items: TJSONArray;
begin
  Result:=TJSONObject.Create; Result.AddPair('id',ID); Result.AddPair('imageId',ImageID);
  PutRect(Result,Bounds); Put(Result,'shape',Shape); Put(Result,'number',Number);
  Put(Result,'zoom',Zoom); Put(Result,'panX',PanX); Put(Result,'panY',PanY);
  Put(Result,'filterKind',FilterKind); Put(Result,'filterStrength',FilterStrength); Put(Result,'frameKind',FrameKind);
  Put(Result,'borderWidth',BorderWidth); Put(Result,'borderColor',BorderColor);
  Items:=TJSONArray.Create; Result.AddPair('overlays',Items); for Overlay in Overlays do Items.AddElement(Overlay.Json);
  if Shape=3 then Result.AddPair('vertices',PointsJson(Vertices));
end;
procedure TComicPanel.Read(J: TJSONObject);
var Items: TJSONArray; Value: TJSONValue; Overlay: TComicOverlay; IDs: TDictionary<string,Boolean>;
begin
  ID:=JStr(J,'id',ID); ImageID:=JStr(J,'imageId',''); Bounds:=ReadRect(J);
  Shape:=Round(JNum(J,'shape',0)); Number:=Round(JNum(J,'number',1));
  Zoom:=JNum(J,'zoom',1); PanX:=JNum(J,'panX',0); PanY:=JNum(J,'panY',0);
  FilterKind:=Round(JNum(J,'filterKind',0)); FilterStrength:=Round(JNum(J,'filterStrength',100)); FrameKind:=Round(JNum(J,'frameKind',0));
  BorderWidth:=JNum(J,'borderWidth',4); BorderColor:=Round(JNum(J,'borderColor',0));
  if not (FilterKind in [0..4]) or not (FilterStrength in [0..100]) or not (FrameKind in [0..2]) or
    IsNan(BorderWidth) or IsInfinite(BorderWidth) or (BorderWidth<0) or (BorderWidth>100) then raise Exception.Create('コマの効果設定が不正です。');
  Overlays.Clear; Value:=J.GetValue('overlays');
  if Value<>nil then begin
    if not (Value is TJSONArray) then raise Exception.Create('効果素材データが不正です。'); Items:=TJSONArray(Value);
    if Items.Count>1000 then raise Exception.Create('コマの効果素材が多すぎます。');
    IDs:=TDictionary<string,Boolean>.Create;
    try for Value in Items do begin
      if not (Value is TJSONObject) then raise Exception.Create('効果素材データが不正です。');
      Overlay:=TComicOverlay.Create; Overlays.Add(Overlay); Overlay.Read(TJSONObject(Value));
      if IDs.ContainsKey(Overlay.ID) then raise Exception.Create('効果素材IDが重複しています。'); IDs.Add(Overlay.ID,True);
    end; finally IDs.Free; end;
  end;
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
var I: Integer; Candidate: TArray<TPointF>;
begin
  if Shape=3 then begin
    if (Bounds.Width<=0) or (Bounds.Height<=0) or (Value.Width<=0) or (Value.Height<=0) then
      raise Exception.Create('Invalid polygon bounds.');
    SetLength(Candidate,Length(Vertices));
    for I:=0 to High(Vertices) do Candidate[I]:=TPointF.Create(
      Value.Left+(Vertices[I].X-Bounds.Left)*Value.Width/Bounds.Width,
      Value.Top+(Vertices[I].Y-Bounds.Top)*Value.Height/Bounds.Height);
    if not ValidPolygon(Candidate) then raise Exception.Create('Invalid resized polygon geometry.');
    Vertices:=Candidate;
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
  inherited; ID:=NewUID; Text:='セリフ'; FontSize:=40; FontFamily:='Yu Gothic'; FontColor:=0; Shape:=1; Overflow:=True;
  Tails:=TObjectList<TComicTail>.Create;
  BorderColor:=0; FillColor:=$FFFFFF; BorderWidth:=3;
  Bounds:=TRectF.Create(100,100,350,420);
end;
constructor TComicTail.Create;
begin inherited; ID:=NewUID; Width:=40; end;
function TComicTail.Valid: Boolean;
  function Coordinate(Value: Double): Boolean;
  begin Result:=not IsNan(Value) and not IsInfinite(Value) and (Abs(Value)<=80000); end;
begin
  Result:=Coordinate(Root.X) and Coordinate(Root.Y) and Coordinate(Tip.X) and Coordinate(Tip.Y) and
    not IsNan(Width) and not IsInfinite(Width) and (Width>=1) and (Width<=2000) and
    (Hypot(Double(Tip.X)-Root.X,Double(Tip.Y)-Root.Y)>=1);
end;
function TComicTail.Handles: TArray<TPointF>;
var Length,DX,DY: Double;
begin
  DX:=Tip.X-Root.X; DY:=Tip.Y-Root.Y; Length:=Max(1,Hypot(DX,DY));
  Result:=[Root,TPointF.Create(Root.X-DY/Length*Width/2,Root.Y+DX/Length*Width/2),Tip];
end;
function TComicTail.Json: TJSONObject;
begin
  Result:=TJSONObject.Create; Result.AddPair('id',ID);
  if Kind=ctThought then Result.AddPair('kind','thought') else Result.AddPair('kind','triangle');
  Put(Result,'rootX',Root.X); Put(Result,'rootY',Root.Y); Put(Result,'tipX',Tip.X); Put(Result,'tipY',Tip.Y); Put(Result,'width',Width);
end;
procedure TComicTail.Read(J: TJSONObject);
var Name: string;
begin
  ID:=JStr(J,'id',ID); Name:=JStr(J,'kind','triangle');
  if Name='triangle' then Kind:=ctTriangle else if Name='thought' then Kind:=ctThought else raise Exception.Create('しっぽの種類が不正です。');
  Root:=TPointF.Create(JNum(J,'rootX',NaN),JNum(J,'rootY',NaN)); Tip:=TPointF.Create(JNum(J,'tipX',NaN),JNum(J,'tipY',NaN));
  Width:=JNum(J,'width',NaN); if (ID='') or not Valid then raise Exception.Create('しっぽの形状が不正です。');
end;
destructor TComicBalloon.Destroy;
begin Tails.Free; inherited; end;
function TComicBalloon.GetHasTail: Boolean;
begin Result:=Tails.Count>0; end;
procedure TComicBalloon.SetHasTail(Value: Boolean);
var Tail: TComicTail;
begin
  if Value and (Tails.Count=0) then begin Tail:=TComicTail.Create; Tail.Root:=Bounds.CenterPoint;
    Tail.Tip:=TPointF.Create(FTipX,FTipY); Tail.Width:=Max(8,Bounds.Width/6); Tails.Add(Tail); end
  else if not Value then begin if Tails.Count>0 then begin FTipX:=Tails[0].Tip.X; FTipY:=Tails[0].Tip.Y; end; Tails.Clear; end;
end;
function TComicBalloon.GetTailX: Double;
begin Result:=FTipX; if Tails.Count>0 then Result:=Tails[0].Tip.X; end;
function TComicBalloon.GetTailY: Double;
begin Result:=FTipY; if Tails.Count>0 then Result:=Tails[0].Tip.Y; end;
procedure TComicBalloon.SetTailX(Value: Double);
begin FTipX:=Value; if Tails.Count>0 then Tails[0].Tip.X:=Value; end;
procedure TComicBalloon.SetTailY(Value: Double);
begin FTipY:=Value; if Tails.Count>0 then Tails[0].Tip.Y:=Value; end;
function TComicBalloon.Json: TJSONObject;
var A: TJSONArray; Tail: TComicTail;
begin
  Result:=TJSONObject.Create; Result.AddPair('id',ID); Result.AddPair('panelId',PanelID);
  Result.AddPair('text',Text); PutRect(Result,Bounds); Put(Result,'shape',Shape); Put(Result,'contour',Ord(Contour));
  Put(Result,'fontSize',FontSize); Put(Result,'vertical',Vertical);
  Result.AddPair('fontFamily',FontFamily); Put(Result,'fontColor',FontColor);
  Put(Result,'fontBold',TFontStyle.fsBold in FontStyle); Put(Result,'fontItalic',TFontStyle.fsItalic in FontStyle);
  Put(Result,'fontUnderline',TFontStyle.fsUnderline in FontStyle); Put(Result,'fontStrikeOut',TFontStyle.fsStrikeOut in FontStyle);
  Put(Result,'borderColor',BorderColor); Put(Result,'fillColor',FillColor); Put(Result,'borderWidth',BorderWidth);
  Put(Result,'textOffsetX',TextOffset.X); Put(Result,'textOffsetY',TextOffset.Y);
  Put(Result,'textLayoutWidth',TextLayoutSize.cx); Put(Result,'textLayoutHeight',TextLayoutSize.cy);
  Put(Result,'textLayoutFontSize',TextLayoutFontSize);
  Put(Result,'transparent',Transparent); Put(Result,'overflow',Overflow);
  Put(Result,'hasTail',HasTail); Put(Result,'tailX',TailX); Put(Result,'tailY',TailY);
  A:=TJSONArray.Create; Result.AddPair('tails',A); for Tail in Tails do A.AddElement(Tail.Json);
end;
procedure TComicBalloon.Read(J: TJSONObject);
var V: TJSONValue; A: TJSONArray; Tail: TComicTail; IDs: TDictionary<string,Boolean>; ContourValue: Double;
begin
  ID:=JStr(J,'id',ID); PanelID:=JStr(J,'panelId',''); Text:=JStr(J,'text',''); Bounds:=ReadRect(J);
  Shape:=Round(JNum(J,'shape',1)); FontSize:=Round(JNum(J,'fontSize',40));
  if not (Shape in [0..2]) then raise Exception.Create('吹き出しの基本形状が不正です。');
  V:=J.GetValue('contour');
  if (V<>nil) and not (V is TJSONNumber) then raise Exception.Create('吹き出しの輪郭が不正です。');
  ContourValue:=JNum(J,'contour',0);
  if IsNan(ContourValue) or IsInfinite(ContourValue) or (ContourValue<0) or (ContourValue>3) or
    (Frac(ContourValue)<>0) then raise Exception.Create('吹き出しの輪郭が不正です。');
  Contour:=TComicBalloonContour(Trunc(ContourValue));
  if (FontSize<1) or (FontSize>1000) then raise Exception.Create('文字サイズが不正です。');
  FontFamily:=JStr(J,'fontFamily','Yu Gothic'); if FontFamily='' then FontFamily:='Yu Gothic';
  if Length(FontFamily)>200 then raise Exception.Create('フォント名が不正です。');
  FontColor:=Round(JNum(J,'fontColor',0)); FontStyle:=[];
  if Flag(J,'fontBold',False) then Include(FontStyle,TFontStyle.fsBold);
  if Flag(J,'fontItalic',False) then Include(FontStyle,TFontStyle.fsItalic);
  if Flag(J,'fontUnderline',False) then Include(FontStyle,TFontStyle.fsUnderline);
  if Flag(J,'fontStrikeOut',False) then Include(FontStyle,TFontStyle.fsStrikeOut);
  BorderColor:=Round(JNum(J,'borderColor',0)); FillColor:=Round(JNum(J,'fillColor',$FFFFFF)); BorderWidth:=JNum(J,'borderWidth',3);
  if IsNan(BorderWidth) or IsInfinite(BorderWidth) or (BorderWidth<0) or (BorderWidth>100) then raise Exception.Create('吹き出しの縁太さが不正です。');
  TextOffset:=TPointF.Create(JNum(J,'textOffsetX',0),JNum(J,'textOffsetY',0));
  TextLayoutSize:=TSizeF.Create(JNum(J,'textLayoutWidth',0),JNum(J,'textLayoutHeight',0));
  TextLayoutFontSize:=Round(JNum(J,'textLayoutFontSize',0));
  if IsNan(TextLayoutSize.cx) or IsInfinite(TextLayoutSize.cx) or IsNan(TextLayoutSize.cy) or IsInfinite(TextLayoutSize.cy) or
    not (((TextLayoutFontSize=0) and (TextLayoutSize.cx=0) and (TextLayoutSize.cy=0)) or
      ((TextLayoutFontSize>=1) and (TextLayoutFontSize<=1000) and (TextLayoutSize.cx>=1) and (TextLayoutSize.cx<=160000) and
       (TextLayoutSize.cy>=1) and (TextLayoutSize.cy<=160000))) then raise Exception.Create('文字の折返し基準が不正です。');
  if IsNan(TextOffset.X) or IsInfinite(TextOffset.X) or IsNan(TextOffset.Y) or IsInfinite(TextOffset.Y) or
    (Abs(TextOffset.X)>80000) or (Abs(TextOffset.Y)>80000) then raise Exception.Create('文字の配置が不正です。');
  Vertical:=Flag(J,'vertical',False); Transparent:=Flag(J,'transparent',False);
  Overflow:=Flag(J,'overflow',True); Tails.Clear;
  FTipX:=JNum(J,'tailX',0); FTipY:=JNum(J,'tailY',0);
  V:=J.GetValue('tails');
  if V=nil then begin
    HasTail:=Flag(J,'hasTail',False);
    if HasTail then begin Tails[0].ID:=ID+'-legacy-tail'; if not Tails[0].Valid then raise Exception.Create('旧形式のしっぽ形状が不正です。'); end;
  end else begin
    if not (V is TJSONArray) or (TJSONArray(V).Count>64) then raise Exception.Create('しっぽ一覧が不正です。');
    A:=TJSONArray(V); IDs:=TDictionary<string,Boolean>.Create;
    try
      for V in A do begin
        if not (V is TJSONObject) then raise Exception.Create('しっぽ項目が不正です。');
        Tail:=TComicTail.Create; Tails.Add(Tail); Tail.Read(TJSONObject(V));
        if IDs.ContainsKey(Tail.ID) then raise Exception.Create('しっぽIDが重複しています。'); IDs.Add(Tail.ID,True);
      end;
    finally IDs.Free; end;
  end;
end;
function TComicBalloon.CaptureTransform: TComicBalloonTransform;
var I: Integer;
begin
  Result.Bounds:=Bounds; Result.FontSize:=FontSize; Result.TextOffset:=TextOffset;
  Result.TextLayoutSize:=TextLayoutSize; Result.TextLayoutFontSize:=TextLayoutFontSize; SetLength(Result.Tails,Tails.Count);
  for I:=0 to Tails.Count-1 do begin Result.Tails[I].Root:=Tails[I].Root; Result.Tails[I].Tip:=Tails[I].Tip; Result.Tails[I].Width:=Tails[I].Width; end;
end;
procedure TComicBalloon.ResetTextLayout;
begin TextLayoutSize:=TSizeF.Create(0,0); TextLayoutFontSize:=0; end;
function TComicBalloon.ApplyTransform(const Source: TComicBalloonTransform; const Target: TRectF): Boolean;
var I: Integer; SX,SY: Double; Prepared: TArray<TComicTailState>; Probe: TComicTail; Offset: TPointF;
  function Map(const P: TPointF): TPointF;
  begin Result:=TPointF.Create(Target.Left+(P.X-Source.Bounds.Left)*SX,Target.Top+(P.Y-Source.Bounds.Top)*SY); end;
  function ValidRect(const R: TRectF): Boolean;
  begin Result:=not IsNan(R.Left) and not IsInfinite(R.Left) and not IsNan(R.Top) and not IsInfinite(R.Top) and
    not IsNan(R.Right) and not IsInfinite(R.Right) and not IsNan(R.Bottom) and not IsInfinite(R.Bottom) and
    (Abs(R.Left)<=80000) and (Abs(R.Top)<=80000) and (Abs(R.Right)<=80000) and (Abs(R.Bottom)<=80000) and
    (R.Width>=1) and (R.Height>=1); end;
begin
  Result:=False; if not ValidRect(Source.Bounds) or not ValidRect(Target) or (Length(Source.Tails)<>Tails.Count) then Exit;
  SX:=Target.Width/Source.Bounds.Width; SY:=Target.Height/Source.Bounds.Height; SetLength(Prepared,Tails.Count); Probe:=TComicTail.Create;
  try
    Offset:=TPointF.Create(Source.TextOffset.X*SX,Source.TextOffset.Y*SY);
    if IsNan(Offset.X) or IsInfinite(Offset.X) or IsNan(Offset.Y) or IsInfinite(Offset.Y) or (Abs(Offset.X)>80000) or (Abs(Offset.Y)>80000) then Exit;
    for I:=0 to Tails.Count-1 do begin
      Prepared[I].Root:=Map(Source.Tails[I].Root); Prepared[I].Tip:=Map(Source.Tails[I].Tip);
      Prepared[I].Width:=Source.Tails[I].Width*Min(SX,SY);
      Probe.Root:=Prepared[I].Root; Probe.Tip:=Prepared[I].Tip; Probe.Width:=Prepared[I].Width; if not Probe.Valid then Exit;
    end;
    for I:=0 to Tails.Count-1 do begin Tails[I].Root:=Prepared[I].Root; Tails[I].Tip:=Prepared[I].Tip; Tails[I].Width:=Prepared[I].Width; end;
    Bounds:=Target; FontSize:=EnsureRange(Round(Source.FontSize*Min(SX,SY)),1,1000);
    TextLayoutSize:=Source.TextLayoutSize; TextLayoutFontSize:=Source.TextLayoutFontSize;
    if (TextLayoutFontSize=0) and ((Abs(SX-1)>0.00001) or (Abs(SY-1)>0.00001)) then begin
      TextLayoutSize:=TSizeF.Create(Max(1,Round(Source.Bounds.Right)-Round(Source.Bounds.Left)-36),Max(1,Round(Source.Bounds.Bottom)-Round(Source.Bounds.Top)-36));
      TextLayoutFontSize:=Source.FontSize;
    end;
    TextOffset:=Offset; Result:=True;
  finally Probe.Free; end;
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
begin
  inherited; Width:=1200; Height:=1700; MarginLeft:=60; MarginTop:=60; MarginRight:=60; MarginBottom:=60;
  Assets:=TObjectList<TComicAsset>.Create; Pages:=TObjectList<TComicPage>.Create;
end;
destructor TComicProject.Destroy;
begin Assets.Free; Pages.Free; inherited; end;
function TComicProject.Json: TJSONObject;
var A: TJSONArray; P: TComicPage; I: TComicAsset; Version: Integer;
begin
  Version:=3;
  Result:=TJSONObject.Create; Put(Result,'version',Version); Result.AddPair('id',ID);
  Result.AddPair('title',Title); Result.AddPair('episode',Episode);
  Result.AddPair('generationPresetId',GenerationPresetID); Result.AddPair('generationPresetName',GenerationPresetName);
  Result.AddPair('generationInstructions',GenerationInstructions);
  Put(Result,'width',Width); Put(Result,'height',Height); Put(Result,'exportCount',ExportCount);
  Put(Result,'marginLeft',MarginLeft); Put(Result,'marginTop',MarginTop);
  Put(Result,'marginRight',MarginRight); Put(Result,'marginBottom',MarginBottom);
  A:=TJSONArray.Create; Result.AddPair('assets',A); for I in Assets do A.AddElement(I.Json);
  A:=TJSONArray.Create; Result.AddPair('pages',A); for P in Pages do A.AddElement(P.Json);
end;
function TComicProject.Snapshot: string;
{$IFDEF DEBUG}var PerfScope: TComicPerfScope;{$ENDIF}
var J: TJSONObject;
begin
  {$IFDEF DEBUG}PerfScope.Start(cpSnapshot);{$ENDIF} J:=Json; try Result:=J.ToJSON; finally J.Free; end; end;
procedure TComicProject.Restore(const S: string);
{$IFDEF DEBUG}var PerfScope: TComicPerfScope;{$ENDIF}
var J: TJSONObject; V: TJSONValue; A: TJSONArray; P: TComicPage; I: TComicAsset; Panel: TComicPanel; Overlay: TComicOverlay; PageIDs: TDictionary<string,Boolean>;
begin
  {$IFDEF DEBUG}PerfScope.Start(cpRestore);{$ENDIF}
  V:=TJSONObject.ParseJSONValue(S);
  if not (V is TJSONObject) then begin V.Free; raise Exception.Create('JSONを読み込めません。'); end;
  J:=TJSONObject(V);
  PageIDs:=TDictionary<string,Boolean>.Create;
  try
    if not (Round(JNum(J,'version',0)) in [1,2,3]) then raise Exception.Create('未対応のプロジェクト形式です。');
    ID:=JStr(J,'id',''); Title:=JStr(J,'title',''); Episode:=JStr(J,'episode','');
    GenerationPresetID:=JStr(J,'generationPresetId',''); GenerationPresetName:=JStr(J,'generationPresetName','');
    GenerationInstructions:=JStr(J,'generationInstructions','');
    if (Length(GenerationPresetName)>200) or (Length(GenerationInstructions)>65536) then raise Exception.Create('作品の生成指示が不正です。');
    Width:=Round(JNum(J,'width',1200)); Height:=Round(JNum(J,'height',1700));
    if (Width<100) or (Width>8000) or (Height<100) or (Height>8000) then raise Exception.Create('出力解像度が不正です。');
    MarginLeft:=Round(JNum(J,'marginLeft',Min(60,(Width-1) div 2)));
    MarginRight:=Round(JNum(J,'marginRight',Min(60,(Width-1) div 2)));
    MarginTop:=Round(JNum(J,'marginTop',Min(60,(Height-1) div 2)));
    MarginBottom:=Round(JNum(J,'marginBottom',Min(60,(Height-1) div 2)));
    if not PageBasis.Valid then raise Exception.Create('ページ外枠の余白が不正です。');
    ExportCount:=Round(JNum(J,'exportCount',0)); Assets.Clear; Pages.Clear;
    A:=J.GetValue<TJSONArray>('assets'); if A<>nil then for V in A do begin
      if not (V is TJSONObject) then raise Exception.Create('画像データが不正です。');
      I:=TComicAsset.Create; Assets.Add(I); I.Read(TJSONObject(V));
      if I.FileName<>'' then SafeChild(Folder,I.FileName);
    end;
    ValidateAssetTree(Assets);
    A:=J.GetValue<TJSONArray>('pages'); if A<>nil then for V in A do begin
      if not (V is TJSONObject) then raise Exception.Create('ページデータが不正です。');
      P:=TComicPage.Create; Pages.Add(P); P.Read(TJSONObject(V));
      for Panel in P.Panels do for Overlay in Panel.Overlays do if Overlay.FileName<>'' then SafeChild(Folder,Overlay.FileName);
      if (P.ID='') or (P.ID<>ExtractFileName(P.ID)) or P.ID.Contains('..') then raise Exception.Create('ページIDが不正です。');
      if PageIDs.ContainsKey(LowerCase(P.ID)) then raise Exception.Create('ページIDが重複しています。'); PageIDs.Add(LowerCase(P.ID),True);
    end;
  finally PageIDs.Free; J.Free; end;
end;
procedure TComicProject.Save;
begin AtomicWrite(TPath.Combine(Folder,'Project.json'),Snapshot); SaveDraft; end;
procedure TComicProject.SaveDraft;
{$IFDEF DEBUG}var PerfScope: TComicPerfScope;{$ENDIF}
var P: TComicPage; J: TJSONObject;
begin
  {$IFDEF DEBUG}PerfScope.Start(cpSaveDraft);{$ENDIF}
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
function TComicProject.PageBasis: TComicPageBasis;
begin
  Result.Width:=Width; Result.Height:=Height; Result.Left:=MarginLeft; Result.Top:=MarginTop;
  Result.Right:=MarginRight; Result.Bottom:=MarginBottom;
end;
procedure TComicProject.SetPageBasis(const Value: TComicPageBasis);
begin
  if not Value.Valid then raise Exception.Create('出力解像度またはページ外枠の余白が不正です。');
  Width:=Value.Width; Height:=Value.Height; MarginLeft:=Value.Left; MarginTop:=Value.Top;
  MarginRight:=Value.Right; MarginBottom:=Value.Bottom;
end;
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
procedure ValidateAssetTree(List: TObjectList<TComicAsset>);
var IDs: TDictionary<string,TComicAsset>; Asset,Parent: TComicAsset;
begin
  IDs:=TDictionary<string,TComicAsset>.Create;
  try
    for Asset in List do begin
      if (Asset.ID='') or IDs.ContainsKey(Asset.ID) then raise Exception.Create('素材のIDが空か重複しています。');
      IDs.Add(Asset.ID,Asset);
    end;
    for Asset in List do if Asset.ParentID<>'' then begin
      if not IDs.TryGetValue(Asset.ParentID,Parent) or (Parent=Asset) or (Parent.ParentID<>'') then
        raise Exception.Create('素材の親子関係が不正です。');
    end;
  finally IDs.Free; end;
end;
procedure ReadAssets(List: TObjectList<TComicAsset>; const FileName: string);
var J,V: TJSONValue; I,Existing: TComicAsset; Prepared: TObjectList<TComicAsset>;
begin
  if not TFile.Exists(FileName) then Exit;
  Prepared:=TObjectList<TComicAsset>.Create; J:=nil;
  try
    J:=TJSONObject.ParseJSONValue(TFile.ReadAllText(FileName,TEncoding.UTF8));
    if not (J is TJSONArray) then raise Exception.Create('キャラ情報を読み込めません。');
    for V in TJSONArray(J) do begin
      if not (V is TJSONObject) then raise Exception.Create('キャラ情報が不正です。');
      I:=TComicAsset.Create; Prepared.Add(I); I.Read(TJSONObject(V));
      if I.FileName<>'' then SafeChild(TPath.Combine(DataRoot,'Characters'),I.FileName);
    end;
    ValidateAssetTree(Prepared);
    for I in Prepared do for Existing in List do if I.ID=Existing.ID then raise Exception.Create('素材のIDが既存項目と重複しています。');
    // 全項目と全参照パスの検証が成功した後だけ公開し、不正な読込で元ライブラリを部分更新しない。
    while Prepared.Count>0 do List.Add(Prepared.Extract(Prepared[0]));
  finally J.Free; Prepared.Free; end;
end;
end.
