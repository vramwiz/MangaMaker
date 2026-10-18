unit ComicIntegrationTests;

// 責務：実ローカルパイプと生成指示の回帰を検証する。外部画像生成は実行しない。
interface
uses ComicTestSupport;
procedure RunBridgeChecks(Host: TComicTestForm);
procedure RunGenerationPresetChecks(Host: TComicTestForm);
implementation
uses Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, Winapi.Imm,
  System.SysUtils, System.Classes, System.Types, System.UITypes,
  System.Math, System.IOUtils, System.Generics.Collections, System.JSON,
  System.Hash, System.DateUtils, Vcl.Controls, Vcl.Forms,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Menus,
  Vcl.Dialogs, Vcl.Graphics, Vcl.Imaging.pngimage, ComicModel,
  ComicAssetDialog, ComicExport, ComicGenerationPresets, ComicGenerationDialog,
  ComicBridge;
type
  TComicIntegrationTestsHelper = class helper for TComicTestForm
    procedure BridgeChecks;
    procedure GenerationPresetChecks;
  end;
procedure TComicIntegrationTestsHelper.BridgeChecks;
  var Probe: TComicTestForm; Bridge: TComicBridge; Project,Reloaded: TComicProject; Manager: TAssetDialog;
    Request,Reply,Data,AssetDataValue: TJSONObject; Pair: TJSONPair; Asset,Other: TComicAsset;
    UID,ChildID,ImageID,OldFile,NewFile,LibraryPath,LibraryBytes,Manifest,Before,After,Original: string;
    Client: TThread; Completed,Lock,Pipe: THandle; Deadline,Started: UInt64; ReplyText,ErrorText: string;
    Failed: Boolean; History,FileCount: Integer; PNG: TPngImage; CorruptPath,AdoptedID: string; ImageBytes: TBytes;
    function Send(const Text: string): TJSONObject;
    begin
      ReplyText:=''; ErrorText:=''; Completed:=CreateEvent(nil,True,False,nil); if Completed=0 then RaiseLastOSError;
      Client:=TThread.CreateAnonymousThread(procedure
        begin
          try ReplyText:=ComicBridgeRequest(Bridge.PipeName,Text,3000);
          except on E: Exception do ErrorText:=E.Message; end;
          SetEvent(Completed);
        end);
      Client.FreeOnTerminate:=False;
      try
        Client.Start; Deadline:=GetTickCount64+5000;
        while (WaitForSingleObject(Completed,10)=WAIT_TIMEOUT) and (GetTickCount64<Deadline) do CheckSynchronize(0);
        Client.WaitFor;
        if ErrorText<>'' then raise Exception.Create('Bridge client: '+ErrorText);
        Result:=TJSONObject.ParseJSONValue(ReplyText) as TJSONObject;
        if Result=nil then raise Exception.Create('Bridge response is not JSON.');
      finally Client.Free; CloseHandle(Completed); end;
    end;
    function NewRequest(const Action,LibraryName: string): TJSONObject;
    begin
      Result:=TJSONObject.Create; Result.AddPair('version',TJSONNumber.Create(1)); Result.AddPair('action',Action);
      if LibraryName<>'' then Result.AddPair('library',LibraryName);
      if LibraryName='images' then Result.AddPair('projectId',Project.ID);
    end;
    procedure Run;
    begin FreeAndNil(Reply); Reply:=Send(Request.ToJSON); FreeAndNil(Request); end;
    procedure Good(const Message: string);
    begin Check(JStr(Reply,'ok','')='true',Message+' '+JStr(Reply,'error','')); end;
    procedure Bad(const Message: string);
    begin Check((JStr(Reply,'ok','')='false') and (JStr(Reply,'error','')<>''),Message); end;
    procedure ExternalClient;
    var Script,ResultFile,Command,ShellPath: string; Startup: TStartupInfo; Process: TProcessInformation; Code: DWORD; ResultJson: TJSONObject;
      function PSQuote(const Value: string): string;
      begin Result:=''''+StringReplace(Value,'''','''''',[rfReplaceAll])+''''; end;
    begin
      Script:=TPath.Combine(TestFolder,'bridge-client-test.ps1'); ResultFile:=TPath.Combine(TestFolder,'bridge-client-result.json');
      AtomicWrite(Script,'$ErrorActionPreference = ''Stop'''+#13#10+
        '$result = & '+PSQuote(TPath.GetFullPath('Tools\MangaMakerBridge.ps1'))+' -ManifestPath '+PSQuote(Bridge.ManifestPath)+' -TimeoutMS 3000'+#13#10+
        '[IO.File]::WriteAllText('+PSQuote(ResultFile)+', ($result | ConvertTo-Json -Depth 64), [Text.UTF8Encoding]::new($false))');
      ShellPath:=TPath.Combine(GetEnvironmentVariable('SystemRoot'),'System32\WindowsPowerShell\v1.0\powershell.exe');
      Command:='"'+ShellPath+'" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+Script+'"';
      Startup:=Default(TStartupInfo); Startup.cb:=SizeOf(Startup); Startup.dwFlags:=STARTF_USESHOWWINDOW; Startup.wShowWindow:=SW_HIDE;
      Process:=Default(TProcessInformation);
      if not CreateProcess(nil,PChar(Command),nil,nil,False,CREATE_NO_WINDOW,nil,PChar(TestFolder),Startup,Process) then RaiseLastOSError;
      try
        Deadline:=GetTickCount64+12000;
        while (WaitForSingleObject(Process.hProcess,10)=WAIT_TIMEOUT) and (GetTickCount64<Deadline) do CheckSynchronize(0);
        GetExitCodeProcess(Process.hProcess,Code); Check((Code=0) and FileExists(ResultFile),'PowerShell helper reaches live pipe from a separate process');
      finally CloseHandle(Process.hThread); CloseHandle(Process.hProcess); end;
      ResultJson:=TJSONObject.ParseJSONValue(TFile.ReadAllText(ResultFile,TEncoding.UTF8)) as TJSONObject;
      try Check((JStr(ResultJson,'ok','')='true') and
        (JStr(ResultJson.GetValue<TJSONObject>('data').GetValue<TJSONObject>('project'),'generationInstructions','')=Project.GenerationInstructions),
        'separate PowerShell client preserves multiline Japanese generation instructions');
      finally ResultJson.Free; end;
    end;
  begin
    Original:=FProject.Snapshot; LibraryPath:=TPath.Combine(DataRoot,'Characters\Library.json'); LibraryBytes:=TFile.ReadAllText(LibraryPath,TEncoding.UTF8);
    Probe:=TComicTestForm.Create(nil); Bridge:=nil; Request:=nil; Reply:=nil; Manager:=nil; PNG:=TPngImage.Create;
    try
      Project:=CreateFixtureProject; Project.Initialize('パイプ fixture','1'); Project.GenerationInstructions:='作品の指示'+#13#10+'第2行'; Probe.AdoptProject(Project,False);
      Bridge:=TComicBridge.Create(TPath.Combine(TestFolder,'Runtime'),Probe.BridgeRequest); Manifest:=Bridge.ManifestPath;
      Check(FileExists(Manifest) and (Pos(Bridge.PipeName,TFile.ReadAllText(Manifest,TEncoding.UTF8))>0),'local pipe publishes a unique process manifest');
      Request:=NewRequest('status',''); Request.AddPair('requestId','照会-1'); Run; Good('live pipe answers UTF-8 status');
      Data:=Reply.GetValue<TJSONObject>('data'); AssetDataValue:=Data.GetValue<TJSONObject>('project');
      Check((JStr(Reply,'requestId','')='照会-1') and (JStr(AssetDataValue,'id','')=Project.ID) and
        (JStr(AssetDataValue,'generationInstructions','')=Project.GenerationInstructions),'status carries project identity and generation snapshot');
      Probe.HandleNeeded; Before:=TFile.ReadAllText(LibraryPath,TEncoding.UTF8); FileCount:=Probe.FCharacters.Count;
      EnableWindow(Probe.Handle,False);
      try
        Request:=NewRequest('status',''); Run; Good('native disabled main window still allows bridge status');
        Request:=NewRequest('create_asset','characters'); Request.AddPair('name','native modal blocked'); Run;
        Bad('native common dialog owner blocks bridge mutation before publication');
        Check((Probe.FCharacters.Count=FileCount) and (TFile.ReadAllText(LibraryPath,TEncoding.UTF8)=Before),
          'native modal write rejection preserves character list and library bytes');
      finally EnableWindow(Probe.Handle,True); end;
      Request:=NewRequest('create_asset','characters'); Request.AddPair('name','パイプ人物'); Request.AddPair('notes','親の外見補足'); Run; Good('pipe creates a named character without an image');
      UID:=JStr(Reply.GetValue<TJSONObject>('data').GetValue<TJSONObject>('asset'),'id','');
      Request:=NewRequest('register_image','characters'); Request.AddPair('assetId',UID); Request.AddPair('sourcePath',TPath.Combine(TestFolder,'reference.bmp')); Run; Good('pipe registers a validated image by character identity');
      OldFile:=JStr(Reply.GetValue<TJSONObject>('data').GetValue<TJSONObject>('asset'),'file','');
      Asset:=nil; for Other in Probe.FCharacters do if Other.ID=UID then Asset:=Other;
      Check((Asset<>nil) and (Asset.FileName<>'') and FileExists(SafeChild(TPath.Combine(DataRoot,'Characters'),Asset.FileName)),
        'registered character image is copied into app storage'); OldFile:=Asset.FileName;
      Request:=NewRequest('create_asset','characters'); Request.AddPair('name','服装の子'); Request.AddPair('parentId',UID); Run; Good('pipe creates a second-level clothing item');
      ChildID:=JStr(Reply.GetValue<TJSONObject>('data').GetValue<TJSONObject>('asset'),'id','');
      Request:=NewRequest('create_asset','characters'); Request.AddPair('name','3階層'); Request.AddPair('parentId',ChildID); Run; Bad('pipe rejects a third hierarchy level');
      Manager:=TAssetDialog.CreateManager(Probe,Probe.FCharacters,nil,True); Probe.FAssetManager:=Manager; Manager.SelectAsset(ChildID);
      Manager.DraftName.Text:='編集中の服装'; Manager.DraftNotes.Text:='選択中の下書き';
      Request:=NewRequest('status',''); Run; Good('pipe status works while character management is open');
      Data:=Reply.GetValue<TJSONObject>('data').GetValue<TJSONObject>('selection');
      Check((JStr(Data,'id','')=ChildID) and (JStr(Data,'draftNotes','')='選択中の下書き') and (JStr(Data,'library','')='characters'),
        'pipe status exposes selected identity and unsaved draft without changing selection');
      Manager.HandleNeeded; EnableWindow(Probe.Handle,False);
      try
        Request:=NewRequest('create_asset','characters'); Request.AddPair('name','manager remains writable'); Run;
        Good('enabled asset manager allows registration while its main owner is disabled');
        Before:=TFile.ReadAllText(LibraryPath,TEncoding.UTF8); FileCount:=Probe.FCharacters.Count; Manager.DraftNotes.Text:='native picker pending draft';
        EnableWindow(Manager.Handle,False);
        try
          Request:=NewRequest('status',''); Run; Good('nested native dialog still allows selected draft status');
          Request:=NewRequest('create_asset','characters'); Request.AddPair('name','nested native blocked'); Run;
          Bad('nested native dialog blocks writes to its disabled asset manager');
          Check((Probe.FCharacters.Count=FileCount) and (TFile.ReadAllText(LibraryPath,TEncoding.UTF8)=Before) and
            (Manager.DraftNotes.Text='native picker pending draft') and (Manager.CurrentAsset.Notes='選択中の下書き'),
            'nested native write rejection keeps library and uncommitted manager draft');
        finally EnableWindow(Manager.Handle,True); Manager.DraftNotes.Text:='選択中の下書き'; end;
      finally EnableWindow(Probe.Handle,True); end;
      Request:=NewRequest('register_image','characters'); Request.AddPair('assetId',UID); Request.AddPair('expectedFileName',OldFile);
      Request.AddPair('sourcePath',TPath.Combine(TestFolder,'reference.bmp')); Run; Good('registration targets its identity after selection changes');
      NewFile:=Asset.FileName;
      Check((Manager.CurrentAsset.ID=ChildID) and (Manager.CurrentAsset.FileName='') and (NewFile<>OldFile) and
        FileExists(SafeChild(TPath.Combine(DataRoot,'Characters'),OldFile)), 'registration preserves changed selection and previous image bytes');
      Request:=NewRequest('read_asset','characters'); Request.AddPair('assetId',ChildID); Run; Good('pipe reads the requested child and parent');
      Data:=Reply.GetValue<TJSONObject>('data'); Check((JStr(Data.GetValue<TJSONObject>('parent'),'id','')=UID) and
        (JStr(Data.GetValue<TJSONObject>('parent'),'referencePath','')<>''),'child query carries only its named parent reference');
      Request:=NewRequest('register_image','characters'); Request.AddPair('assetId',UID); Request.AddPair('expectedFileName',OldFile);
      Request.AddPair('sourcePath',TPath.Combine(TestFolder,'reference.bmp')); Run; Bad('stale image expectation rejects registration');
      Request:=NewRequest('register_image','characters'); Request.AddPair('assetId',UID); Request.AddPair('sourcePath',TPath.Combine(TestFolder,'missing.png')); Run; Bad('missing generated image leaves the existing reference');
      Check(Asset.FileName=NewFile,'failed registration preserves the adopted image');
      Manager.SelectAsset(UID); CorruptPath:=SafeChild(TPath.Combine(DataRoot,'Characters'),Asset.FileName); ImageBytes:=TFile.ReadAllBytes(CorruptPath);
      try
        AtomicWrite(CorruptPath,'broken image');
        Request:=NewRequest('create_asset','characters'); Request.AddPair('name','別の登録先'); Request.AddPair('parentId',UID); Run;
        Good('a broken selected preview cannot turn a saved creation into an error');
        AdoptedID:=JStr(Reply.GetValue<TJSONObject>('data').GetValue<TJSONObject>('asset'),'id','');
        Check((Manager.CurrentAsset.ID=UID) and (Manager.PreviewError<>'') and
          (Reply.GetValue<TJSONObject>('data').GetValue('warnings') is TJSONArray), 'preview failure is reported separately while manager selection remains usable');
        Request:=NewRequest('register_image','characters'); Request.AddPair('assetId',AdoptedID); Request.AddPair('expectedFileName','');
        Request.AddPair('sourcePath',TPath.Combine(TestFolder,'reference.bmp')); Run;
        Good('saved image registration succeeds while another selected preview is corrupt');
        Check(Reply.GetValue<TJSONObject>('data').GetValue('warnings') is TJSONArray,'successful adoption includes a separate preview warning');
        Request:=NewRequest('register_image','characters'); Request.AddPair('assetId',AdoptedID); Request.AddPair('expectedFileName','');
        Request.AddPair('sourcePath',TPath.Combine(TestFolder,'reference.bmp')); Run; Bad('repeating stale registration after a preview warning cannot adopt twice');
        Request:=NewRequest('read_asset','characters'); Request.AddPair('assetId',AdoptedID); Run;
        Good('saved target can be queried after a preview warning without repeating creation');
      finally TFile.WriteAllBytes(CorruptPath,ImageBytes); Manager.RefreshFromExternal; end;
      Check((Manager.PreviewError='') and (Manager.CurrentAsset.ID=UID),'repaired external preview resumes without changing adopted target or selection');
      FileCount:=Length(TDirectory.GetFiles(TPath.Combine(DataRoot,'Characters'),'*.bmp')); Before:=TFile.ReadAllText(LibraryPath,TEncoding.UTF8);
      Lock:=CreateFile(PChar(LibraryPath),GENERIC_READ,FILE_SHARE_READ,nil,OPEN_EXISTING,0,0);
      try
        Request:=NewRequest('register_image','characters'); Request.AddPair('assetId',UID); Request.AddPair('sourcePath',TPath.Combine(TestFolder,'reference.bmp')); Run;
        Bad('library publication failure is returned through the live pipe');
        Check((Asset.FileName=NewFile) and (Length(TDirectory.GetFiles(TPath.Combine(DataRoot,'Characters'),'*.bmp'))=FileCount) and
          (TFile.ReadAllText(LibraryPath,TEncoding.UTF8)=Before),'failed registration rolls back metadata and removes only its new copied file');
      finally CloseHandle(Lock); end;
      Probe.FAssetManager:=nil; FreeAndNil(Manager);
      Probe.FCharacterLibraryWritable:=False; Request:=NewRequest('create_asset','characters'); Request.AddPair('name','禁止'); Run; Bad('pipe respects protected character library'); Probe.FCharacterLibraryWritable:=True;
      Request:=NewRequest('create_asset','images'); Request.AddPair('name','背景'); Run; Good('pipe creates a project scene');
      ImageID:=JStr(Reply.GetValue<TJSONObject>('data').GetValue<TJSONObject>('asset'),'id',''); Before:=Project.Snapshot; History:=Probe.FUndo.Count;
      Request:=NewRequest('register_image','images'); Request.AddPair('assetId',ImageID); Request.AddPair('sourcePath',TPath.Combine(TestFolder,'reference.bmp')); Run; Good('pipe registers a project image');
      After:=Project.Snapshot; NewFile:=Project.Asset(ImageID).FileName;
      Check((Probe.FUndo.Count=History+1) and (Project.Asset(ImageID).FileName<>'') and FileExists(Project.ImagePath(ImageID)),
        'project image registration commits one undo operation');
      Reloaded:=CreateFixtureProject;
      try Reloaded.Load(TPath.Combine(Project.Folder,'Draft.json')); Check(Reloaded.Snapshot=After,'registered image and project generation snapshot persist in recoverable draft');
      finally Reloaded.Free; end;
      Probe.Undo(nil); Check(Project.Snapshot=Before,'pipe image registration undo restores previous reference');
      Probe.Redo(nil); Check((Project.Snapshot=After) and FileExists(Project.ImagePath(ImageID)),'pipe registration redo reuses retained copied bytes');
      Request:=NewRequest('register_image','images'); Pair:=Request.RemovePair('projectId'); Pair.Free; Request.AddPair('projectId','old-project');
      Request.AddPair('assetId',ImageID); Request.AddPair('sourcePath',TPath.Combine(TestFolder,'reference.bmp')); Run; Bad('changed project identity rejects a late image');
      Check(Project.Snapshot=After,'late registration cannot mutate the newly selected project');
      Probe.FDragging:=True; Request:=NewRequest('create_asset','images'); Request.AddPair('name','操作中'); Run; Bad('pending edit blocks pipe mutation'); Probe.FDragging:=False;
      FreeAndNil(Reply); Reply:=Send('{bad}'); Bad('malformed JSON returns a framed error and keeps server alive');
      FreeAndNil(Reply); Reply:=Send('{"version":1,"action":"status","action":"action"}'); Bad('duplicate JSON keys cannot change command meaning');
      Request:=NewRequest('list_presets',''); Run; Good('pipe exposes common generation instructions');
      Failed:=False; try ComicBridgeRequest('\\remote\pipe\unsafe','{}',10); except Failed:=True; end; Check(Failed,'native bridge client rejects remote pipe names');
      Request:=NewRequest('status',''); Run; Good('pipe remains usable after rejected requests');
      ExternalClient;
      // 未完の要求を残して終了し、受信待ちのI/Oが取り消されることを確認する。
      WaitNamedPipe(PChar('\\.\pipe\'+Bridge.PipeName),1000);
      Pipe:=CreateFile(PChar('\\.\pipe\'+Bridge.PipeName),GENERIC_READ or GENERIC_WRITE,0,nil,OPEN_EXISTING,FILE_FLAG_OVERLAPPED,0);
      Check(Pipe<>INVALID_HANDLE_VALUE,'incomplete bridge connection opens for cancellation regression');
      try Started:=GetTickCount64; FreeAndNil(Bridge); Check(GetTickCount64-Started<1500,'app shutdown cancels an incomplete pipe read promptly');
      finally CloseHandle(Pipe); end;
      Check(not FileExists(Manifest),'shutdown removes only this process bridge manifest');
      Check(FProject.Snapshot=Original,'live pipe fixtures preserve the active project');
    finally
      Probe.FAssetManager:=nil; Manager.Free; Request.Free; Reply.Free; Bridge.Free; PNG.Free; Probe.Free;
      AtomicWrite(LibraryPath,LibraryBytes);
    end;
  end;

procedure RunBridgeChecks(Host: TComicTestForm);
begin Host.BridgeChecks; end;
procedure TComicIntegrationTestsHelper.GenerationPresetChecks;
  var Probe: TComicTestForm; Project,Reloaded: TComicProject; Presets,CopyPresets,Broken: TObjectList<TComicGenerationPreset>;
    Preset: TComicGenerationPreset; Dialog: TComicGenerationDialog; Path,ID,Instructions,Before,Original: string;
    Lock: THandle; Failed: Boolean; I,PPI: Integer; PNG: TPngImage;
  begin
    Original:=FProject.Snapshot; Probe:=TComicTestForm.Create(nil); Presets:=TObjectList<TComicGenerationPreset>.Create; CopyPresets:=TObjectList<TComicGenerationPreset>.Create;
    Broken:=TObjectList<TComicGenerationPreset>.Create; PNG:=TPngImage.Create;
    try
      Project:=CreateFixtureProject; Project.Initialize('生成指示 fixture','1'); Probe.AdoptProject(Project,False);
      Preset:=TComicGenerationPreset.Create; Preset.Name:='漫画の共通指示'; Preset.Instructions:='人物の同一性を保つ。'+#13#10+'背景の位置関係を維持する。';
      ID:=Preset.ID; Instructions:=Preset.Instructions; Presets.Add(Preset);
      Preset:=TComicGenerationPreset.Create; Preset.Name:='別の指示'; Preset.Instructions:='追加の指示'; Presets.Add(Preset);
      Path:=TPath.Combine(TestFolder,'generation-presets.json'); SaveGenerationPresets(Presets,Path); LoadGenerationPresets(CopyPresets,Path);
      Check((CopyPresets.Count=2) and (CopyPresets[0].ID=ID) and (CopyPresets[0].Instructions=Instructions),
        'generation presets save and reload stable identity and multiline Japanese instructions');
      Check(ExportSequence(Project,Probe.FRenderer,False)=1,'generation fixture exports its initial blank page');
      Probe.ApplyGenerationPreset(ID,Presets[0].Name,Instructions);
      Check((Project.GenerationPresetID=ID) and (Project.GenerationInstructions=Instructions),'applying generation preset copies its instruction snapshot into the project');
      Check(ExportSequence(Project,Probe.FRenderer,False)=0,'generation instruction changes leave completed PNG cache intact');
      UpdateGenerationPreset(Presets,Presets[0],'変更した共通指示','将来用の本文',Path);
      Check((Project.GenerationPresetName='漫画の共通指示') and (Project.GenerationInstructions=Instructions),
        'later common generation edits cannot alter an applied project snapshot');
      RemoveGenerationPreset(Presets,Presets[0],Path);
      Check((Presets.Count=1) and (Project.GenerationPresetID=ID) and (Project.GenerationInstructions=Instructions),
        'deleting a common generation preset preserves project instructions');
      Probe.Undo(nil); Check((Project.GenerationPresetID='') and (Project.GenerationInstructions=''),'generation preset apply undoes as one project operation');
      Probe.Redo(nil); Check(Project.GenerationInstructions=Instructions,'generation preset redo restores its exact snapshot');
      Project.Save; Reloaded:=CreateFixtureProject;
      try Reloaded.Load(TPath.Combine(Project.Folder,'Project.json')); Check(Reloaded.GenerationInstructions=Instructions,'project generation snapshot survives save and reload');
      finally Reloaded.Free; end;
      Before:=TFile.ReadAllText(Path,TEncoding.UTF8); Lock:=CreateFile(PChar(Path),GENERIC_READ,FILE_SHARE_READ,nil,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,0);
      Check(Lock<>INVALID_HANDLE_VALUE,'generation library can be locked to inject publication failure');
      try
        Failed:=False; try UpdateGenerationPreset(Presets,Presets[0],'失敗する名前','失敗する本文',Path); except Failed:=True; end;
        Check(Failed and (Presets[0].Name='別の指示') and (Presets[0].Instructions='追加の指示') and (TFile.ReadAllText(Path,TEncoding.UTF8)=Before),
          'failed generation preset update restores name body and original library');
        Failed:=False; try RemoveGenerationPreset(Presets,Presets[0],Path); except Failed:=True; end;
        Check(Failed and (Presets.Count=1) and (Presets[0].Name='別の指示'),'failed generation preset deletion restores the item and order');
      finally CloseHandle(Lock); end;
      Dialog:=TComicGenerationDialog.CreateManager(Self,CopyPresets,Path,True,True);
      try
        Dialog.SelectPreset(1); Dialog.SetDraft('作品専用に変更','表示中の本文だけを適用'); Dialog.AcceptSelection;
        Check((Dialog.ModalResult=mrOK) and (Dialog.SelectedName='作品専用に変更') and (Dialog.SelectedInstructions='表示中の本文だけを適用') and
          (CopyPresets[1].Name='別の指示') and (TFile.ReadAllText(Path,TEncoding.UTF8)=Before),
          'generation dialog applies its displayed draft without silently rewriting the common preset');
        for PPI in [96,144] do begin
          Dialog.Scaled:=True; Dialog.ScaleForPPI(PPI); Dialog.Scaled:=False; Dialog.ClientWidth:=MulDiv(880,PPI,96); Dialog.ClientHeight:=MulDiv(580,PPI,96); Dialog.Realign;
          Dialog.HandleNeeded; B.SetSize(Dialog.ClientWidth,Dialog.ClientHeight); Dialog.PaintTo(B.Canvas,0,0); PNG.Assign(B); PNG.SaveToFile(TPath.Combine(TestFolder,'generation-presets-'+IntToStr(PPI)+'.png'));
          for I:=0 to Dialog.ComponentCount-1 do if Dialog.Components[I] is TButton then with TButton(Dialog.Components[I]) do
            Check((Left>=0) and (Top>=0) and (Left+Width<=Parent.ClientWidth) and (Top+Height<=Parent.ClientHeight),
              'generation preset button remains reachable at PPI '+IntToStr(PPI)+' '+Caption);
        end;
      finally Dialog.Free; end;
      Dialog:=TComicGenerationDialog.CreateManager(Self,CopyPresets,Path,False,False);
      try
        Dialog.AcceptSelection; Check(Dialog.ModalResult=0,'generation preset cannot be applied without an open project');
        Failed:=False; try Dialog.SetDraft('禁止','本文'); except Failed:=True; end;
        Check(Failed and (CopyPresets[0].Name='漫画の共通指示'),'read-only generation manager preserves existing entries');
      finally Dialog.Free; end;
      J:=CopyPresets[0].Json; try Before:='{"version":1,"presets":['+J.ToJSON+',42]}'; finally J.Free; end;
      AtomicWrite(Path,Before); Failed:=False; try LoadGenerationPresets(Broken,Path); except Failed:=True; end;
      Check(Failed and (Broken.Count=0) and (TFile.ReadAllText(Path,TEncoding.UTF8)=Before),
        'invalid generation library cannot publish a valid prefix or overwrite source data');
      Check(FProject.Snapshot=Original,'generation fixture preserves the active editing project');
    finally PNG.Free; Broken.Free; CopyPresets.Free; Presets.Free; Probe.Free; end;
  end;

procedure RunGenerationPresetChecks(Host: TComicTestForm);
begin Host.GenerationPresetChecks; end;
end.
