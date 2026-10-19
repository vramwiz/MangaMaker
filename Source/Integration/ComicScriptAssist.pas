unit ComicScriptAssist;

// 責務：台本を既存の画像素材・文字入力へ補完する。専用の編集画面や生成待ち行列は持たない。
interface
uses System.SysUtils, System.Classes, System.Generics.Collections, ComicModel, ComicScript;
type
  TScriptImportResult = record
    Added,Updated,Deferred: Integer;
    Details: string;
    function Summary: string;
  end;
procedure BindScriptReference(Script: TComicScript; Characters: TObjectList<TComicAsset>);
function ImportComicScript(Project: TComicProject; Characters: TObjectList<TComicAsset>; const Text: string): TScriptImportResult;
function ScriptImageID(Project: TComicProject; const AssetID: string): string;
procedure ScriptDialogueChoices(Project: TComicProject; const AssetID: string; Choices: TStrings);
function ScriptDialogueText(Project: TComicProject; const Choice: string): string;
procedure RequireScriptBackground(Project: TComicProject; Asset: TComicAsset);
implementation
uses System.IOUtils, System.JSON, ComicScriptPlan, ComicAssetEditing;

function TScriptImportResult.Summary: string;
begin Result:=Format('台本から画像管理へ追加%d件・補完%d件。未完・不足は%d件だけ保留しました。',[Added,Updated,Deferred]); end;
procedure BindScriptReference(Script: TComicScript; Characters: TObjectList<TComicAsset>);
var Definition: TScriptItem; A,Candidate: TComicAsset; Description: string;
begin
  if Characters=nil then Exit;
  Definition:=Script.Find('主人公'); if Definition=nil then Exit;
  if (Definition.Get('登録名')<>'') or (Definition.Get('参照ID')<>'') then Exit;
  Description:=Definition.Get('外見');
  if not (Description.Contains('三面図') or Description.Contains('参照画像')) then Exit;
  Candidate:=nil;
  for A in Characters do if (A.ParentID='') and (A.ImageFile<>'') and
    FileExists(SafeChild(TPath.Combine(DataRoot,'Characters'),A.ImageFile)) then begin
    if Candidate<>nil then Exit; Candidate:=A;
  end;
  if Candidate=nil then Exit;
  Definition.Put('登録名',Candidate.CharacterName); Definition.Put('状態名',Candidate.StateName); Definition.Put('参照ID',Candidate.ID);
end;
function ReadProgress(Project: TComicProject): TJSONObject;
var V: TJSONValue;
begin
  if Project.ScriptProgress='' then Exit(TJSONObject.Create);
  V:=TJSONObject.ParseJSONValue(Project.ScriptProgress);
  if not (V is TJSONObject) then begin V.Free; raise Exception.Create('台本の素材対応が不正です。'); end;
  Result:=TJSONObject(V);
end;
function Entry(State: TJSONObject; const Key: string): TJSONObject;
var V: TJSONValue;
begin Result:=nil; V:=State.GetValue(Key); if V is TJSONObject then Result:=TJSONObject(V); end;
function AssetFor(State: TJSONObject; Project: TComicProject; const Key: string): TComicAsset;
var E: TJSONObject;
begin Result:=nil; E:=Entry(State,Key); if E<>nil then Result:=Project.Asset(JStr(E,'uid','')); end;
function RefKey(const IDs: TArray<string>): string;
begin Result:=string.Join(',',IDs); end;
function ScriptPrefix(Script: TComicScript; State: TJSONObject): string;
var ID,Previous,Key: string; Pair: TJSONPair;
begin
  ID:=Script.Work.Get('台本ID');
  if ID='' then ID:=JStr(State,'__scriptId','');
  if ID='' then begin
    // 既に同じ作品へ取り込んだ台本のIDを、省略した再読込で失わない。
    Previous:='';
    for Pair in State do if Pair.JsonValue is TJSONObject then begin
      Key:=Copy(Pair.JsonString.Value,1,LastDelimiter('/',Pair.JsonString.Value)-1);
      if Key='' then Continue;
      if (Previous<>'') and (Previous<>Key) then begin Previous:='main'; Break; end;
      Previous:=Key;
    end;
    ID:=Previous;
  end;
  if ID='' then ID:='main';
  State.RemovePair('__scriptId').Free; State.AddPair('__scriptId',ID); Result:=ID+'/';
