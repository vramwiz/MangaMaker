unit ComicAssetsTests;

// 責務：人物・場面管理と読込失敗を検証し、元データと参照IDの保持を確認する。
interface
uses ComicTestSupport;
procedure RunSafetyChecks(Host: TComicTestForm);
procedure RunCharacterGroupChecks(Host: TComicTestForm);
procedure RunSceneGenerationChecks(Host: TComicTestForm);
implementation
uses Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, Winapi.Imm,
  System.SysUtils, System.Classes, System.Types, System.UITypes,
  System.Math, System.IOUtils, System.Generics.Collections, System.JSON,
  System.Hash, System.DateUtils, Vcl.Controls, Vcl.Forms,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Menus,
  Vcl.Dialogs, Vcl.Graphics, Vcl.Imaging.pngimage, ComicModel,
  ComicAssetDialog, ComicAssetEditing, ComicCharacterRefs;
type
  TComicAssetsTestsHelper = class helper for TComicTestForm
    procedure SafetyChecks;
    procedure CharacterGroupChecks;
    procedure SceneGenerationChecks;
  end;
procedure TComicAssetsTestsHelper.SafetyChecks;
  var LibraryPath,ValidText,BadText: string; OriginalBytes: TBytes;
    Assets: TObjectList<TComicAsset>; Existing: TComicAsset; Probe: TComicTestForm;
    Manager: TAssetDialog; P: TComicProject; Failed,CanClose: Boolean; State: string;
  begin
    LibraryPath:=TPath.Combine(DataRoot,'Characters\Library.json');
    OriginalBytes:=TFile.ReadAllBytes(LibraryPath); ValidText:=TFile.ReadAllText(LibraryPath,TEncoding.UTF8);
    Assets:=TObjectList<TComicAsset>.Create; Probe:=nil;
    try
      Existing:=TComicAsset.Create; Existing.Name:='既存の保持項目'; Assets.Add(Existing);
      BadText:=Copy(ValidText,1,Length(ValidText)-1)+',42]'; AtomicWrite(LibraryPath,BadText);
      Failed:=False; try ReadAssets(Assets,LibraryPath); except Failed:=True; end;
      Check(Failed and (Assets.Count=1) and (Assets[0]=Existing) and (Existing.Name='既存の保持項目'),
        'invalid trailing character-library item cannot publish a valid prefix');
      Check(TFile.ReadAllText(LibraryPath,TEncoding.UTF8)=BadText,'failed character-library read preserves the entire source file');
      Probe:=TComicTestForm.Create(nil);
      Check(not Probe.FCharacterLibraryWritable and (Probe.FCharacters.Count=0) and not Probe.HasCharacter,
        'startup with an invalid character library blocks production and persistence');
      Manager:=TAssetDialog.CreateManager(Probe,Probe.FCharacters,nil,True,Probe.FCharacterLibraryWritable);
      try CanClose:=True; Manager.OnCloseQuery(Manager,CanClose);
        Check(CanClose and (TFile.ReadAllText(LibraryPath,TEncoding.UTF8)=BadText),
          'closing read-only character manager cannot overwrite an unreadable library');
      finally Manager.Free; end;
      BadText:='[{"id":"safe","name":"prefix"},{"id":"unsafe","file":"..\\escape.png"}]';
      AtomicWrite(LibraryPath,BadText); Failed:=False;
      try ReadAssets(Assets,LibraryPath); except Failed:=True; end;
      Check(Failed and (Assets.Count=1) and (Assets[0]=Existing),
        'invalid character image path cannot publish earlier library entries');
      AtomicWrite(LibraryPath,ValidText); ReadAssets(Assets,LibraryPath);
      Check((Assets.Count=2) and (Assets[1].Name=FCharacters[0].Name),'repaired character library loads completely on retry');

      P:=CreateFixtureProject; P.Initialize('切替元 fixture','1'); Probe.AdoptProject(P,False);
      Probe.FGeometryPoints.Add(TPointF.Create(120,130)); Probe.FTool:=8; Probe.FFirst:=True;
      Probe.FSplitStage:=2; Probe.FSplitPanelID:='previous-panel'; Probe.FPageDropIndex:=3;
      P:=CreateFixtureProject; P.Initialize('切替先 fixture','2'); State:=P.Snapshot;
      Probe.AdoptProject(P,False);
      Check((Probe.FGeometryPoints.Count=0) and (Probe.FSplitStage=0) and (Probe.FSplitPanelID='') and
        not Probe.FFirst and (Probe.FTool=0) and (Probe.FPageDropIndex=-1),
        'new/open project adoption clears pending polygon rectangle split and page-drop state');
      Check((Probe.FProject.Snapshot=State) and (Probe.FUndo.Count=0) and (Probe.FRedo.Count=0),
        'project adoption preserves new project content and starts clean history');
      Probe.FDragging:=True; Probe.FDragMoved:=True; Probe.FDragSnapshot:=Probe.FProject.Snapshot;
      Probe.FProject.Title:='temporary drag mutation'; Probe.FDragVertex:=1;
      P:=CreateFixtureProject; P.Folder:=Probe.FProject.Folder; P.Restore(Probe.FDragSnapshot); State:=P.Snapshot;
      Probe.AdoptProject(P,True);
      Check(not Probe.FDragging and not Probe.FDragMoved and (Probe.FDragVertex=-1) and
        (Probe.FDragSnapshot='') and (Probe.FProject.Snapshot=State) and Probe.FDirty,
        'project adoption cancels the previous drag before installing recovered content');
    finally Probe.Free; Assets.Free; TFile.WriteAllBytes(LibraryPath,OriginalBytes); end;
    Check(TFile.ReadAllText(LibraryPath,TEncoding.UTF8)=ValidText,'isolated library corruption tests restore the fixture library');
  end;

