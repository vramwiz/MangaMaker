unit ComicAssetEditing;

// 責務：人物グループの親切替・並替を扱い、各参照のIDと画像を保持する。

interface

uses System.SysUtils, System.Generics.Collections, ComicModel;

type
  TComicAssetState = record
    Item: TComicAsset;
    Json: string;
  end;

function AssetByID(List: TObjectList<TComicAsset>; const ID: string): TComicAsset;
function CharacterRoot(List: TObjectList<TComicAsset>; Item: TComicAsset): TComicAsset;
procedure NormalizeCharacters(List: TObjectList<TComicAsset>);
procedure SetCharacterInfo(List: TObjectList<TComicAsset>; Item: TComicAsset; const Name,Notes: string);
function CaptureAssets(List: TObjectList<TComicAsset>): TArray<TComicAssetState>;
procedure RestoreAssets(List: TObjectList<TComicAsset>; const State: TArray<TComicAssetState>);
function PromoteCharacter(List: TObjectList<TComicAsset>; Child: TComicAsset): Boolean;
function ReorderCharacter(List: TObjectList<TComicAsset>; Moving,Before: TComicAsset): Boolean;
function NewSceneAsset(List: TObjectList<TComicAsset>; Source: TComicAsset; const Mode,Name,Notes,Title,Episode: string): TComicAsset;

implementation

uses System.JSON;

function NewSceneAsset(List: TObjectList<TComicAsset>; Source: TComicAsset; const Mode,Name,Notes,Title,Episode: string): TComicAsset;
var Root: TComicAsset;
begin
  if (Mode<>'scene') and (Mode<>'child') and (Mode<>'alternate_scene') and (Mode<>'title') then raise Exception.Create('画像の追加方式が不正です。');
  if (Mode<>'scene') and ((Source=nil) or (List.IndexOf(Source)<0)) then raise Exception.Create('参照元の画像を選択してください。');
  Root:=CharacterRoot(List,Source);
  if (Mode='title') and (Source.ParentID='') then raise Exception.Create('タイトル画像は子画像を参照してください。');
  Result:=TComicAsset.Create;
  try
    Result.Name:=Name; Result.Notes:=Notes; Result.SceneID:=Result.ID;
    if Mode<>'scene' then begin
      Result.SceneID:=Root.SceneID; if Result.SceneID='' then Result.SceneID:=Root.ID;
      Result.SourceID:=Root.ID;
      if Mode<>'alternate_scene' then begin Result.ParentID:=Root.ID; Result.CharacterRefs:=Copy(Source.CharacterRefs); end;
    end;
    if Mode='title' then begin Result.SourceID:=Source.ID; Result.TitleImage:=True; Result.TitleText:=Title; Result.EpisodeText:=Episode; end;
  except Result.Free; raise; end;
end;

function AssetByID(List: TObjectList<TComicAsset>; const ID: string): TComicAsset;
var Item: TComicAsset;
begin Result:=nil; for Item in List do if Item.ID=ID then Exit(Item); end;
function CharacterRoot(List: TObjectList<TComicAsset>; Item: TComicAsset): TComicAsset;
begin
  Result:=nil; if (Item=nil) or (List.IndexOf(Item)<0) then Exit;
  Result:=Item; if Item.ParentID<>'' then Result:=AssetByID(List,Item.ParentID);
end;
procedure NormalizeCharacters(List: TObjectList<TComicAsset>);
var Root,Child: TComicAsset;
begin
  ValidateAssetTree(List);
  for Root in List do if Root.ParentID='' then begin
    if Root.CharacterID='' then begin
      Root.CharacterID:=Root.ID;
      if Root.CharacterName='' then Root.CharacterName:=Root.Name;
      if Root.CharacterNotes='' then Root.CharacterNotes:=Root.Notes;
    end;
    if Root.StateName='' then Root.StateName:='基本服装';
    Root.Name:=Root.CharacterName;
    for Child in List do if Child.ParentID=Root.ID then begin
      Child.CharacterID:=Root.CharacterID; Child.CharacterName:=Root.CharacterName; Child.CharacterNotes:=Root.CharacterNotes;
      if Child.StateName='' then Child.StateName:=Child.Name; Child.Name:=Child.StateName;
    end;
  end;
