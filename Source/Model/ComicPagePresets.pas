unit ComicPagePresets;

// 責務：共通ページ基準を保存する。作品には値を複製し、共通側の変更を波及させない。

interface

uses System.SysUtils, System.JSON, System.Generics.Collections, ComicModel;

const BuiltInPagePresetCount=3;

type
  TComicPagePreset = class
    ID,Name: string;
    BuiltIn: Boolean;
    Basis: TComicPageBasis;
    constructor Create;
    function Json: TJSONObject;
    procedure Read(J: TJSONObject);
  end;

procedure SeedPagePresets(List: TObjectList<TComicPagePreset>);
procedure LoadPagePresets(List: TObjectList<TComicPagePreset>; const FileName: string);
procedure SavePagePresets(List: TObjectList<TComicPagePreset>; const FileName: string);

implementation

uses System.IOUtils, System.Math;

constructor TComicPagePreset.Create;
begin inherited; ID:=NewUID; Basis.Width:=DefaultPageWidth; Basis.Height:=DefaultPageHeight;
  Basis.Left:=60; Basis.Top:=60; Basis.Right:=60; Basis.Bottom:=60; end;
function TComicPagePreset.Json: TJSONObject;
begin
  Result:=TJSONObject.Create; Result.AddPair('id',ID); Result.AddPair('name',Name);
  Result.AddPair('width',TJSONNumber.Create(Basis.Width)); Result.AddPair('height',TJSONNumber.Create(Basis.Height));
  Result.AddPair('left',TJSONNumber.Create(Basis.Left)); Result.AddPair('top',TJSONNumber.Create(Basis.Top));
  Result.AddPair('right',TJSONNumber.Create(Basis.Right)); Result.AddPair('bottom',TJSONNumber.Create(Basis.Bottom));
end;
procedure TComicPagePreset.Read(J: TJSONObject);
  function Number(const Key: string): Integer;
  var Value: Double;
  begin
    Value:=JNum(J,Key,NaN);
    if IsNan(Value) or IsInfinite(Value) or (Value<0) or (Value>8000) or (Frac(Value)<>0) then
      raise Exception.Create('ページ基準の数値が不正です。');
    Result:=Round(Value);
  end;
begin
  ID:=JStr(J,'id',''); Name:=Trim(JStr(J,'name',''));
  Basis.Width:=Number('width'); Basis.Height:=Number('height'); Basis.Left:=Number('left');
  Basis.Top:=Number('top'); Basis.Right:=Number('right'); Basis.Bottom:=Number('bottom');
  if (ID='') or (Name='') or (Length(Name)>200) or not Basis.Valid then
    raise Exception.Create('ページ基準プリセットが不正です。');
end;
procedure SeedPagePresets(List: TObjectList<TComicPagePreset>);
  procedure Add(const ID,Name: string; Width,Height: Integer);
  var Preset: TComicPagePreset;
  begin
    Preset:=TComicPagePreset.Create; Preset.ID:=ID; Preset.Name:=Name;
    Preset.Basis.Width:=Width; Preset.Basis.Height:=Height; Preset.BuiltIn:=True; List.Add(Preset);
  end;
begin
  Add('builtin-niconico','ニコニコ漫画 650 × 975 / 余白60',DefaultPageWidth,DefaultPageHeight);
  Add('builtin-standard','1200 × 1700 / 余白60',1200,1700);
  Add('builtin-portrait-2x','1300 × 1950 / 余白60',1300,1950);
end;
procedure SavePagePresets(List: TObjectList<TComicPagePreset>; const FileName: string);
var J: TJSONObject; A: TJSONArray; Preset: TComicPagePreset;
begin
  J:=TJSONObject.Create;
  try
    J.AddPair('version',TJSONNumber.Create(1)); A:=TJSONArray.Create; J.AddPair('presets',A);
    for Preset in List do if not Preset.BuiltIn then begin
      if not Preset.Basis.Valid or (Trim(Preset.Name)='') then raise Exception.Create('ページ基準プリセットが不正です。');
      A.AddElement(Preset.Json);
    end;
    AtomicWrite(FileName,J.ToJSON);
  finally J.Free; end;
end;
procedure LoadPagePresets(List: TObjectList<TComicPagePreset>; const FileName: string);
var J,V: TJSONValue; A: TJSONArray; Preset: TComicPagePreset; Prepared: TObjectList<TComicPagePreset>;
  IDs: TDictionary<string,Boolean>;
begin
  if not FileExists(FileName) then Exit;
  Prepared:=TObjectList<TComicPagePreset>.Create; IDs:=TDictionary<string,Boolean>.Create; J:=nil;
  try
    J:=TJSONObject.ParseJSONValue(TFile.ReadAllText(FileName,TEncoding.UTF8));
    if not (J is TJSONObject) then raise Exception.Create('ページ基準ライブラリが不正です。');
    if JNum(TJSONObject(J),'version',0)<>1 then raise Exception.Create('ページ基準ライブラリの形式が未対応です。');
    A:=TJSONObject(J).GetValue<TJSONArray>('presets'); if A=nil then raise Exception.Create('ページ基準一覧が不正です。');
    for Preset in List do IDs.Add(Preset.ID,True);
    for V in A do begin
      if not (V is TJSONObject) then raise Exception.Create('ページ基準プリセットが不正です。');
      Preset:=TComicPagePreset.Create; Prepared.Add(Preset); Preset.Read(TJSONObject(V));
      if IDs.ContainsKey(Preset.ID) then raise Exception.Create('ページ基準IDが重複しています。'); IDs.Add(Preset.ID,True);
    end;
    while Prepared.Count>0 do List.Add(Prepared.Extract(Prepared[0]));
  finally J.Free; IDs.Free; Prepared.Free; end;
end;

end.
