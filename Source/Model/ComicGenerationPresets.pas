unit ComicGenerationPresets;

// 責務：画像生成の共通指示を管理し、作品に適用した本文の独立性を保つ。

interface

uses System.SysUtils, System.JSON, System.Generics.Collections;

type
  TComicGenerationPreset = class
    ID,Name,Instructions: string;
    constructor Create;
    function Json: TJSONObject;
    procedure Read(J: TJSONObject);
  end;

procedure LoadGenerationPresets(List: TObjectList<TComicGenerationPreset>; const FileName: string);
procedure SaveGenerationPresets(List: TObjectList<TComicGenerationPreset>; const FileName: string);
procedure UpdateGenerationPreset(List: TObjectList<TComicGenerationPreset>; Preset: TComicGenerationPreset;
  const Name,Instructions,FileName: string);
procedure RemoveGenerationPreset(List: TObjectList<TComicGenerationPreset>; Preset: TComicGenerationPreset; const FileName: string);

implementation

uses System.IOUtils, ComicModel;

constructor TComicGenerationPreset.Create;
begin inherited; ID:=NewUID; end;
function TComicGenerationPreset.Json: TJSONObject;
begin Result:=TJSONObject.Create; Result.AddPair('id',ID); Result.AddPair('name',Name); Result.AddPair('instructions',Instructions); end;
procedure TComicGenerationPreset.Read(J: TJSONObject);
begin
  ID:=JStr(J,'id',''); Name:=Trim(JStr(J,'name','')); Instructions:=JStr(J,'instructions','');
  if (ID='') or (Name='') or (Length(Name)>200) or (Length(Instructions)>65536) then raise Exception.Create('画像生成プリセットが不正です。');
end;
procedure SaveGenerationPresets(List: TObjectList<TComicGenerationPreset>; const FileName: string);
var J: TJSONObject; A: TJSONArray; Preset: TComicGenerationPreset;
begin
  J:=TJSONObject.Create;
  try J.AddPair('version',TJSONNumber.Create(1)); A:=TJSONArray.Create; J.AddPair('presets',A);
    for Preset in List do A.AddElement(Preset.Json); AtomicWrite(FileName,J.ToJSON);
  finally J.Free; end;
end;
procedure LoadGenerationPresets(List: TObjectList<TComicGenerationPreset>; const FileName: string);
var J,V: TJSONValue; A: TJSONArray; Prepared: TObjectList<TComicGenerationPreset>; Preset: TComicGenerationPreset;
  IDs: TDictionary<string,Boolean>;
begin
  if not FileExists(FileName) then Exit; Prepared:=TObjectList<TComicGenerationPreset>.Create; IDs:=TDictionary<string,Boolean>.Create; J:=nil;
  try
    J:=TJSONObject.ParseJSONValue(TFile.ReadAllText(FileName,TEncoding.UTF8));
    if not (J is TJSONObject) or (JNum(TJSONObject(J),'version',0)<>1) then raise Exception.Create('画像生成ライブラリの形式が不正です。');
    A:=TJSONObject(J).GetValue<TJSONArray>('presets'); if (A=nil) or (A.Count>1000) then raise Exception.Create('画像生成プリセット一覧が不正です。');
    for Preset in List do IDs.Add(Preset.ID,True);
    for V in A do begin
      if not (V is TJSONObject) then raise Exception.Create('画像生成プリセット項目が不正です。');
      Preset:=TComicGenerationPreset.Create; Prepared.Add(Preset); Preset.Read(TJSONObject(V));
      if IDs.ContainsKey(Preset.ID) then raise Exception.Create('画像生成プリセットIDが重複しています。'); IDs.Add(Preset.ID,True);
    end;
    while Prepared.Count>0 do List.Add(Prepared.Extract(Prepared[0]));
  finally J.Free; IDs.Free; Prepared.Free; end;
end;
procedure UpdateGenerationPreset(List: TObjectList<TComicGenerationPreset>; Preset: TComicGenerationPreset;
  const Name,Instructions,FileName: string);
var PreviousName,PreviousInstructions: string; Other: TComicGenerationPreset;
begin
  if (Preset=nil) or (List.IndexOf(Preset)<0) then raise Exception.Create('プリセットを選択してください。');
  if (Trim(Name)='') or (Length(Trim(Name))>200) or (Length(Instructions)>65536) then raise Exception.Create('名前または本文の長さが不正です。');
  for Other in List do if (Other<>Preset) and SameText(Other.Name,Trim(Name)) then raise Exception.Create('同じ名前のプリセットがあります。');
  PreviousName:=Preset.Name; PreviousInstructions:=Preset.Instructions; Preset.Name:=Trim(Name); Preset.Instructions:=Instructions;
  try SaveGenerationPresets(List,FileName); except Preset.Name:=PreviousName; Preset.Instructions:=PreviousInstructions; raise; end;
end;
procedure RemoveGenerationPreset(List: TObjectList<TComicGenerationPreset>; Preset: TComicGenerationPreset; const FileName: string);
var Index: Integer;
begin
  Index:=List.IndexOf(Preset); if (Preset=nil) or (Index<0) then raise Exception.Create('プリセットを選択してください。');
  List.Extract(Preset); try SaveGenerationPresets(List,FileName); except List.Insert(Index,Preset); raise; end; Preset.Free;
end;

end.