procedure RunSafetyChecks(Host: TComicTestForm);
begin Host.SafetyChecks; end;
procedure TComicAssetsTestsHelper.CharacterGroupChecks;
  var Items,Reloaded,Broken: TObjectList<TComicAsset>; A,A1,A2,BRoot,B1: TComicAsset; Manager: TAssetDialog;
    AID,A1ID,A2ID,BID,GroupID,Before,Path,LibraryPath,LibraryBytes,Original: string; State: TArray<TComicAssetState>;
    Node: TTreeNode; PNG: TPngImage; Lock: THandle; Failed,CanClose: Boolean; PPI,I: Integer; Json: TJSONObject;
    function ListJson(List: TObjectList<TComicAsset>): string;
    var Json: TJSONArray; Item: TComicAsset;
    begin Json:=TJSONArray.Create; try for Item in List do Json.AddElement(Item.Json); Result:=Json.ToJSON; finally Json.Free; end; end;
    function Add(const Name,ParentID: string): TComicAsset;
    begin Result:=TComicAsset.Create; Result.Name:=Name; Result.ParentID:=ParentID; Result.Notes:='状態の補足 '+Name;
      Result.FileName:='reference.bmp'; Items.Add(Result); end;
    procedure Drag(const MovingID,TargetID: string; Expected: Boolean);
    var DragObject: TDragObject; Target,Node: TTreeNode; R: TRect; Accept: Boolean;
    begin
      Manager.SelectAsset(MovingID); Manager.HandleNeeded; Target:=nil;
      for Node in Manager.AssetTree.Items do if (Node.Data<>nil) and (TComicAsset(Node.Data).ID=TargetID) then Target:=Node;
      if Target=nil then raise Exception.Create('Character drag target missing.');
      DragObject:=nil; Manager.AssetTree.OnStartDrag(Manager.AssetTree,DragObject); Target.MakeVisible; R:=Target.DisplayRect(True);
      Manager.AssetTree.OnDragOver(Manager.AssetTree,Manager.AssetTree,R.CenterPoint.X,R.CenterPoint.Y,dsDragMove,Accept);
      Check(Accept=Expected,'character tree drag permission '+MovingID+' to '+TargetID);
      if Accept then Manager.AssetTree.OnDragDrop(Manager.AssetTree,Manager.AssetTree,R.CenterPoint.X,R.CenterPoint.Y);
      Manager.AssetTree.OnEndDrag(Manager.AssetTree,Manager.AssetTree,R.CenterPoint.X,R.CenterPoint.Y);
    end;
  begin
    Original:=FProject.Snapshot; LibraryPath:=TPath.Combine(DataRoot,'Characters\Library.json'); LibraryBytes:=TFile.ReadAllText(LibraryPath,TEncoding.UTF8);
    Items:=TObjectList<TComicAsset>.Create; Reloaded:=TObjectList<TComicAsset>.Create; Broken:=TObjectList<TComicAsset>.Create; Manager:=nil; PNG:=TPngImage.Create;
    try
      A:=Add('人物A',''); AID:=A.ID; A1:=Add('冬服',AID); A1ID:=A1.ID; A2:=Add('夏服',AID); A2ID:=A2.ID;
      BRoot:=Add('人物B',''); BID:=BRoot.ID; B1:=Add('外出着',BID); NormalizeCharacters(Items); GroupID:=A.CharacterID;
      Check((GroupID=AID) and (A1.CharacterID=GroupID) and (A2.CharacterID=GroupID) and (A.StateName='基本服装'),
        'legacy character names initialize stable shared identity and state names');
      SetCharacterInfo(Items,A1,'人物Aの共通名','共通の外見補足');
      Check((A.Name='人物Aの共通名') and (A2.CharacterName=A.Name) and (A2.CharacterNotes='共通の外見補足') and (A1.Name='冬服'),
        'editing common character information from a child preserves individual state names');
      A.CharacterNotes:=''; NormalizeCharacters(Items); Check(A.CharacterNotes='','normalization preserves an intentionally empty common supplement');
      State:=CaptureAssets(Items); Before:=ListJson(Items);
      Check(PromoteCharacter(Items,A1),'character child promotes to the base reference');
      Check((A1.ParentID='') and (A1.Name='人物Aの共通名') and (A1.StateName='冬服') and (A1.CharacterID=GroupID) and
        (A.ParentID=A1ID) and (A.Name='基本服装') and (A2.ParentID=A1ID) and (A.ID=AID) and (A2.ID=A2ID),
        'promotion swaps parent role while preserving character and every variant identity');
      Check((A.FileName='reference.bmp') and (A1.FileName='reference.bmp') and (BRoot.ParentID='') and (B1.ParentID=BID),
        'promotion retains image references and unrelated groups');
      Path:=TPath.Combine(TestFolder,'character-groups.json'); WriteAssets(Items,Path); ReadAssets(Reloaded,Path); NormalizeCharacters(Reloaded);
      Check(ListJson(Reloaded)=ListJson(Items),'promoted character group saves and reloads stable metadata order and hierarchy');
      RestoreAssets(Items,State); Check(ListJson(Items)=Before,'asset state restore keeps original object pointers and exact order');
      Check(not ReorderCharacter(Items,A1,B1) and (ListJson(Items)=Before),'character child cannot move to another person');
      Check(ReorderCharacter(Items,BRoot,A) and (Items[0]=BRoot) and (Items[1]=B1),'moving a parent carries its full group together');
      Check(ReorderCharacter(Items,A2,A1) and (Items.IndexOf(A2)<Items.IndexOf(A1)) and (A2.ParentID=AID),'child reordering remains inside the same person');
      RestoreAssets(Items,State); Manager:=TAssetDialog.CreateManager(Self,Items,nil,True); Manager.SelectAsset(A1ID);
      Manager.CommonName.Text:='画面から変更した人物'; Manager.CommonNotes.Text:='共通情報を保持'; Manager.DraftName.Text:='冬の制服'; Manager.FlushDraft;
      Check((A.Name='画面から変更した人物') and (A2.CharacterNotes='共通情報を保持') and (A1.Name='冬の制服'),
        'character manager stores common and state edits independently');
      Manager.PromoteSelected; Check((Manager.CurrentAsset=A1) and (A1.ParentID='') and (A.ParentID=A1ID) and (A1.CharacterID=GroupID),
        'promotion from the actual management command preserves selected reference and shared identity');
      for Node in Manager.AssetTree.Items do if Node.Data=Pointer(A1) then Node.Expand(False);
      Drag(A1ID,BID,True);
      Check((Items[0]=A1) and (Items[1]=A) and (Items[2]=A2),'tree parent drag moves its reference and all children as a block');
      for Node in Manager.AssetTree.Items do if Node.Data=Pointer(A1) then Check(Node.Expanded,'parent drag restores its previous expanded state');
      Drag(A2ID,AID,True); Check(Items.IndexOf(A2)<Items.IndexOf(A),'tree child drag changes same-parent order');
      Before:=ListJson(Items); Drag(A2ID,B1.ID,False); Check(ListJson(Items)=Before,'rejected cross-person tree drag preserves all assets');
      Lock:=CreateFile(PChar(LibraryPath),GENERIC_READ,FILE_SHARE_READ,nil,OPEN_EXISTING,0,0);
      Check(Lock<>INVALID_HANDLE_VALUE,'character group library locks for rollback regression');
      try
        Manager.SelectAsset(AID); Before:=ListJson(Items); Failed:=False; try Manager.PromoteSelected; except Failed:=True; end;
        Check(Failed and (ListJson(Items)=Before) and (Manager.CurrentAsset=A),'failed promotion restores the exact hierarchy metadata and object selection');
        Failed:=False; try Manager.MoveAsset(BID,A1ID); except Failed:=True; end;
        Check(Failed and (ListJson(Items)=Before),'failed group reorder restores all object positions');
      finally CloseHandle(Lock); end;
      for PPI in [96,144] do begin
        Manager.Scaled:=True; Manager.ScaleForPPI(PPI); Manager.Scaled:=False; Manager.ClientWidth:=MulDiv(940,PPI,96); Manager.ClientHeight:=MulDiv(660,PPI,96); Manager.Realign;
        B.SetSize(Manager.ClientWidth,Manager.ClientHeight); Manager.PaintTo(B.Canvas,0,0); PNG.Assign(B);
        PNG.SaveToFile(TPath.Combine(TestFolder,'character-groups-'+IntToStr(PPI)+'.png'));
        Check((Manager.CommonName.Left>=0) and (Manager.CommonName.Top>=0) and
          (Manager.CommonName.Top+Manager.CommonName.Height<=Manager.CommonName.Parent.ClientHeight) and
          (Manager.CommonNotes.Height>0),'character shared fields remain reachable at PPI '+IntToStr(PPI));
        for I:=0 to Manager.ComponentCount-1 do if Manager.Components[I] is TButton then with TButton(Manager.Components[I]) do
          Check((Left>=0) and (Top>=0) and (Left+Width<=Parent.ClientWidth) and (Top+Height<=Parent.ClientHeight),
            'character group action remains reachable '+Caption+' '+IntToStr(PPI));
      end;
      CanClose:=True; Manager.OnCloseQuery(Manager,CanClose); Reloaded.Clear; ReadAssets(Reloaded,LibraryPath); NormalizeCharacters(Reloaded);
      Check(ListJson(Reloaded)=ListJson(Items),'character UI promotion order and shared edits survive close save and reload');
      Manager.Free; Manager:=TAssetDialog.CreateManager(Self,Items,nil,True,False); Manager.SelectAsset(AID); Before:=ListJson(Items);
      Manager.PromoteSelected; Manager.MoveAsset(BID,A1ID); Check(ListJson(Items)=Before,'protected character manager rejects promotion and reorder');
      Json:=A1.Json; try AtomicWrite(Path,'['+Json.ToJSON+','+Json.ToJSON+']'); finally Json.Free; end;
      Failed:=False; try ReadAssets(Broken,Path); except Failed:=True; end;
      Check(Failed and (Broken.Count=0),'duplicate character IDs cannot publish an ambiguous prefix');
      Check(FProject.Snapshot=Original,'character group fixtures preserve the active project');
    finally Manager.Free; PNG.Free; Broken.Free; Reloaded.Free; Items.Free; AtomicWrite(LibraryPath,LibraryBytes); end;
  end;

