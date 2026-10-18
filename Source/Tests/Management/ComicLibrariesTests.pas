unit ComicLibrariesTests;

// 責務：共通ライブラリと作品スナップショットの独立性、保存失敗時の復旧を検証する。
interface
uses ComicTestSupport;
procedure RunPageBasisChecks(Host: TComicTestForm);
procedure RunLayoutManagementChecks(Host: TComicTestForm);
procedure RunRecentProjectChecks(Host: TComicTestForm);
implementation
uses Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, Winapi.Imm,
  System.SysUtils, System.Classes, System.Types, System.UITypes,
  System.Math, System.IOUtils, System.Generics.Collections, System.JSON,
  System.Hash, System.DateUtils, Vcl.Controls, Vcl.Forms,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Menus,
  Vcl.Dialogs, Vcl.Graphics, Vcl.Imaging.pngimage, ComicModel,
  ComicLayouts, ComicExport, ComicIconButton, ComicPagePresets,
  ComicPageDialog, ComicRecentProjects;
type
  TComicLibrariesTestsHelper = class helper for TComicTestForm
    procedure PageBasisChecks;
    procedure LayoutManagementChecks;
    procedure RecentProjectChecks;
  end;
procedure TComicLibrariesTestsHelper.PageBasisChecks;
  var Probe: TComicTestForm; Project,Reloaded: TComicProject; Basis,OriginalBasis,Invalid: TComicPageBasis;
    Bounds: TRectF; Presets,CopyPresets: TObjectList<TComicPagePreset>; Dialog: TComicPageDialog;
    Preset: TComicPagePreset; Path,Before,Name,ID: string; Lock: THandle; KeyValue: Word;
    Failed: Boolean; History,I,PPI: Integer; Snap: TPointF; PNG: TPngImage;
  begin
    Probe:=TComicTestForm.Create(nil); Presets:=TObjectList<TComicPagePreset>.Create;
    CopyPresets:=TObjectList<TComicPagePreset>.Create; PNG:=TPngImage.Create;
    try
      Project:=CreateFixtureProject; Project.Initialize('ページ基準 fixture','1'); Probe.AdoptProject(Project,False);
      OriginalBasis:=Project.PageBasis;
      Check((OriginalBasis.Width=1200) and (OriginalBasis.Height=1700),'legacy page geometry fixture uses its explicit canvas dimensions');
      Project.Pages.Add(TComicPage.Create);
      P:=TComicPanel.Create; P.Bounds:=TRectF.Create(100,100,1100,1500); P.ImageID:=Project.ImportImage(TPath.Combine(TestFolder,'reference.bmp'),'').ID;
      Project.Pages[0].Panels.Add(P); Bounds:=P.Bounds;
      Check(ExportSequence(Project,Probe.FRenderer,False)=2,'page-basis fixture exports both initial pages');
      Basis:=OriginalBasis; Basis.Width:=600; Basis.Height:=850; Basis.Left:=32; Basis.Top:=40; Basis.Right:=44; Basis.Bottom:=48;
      Probe.ApplyPageBasis(Basis);
      Check(Project.PageBasis.Same(Basis) and (Project.Pages[0].Panels[0].Bounds=TRectF.Create(50,50,550,750)) and (Project.Pages.Count=2),
        'page basis scales objects on every page uniformly around the page center');
      Snap:=Probe.SnapCreationPoint(TPointF.Create(33,41));
      Check((Snap.X=32) and (Snap.Y=40),'creation snaps to the configured shared page frame');
      Project.Save; Reloaded:=CreateFixtureProject;
      try Reloaded.Load(TPath.Combine(Project.Folder,'Project.json'));
        Check(Reloaded.PageBasis.Same(Basis),'page resolution and all four margins survive save and reload');
      finally Reloaded.Free; end;
      Check(ExportSequence(Project,Probe.FRenderer,False)=2,'page resolution change invalidates every rendered page');
      Basis.Left:=36; Probe.ApplyPageBasis(Basis);
      Check(ExportSequence(Project,Probe.FRenderer,False)=0,'guide-only margin change preserves completed PNG cache');
      History:=Probe.FUndo.Count; Probe.ApplyPageBasis(Basis);
      Check(Probe.FUndo.Count=History,'applying the same page basis does not create an undo entry');
      Before:=Project.Snapshot; Invalid:=Basis; Invalid.Right:=600; Failed:=False;
      try Probe.ApplyPageBasis(Invalid); except Failed:=True; end;
      Check(Failed and (Project.Snapshot=Before) and (Probe.FUndo.Count=History),'invalid page margins are rejected before content or undo changes');
      Probe.Undo(nil); Check(Project.PageBasis.Left=32,'one undo restores the previous page frame');
      Probe.Redo(nil); Check(Project.PageBasis.Left=36,'page frame redo restores all settings together');
      Probe.Undo(nil); Probe.Undo(nil); Check(Project.PageBasis.Same(OriginalBasis),'page resolution undo restores the original shared basis');
      Probe.Redo(nil); Probe.Redo(nil); Check(Project.PageBasis.Same(Basis),'page resolution and frame survive chained redo');
      Probe.AddPage(nil); Check((Project.Pages.Count=3) and Project.PageBasis.Same(Basis),'new pages inherit the project page basis');
      SeedPagePresets(Presets); Path:=TPath.Combine(TestFolder,'page-bases-library.json');
      Dialog:=TComicPageDialog.CreateSettings(Self,Basis,Presets,Path,True);
      try
        Dialog.SelectPreset(0); KeyValue:=VK_ESCAPE; Dialog.KeyDown(KeyValue,[]);
        Check((Dialog.ModalResult=mrCancel) and Dialog.ResultBasis.Same(Basis) and Project.PageBasis.Same(Basis),
          'canceling a preset selection preserves project and original dialog result');
        Dialog.ModalResult:=0; Dialog.SetDraftBasis(Invalid); KeyValue:=VK_RETURN; Dialog.KeyDown(KeyValue,[]);
        Check(Dialog.ModalResult=0,'invalid page settings keep the dialog open for correction');
        Dialog.SetDraftBasis(Basis); Preset:=Dialog.RegisterPreset('日本語・ページ基準'); ID:=Preset.ID;
        LoadPagePresets(CopyPresets,Path);
        Check((CopyPresets.Count=1) and (CopyPresets[0].ID=ID) and CopyPresets[0].Basis.Same(Basis),
          'common page preset saves and reloads its identity dimensions and margins');
        Dialog.RenamePreset(BuiltInPagePresetCount,'更新したページ基準'); Name:=Presets[BuiltInPagePresetCount].Name;
        Check((Presets[BuiltInPagePresetCount].ID=ID) and (Name='更新したページ基準'),'renaming a page preset preserves its identity');
        Lock:=CreateFile(PChar(Path),GENERIC_READ,FILE_SHARE_READ,nil,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,0);
        Check(Lock<>INVALID_HANDLE_VALUE,'page-preset library can be locked to inject publication failure');
        Before:=TFile.ReadAllText(Path,TEncoding.UTF8);
        try
          Failed:=False; try Dialog.RenamePreset(BuiltInPagePresetCount,'失敗する名前'); except Failed:=True; end;
          Check(Failed and (Presets[BuiltInPagePresetCount].Name=Name) and (TFile.ReadAllText(Path,TEncoding.UTF8)=Before),
            'failed page-preset rename restores memory and retains original library bytes');
          Failed:=False; try Dialog.RegisterPreset('失敗する追加'); except Failed:=True; end;
          Check(Failed and (Presets.Count=BuiltInPagePresetCount+1) and (TFile.ReadAllText(Path,TEncoding.UTF8)=Before),
            'failed page-preset registration cannot publish a partial item');
          Failed:=False; try Dialog.RemovePreset(BuiltInPagePresetCount); except Failed:=True; end;
          Check(Failed and (Presets.Count=BuiltInPagePresetCount+1) and (Presets[BuiltInPagePresetCount].ID=ID),
            'failed page-preset deletion restores the exact item and order');
        finally CloseHandle(Lock); end;
        Dialog.RemovePreset(BuiltInPagePresetCount);
        Check((Presets.Count=BuiltInPagePresetCount) and Project.PageBasis.Same(Basis),'deleting a common preset keeps the applied project snapshot');
        Failed:=False; try Dialog.RemovePreset(0); except Failed:=True; end;
        Check(Failed and (Presets.Count=BuiltInPagePresetCount),'built-in page basis remains available after deletion attempts');
        Dialog.SetDraftBasis(Basis); KeyValue:=VK_RETURN; Dialog.KeyDown(KeyValue,[]);
        Check((Dialog.ModalResult=mrOK) and Dialog.ResultBasis.Same(Basis),'valid page settings commit the complete basis');
        for PPI in [96,144] do begin
          Dialog.Scaled:=True; Dialog.ScaleForPPI(PPI); Dialog.Scaled:=False;
          Dialog.ClientWidth:=MulDiv(650,PPI,96); Dialog.ClientHeight:=MulDiv(510,PPI,96); Dialog.Realign;
          Dialog.HandleNeeded; B.SetSize(Dialog.ClientWidth,Dialog.ClientHeight); Dialog.PaintTo(B.Canvas,0,0);
          PNG.Assign(B); PNG.SaveToFile(TPath.Combine(TestFolder,'page-basis-'+IntToStr(PPI)+'.png'));
          for I:=0 to Dialog.ComponentCount-1 do if Dialog.Components[I] is TButton then with TButton(Dialog.Components[I]) do
            Check((Left>=0) and (Top>=0) and (Left+Width<=Parent.ClientWidth) and (Top+Height<=Parent.ClientHeight),
              'page-basis button remains reachable at PPI '+IntToStr(PPI)+' '+Caption);
        end;
      finally Dialog.Free; end;
      J:=CopyPresets[0].Json;
      try Before:='{"version":1,"presets":['+J.ToJSON+',42]}'; finally J.Free; end;
      AtomicWrite(Path,Before); Failed:=False; try LoadPagePresets(Presets,Path); except Failed:=True; end;
      Check(Failed and (Presets.Count=BuiltInPagePresetCount) and (TFile.ReadAllText(Path,TEncoding.UTF8)=Before),
        'malformed page-preset library cannot publish a valid prefix or alter the file');
      Dialog:=TComicPageDialog.CreateSettings(Self,Basis,Presets,Path,False);
      try
        Failed:=False; try Dialog.RegisterPreset('書込禁止'); except Failed:=True; end;
        Check(Failed and (TFile.ReadAllText(Path,TEncoding.UTF8)=Before),'unreadable page-preset library remains protected from registration');
        Dialog.SetDraftBasis(Basis); KeyValue:=VK_RETURN; Dialog.KeyDown(KeyValue,[]);
        Check((Dialog.ModalResult=mrOK) and Dialog.ResultBasis.Same(Basis),'project settings remain editable when common preset persistence is blocked');
      finally Dialog.Free; end;
    finally PNG.Free; CopyPresets.Free; Presets.Free; Probe.Free; end;
  end;

