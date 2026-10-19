unit ComicScriptGeneration;

// 責務：台本と既存素材から未取得画像の処理順を計算する。生成や画面操作は行わない。
interface
uses System.JSON, System.Generics.Collections, ComicModel;
function ScriptGenerationPlan(Project: TComicProject; Characters: TObjectList<TComicAsset>): TJSONObject;
function NextScriptGenerationAsset(Plan: TJSONObject): string;
function ScriptContinuityData(Project: TComicProject; const AssetID: string): TJSONArray;
implementation
uses System.SysUtils, System.IOUtils, ComicScript, ComicProjectReferences;

function LinkedAsset(Project: TComicProject; State: TJSONObject; const Prefix,ID: string): TComicAsset;
var V: TJSONValue;
begin
  Result:=nil; V:=State.GetValue(Prefix+ID);
  if V is TJSONObject then Result:=Project.Asset(JStr(TJSONObject(V),'uid',''));
end;
function Continuity(Script: TComicScript; Item: TScriptItem; Project: TComicProject; State: TJSONObject; const Prefix: string): TJSONArray;
var Alias: string; Definition,Previous: TScriptItem; A: TComicAsset; Row: TJSONObject;
begin
  Result:=TJSONArray.Create;
  // 登録参照を持たない固有人物は、最初の登場画像を以後の外見基準にする。群衆は固定しない。
  for Alias in ScriptNames(Item.Get('人物')) do begin
    Definition:=Script.FindCharacter(Alias);
    if (Definition=nil) or (Definition.Get('登録名')<>'') or (Definition.Get('参照ID')<>'') or
      (Length(ScriptNames(Definition.ID))>1) or Definition.ID.Contains('・') then Continue;
    for Previous in Script.Items do begin
      if Previous=Item then Break;
      if (Previous.Kind<>skImage) or not ScriptHasName(Previous.Get('人物'),Alias) then Continue;
      A:=LinkedAsset(Project,State,Prefix,Previous.ID); Row:=TJSONObject.Create; Result.AddElement(Row);
      Row.AddPair('role',Alias); Row.AddPair('scriptId',Previous.ID); Row.AddPair('referencePath','');
      if (A<>nil) and (A.ImageFile<>'') and FileExists(Project.ImagePath(A.ID)) then begin
        Row.RemovePair('referencePath').Free; Row.AddPair('referencePath',Project.ImagePath(A.ID));
      end;
      Break;
    end;
  end;
end;
function ScriptContinuityData(Project: TComicProject; const AssetID: string): TJSONArray;
var Script: TComicScript; State: TJSONObject; Value: TJSONValue; Prefix: string; Item: TScriptItem; A: TComicAsset;
begin
  Result:=nil; Script:=TComicScript.Create; State:=nil;
  try
    Script.Read(Project.ScriptSource); Value:=TJSONObject.ParseJSONValue(Project.ScriptProgress);
    if Value is TJSONObject then State:=TJSONObject(Value) else begin Value.Free; State:=TJSONObject.Create; end;
    Prefix:=Script.Work.Get('台本ID',JStr(State,'__scriptId','main'))+'/';
    for Item in Script.Items do if Item.Kind=skImage then begin
      A:=LinkedAsset(Project,State,Prefix,Item.ID);
      if (A<>nil) and (A.ID=AssetID) then begin Result:=Continuity(Script,Item,Project,State,Prefix); Break; end;
    end;
    if Result=nil then Result:=TJSONArray.Create;
  finally State.Free; Script.Free; end;
end;

function ScriptGenerationPlan(Project: TComicProject; Characters: TObjectList<TComicAsset>): TJSONObject;
var Script: TComicScript; State: TJSONObject; Value: TJSONValue; Item: TScriptItem;
  Rows,ContinuityRefs: TJSONArray; Row: TJSONObject; Asset,Source,Character: TComicAsset;
  Prefix,Status,Reason,RefID: string; Completed,Ready,Waiting,Deferred: Integer;
