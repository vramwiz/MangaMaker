unit ComicProjectWorkflowTests;

// 責務：今回の作品作成・画面移動・可搬保存だけを隔離データで確認し、DPI総当たりは行わない。
interface
uses ComicTestSupport;
procedure RunProjectWorkflowChecks(Host: TComicTestForm);
implementation
uses System.Types, System.SysUtils, System.IOUtils, System.Classes, System.JSON, System.Generics.Collections,
  Vcl.Forms, Vcl.Graphics, Vcl.Controls, Vcl.StdCtrls, ComicModel, ComicProjectCreation,
  ComicProjectReferences, ComicAssetEditing, ComicNewProjectDialog, ComicExport;
type
  TWorkflowHelper = class helper for TComicTestForm
    procedure Workflow;
  end;
procedure TWorkflowHelper.Workflow;
var Project,CopyProject: TComicProject; Image,Ref,Child: TComicAsset;
  Shared,Empty: TObjectList<TComicAsset>; Basis: TComicPageBasis; Folder,CopyFolder,Source,State,Text,Original: string;
  Dialog: TComicNewProjectDialog; Failed: Boolean; ModalCount,Mode: Integer; Paths: TArray<string>;
  Request,Response: TJSONObject;
begin
  Lines:=TStringList.Create; B:=TBitmap.Create; Shared:=TObjectList<TComicAsset>.Create;
  Empty:=TObjectList<TComicAsset>.Create; CopyProject:=TComicProject.Create; Project:=nil;
  try
    Check((FProject=nil) and not FPrimaryBar.Visible,'startup keeps editing and primary navigation hidden');
    Characters(nil);
    Check((FCharacterWorkspace<>nil) and FPrimaryButtons[2].Enabled and not FPrimaryButtons[0].Enabled and
      not FPrimaryButtons[1].Enabled,'common character management opens before creating a project');
    CloseImageWorkspace;
    Basis.Width:=650; Basis.Height:=975; Basis.Left:=60; Basis.Top:=60; Basis.Right:=60; Basis.Bottom:=60;
    Folder:=TPath.Combine(TestFolder,'指定した保存先'); CopyFolder:=TPath.Combine(TestFolder,'Windowsコピー相当');
    Failed:=False; try Project:=CreateProjectAt('','作品','','',Basis,Empty); except Failed:=True; end;
    Check(Failed and (Project=nil),'new project rejects an empty destination');
    Dialog:=TComicNewProjectDialog.CreateSettings(Self,FPagePresets);
    try
      Check(Dialog.Basis.Same(Basis),'new project paper fields start with the default preset');
      B.SetSize(Dialog.ClientWidth,Dialog.ClientHeight); Dialog.PaintTo(B.Canvas,0,0);
      B.SaveToFile(TPath.Combine(TestFolder,'new-project.bmp'));
    finally Dialog.Free; end;
    Project:=CreateProjectAt(Folder,'フォルダ名とは違う作品名','','',Basis,Empty);
    Check(SameFileName(Project.Folder,Folder) and FileExists(TPath.Combine(Folder,'Project.json')),
      'new project uses the selected folder directly');
    Check((Project.Episode='') and (Project.Pages.Count=1) and (Project.Pages[0].Panels.Count=0),
      'optional episode and script create one empty page without characters');
    Check(not DirectoryExists(TPath.Combine(Folder,'Images')) and not DirectoryExists(TPath.Combine(Folder,'Pages')),
      'new project creates no automatic images pages or UID subfolder');
    Source:=TPath.Combine(TestFolder,'reference.bmp'); B.SetSize(32,32); B.Canvas.Brush.Color:=clRed;
    B.Canvas.FillRect(Rect(0,0,32,32)); B.SaveToFile(Source);
    Image:=Project.ImportImage(Source,'');
    Check((Image.RelativePath<>'') and (ExtractFilePath(Image.RelativePath)='') and FileExists(Project.ImagePath(Image.ID)),
      'imported image uses a new relative path in the project root');
    Image.FileName:='old-reference.bmp'; TFile.Copy(Source,SafeChild(Folder,Image.FileName));
    State:=Image.RelativePath; Image.RelativePath:='missing-new.bmp';
    Check(not FileExists(Project.ImagePath(Image.ID)) and Project.ImagePath(Image.ID).EndsWith('missing-new.bmp'),
      'missing new reference never falls back to an existing old image');
    Image.RelativePath:=''; Check(FileExists(Project.ImagePath(Image.ID)),'old reference is used only when the new field is empty');
    Image.RelativePath:=State;
    ForceDirectories(TPath.Combine(DataRoot,'Characters'));
    Ref:=TComicAsset.Create; Ref.Name:='共有人物'; Ref.CharacterName:=Ref.Name; Ref.FileName:='workflow-ref.bmp'; Shared.Add(Ref);
    TFile.Copy(Source,Ref.ImagePath(TPath.Combine(DataRoot,'Characters')));
    Child:=NewSceneAsset(Project.Assets,Image,'child','参照あり画像','','',''); Project.Assets.Add(Child);
    Child.CharacterRefs:=[Ref.ID]; CaptureProjectReferences(Project,Shared);
    Check((Project.CharacterReferences.Count=1) and FileExists(ProjectCharacterPath(Project,Empty,Ref.ID)),
      'selected character image is copied to project References');
    Project.Save; Original:=TFile.ReadAllText(TPath.Combine(Folder,'Project.json'));
    TDirectory.Copy(Folder,CopyFolder); CopyProject.Load(TPath.Combine(CopyFolder,'Project.json'));
    Check(SameFileName(ExtractFileDir(CopyProject.ImagePath(Image.ID)),CopyFolder),
      'copied project resolves images from the copied project file location');
    TFile.Delete(Ref.ImagePath(TPath.Combine(DataRoot,'Characters')));
    Check(FileExists(ProjectCharacterPath(CopyProject,Empty,Ref.ID)),
      'copied project retains character references without the shared library');
    CopyProject.Title:='コピー先だけ変更'; CopyProject.Save;
    Check(TFile.ReadAllText(TPath.Combine(Folder,'Project.json'))=Original,
      'saving a copied project with the same internal ID never writes to its source');
    Check(FileExists(TPath.Combine(CopyFolder,'Page-'+CopyProject.Pages[0].ID+'.json')),
      'page sidecar is saved in the selected project root');
    State:=Child.ID; AdoptProject(CopyProject,False); CopyProject:=nil;
    FPrimaryButtons[1].Click; FImageWorkspace.SelectAsset(State);
    Text:=GenerationSnapshot('images',FProject.ID,State,Paths);
    Check((Text<>'') and (Length(Paths)=2),'copied project generation uses local image and character references');
    for var Path in Paths do Check(Path.StartsWith(CopyFolder,True),'generation reference stays within the copied folder');
    FPrimaryButtons[0].Click;
    Project.Free; Project:=nil;
    Text:='[作品]'#13#10'作品名：背景だけ'#13#10'# 1ページ目'#13#10'* B001'#13#10'[内容：夕方の空]';
    Project:=CreateProjectAt(TPath.Combine(TestFolder,'台本あり'),'背景だけ','',Text,Basis,Empty);
    Check((Project.ScriptSource=Text) and (Project.Assets.Count>0) and FileExists(TPath.Combine(Project.Folder,'Script.txt')),
      'pasted script is optional and its original is stored in the project root');
    Check((Project.Pages.Count=1) and (Project.Pages[0].Panels.Count=0),'script import leaves an empty initial page');
    AdoptProject(Project,False); Project:=nil;
    Check(FPrimaryBar.Visible and (FPrimaryIndex=0) and FPages.Parent.Visible,'new project defaults to page editing');
    FPrimaryButtons[1].Click;
    Check((FImageWorkspace<>nil) and not FPages.Parent.Visible and (FPrimaryIndex=1),
      'characterless image management opens at the primary level');
    FImageWorkspace.SelectAsset(FProject.Assets[0].ID);
    Text:=GenerationSnapshot('images',FProject.ID,FProject.Assets[0].ID,Paths);
    Check((Text<>'') and (Length(Paths)=0),'background generation context is valid without characters or reference images');
    Request:=TJSONObject.Create;
    try
      Request.AddPair('version',TJSONNumber.Create(1)); Request.AddPair('action','register_image');
      Request.AddPair('library','images'); Request.AddPair('projectId',FProject.ID);
      Request.AddPair('assetId',FProject.Assets[0].ID); Request.AddPair('sourcePath',Source);
      BridgeRequest(Request.ToJSON,Text); Response:=TJSONObject.ParseJSONValue(Text) as TJSONObject;
      try Check((JStr(Response,'ok','')='true') and (FProject.Assets[0].RelativePath<>'') and
        (ExtractFilePath(FProject.Assets[0].RelativePath)=''),'bridge image registration works without characters and stores a root relative path');
      finally Response.Free; end;
    finally Request.Free; end;
    ModalCount:=Application.ModalLevel; FPrimaryButtons[2].Click;
    Check((FCharacterWorkspace<>nil) and (FImageWorkspace=nil) and (Application.ModalLevel=ModalCount),
      'character manager is embedded at the same navigation level');
    FCharacterWorkspace.DraftName.Text:=''; FPrimaryButtons[0].Click;
    Check((FPrimaryIndex=0) and FPages.Parent.Visible and FView.Visible,'returning to page editing restores its regions');
    FModeButtons[3].Click; Mode:=FTabs.ActivePageIndex; FPrimaryButtons[1].Click; FPrimaryButtons[0].Click;
    Check(FTabs.ActivePageIndex=Mode,'primary navigation preserves the page editing mode');
    Check(FModeButtons[5].Visible=False,'image management is absent from the page tool icon row');
    FModeButtons[0].Click; ApplyLayout(FLayouts[0],-1);
    Check(Page.Panels.Count>0,'page layouts work without registered characters or images');
    Check(ExportSequence(FProject,FRenderer,True)>0,'characterless project exports successfully');
    Check(FileExists(TPath.Combine(FProject.Folder,'0001.png')),'PNG output uses the project root');
    Capture('page-workspace'); FPrimaryButtons[1].Click; Capture('image-workspace');
    FPrimaryButtons[2].Click; Capture('character-workspace'); FPrimaryButtons[0].Click;
    FDirty:=False;
    Lines.Add('PASS: focused project workflow completed without external generation.');
    TFile.WriteAllText(TPath.Combine(TestFolder,'result.txt'),Lines.Text,TEncoding.UTF8);
  finally Project.Free; CopyProject.Free; Empty.Free; Shared.Free; B.Free; Lines.Free; end;
end;
procedure RunProjectWorkflowChecks(Host: TComicTestForm);
begin Host.Workflow; end;
end.