procedure RunPageBasisChecks(Host: TComicTestForm);
begin Host.PageBasisChecks; end;
procedure TComicLibrariesTestsHelper.LayoutManagementChecks;
  var TemplateList,CopyLibrary: TObjectList<TComicLayout>; Layout: TComicLayout; Applied: TComicProject;
    Path,ID,Before,ProjectBefore,TemplateJson,LibraryBefore: string; Bounds: TRectF; Lock: THandle; Failed,Writable: Boolean;
    Button: TComicIconButton; Index: Integer; J: TJSONObject;
  begin
    TemplateList:=TObjectList<TComicLayout>.Create; CopyLibrary:=TObjectList<TComicLayout>.Create;
    Applied:=CreateFixtureProject; ProjectBefore:=FProject.Snapshot;
    try
      SeedLayouts(TemplateList); Layout:=TComicLayout.Create; Layout.Name:='管理テスト'; Layout.Capture(FProject,Page);
      TemplateList.Add(Layout); ID:=Layout.ID; Bounds:=Layout.Panels[0].Bounds; Path:=TPath.Combine(TestFolder,'managed-layouts.json');
      SaveLayouts(TemplateList,Path); Applied.Pages.Add(TComicPage.Create); Layout.Apply(Applied.Pages[0],1200,1700);
      RenameLayout(TemplateList,Layout,'日本語に名前変更',Path);
      Check((Layout.ID=ID) and (Layout.Name='日本語に名前変更') and (Layout.Panels[0].Bounds=Bounds),
        'template rename preserves identity and captured geometry');
      SeedLayouts(CopyLibrary); LoadLayouts(CopyLibrary,Path);
      Check((CopyLibrary.Count=BuiltInLayoutCount+1) and (CopyLibrary.Last.ID=ID) and (CopyLibrary.Last.Name=Layout.Name),
        'renamed template reloads with its stable identity');
      Before:=TFile.ReadAllText(Path,TEncoding.UTF8); Failed:=False;
      try RenameLayout(TemplateList,TemplateList[0],'変更禁止',Path); except Failed:=True; end;
      Check(Failed and (TFile.ReadAllText(Path,TEncoding.UTF8)=Before),'built-in template rename is rejected before persistence');
      Failed:=False; try RenameLayout(TemplateList,Layout,' ',Path); except Failed:=True; end;
      Check(Failed and (Layout.Name='日本語に名前変更'),'empty template rename leaves the previous name intact');
      Failed:=False; try RenameLayout(TemplateList,Layout,TemplateList[0].Name,Path); except Failed:=True; end;
      Check(Failed and (Layout.ID=ID),'duplicate template names are rejected without losing identity');
      Lock:=CreateFile(PChar(Path),GENERIC_READ,FILE_SHARE_READ,nil,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,0);
      Check(Lock<>INVALID_HANDLE_VALUE,'template library locks can inject publication failure');
      try
        Failed:=False; try RenameLayout(TemplateList,Layout,'書込失敗',Path); except Failed:=True; end;
        Check(Failed and (Layout.Name='日本語に名前変更') and (TFile.ReadAllText(Path,TEncoding.UTF8)=Before),
          'failed template rename restores memory and retains the original library');
        Failed:=False; try RemoveLayout(TemplateList,Layout,Path); except Failed:=True; end;
        Check(Failed and (TemplateList.Count=BuiltInLayoutCount+1) and (TemplateList[BuiltInLayoutCount]=Layout) and (TemplateList[BuiltInLayoutCount].ID=ID),
          'failed template deletion restores the exact item and list order');
      finally CloseHandle(Lock); end;
      J:=Layout.Json; try TemplateJson:=J.ToJSON; finally J.Free; end;
      Before:=Applied.Snapshot; RemoveLayout(TemplateList,Layout,Path);
      Check((TemplateList.Count=BuiltInLayoutCount) and (Applied.Snapshot=Before),'deleting a common template retains previously applied page contents');
      // 更新後も登録分だけを読み込み、削除した自作テンプレートを標準追加で復活させない。
      CopyLibrary.Clear; SeedLayouts(CopyLibrary); LibraryBefore:=TFile.ReadAllText(Path,TEncoding.UTF8); LoadLayouts(CopyLibrary,Path);
      Check((CopyLibrary.Count=BuiltInLayoutCount) and (TFile.ReadAllText(Path,TEncoding.UTF8)=LibraryBefore),
        'new standard layouts coexist with existing libraries without rewriting or reviving deleted custom templates');
      Failed:=False; try RemoveLayout(TemplateList,TemplateList[0],Path); except Failed:=True; end;
      Check(Failed and (TemplateList.Count=BuiltInLayoutCount),'built-in templates remain available after deletion attempts');
      Before:='{"version":2,"layouts":['+TemplateJson+',42]}'; AtomicWrite(Path,Before);
      Failed:=False; try LoadLayouts(TemplateList,Path); except Failed:=True; end;
      Check(Failed and (TemplateList.Count=BuiltInLayoutCount) and (TFile.ReadAllText(Path,TEncoding.UTF8)=Before),
        'invalid trailing template item cannot publish a valid prefix or overwrite the library');
      Layout:=TComicLayout.Create; Layout.Name:='UI管理 fixture'; Layout.Capture(FProject,Page); FLayouts.Add(Layout);
      Index:=FLayouts.Count-1; RefreshLayouts(Index);
      for Button in FIconButtons do if Button.Role=brManageLayout then Check(Button.Enabled,'custom template enables its management button '+Button.Caption);
      Writable:=FLayoutLibraryWritable; FLayoutLibraryWritable:=False; UpdateIconState;
      for Button in FIconButtons do if Button.Role=brManageLayout then Check(not Button.Enabled,'unreadable template library disables management '+Button.Caption);
      FLayoutLibraryWritable:=Writable; FLayouts.Extract(Layout); RefreshLayouts(0); Layout.Free;
      Check(FProject.Snapshot=ProjectBefore,'template management and persistence failures preserve the active project');
    finally Applied.Free; CopyLibrary.Free; TemplateList.Free; end;
  end;

