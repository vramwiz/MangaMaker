unit ComicWorkspaceBridge;

// 責務：外部要求をUIスレッドで検証し、IDで固定した対象へ登録する。
interface
uses MangaMakerMainForm;
procedure HandleWorkspaceBridge(Form: TMainForm; const Request: string; out Reply: string);
implementation
uses Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, Winapi.Imm,
  System.SysUtils, System.Classes, System.Types, System.UITypes,
  System.Math, System.IOUtils, System.Generics.Collections, System.JSON,
  System.Hash, System.DateUtils, Vcl.Controls, Vcl.Forms,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Menus,
  Vcl.Dialogs, Vcl.Graphics, Vcl.Imaging.pngimage, ComicModel,
  ComicGenerationPresets, ComicAssetEditing, ComicImageAdoption, ComicScriptGeneration, ComicWorkspaceGeneration, ComicProjectReferences;
type
  TComicWorkspaceBridgeHelper = class helper for TMainForm
    procedure HandleWorkspaceBridge(const Request: string; out Reply: string);
  end;
procedure TComicWorkspaceBridgeHelper.HandleWorkspaceBridge(const Request: string; out Reply: string);
var Value: TJSONValue; Input,Output,Data,Info: TJSONObject; Items: TJSONArray;
  Action,Scope,ID,ParentID,Root,Path,Relative,Before,OldFile,RequestID,Mode,SourceID,RefID: string;
  Assets: TObjectList<TComicAsset>; Asset,Parent,Created,Source,Ref,RefProbe: TComicAsset; Preset: TComicGenerationPreset;
  ParsedRefs,GenerationRefs: TArray<string>; RefData,RefParent: TJSONObject;
  Characters,Mutating,Generated,AlreadyAdopted: Boolean; ManagedLock: TFileStream; Pair: TJSONPair; Keys: TDictionary<string,Boolean>; WriteTarget: TWinControl;
  function Text(const Name: string; Required: Boolean=False; Limit: Integer=65536): string;
  var Item: TJSONValue;
  begin
    Item:=Input.GetValue(Name); Result:='';
    if Item=nil then begin if Required then raise Exception.Create('必須項目がありません：'+Name); Exit; end;
    if not (Item is TJSONString) then raise Exception.Create('文字列で指定してください：'+Name);
    Result:=Item.Value;
    if (Length(Result)>Limit) or (Pos(#0,Result)>0) or (Required and (Result='')) then raise Exception.Create('値が不正です：'+Name);
  end;
  procedure RequireProject;
  begin
    if FProject=nil then raise Exception.Create('作品が開かれていません。');
    if Text('projectId',True,200)<>FProject.ID then raise Exception.Create('対象作品が切り替わりました。状態を取得し直してください。');
  end;
  procedure SelectLibrary;
  begin
    Scope:=Text('library',True,20); Characters:=Scope='characters';
    if Characters then begin Assets:=FCharacters; Root:=TPath.Combine(DataRoot,'Characters'); end
    else if Scope='images' then begin RequireProject; Assets:=FProject.Assets; Root:=FProject.Folder; end
    else raise Exception.Create('libraryはcharactersまたはimagesで指定してください。');
    if Mutating then begin
      if Characters and not FCharacterLibraryWritable then raise Exception.Create('共通キャラは読み取りのみです。');
    end;
  end;
  function FindAsset(const UID: string): TComicAsset;
  var Item: TComicAsset;
  begin Result:=nil; for Item in Assets do if Item.ID=UID then Exit(Item); end;
  function AssetData(Item: TComicAsset): TJSONObject;
  begin
    Result:=Item.Json; if Item.ImageFile<>'' then Result.AddPair('referencePath',Item.ImagePath(Root)) else Result.AddPair('referencePath','');
    if Characters then Result.AddPair('storageFolder',Root) else Result.AddPair('storageFolder',Root);
    if (FAssetManager<>nil) and (FAssetManager.CurrentAsset=Item) then begin
      Result.AddPair('draftName',FAssetManager.DraftName.Text); Result.AddPair('draftNotes',FAssetManager.DraftNotes.Text);
      if FAssetManager.IsCharacters then begin
        Result.AddPair('draftCharacterName',FAssetManager.CommonName.Text); Result.AddPair('draftCharacterNotes',FAssetManager.CommonNotes.Text);
      end;
    end;
  end;
  function CharacterData(Item: TComicAsset): TJSONObject;
  begin
    Result:=Item.Json;
    Result.AddPair('referencePath',ProjectCharacterPath(FProject,FCharacters,Item.ID));
    if (FAssetManager<>nil) and FAssetManager.IsCharacters and (FAssetManager.CurrentAsset<>nil) and
      (FAssetManager.CurrentAsset.CharacterID=Item.CharacterID) then begin
      Result.AddPair('draftCharacterName',FAssetManager.CommonName.Text); Result.AddPair('draftCharacterNotes',FAssetManager.CommonNotes.Text);
    end;
  end;
  procedure Persist;
  begin
    if Characters then WriteAssets(Assets,TPath.Combine(Root,'Library.json'))
    else begin CaptureProjectReferences(FProject,FCharacters); AtomicWrite(TPath.Combine(Root,'Draft.json'),FProject.Snapshot); end;
  end;
  procedure Published;
  var Warnings: TJSONArray;
    procedure Warn(const Message: string);
    begin if Warnings=nil then begin Warnings:=TJSONArray.Create; Data.AddPair('warnings',Warnings); end; Warnings.Add(Message); end;
  begin
    Warnings:=nil;
    if not Characters then begin
      if (FAssetManager=nil) or FAssetManager.IsCharacters then begin FUndo.Add(Before); FRedo.Clear; if FUndo.Count>40 then FUndo.Delete(0); end;
      FDirty:=True; FRenderer.ClearCache;
    end;
    if Generated and (FGenerationActive<>nil) and not Characters then
      FRenderer.PrimeImage(ID,FGenerationActive.Worker.TakeBitmap);
    if FAssetManager<>nil then
      try
        if Generated and (FGenerationActive<>nil) then FAssetManager.RefreshFromGenerated(FGenerationActive.AssetID,FGenerationActive.Worker.Preview)
        else FAssetManager.RefreshFromExternal; if FAssetManager.PreviewError<>'' then Warn('参照画像の表示: '+FAssetManager.PreviewError);
      except on E: Exception do Warn('管理画面の更新: '+E.Message); end;
    try RefreshUI; except on E: Exception do Warn('ページ画面の更新: '+E.Message); end;
  end;
begin
  Generated:=False; ManagedLock:=nil;
  Value:=TJSONObject.ParseJSONValue(Request); Output:=TJSONObject.Create; Keys:=TDictionary<string,Boolean>.Create;
  try
    try
      if not (Value is TJSONObject) then raise Exception.Create('要求はJSONオブジェクトで指定してください。');
      Input:=TJSONObject(Value);
      for Pair in Input do begin if Keys.ContainsKey(Pair.JsonString.Value) then raise Exception.Create('同じ項目を重複指定できません。'); Keys.Add(Pair.JsonString.Value,True); end;
      if JNum(Input,'version',0)<>1 then raise Exception.Create('version:1を指定してください。');
      RequestID:=Text('requestId',False,128); if RequestID<>'' then Output.AddPair('requestId',RequestID);
      Action:=Text('action',True,40); Data:=TJSONObject.Create; Output.AddPair('data',Data);
      Mutating:=(Action='create_asset') or (Action='register_image') or (Action='start_script_generation') or (Action='cancel_generation');
      if Mutating and (InlineTextActive or FDragging or FFirst or (FGeometryPoints.Count>0) or (FSplitStage>0)) then raise Exception.Create('編集操作の確定または取消後に登録してください。');
      WriteTarget:=Self; if FAssetManager<>nil then WriteTarget:=FAssetManager;
      if Mutating and (FImageWorkspace<>nil) and HandleAllocated and not IsWindowEnabled(Handle) then
        raise Exception.Create('開いているダイアログを閉じてから登録してください。');
      // 標準ダイアログはActiveCustomFormに現れないため、所有ウィンドウの無効化も書込拒否の境界に使う。
      if Mutating and WriteTarget.HandleAllocated and not IsWindowEnabled(WriteTarget.Handle) then
        raise Exception.Create('開いているダイアログを閉じてから登録してください。');
      if Mutating and not FTesting and (Screen.ActiveCustomForm<>nil) and (Screen.ActiveCustomForm<>Self) and
        (Screen.ActiveCustomForm<>FAssetManager) then raise Exception.Create('別の編集画面を閉じてから登録してください。');
      if Action='status' then begin
        Data.AddPair('version',TJSONNumber.Create(1)); Data.AddPair('characterLibraryWritable',TJSONBool.Create(FCharacterLibraryWritable));
        Data.AddPair('canProduce',TJSONBool.Create(FProject<>nil));
        if FProject<>nil then begin
          Info:=TJSONObject.Create; Data.AddPair('project',Info); Info.AddPair('id',FProject.ID); Info.AddPair('title',FProject.Title);
          Info.AddPair('episode',FProject.Episode); Info.AddPair('folder',FProject.Folder); Info.AddPair('pageId','');
          if Page<>nil then begin Pair:=Info.RemovePair('pageId'); Pair.Free; Info.AddPair('pageId',Page.ID); end;
          Info.AddPair('generationPresetId',FProject.GenerationPresetID); Info.AddPair('generationPresetName',FProject.GenerationPresetName);
          Info.AddPair('generationInstructions',FProject.GenerationInstructions);
          Info.AddPair('scriptLoaded',TJSONBool.Create(FProject.ScriptSource<>''));
        end;
        if (FAssetManager<>nil) and (FAssetManager.CurrentAsset<>nil) then begin
          Characters:=FAssetManager.IsCharacters;
          if Characters then begin Root:=TPath.Combine(DataRoot,'Characters'); Scope:='characters'; end
          else begin Root:=FProject.Folder; Scope:='images'; end;
          Info:=AssetData(FAssetManager.CurrentAsset); Info.AddPair('library',Scope); Data.AddPair('selection',Info);
        end else if (FProject<>nil) and (FImages.ItemIndex>=0) then begin
          Characters:=False; Root:=FProject.Folder; Info:=AssetData(TComicAsset(FImages.Items.Objects[FImages.ItemIndex]));
          Info.AddPair('library','images'); Data.AddPair('selection',Info);
        end;
      end else if Action='read_script' then begin
        RequireProject; Data.AddPair('source',FProject.ScriptSource);
        Data.AddPair('plan',ScriptGenerationPlan(FProject,FCharacters));
        Data.AddPair('sequenceActive',TJSONBool.Create(FScriptGenerationProject<>''));
        Data.AddPair('generatedCount',TJSONNumber.Create(FScriptGenerationCount));
        if FGenerationActive<>nil then begin
          Data.AddPair('activeAssetId',FGenerationActive.AssetID); Data.AddPair('stage',FGenerationActive.Worker.Stage);
        end;
        if (FAssetManager<>nil) and (FAssetManager.GenerationStatus<>nil) then Data.AddPair('status',FAssetManager.GenerationStatus.Caption);
      end else if Action='generation_context' then begin
        RequireProject; ID:=Text('assetId',True,200);
        Path:=GenerationSnapshot('images',FProject.ID,ID,GenerationRefs);
        Data.AddPair('fingerprint',Path); Data.AddPair('context',TJSONObject.ParseJSONValue(Path));
      end else if Action='start_script_generation' then begin
        RequireProject;
        if (FAssetManager=nil) or FAssetManager.IsCharacters then raise Exception.Create('画像管理を開いてから開始してください。');
        if (Input.GetValue('limit')<>nil) and not (Input.GetValue('limit') is TJSONNumber) then raise Exception.Create('limitは整数で指定してください。');
        if (JNum(Input,'limit',0)<0) or (JNum(Input,'limit',0)>10000) or (Frac(JNum(Input,'limit',0))<>0) then raise Exception.Create('limitは0〜10000の整数で指定してください。');
        RunWorkspaceStartScriptGeneration(Self,FAssetManager,Round(JNum(Input,'limit',0)));
        Data.AddPair('started',TJSONBool.Create(FGenerationActive<>nil)); Data.AddPair('status',FAssetManager.GenerationStatus.Caption);
      end else if Action='cancel_generation' then begin
        RequireProject; CancelGeneration(nil); Data.AddPair('cancelled',TJSONBool.Create(True));
      end else if Action='list_presets' then begin
        Items:=TJSONArray.Create; Data.AddPair('presets',Items); for Preset in FGenerationPresets do Items.AddElement(Preset.Json);
        Data.AddPair('writable',TJSONBool.Create(FGenerationWritable));
      end else if (Action='list_assets') or (Action='read_asset') then begin
        SelectLibrary;
        if Action='list_assets' then begin Items:=TJSONArray.Create; Data.AddPair('assets',Items); for Asset in Assets do Items.AddElement(AssetData(Asset)); end
        else begin
          Asset:=FindAsset(Text('assetId',True,200)); if Asset=nil then raise Exception.Create('対象IDが見つかりません。');
          Data.AddPair('asset',AssetData(Asset)); Parent:=FindAsset(Asset.ParentID); if Parent<>nil then Data.AddPair('parent',AssetData(Parent));
          if not Characters then begin
            Source:=FindAsset(Asset.SourceID);
            if (Source<>nil) and (Source<>Parent) then Data.AddPair('source',AssetData(Source));
            if (Asset.SourceID<>'') and (Source=nil) then Data.AddPair('sourceMissing',TJSONBool.Create(True));
            Items:=TJSONArray.Create; Data.AddPair('references',Items);
            for RefID in Asset.CharacterRefs do begin
              Ref:=ProjectCharacter(FProject,FCharacters,RefID); RefData:=TJSONObject.Create; Items.AddElement(RefData);
              RefData.AddPair('id',RefID);
              if Ref=nil then RefData.AddPair('missing',TJSONBool.Create(True))
              else begin
                RefData.AddPair('asset',CharacterData(Ref)); Parent:=ProjectCharacter(FProject,FCharacters,Ref.ParentID);
                if (Parent<>nil) and (Parent<>Ref) then begin RefParent:=CharacterData(Parent); RefData.AddPair('parent',RefParent); end;
              end;
            end;
          end;
        end;
      end else if Action='create_asset' then begin
        SelectLibrary; ParentID:=Text('parentId',False,200); Parent:=FindAsset(ParentID);
        if (ParentID<>'') and ((Parent=nil) or (Parent.ParentID<>'')) then raise Exception.Create('子は既存の親を指定してください。');
        ID:=Trim(Text('name',True,200)); if ID='' then raise Exception.Create('名前を指定してください。'); Path:=Text('notes');
        Mode:=Text('mode',False,40); SourceID:=Text('sourceId',False,200); Source:=nil;
        if not Characters then begin
          if SourceID<>'' then Source:=FindAsset(SourceID) else Source:=Parent;
          if (SourceID<>'') and (Source=nil) then raise Exception.Create('参照元の画像が見つかりません。');
          if Mode='' then begin if Source<>nil then Mode:='child' else Mode:='scene'; end;
          if (Mode='scene') and ((ParentID<>'') or (SourceID<>'')) then raise Exception.Create('新規場面には参照元を指定しません。');
          if (Mode='alternate_scene') and (ParentID<>'') then raise Exception.Create('別位置の背景は親階層へ追加します。');
          RefProbe:=TComicAsset.Create;
          try RefProbe.Read(Input); ParsedRefs:=Copy(RefProbe.CharacterRefs); finally RefProbe.Free; end;
          for RefID in ParsedRefs do if ProjectCharacter(FProject,FCharacters,RefID)=nil then raise Exception.Create('参照人物IDが見つかりません：'+RefID);
          if ((Mode='scene') or (Mode='alternate_scene')) and (Length(ParsedRefs)>0) then raise Exception.Create('背景の親は人物を参照しません。');
        end else if (Mode<>'') or (SourceID<>'') or (Input.GetValue('characterIds')<>nil) then raise Exception.Create('人物登録には画像用の追加方式を指定できません。');
        if FAssetManager<>nil then FAssetManager.FlushDraft;
        if not Characters then Before:=FProject.Snapshot;
        if Characters then begin Created:=TComicAsset.Create; Created.Name:=ID; Created.Notes:=Path; Created.ParentID:=ParentID; end
        else begin
          Created:=NewSceneAsset(Assets,Source,Mode,ID,Path,FProject.Title,FProject.Episode);
          if Input.GetValue('characterIds')<>nil then Created.CharacterRefs:=Copy(ParsedRefs);
        end;
        Assets.Add(Created);
        if Characters then NormalizeCharacters(Assets);
        try Persist; except Assets.Remove(Created); raise; end;
        Data.AddPair('asset',AssetData(Created)); Published;
      end else if Action='register_image' then begin
        SelectLibrary; Asset:=FindAsset(Text('assetId',True,200)); if Asset=nil then raise Exception.Create('対象IDが見つかりません。');
        Generated:=Input.GetValue('generationRequestId')<>nil; AlreadyAdopted:=False;
        if Generated then begin
          if (FGenerationActive=nil) or (Text('generationRequestId',True,200)<>FGenerationActive.RequestID) or
            (Scope<>FGenerationActive.LibraryName) or (Asset.ID<>FGenerationActive.AssetID) or
            not FGenerationActive.Worker.Finished or not FGenerationActive.Worker.Success or
            not GenerationTargetMatches(FGenerationActive) then raise Exception.Create('生成要求が失効したか、対象が変更されました。');
          AlreadyAdopted:=FGenerationActive.Adopted;
        end;
        if not AlreadyAdopted and (Input.GetValue('expectedFileName')<>nil) and (Text('expectedFileName',False,1024)<>Asset.ImageFile) then
          raise Exception.Create('対象画像が更新されています。状態を取得し直してください。');
        if not Characters and (Input.GetValue('expectedContext')<>nil) then begin
          if FAssetManager<>nil then FAssetManager.FlushDraft;
          if Text('expectedContext',True,131072)<>GenerationSnapshot('images',FProject.ID,Asset.ID,GenerationRefs) then
            raise Exception.Create('生成条件または参照画像が変わりました。状態を取得し直してください。');
        end;
        Path:=Text('sourcePath',True,4096); RequireLocalImagePath(Path); Path:=TPath.GetFullPath(Path);
        if not AlreadyAdopted then begin
          if FAssetManager<>nil then FAssetManager.FlushDraft;
          if not Characters then Before:=FProject.Snapshot;
          if Generated then begin
            Relative:=FGenerationActive.Worker.PreparedRelative;
            if (Relative='') or not SameFileName(ExcludeTrailingPathDelimiter(TPath.GetFullPath(Root)),ExcludeTrailingPathDelimiter(TPath.GetFullPath(FGenerationActive.Root))) or
              not SameFileName(Path,SafeChild(Root,Relative)) then raise Exception.Create('受信した生成ファイルと登録先が一致しません。');
          end else begin
            Relative:='';
            Relative:=CopyValidatedComicImage(Path,Root,Relative);
            ID:=SafeChild(Root,Relative);
            try
              ManagedLock:=TFileStream.Create(ID,fmOpenRead or fmShareDenyWrite);
              ValidateComicImage(ID);
            except FreeAndNil(ManagedLock); try TFile.Delete(ID); except end; raise; end;
          end;
          ID:=SafeChild(Root,Relative); OldFile:=Asset.RelativePath;
          try
            Asset.RelativePath:=Relative; Persist;
          except
            Asset.RelativePath:=OldFile; FreeAndNil(ManagedLock);
            if not Generated then try TFile.Delete(ID); except end;
            raise;
          end;
          if Generated then begin FGenerationActive.Adopted:=True; FGenerationActive.Worker.MarkAdopted; end;
        end;
        Data.AddPair('asset',AssetData(Asset)); if not AlreadyAdopted then Published;
      end else raise Exception.Create('未対応の操作です：'+Action);
      Output.AddPair('ok',TJSONBool.Create(True));
    except on E: Exception do begin Pair:=Output.RemovePair('data'); Pair.Free;
      Output.AddPair('ok',TJSONBool.Create(False)); Output.AddPair('error',E.Message); end; end;
    Reply:=Output.ToJSON;
  finally ManagedLock.Free; Keys.Free; Output.Free; Value.Free; end;
end;
procedure HandleWorkspaceBridge(Form: TMainForm; const Request: string; out Reply: string);
begin Form.HandleWorkspaceBridge(Request,Reply); end;
end.
