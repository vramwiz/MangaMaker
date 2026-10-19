unit ComicProjectReferences;

// 責務：使用する人物参照を作品内へ固定し、フォルダコピー後も共通ライブラリへ依存させない。
interface
uses System.Generics.Collections, ComicModel;
function ProjectCharacter(Project: TComicProject; Shared: TObjectList<TComicAsset>; const ID: string): TComicAsset;
function ProjectCharacterPath(Project: TComicProject; Shared: TObjectList<TComicAsset>; const ID: string): string;
procedure CaptureProjectReferences(Project: TComicProject; Shared: TObjectList<TComicAsset>);
implementation
uses System.SysUtils, System.IOUtils, System.JSON;
function Find(List: TObjectList<TComicAsset>; const ID: string): TComicAsset;
begin Result:=nil; if List<>nil then for var Item in List do if Item.ID=ID then Exit(Item); end;
function ProjectCharacter(Project: TComicProject; Shared: TObjectList<TComicAsset>; const ID: string): TComicAsset;
begin
  Result:=nil; if Project<>nil then Result:=Find(Project.CharacterReferences,ID);
  if Result=nil then Result:=Find(Shared,ID);
end;
function ProjectCharacterPath(Project: TComicProject; Shared: TObjectList<TComicAsset>; const ID: string): string;
var Item: TComicAsset;
begin
  Result:='';
  if Project<>nil then begin
    Item:=Find(Project.CharacterReferences,ID);
    // 新参照の欠損は共通画像へ戻さず、参照切れとして呼出元へ伝える。
    if Item<>nil then Exit(Item.ImagePath(Project.Folder));
  end;
  Item:=Find(Shared,ID); if Item<>nil then Result:=Item.ImagePath(TPath.Combine(DataRoot,'Characters'));
end;
procedure CaptureProjectReferences(Project: TComicProject; Shared: TObjectList<TComicAsset>);
  procedure Capture(const ID: string);
  var Source,CopyAsset: TComicAsset; Path,Relative: string; Json: TJSONObject;
  begin
    if Find(Project.CharacterReferences,ID)<>nil then Exit;
    Source:=Find(Shared,ID); if Source=nil then Exit;
    Path:=Source.ImagePath(TPath.Combine(DataRoot,'Characters'));
    if (Path='') or not FileExists(Path) then Exit;
    Relative:='References\'+NewUID+LowerCase(ExtractFileExt(Path));
    ForceDirectories(TPath.Combine(Project.Folder,'References'));
    CopyAsset:=TComicAsset.Create;
    try
      Json:=Source.Json; try CopyAsset.Read(Json); finally Json.Free; end;
      CopyAsset.RelativePath:=Relative;
      TFile.Copy(Path,SafeChild(Project.Folder,Relative),False);
      Project.CharacterReferences.Add(CopyAsset);
    except CopyAsset.Free; raise; end;
    if Source.ParentID<>'' then Capture(Source.ParentID);
  end;
begin
  if Project=nil then Exit;
  for var Asset in Project.Assets do for var ID in Asset.CharacterRefs do Capture(ID);
end;
end.
