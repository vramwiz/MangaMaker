unit ComicEffectGroups;

// 責務：共通素材の分類と所属を保存し、分類削除でも素材のID・画像を保持する。
interface
uses System.SysUtils, System.Classes, System.JSON, System.Generics.Collections;
const UngroupedEffectID = 'ungrouped';
type
  TComicEffectGroup = class
    ID,Name: string;
    constructor Create(const AID,AName: string);
  end;
  TComicEffectGroups = class
  private
    FGroups: TObjectList<TComicEffectGroup>;
    FAssignments: TDictionary<string,string>;
    FFileName: string;
    function Json: TJSONObject;
    procedure Read(const Text: string);
    procedure Persist(const Before: string);
    procedure CheckName(const Name,ExceptID: string);
  public
    constructor Create(const FileName: string);
    destructor Destroy; override;
    procedure Load;
    function Find(const ID: string): TComicEffectGroup;
    function GroupOf(const MaterialID: string): string;
    function Add(const Name: string): string;
    procedure Rename(const ID,Name: string);
    procedure Delete(const ID: string);
    procedure Move(const MaterialID,GroupID: string);
    function Snapshot: string;
    property Groups: TObjectList<TComicEffectGroup> read FGroups;
  end;
implementation
uses System.IOUtils, ComicModel;
constructor TComicEffectGroup.Create(const AID,AName: string);
begin inherited Create; ID:=AID; Name:=AName; end;
constructor TComicEffectGroups.Create(const FileName: string);
begin
  inherited Create; FFileName:=FileName; FGroups:=TObjectList<TComicEffectGroup>.Create;
  FAssignments:=TDictionary<string,string>.Create;
  FGroups.Add(TComicEffectGroup.Create(UngroupedEffectID,'未分類'));
end;
destructor TComicEffectGroups.Destroy;
begin FAssignments.Free; FGroups.Free; inherited; end;
function TComicEffectGroups.Find(const ID: string): TComicEffectGroup;
var Group: TComicEffectGroup;
begin Result:=nil; for Group in FGroups do if Group.ID=ID then Exit(Group); end;
function TComicEffectGroups.GroupOf(const MaterialID: string): string;
begin if not FAssignments.TryGetValue(MaterialID,Result) then Result:=UngroupedEffectID; end;
procedure TComicEffectGroups.CheckName(const Name,ExceptID: string);
var Group: TComicEffectGroup;
begin
  if (Trim(Name)='') or (Length(Trim(Name))>100) then raise Exception.Create('グループ名は1～100文字で指定してください。');
  for Group in FGroups do if (Group.ID<>ExceptID) and SameText(Group.Name,Trim(Name)) then raise Exception.Create('同じ名前のグループがあります。');
end;
function TComicEffectGroups.Json: TJSONObject;
var Groups,Assignments: TJSONArray; Group: TComicEffectGroup; Pair: TPair<string,string>;
begin
  Result:=TJSONObject.Create; Result.AddPair('version',TJSONNumber.Create(1));
  Groups:=TJSONArray.Create; Result.AddPair('groups',Groups);
  for Group in FGroups do if Group.ID<>UngroupedEffectID then
    Groups.AddElement(TJSONObject.Create.AddPair('id',Group.ID).AddPair('name',Group.Name));
  Assignments:=TJSONArray.Create; Result.AddPair('assignments',Assignments);
  for Pair in FAssignments do Assignments.AddElement(TJSONObject.Create.AddPair('materialId',Pair.Key).AddPair('groupId',Pair.Value));
end;
function TComicEffectGroups.Snapshot: string;
var Value: TJSONObject;
begin Value:=Json; try Result:=Value.ToJSON; finally Value.Free; end; end;
procedure TComicEffectGroups.Read(const Text: string);
var Value,Entry: TJSONValue; Root,Item: TJSONObject; Prepared: TObjectList<TComicEffectGroup>;
  Assignments: TDictionary<string,string>; IDs,Names: TDictionary<string,Boolean>; ID,Name,GroupID: string;