end;
function ScriptNotes(Script: TComicScript; Item: TScriptItem; Characters: TObjectList<TComicAsset>): string;
var I: Integer; Key,Alias,Error: string; Definition: TScriptItem; A: TComicAsset;
begin
  Result:='台本 '+Item.ID+sLineBreak+'画風：'+Script.Work.Get('画風','日本のカラー漫画、人物と背景の画風を統一');
  for I:=0 to Item.Fields.Count-1 do begin
    Key:=Item.Fields.Names[I];
    if (Key='使用効果') or (Key='使用オノマトペ') or (Key='生成') or (Key='確認事項') then Continue;
    Result:=Result+sLineBreak+Key+'：'+Item.Fields.ValueFromIndex[I];
  end;
  for Alias in ScriptNames(Item.Get('人物')) do begin
    Definition:=Script.FindCharacter(Alias); if Definition=nil then Continue;
    Result:=Result+sLineBreak+'人物補足 '+Alias+'：'+Definition.Description;
    if (Definition.Get('登録名')<>'') or (Definition.Get('参照ID')<>'') then begin
      A:=ResolveScriptCharacter(Characters,Definition,Item,Error);
      if A<>nil then Result:=Result+sLineBreak+'登録人物：'+A.CharacterName+'／'+A.StateName+sLineBreak+A.CharacterNotes+sLineBreak+A.Notes;
    end;
  end;
  Result:=Result+sLineBreak+'本編画像にセリフ・吹き出し・文字を描かない。セリフはMangaMakerで配置する。';
end;

function ImportComicScript(Project: TComicProject; Characters: TObjectList<TComicAsset>; const Text: string): TScriptImportResult;
var Script: TComicScript; State,E,Next: TJSONObject; Item,Definition: TScriptItem;
  Asset,Parent,Character: TComicAsset; Alias,Error,Prefix,Key,Name,Notes,Mode,Before: string;
  Refs: TList<string>; Missing: Boolean;