procedure RunCharacterGroupChecks(Host: TComicTestForm);
begin Host.CharacterGroupChecks; end;
procedure TComicAssetsTestsHelper.SceneGenerationChecks;
  var Probe: TComicTestForm; Project,Reloaded: TComicProject; Parent,Child,Alternate,TitleAsset: TComicAsset;
    Manager: TAssetDialog; Selector: TComicCharacterRefDialog; PNG: TPngImage; Request,Response,Data: TJSONObject; JsonRefs: TJSONArray;
    Before,After,Original,ParentID,ChildID,CharacterID,ReplyText: string; IDs: TArray<string>; History,PPI,I: Integer; CanClose: Boolean;
    procedure Command;
    begin
      Probe.BridgeRequest(Request.ToJSON,ReplyText); FreeAndNil(Request); FreeAndNil(Response);
      Response:=TJSONObject.ParseJSONValue(ReplyText) as TJSONObject;
    end;
    procedure CreateRequest(const Action: string);
    begin Request:=TJSONObject.Create; Request.AddPair('version',TJSONNumber.Create(1)); Request.AddPair('action',Action);
      Request.AddPair('library','images'); Request.AddPair('projectId',Project.ID); end;
  begin
    Original:=FProject.Snapshot; Probe:=TComicTestForm.Create(nil); PNG:=TPngImage.Create; Manager:=nil; Selector:=nil; Request:=nil; Response:=nil;
    try
      Project:=CreateFixtureProject; Project.Initialize('場面とタイトル fixture','第2話'); Probe.AdoptProject(Project,False);
      Parent:=Project.ImportImage(TPath.Combine(TestFolder,'reference.bmp'),''); ParentID:=Parent.ID;
      CharacterID:=Probe.FCharacters[0].ID; Before:=Project.Snapshot; History:=Probe.FUndo.Count;
      Manager:=TAssetDialog.CreateManager(Probe,Project.Assets,Project,False,True,Probe.GenerationPresets,Probe.FCharacters); Probe.FAssetManager:=Manager;
      Manager.SelectAsset(ParentID); Manager.ApplyReferences([CharacterID]);
      Check(Length(Parent.CharacterRefs)=0,'background root cannot receive character references through its manager');
      Child:=NewSceneAsset(Project.Assets,Parent,'child','本文の子','追加指示',Project.Title,Project.Episode); Project.Assets.Add(Child); ChildID:=Child.ID;
      Manager.RefreshFromExternal; Manager.SelectAsset(ChildID); Manager.ApplyReferences([CharacterID]);
      Check((Child.ParentID=ParentID) and (Child.SourceID=ParentID) and (Child.SceneID=ParentID) and (Length(Child.CharacterRefs)=1),
        'scene child retains background source scene relation and selected character identity');
      Selector:=TComicCharacterRefDialog.CreateSelector(Manager,Probe.FCharacters,Child.CharacterRefs); Selector.SetChecked(CharacterID,False);
      Selector.ModalResult:=mrCancel; Check((Length(Child.CharacterRefs)=1) and (Selector.SelectedIDs[0]=CharacterID),
        'cancelling reference selection retains its existing draft and asset'); FreeAndNil(Selector);
      Selector:=TComicCharacterRefDialog.CreateSelector(Manager,Probe.FCharacters,[CharacterID,'missing-reference']);
      Selector.AcceptSelection; IDs:=Selector.SelectedIDs;
      Check((Length(IDs)=2) and (IDs[1]='missing-reference'),'unresolved existing reference is retained until explicitly unchecked'); FreeAndNil(Selector);
      Selector:=TComicCharacterRefDialog.CreateSelector(Manager,Probe.FCharacters,Child.CharacterRefs); Selector.SetChecked(CharacterID,False); Selector.AcceptSelection;
      Manager.ApplyReferences(Selector.SelectedIDs); Check(Length(Child.CharacterRefs)=0,'scene child supports generation with zero characters'); FreeAndNil(Selector);
      Manager.ApplyReferences([CharacterID]); Manager.AddSceneVariant('alternate_scene'); Alternate:=Manager.CurrentAsset;
      Check((Alternate.ParentID='') and (Alternate.SourceID=ParentID) and (Alternate.SceneID=ParentID) and (Length(Alternate.CharacterRefs)=0),
        'alternate background becomes a sibling root retaining its source and scene relation');
      Manager.SelectAsset(ChildID); Manager.AddSceneVariant('title'); TitleAsset:=Manager.CurrentAsset;
      Check((TitleAsset.ParentID=ParentID) and (TitleAsset.SourceID=ChildID) and TitleAsset.TitleImage and
        (TitleAsset.TitleText=Project.Title) and (TitleAsset.EpisodeText=Project.Episode) and (TitleAsset.CharacterRefs[0]=CharacterID),
        'title derivative remains at the second level and snapshots title episode and character references');
      Probe.ApplyGenerationPreset('manager-preset','管理から適用','共通本文'); Check(Probe.FUndo.Count=History,'generation apply inside image management defers its project history');
      CreateRequest('register_image'); Request.AddPair('assetId',TitleAsset.ID); Request.AddPair('sourcePath',TPath.Combine(TestFolder,'reference.bmp')); Command;
      Check((JStr(Response,'ok','')='true') and (Probe.FUndo.Count=History),'pipe adoption during image management shares its pending undo operation');
      CreateRequest('read_asset'); Request.AddPair('assetId',TitleAsset.ID); Command; Data:=Response.GetValue<TJSONObject>('data');
      Check((JStr(Response,'ok','')='true') and (JStr(Data.GetValue<TJSONObject>('source'),'id','')=ChildID) and
        (Data.GetValue<TJSONArray>('references').Count=1) and
        (JStr(Data.GetValue<TJSONArray>('references').Items[0] as TJSONObject,'id','')=CharacterID),
        'title generation query returns its actual child source and only selected character data');
      CreateRequest('create_asset'); Request.AddPair('name','パイプ別位置'); Request.AddPair('mode','alternate_scene'); Request.AddPair('sourceId',ParentID); Command;
      Check((JStr(Response,'ok','')='true') and (JStr(Response.GetValue<TJSONObject>('data').GetValue<TJSONObject>('asset'),'parentId','')=''),
        'pipe creates alternate backgrounds at root level');
      CreateRequest('create_asset'); Request.AddPair('name','パイプタイトル'); Request.AddPair('mode','title'); Request.AddPair('sourceId',ChildID); Command;
      Check((JStr(Response,'ok','')='true') and (JStr(Response.GetValue<TJSONObject>('data').GetValue<TJSONObject>('asset'),'sourceId','')=ChildID),
        'pipe creates title derivatives from second-level source images');
      After:=Project.Snapshot;
      CreateRequest('create_asset'); Request.AddPair('name','不正な人物参照'); Request.AddPair('parentId',ParentID);
      JsonRefs:=TJSONArray.Create; JsonRefs.Add('unknown-person'); Request.AddPair('characterIds',JsonRefs); Command;
      Check((JStr(Response,'ok','')='false') and (Project.Snapshot=After),'unknown explicit character reference rejects creation before any mutation');
      CreateRequest('create_asset'); Request.AddPair('name','親の人物参照'); JsonRefs:=TJSONArray.Create; JsonRefs.Add(CharacterID); Request.AddPair('characterIds',JsonRefs); Command;
      Check((JStr(Response,'ok','')='false') and (Project.Snapshot=After),'background parent generation excludes character references');
      for PPI in [96,144] do begin
        Selector:=TComicCharacterRefDialog.CreateSelector(Manager,Probe.FCharacters,Child.CharacterRefs);
        try
          Selector.Scaled:=True; Selector.ScaleForPPI(PPI); Selector.Scaled:=False; Selector.ClientWidth:=MulDiv(600,PPI,96); Selector.ClientHeight:=MulDiv(500,PPI,96); Selector.Realign;
          Selector.HandleNeeded; B.SetSize(Selector.ClientWidth,Selector.ClientHeight); Selector.PaintTo(B.Canvas,0,0); PNG.Assign(B);
          PNG.SaveToFile(TPath.Combine(TestFolder,'character-references-'+IntToStr(PPI)+'.png'));
          for I:=0 to Selector.ComponentCount-1 do if Selector.Components[I] is TButton then with TButton(Selector.Components[I]) do
            Check((Left>=0) and (Top>=0) and (Left+Width<=Parent.ClientWidth) and (Top+Height<=Parent.ClientHeight),
              'reference selector button remains reachable '+Caption+' '+IntToStr(PPI));
        finally FreeAndNil(Selector); end;
        Manager.Scaled:=True; Manager.ScaleForPPI(PPI); Manager.Scaled:=False; Manager.ClientWidth:=MulDiv(940,PPI,96); Manager.ClientHeight:=MulDiv(660,PPI,96); Manager.Realign;
        B.SetSize(Manager.ClientWidth,Manager.ClientHeight); Manager.PaintTo(B.Canvas,0,0); PNG.Assign(B);
        PNG.SaveToFile(TPath.Combine(TestFolder,'scene-generation-'+IntToStr(PPI)+'.png'));
      end;
      CanClose:=True; Manager.OnCloseQuery(Manager,CanClose); Probe.FAssetManager:=nil; FreeAndNil(Manager); Probe.FinishImageManagement(Before,True);
      After:=Project.Snapshot; Check(Probe.FUndo.Count=History+1,'image manager changes pipe adoption and generation snapshot commit as one undo');
      Project.Save; Reloaded:=CreateFixtureProject;
      try Reloaded.Load(TPath.Combine(Project.Folder,'Project.json')); Check(Reloaded.Snapshot=After,'scene sources title metadata selected references and generation conditions save and reload');
      finally Reloaded.Free; end;
      Probe.Undo(nil); Check(Project.Snapshot=Before,'image manager undo removes all newly added derivations and conditions');
      Probe.Redo(nil); Check(Project.Snapshot=After,'image manager redo restores every relation and retained adopted image');
      Check(FProject.Snapshot=Original,'scene generation fixtures preserve the active project');
    finally Probe.FAssetManager:=nil; Response.Free; Request.Free; Selector.Free; Manager.Free; PNG.Free; Probe.Free; end;
  end;

procedure RunSceneGenerationChecks(Host: TComicTestForm);
begin Host.SceneGenerationChecks; end;
end.