begin
  Value:=nil; Prepared:=TObjectList<TComicEffectGroup>.Create; Assignments:=TDictionary<string,string>.Create;
  IDs:=TDictionary<string,Boolean>.Create; Names:=TDictionary<string,Boolean>.Create;
  try
    Value:=TJSONObject.ParseJSONValue(Text);
    if not (Value is TJSONObject) then raise Exception.Create('素材グループの形式が不正です。');
    Root:=TJSONObject(Value);
    if (JNum(Root,'version',0)<>1) or not (Root.GetValue('groups') is TJSONArray) or not (Root.GetValue('assignments') is TJSONArray) then
      raise Exception.Create('素材グループの一覧が不正です。');
    Prepared.Add(TComicEffectGroup.Create(UngroupedEffectID,'未分類')); IDs.Add(UngroupedEffectID,True); Names.Add('未分類',True);
    for Entry in TJSONArray(Root.GetValue('groups')) do begin
      if not (Entry is TJSONObject) then raise Exception.Create('素材グループの項目が不正です。');
      Item:=TJSONObject(Entry); ID:=JStr(Item,'id',''); Name:=Trim(JStr(Item,'name',''));
      if (ID='') or (Length(ID)>200) or IDs.ContainsKey(ID) or (Name='') or (Length(Name)>100) or Names.ContainsKey(LowerCase(Name)) then
        raise Exception.Create('素材グループのIDまたは名前が不正です。');
      IDs.Add(ID,True); Names.Add(LowerCase(Name),True); Prepared.Add(TComicEffectGroup.Create(ID,Name));
    end;
    for Entry in TJSONArray(Root.GetValue('assignments')) do begin
      if not (Entry is TJSONObject) then raise Exception.Create('素材所属の項目が不正です。');
      Item:=TJSONObject(Entry); ID:=JStr(Item,'materialId',''); GroupID:=JStr(Item,'groupId','');
      if (ID='') or (Length(ID)>200) or Assignments.ContainsKey(ID) or not IDs.ContainsKey(GroupID) then raise Exception.Create('素材所属が不正です。');
      if GroupID<>UngroupedEffectID then Assignments.Add(ID,GroupID);
    end;
    // 全件を検証するまで現行分類を置換せず、不正読込で途中の項目を公開しない。
    FGroups.Free; FGroups:=Prepared; Prepared:=nil; FAssignments.Free; FAssignments:=Assignments; Assignments:=nil;
  finally Value.Free; Prepared.Free; Assignments.Free; IDs.Free; Names.Free; end;
end;
procedure TComicEffectGroups.Load;
begin if FileExists(FFileName) then Read(TFile.ReadAllText(FFileName,TEncoding.UTF8)); end;
procedure TComicEffectGroups.Persist(const Before: string);
begin
  try AtomicWrite(FFileName,Snapshot);
  except Read(Before); raise; end;
end;
function TComicEffectGroups.Add(const Name: string): string;
var Before: string;
begin CheckName(Name,''); Before:=Snapshot; Result:=NewUID; FGroups.Add(TComicEffectGroup.Create(Result,Trim(Name))); Persist(Before); end;
procedure TComicEffectGroups.Rename(const ID,Name: string);
var Group: TComicEffectGroup; Before: string;
begin
  Group:=Find(ID); if (Group=nil) or (ID=UngroupedEffectID) then raise Exception.Create('未分類は名前を変更できません。');
  CheckName(Name,ID); Before:=Snapshot; Group.Name:=Trim(Name); Persist(Before);
end;
procedure TComicEffectGroups.Delete(const ID: string);
var Group: TComicEffectGroup; Before: string; MaterialID: string;
begin
  Group:=Find(ID); if (Group=nil) or (ID=UngroupedEffectID) then raise Exception.Create('未分類は削除できません。');
  Before:=Snapshot;
  // 分類だけを削除し、所属素材は未分類へ戻す。画像や作品内の参照には触れない。
  for MaterialID in FAssignments.Keys.ToArray do if FAssignments[MaterialID]=ID then FAssignments.Remove(MaterialID);
  FGroups.Remove(Group); Persist(Before);
end;
procedure TComicEffectGroups.Move(const MaterialID,GroupID: string);
var Before: string;
begin
  if (MaterialID='') or (Find(GroupID)=nil) then raise Exception.Create('移動先グループがありません。');
  if GroupOf(MaterialID)=GroupID then Exit; Before:=Snapshot;
  if GroupID=UngroupedEffectID then FAssignments.Remove(MaterialID) else FAssignments.AddOrSetValue(MaterialID,GroupID);
  Persist(Before);
end;
end.