procedure RunLayoutManagementChecks(Host: TComicTestForm);
begin Host.LayoutManagementChecks; end;
procedure TComicLibrariesTestsHelper.RecentProjectChecks;
  var Recent,CopyRecent: TComicRecentProjects; Probe: TComicTestForm; Project: TComicProject; Path,Before,Original,Saved,Draft,SourceFile,BrokenFile: string;
    Lock: THandle; I,History: Integer; Failed: Boolean; Json: TJSONObject; Pair: TJSONPair; Pages: TJSONArray; BadBalloon: TComicBalloon;
  begin
    Original:=FProject.Snapshot; Recent:=TComicRecentProjects.Create; CopyRecent:=TComicRecentProjects.Create; Probe:=TComicTestForm.Create(nil);
    try
      Path:=TPath.Combine(TestFolder,'recent-projects.json');
      for I:=0 to 24 do Recent.Remember(TPath.Combine(TestFolder,'recent-'+IntToStr(I)+'.json'),'作品'+IntToStr(I),'第1話',Path);
      Check((Recent.Items.Count=20) and (Recent.Items[0].Title='作品24') and (Recent.Items[19].Title='作品5'),'recent projects retain the newest twenty entries');
      Recent.Remember(UpperCase(Recent.Items[10].FileName),'再度開く','第2話',Path);
      Check((Recent.Items.Count=20) and (Recent.Items[0].Title='再度開く'),'recent projects deduplicate Windows paths case-insensitively');
      CopyRecent.Load(Path); Check((CopyRecent.Items.Count=20) and (CopyRecent.Items[0].Episode='第2話'),'recent metadata and ordering save and reload');
      Before:=TFile.ReadAllText(Path,TEncoding.UTF8); Lock:=CreateFile(PChar(Path),GENERIC_READ,FILE_SHARE_READ,nil,OPEN_EXISTING,0,0);
      try
        Failed:=False; try Recent.Remember(TPath.Combine(TestFolder,'failed-project.json'),'失敗','1',Path); except Failed:=True; end;
        Check(Failed and (Recent.Items[0].Title='再度開く') and (TFile.ReadAllText(Path,TEncoding.UTF8)=Before),'failed recent write preserves memory order and original file');
        Failed:=False; try Recent.Clear(Path); except Failed:=True; end; Check(Failed and (Recent.Items.Count=20),'failed history clear restores all entries');
      finally CloseHandle(Lock); end;
      Json:=Recent.Items[0].Json; try AtomicWrite(Path,'{"version":1,"projects":['+Json.ToJSON+',42]}'); finally Json.Free; end;
      Failed:=False; try CopyRecent.Load(Path); except Failed:=True; end;
      Check(Failed and (CopyRecent.Items.Count=20) and (CopyRecent.Items[0].Title='再度開く'),'malformed recent file cannot publish a prefix or replace existing history');
      AtomicWrite(Path,Before); Recent.Clear(Path); CopyRecent.Load(Path); Check(CopyRecent.Items.Count=0,'explicit history clear saves an empty list');
      Project:=CreateFixtureProject; Project.Initialize('履歴から開く','第1話'); SourceFile:=TPath.Combine(Project.Folder,'Project.json');
      Saved:=Project.Snapshot; Project.Title:='未保存の作業を復元'; Project.SaveDraft; Draft:=Project.Snapshot; Project.Free;
      Probe.OpenProjectFile(SourceFile,0); Check((Probe.FProject.Snapshot=Saved) and not Probe.FDirty,'history open can keep the formally saved project');
      Check((Probe.FRecent.Items.Count>0) and (Probe.FRecent.Items[0].FileName=SourceFile),'successful open records the original Project.json path');
      Probe.OpenProjectFile(SourceFile,1); Check((Probe.FProject.Snapshot=Draft) and Probe.FDirty,'history open can restore a valid draft and mark the project dirty');
      Check(Probe.FRecent.Items[0].FileName=SourceFile,'draft restoration keeps the normal project path in history');
      Before:=Probe.FProject.Snapshot; History:=Probe.FUndo.Count; BrokenFile:=TPath.Combine(TestFolder,'invalid-recent-project.json'); AtomicWrite(BrokenFile,'{invalid}');
      Failed:=False; try Probe.OpenProjectFile(BrokenFile,0); except Failed:=True; end;
      Check(Failed and (Probe.FProject.Snapshot=Before) and (Probe.FUndo.Count=History) and (Probe.FRecent.Items[0].FileName=SourceFile),
        'failed history load preserves active project history and selected original path');
      AtomicWrite(TPath.Combine(Probe.FProject.Folder,'Draft.json'),'{invalid}'); Failed:=False; try Probe.OpenProjectFile(SourceFile,1); except Failed:=True; end;
      Check(Failed and (Probe.FProject.Snapshot=Before),'failed draft restoration preserves the active project');
      Json:=Probe.FProject.Json;
      try Pair:=Json.RemovePair('id'); Pair.Free; Json.AddPair('id','different-project'); AtomicWrite(TPath.Combine(Probe.FProject.Folder,'Draft.json'),Json.ToJSON);
      finally Json.Free; end;
      Failed:=False; try Probe.OpenProjectFile(SourceFile,1); except Failed:=True; end;
      Check(Failed and (Probe.FProject.Snapshot=Before),'draft for a different project cannot replace the active project');
      Json:=Probe.FProject.Json;
      try Pages:=Json.GetValue<TJSONArray>('pages'); Pages.AddElement(Probe.FProject.Pages[0].Json); AtomicWrite(BrokenFile,Json.ToJSON); finally Json.Free; end;
      Failed:=False; try Probe.OpenProjectFile(BrokenFile,0); except Failed:=True; end;
      Check(Failed and (Probe.FProject.Snapshot=Before),'duplicate page identities are rejected before replacing the active project');
      Json:=Probe.FProject.Json;
      try
        Pages:=Json.GetValue<TJSONArray>('pages'); Pair:=TJSONObject(Pages.Items[0]).RemovePair('id'); Pair.Free;
        TJSONObject(Pages.Items[0]).AddPair('id','page-identity');
        Pages.AddElement(Probe.FProject.Pages[0].Json); Pair:=TJSONObject(Pages.Items[Pages.Count-1]).RemovePair('id'); Pair.Free;
        TJSONObject(Pages.Items[Pages.Count-1]).AddPair('id','PAGE-IDENTITY'); AtomicWrite(BrokenFile,Json.ToJSON);
      finally Json.Free; end;
      Failed:=False; try Probe.OpenProjectFile(BrokenFile,0); except Failed:=True; end;
      Check(Failed and (Probe.FProject.Snapshot=Before),'page identities cannot alias the same Windows save and cache path');
      BadBalloon:=TComicBalloon.Create; Json:=BadBalloon.Json;
      try Pair:=Json.RemovePair('fontSize'); Pair.Free; Json.AddPair('fontSize',TJSONNumber.Create(0)); Failed:=False;
        try BadBalloon.Read(Json); except Failed:=True; end; Check(Failed,'zero-sized text cannot enter a restored project');
      finally Json.Free; BadBalloon.Free; end;
      Probe.FRecent.Remember(BrokenFile,'壊れた作品','1',TPath.Combine(TestFolder,'menu-history.json')); TFile.Delete(BrokenFile); Probe.RefreshRecentMenu;
      Check(Probe.FRecentItems[0].Visible and not Probe.FRecentItems[0].Enabled,'missing project remains listed with an unavailable history action');
      Check(FProject.Snapshot=Original,'recent project fixtures preserve the active project');
    finally Probe.Free; CopyRecent.Free; Recent.Free; end;
  end;

procedure RunRecentProjectChecks(Host: TComicTestForm);
begin Host.RecentProjectChecks; end;
end.