begin
  Result:=TJSONObject.Create; Script:=TComicScript.Create; State:=nil;
  try
    if Project=nil then raise Exception.Create('作品が開かれていません。');
    Script.Read(Project.ScriptSource);
    Value:=TJSONObject.ParseJSONValue(Project.ScriptProgress);
    if Value is TJSONObject then State:=TJSONObject(Value) else begin Value.Free; State:=TJSONObject.Create; end;
    Prefix:=Script.Work.Get('台本ID',JStr(State,'__scriptId','main'))+'/';
    Rows:=TJSONArray.Create; Result.AddPair('items',Rows);
    Completed:=0; Ready:=0; Waiting:=0; Deferred:=0;
    for Item in Script.Items do begin
      if not (Item.Kind in [skBackground,skAlternate,skImage]) then Continue;
      Row:=TJSONObject.Create; Rows.AddElement(Row); Row.AddPair('scriptId',Item.ID);
      Row.AddPair('page',TJSONNumber.Create(Item.Page));
      Asset:=LinkedAsset(Project,State,Prefix,Item.ID);
      Row.AddPair('assetId',''); if Asset<>nil then begin Row.RemovePair('assetId').Free; Row.AddPair('assetId',Asset.ID); end;
      Status:='ready'; Reason:='';
      if (Item.Problems.Count>0) or (Item.Get('生成')='保留') or (Asset=nil) then begin
        Status:='deferred'; Reason:=Trim(Item.Problems.Text);
        if Reason='' then Reason:='保留中、または画像管理への取込が必要です。';
      end else if (Asset.ImageFile<>'') and FileExists(Project.ImagePath(Asset.ID)) then Status:='completed'
      else begin
        if Asset.SourceID<>'' then begin
          Source:=Project.Asset(Asset.SourceID);
          if (Source=nil) or (Source.ImageFile='') or not FileExists(Project.ImagePath(Source.ID)) then begin
            Status:='waiting'; Reason:='参照背景の画像取得待ち';
          end;
        end;
        ContinuityRefs:=Continuity(Script,Item,Project,State,Prefix);
        try
          for var V in ContinuityRefs do if JStr(TJSONObject(V),'referencePath','')='' then begin
            Status:='waiting'; Reason:='人物の初登場画像待ち：'+JStr(TJSONObject(V),'scriptId',''); Break;
          end;
        finally ContinuityRefs.Free; end;
        for RefID in Asset.CharacterRefs do begin
          Character:=ProjectCharacter(Project,Characters,RefID);
          if (Character=nil) or (Character.ImageFile='') or
            not FileExists(ProjectCharacterPath(Project,Characters,RefID)) then begin
            Status:='deferred'; Reason:='登録キャラの参照画像がありません：'+RefID; Break;
          end;
        end;
      end;
      if Status='completed' then Inc(Completed) else if Status='ready' then Inc(Ready)
      else if Status='waiting' then Inc(Waiting) else Inc(Deferred);
      Row.AddPair('status',Status); Row.AddPair('reason',Reason);
    end;
    Result.AddPair('completed',TJSONNumber.Create(Completed)); Result.AddPair('ready',TJSONNumber.Create(Ready));
    Result.AddPair('waiting',TJSONNumber.Create(Waiting)); Result.AddPair('deferred',TJSONNumber.Create(Deferred));
    Result.AddPair('errors',Script.Errors.Text); Result.AddPair('nextAssetId',NextScriptGenerationAsset(Result));
  except State.Free; Script.Free; Result.Free; raise;
  end;
  State.Free; Script.Free;
end;
function NextScriptGenerationAsset(Plan: TJSONObject): string;
var Rows: TJSONArray; V: TJSONValue; Row: TJSONObject;
begin
  Result:=''; Rows:=Plan.GetValue<TJSONArray>('items');
  if Rows<>nil then for V in Rows do if V is TJSONObject then begin
    Row:=TJSONObject(V); if JStr(Row,'status','')='ready' then Exit(JStr(Row,'assetId',''));
  end;
end;
end.