begin
  Result:=Default(TScriptImportResult); Script:=TComicScript.Create; State:=nil; Refs:=TList<string>.Create;
  try
    Script.Read(Text); BindScriptReference(Script,Characters);
    if Script.FatalErrors.Count>0 then raise Exception.Create(Script.FatalErrors.Text);
    State:=ReadProgress(Project); Before:=Project.Snapshot; Prefix:=ScriptPrefix(Script,State);
    try
      for Item in Script.Items do begin
        if not (Item.Kind in [skBackground,skAlternate,skImage]) then Continue;
        if (Item.Problems.Count>0) or (Item.Get('生成')='保留') then begin Inc(Result.Deferred); Continue; end;
        Parent:=nil; Missing:=False; Refs.Clear;
        Key:=Item.Get('背景'); if Item.Kind=skAlternate then Key:=Item.Get('参照背景');
        if (Item.Kind<>skBackground) then begin
          Parent:=AssetFor(State,Project,Prefix+Key); if Parent=nil then Missing:=True;
        end;
        if Item.Kind=skImage then for Alias in ScriptNames(Item.Get('人物')) do begin
          Definition:=Script.FindCharacter(Alias);
          if (Definition=nil) or (Definition.Problems.Count>0) then begin Missing:=True; Continue; end;
          if (Definition.Get('参照方式')='説明のみ') and (Definition.Get('参照ID')='') then Continue;
          Character:=ResolveScriptCharacter(Characters,Definition,Item,Error);
          if Character=nil then Missing:=True else if not Refs.Contains(Character.ID) then Refs.Add(Character.ID);
        end;
        if Missing then begin Inc(Result.Deferred); Continue; end;
        Notes:=ScriptNotes(Script,Item,Characters);
        if (Notes='') or (Length(Notes)>65536) then begin Inc(Result.Deferred); Continue; end;
        Key:=Prefix+Item.ID; E:=Entry(State,Key); Asset:=AssetFor(State,Project,Key);
        Name:=Trim(Item.ID+' '+Item.Name);
        if Asset=nil then begin
          Mode:='scene'; if Item.Kind=skAlternate then Mode:='alternate_scene'; if Item.Kind=skImage then Mode:='child';
          Asset:=NewSceneAsset(Project.Assets,Parent,Mode,Name,Notes,'',''); Project.Assets.Add(Asset);
          Asset.CharacterRefs:=Refs.ToArray; Inc(Result.Added);
        end else begin
          // 再読込で人が直した名前・説明・人物参照を戻さず、前回の自動補完と一致する欄だけ更新する。
          if (E<>nil) and (Asset.Notes=JStr(E,'scriptNotes',#1)) then Asset.Notes:=Notes;
          if (E<>nil) and (Asset.Name=JStr(E,'scriptName',#1)) then Asset.Name:=Name;
          if (E<>nil) and (RefKey(Asset.CharacterRefs)=JStr(E,'scriptRefs',#1)) then Asset.CharacterRefs:=Refs.ToArray;
          if Parent<>nil then begin
            if (Item.Kind=skImage) and (E<>nil) and (Asset.ParentID=JStr(E,'scriptParent',#1)) then Asset.ParentID:=Parent.ID;
            if (E<>nil) and (Asset.SourceID=JStr(E,'scriptSource',#1)) then begin Asset.SourceID:=Parent.ID; Asset.SceneID:=Parent.SceneID; end;
          end;
          Inc(Result.Updated);
        end;
        Next:=TJSONObject.Create; Next.AddPair('uid',Asset.ID); Next.AddPair('scriptNotes',Notes);
        Next.AddPair('scriptName',Name); Next.AddPair('scriptRefs',RefKey(Refs.ToArray));
        if Parent<>nil then begin Next.AddPair('scriptSource',Parent.ID); if Item.Kind=skImage then Next.AddPair('scriptParent',Parent.ID); end;
        State.RemovePair(Key).Free; State.AddPair(Key,Next);
      end;
      Project.ScriptSource:=Text; Project.ScriptProgress:=State.ToJSON;
      AtomicWrite(TPath.Combine(Project.Folder,'Draft.json'),Project.Snapshot);
    except Project.Restore(Before); raise; end;
    Result.Details:=Script.Errors.Text;
  finally Refs.Free; State.Free; Script.Free; end;
end;

function ScriptImageID(Project: TComicProject; const AssetID: string): string;
var State: TJSONObject; Pair: TJSONPair;
begin
  Result:=''; if (Project=nil) or (AssetID='') then Exit;
  State:=ReadProgress(Project);
  try
    for Pair in State do if (Pair.JsonValue is TJSONObject) and
      (JStr(TJSONObject(Pair.JsonValue),'uid','')=AssetID) then Exit(Copy(Pair.JsonString.Value,LastDelimiter('/',Pair.JsonString.Value)+1,MaxInt));
  finally State.Free; end;
end;
procedure ScriptDialogueChoices(Project: TComicProject; const AssetID: string; Choices: TStrings);
var Script: TComicScript; Item: TScriptItem; ImageID: string;
begin
  Choices.BeginUpdate;
  try
    Choices.Clear; Choices.Add('台本からセリフを選択');
    if (Project=nil) or (Project.ScriptSource='') then Exit;
    Script:=TComicScript.Create;
    try
      Script.Read(Project.ScriptSource); ImageID:=ScriptImageID(Project,AssetID);
      for Item in Script.Items do if (Item.Kind=skDialogue) and (Item.Problems.Count=0) and
        ((ImageID='') or (Item.Get('画像')=ImageID)) then
        Choices.Add(Item.ID+' '+Item.Get('画像')+' '+Item.Get('話者')+'：'+Copy(Item.Get('本文').Replace(sLineBreak,' / '),1,80));
    finally Script.Free; end;
  finally Choices.EndUpdate; end;
end;
function ScriptDialogueText(Project: TComicProject; const Choice: string): string;
var Script: TComicScript; Item: TScriptItem; ID: string;
begin
  Result:=''; if Project=nil then Exit; ID:=Copy(Choice,1,Pos(' ',Choice)-1);
  Script:=TComicScript.Create;
  try
    Script.Read(Project.ScriptSource); Item:=Script.Find(ID);
    if (Item<>nil) and (Item.Kind=skDialogue) and (Item.Problems.Count=0) then Result:=Item.Get('本文');
  finally Script.Free; end;
end;
procedure RequireScriptBackground(Project: TComicProject; Asset: TComicAsset);
var Parent: TComicAsset;
begin
  if (Project=nil) or (Asset=nil) or (ScriptImageID(Project,Asset.ID)='') then Exit;
  if Asset.SourceID='' then Exit;
  Parent:=Project.Asset(Asset.SourceID);
  if (Parent=nil) or (Parent.ImageFile='') or not FileExists(Project.ImagePath(Parent.ID)) then
    raise Exception.Create('台本の参照背景を先に生成または画像登録してください。');
end;
end.