end;
procedure SetCharacterInfo(List: TObjectList<TComicAsset>; Item: TComicAsset; const Name,Notes: string);
var Root,Child: TComicAsset;
begin
  Root:=CharacterRoot(List,Item); if Root=nil then raise Exception.Create('人物の親が見つかりません。');
  if (Length(Name)>200) or (Length(Notes)>65536) then raise Exception.Create('人物の共通情報が長すぎます。');
  Root.CharacterName:=Trim(Name); Root.CharacterNotes:=Notes; Root.Name:=Root.CharacterName;
  for Child in List do if Child.ParentID=Root.ID then begin Child.CharacterName:=Root.CharacterName; Child.CharacterNotes:=Notes; Child.CharacterID:=Root.CharacterID; end;
end;
function CaptureAssets(List: TObjectList<TComicAsset>): TArray<TComicAssetState>;
var I: Integer; J: TJSONObject;
begin
  SetLength(Result,List.Count);
  for I:=0 to List.Count-1 do begin Result[I].Item:=List[I]; J:=List[I].Json;
    try Result[I].Json:=J.ToJSON; finally J.Free; end;
  end;
end;
procedure RestoreAssets(List: TObjectList<TComicAsset>; const State: TArray<TComicAssetState>);
var I,At: Integer; J: TJSONObject;
begin
  if Length(State)<>List.Count then raise Exception.Create('素材の復元対象が変わっています。');
  for I:=0 to High(State) do begin
    At:=List.IndexOf(State[I].Item); if At<0 then raise Exception.Create('素材の復元対象が見つかりません。');
    List.Move(At,I); J:=TJSONObject.ParseJSONValue(State[I].Json) as TJSONObject;
    try State[I].Item.Read(J); finally J.Free; end;
  end;
end;
function PromoteCharacter(List: TObjectList<TComicAsset>; Child: TComicAsset): Boolean;
var Parent,Item: TComicAsset; ParentID: string;
begin
  Result:=False; if (Child=nil) or (Child.ParentID='') or (List.IndexOf(Child)<0) then Exit;
  NormalizeCharacters(List); Parent:=CharacterRoot(List,Child); if Parent=nil then Exit; ParentID:=Parent.ID;
  Child.ParentID:=''; Child.Name:=Parent.CharacterName;
  for Item in List do if (Item<>Child) and ((Item=Parent) or (Item.ParentID=ParentID)) then begin
    Item.ParentID:=Child.ID; Item.Name:=Item.StateName;
  end;
  // 親切替でも人物グループの位置と全服装のIDを保ち、作品の参照を失わせない。
  List.Move(List.IndexOf(Child),List.IndexOf(Parent)); ValidateAssetTree(List); Result:=True;
end;
function ReorderCharacter(List: TObjectList<TComicAsset>; Moving,Before: TComicAsset): Boolean;
var Group: TList<TComicAsset>; Item,TargetRoot: TComicAsset; I,At: Integer; Old: TArray<TComicAssetState>;
begin
  Result:=False;
  if (Moving=nil) or (Before=nil) or (Moving=Before) or (List.IndexOf(Moving)<0) or (List.IndexOf(Before)<0) then Exit;
  Old:=CaptureAssets(List);
  if Moving.ParentID<>'' then begin
    if (Before.ParentID<>Moving.ParentID) and (Before.ID<>Moving.ParentID) then Exit;
    if Before.ID=Moving.ParentID then begin
      At:=-1; for I:=0 to List.Count-1 do if (List[I].ParentID=Moving.ParentID) and (List[I]<>Moving) then begin At:=I; Break; end;
      if At<0 then Exit;
    end else At:=List.IndexOf(Before);
    I:=List.IndexOf(Moving); if I<At then Dec(At); List.Move(I,At);
  end else begin
    TargetRoot:=CharacterRoot(List,Before); if (TargetRoot=nil) or (TargetRoot=Moving) then Exit;
    Group:=TList<TComicAsset>.Create;
    try
      Group.Add(Moving); for Item in List do if Item.ParentID=Moving.ID then Group.Add(Item);
      for Item in Group do List.Extract(Item); At:=List.IndexOf(TargetRoot);
      for I:=0 to Group.Count-1 do List.Insert(At+I,Group[I]);
    finally Group.Free; end;
  end;
  for I:=0 to High(Old) do if List[I]<>Old[I].Item then Exit(True);
end;

end.
