unit ComicRecentProjects;

// 責務：正常に開いた作品の履歴を保持する。履歴整理は作品ファイルを削除しない。

interface

uses System.SysUtils, System.Generics.Collections, System.JSON;

type
  TComicRecentProject = class
    FileName,Title,Episode: string;
    function Json: TJSONObject;
  end;
  TComicRecentProjects = class
  private
    FItems: TObjectList<TComicRecentProject>;
    function Json: string;
    procedure Read(const Text: string);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Load(const Path: string);
    procedure Remember(const FileName,Title,Episode,Path: string);
    procedure Clear(const Path: string);
    property Items: TObjectList<TComicRecentProject> read FItems;
  end;

implementation

uses System.IOUtils, ComicModel;

constructor TComicRecentProjects.Create;
begin inherited; FItems:=TObjectList<TComicRecentProject>.Create; end;
destructor TComicRecentProjects.Destroy;
begin FItems.Free; inherited; end;
function TComicRecentProject.Json: TJSONObject;
begin Result:=TJSONObject.Create; Result.AddPair('file',FileName); Result.AddPair('title',Title); Result.AddPair('episode',Episode); end;
function TComicRecentProjects.Json: string;
var Root: TJSONObject; Entries: TJSONArray; Item: TComicRecentProject;
begin
  Root:=TJSONObject.Create;
  try Root.AddPair('version',TJSONNumber.Create(1)); Entries:=TJSONArray.Create; Root.AddPair('projects',Entries);
    for Item in FItems do Entries.AddElement(Item.Json); Result:=Root.ToJSON;
  finally Root.Free; end;
end;
procedure TComicRecentProjects.Read(const Text: string);
var Value,Entry: TJSONValue; Root: TJSONObject; Entries: TJSONArray; Item: TComicRecentProject; Prepared: TObjectList<TComicRecentProject>; Seen: TDictionary<string,Boolean>;
begin
  Value:=nil; Prepared:=TObjectList<TComicRecentProject>.Create; Seen:=TDictionary<string,Boolean>.Create;
  try
    Value:=TJSONObject.ParseJSONValue(Text); if not (Value is TJSONObject) then raise Exception.Create('読込履歴が不正です。'); Root:=TJSONObject(Value);
    if JNum(Root,'version',0)<>1 then raise Exception.Create('未対応の読込履歴形式です。'); Entries:=Root.GetValue<TJSONArray>('projects');
    if (Entries=nil) or (Entries.Count>20) then raise Exception.Create('読込履歴の件数が不正です。');
    for Entry in Entries do begin
      if not (Entry is TJSONObject) then raise Exception.Create('読込履歴の項目が不正です。'); Item:=TComicRecentProject.Create; Prepared.Add(Item);
      Item.FileName:=JStr(TJSONObject(Entry),'file',''); Item.Title:=JStr(TJSONObject(Entry),'title',''); Item.Episode:=JStr(TJSONObject(Entry),'episode','');
      if (Item.FileName='') or (Length(Item.FileName)>4096) or not TPath.IsPathRooted(Item.FileName) or
        (Length(Item.Title)>200) or (Length(Item.Episode)>200) or (Pos(#0,Item.FileName)>0) then raise Exception.Create('読込履歴の保存先が不正です。');
      Item.FileName:=TPath.GetFullPath(Item.FileName);
      if Seen.ContainsKey(LowerCase(Item.FileName)) then raise Exception.Create('読込履歴が重複しています。'); Seen.Add(LowerCase(Item.FileName),True);
    end;
    FItems.Clear; while Prepared.Count>0 do FItems.Add(Prepared.Extract(Prepared[0]));
  finally Seen.Free; Prepared.Free; Value.Free; end;
end;
procedure TComicRecentProjects.Load(const Path: string);
begin if FileExists(Path) then Read(TFile.ReadAllText(Path,TEncoding.UTF8)); end;
procedure TComicRecentProjects.Remember(const FileName,Title,Episode,Path: string);
var Before,FullPath: string; I: Integer; Item: TComicRecentProject;
begin
  FullPath:=TPath.GetFullPath(FileName); if not TPath.IsPathRooted(FileName) or (Length(Title)>200) or (Length(Episode)>200) then raise Exception.Create('作品履歴の指定が不正です。');
  Before:=Json;
  for I:=FItems.Count-1 downto 0 do if SameText(FItems[I].FileName,FullPath) then FItems.Delete(I);
  Item:=TComicRecentProject.Create; Item.FileName:=FullPath; Item.Title:=Title; Item.Episode:=Episode; FItems.Insert(0,Item);
  while FItems.Count>20 do FItems.Delete(FItems.Count-1);
  try AtomicWrite(Path,Json); except Read(Before); raise; end;
end;
procedure TComicRecentProjects.Clear(const Path: string);
var Before: string;
begin Before:=Json; FItems.Clear; try AtomicWrite(Path,Json); except Read(Before); raise; end; end;

end.
