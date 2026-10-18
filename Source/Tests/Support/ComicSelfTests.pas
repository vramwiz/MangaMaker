unit ComicSelfTests;

// 責務：専用データで分野別回帰を順に実行し、全完了時だけ最終結果を保存する。
interface
uses ComicTestSupport;
procedure RunSelfTests(Host: TComicTestForm; const Folder: string);
implementation
uses Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, Winapi.Imm,
  System.SysUtils, System.Classes, System.Types, System.UITypes,
  System.Math, System.IOUtils, System.Generics.Collections, System.JSON,
  System.Hash, System.DateUtils, Vcl.Controls, Vcl.Forms,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Menus,
  Vcl.Dialogs, Vcl.Graphics, Vcl.Imaging.pngimage, ComicModel,
  ComicAssetDialog, ComicLayouts, ComicExport, ComicEditingTests,
  ComicGeometryTests, ComicImageLayoutTests, ComicTextTests, ComicInlineTextTests, ComicBalloonsTests, ComicAssetsTests,
  ComicIntegrationTests, ComicLibrariesTests, ComicRenderingTests, ComicWorkspaceTests, ComicMaterialPaneTests, ComicScriptTests, ComicAssetDialogTests, ComicPlacementTests, ComicEffectRotationTests, ComicPageResizeTests, ComicDragDropTests, ComicBalloonSelectionTests, ComicPageRefreshTests, ComicPageDefaultsTests;
type
  TComicSelfTestHelper = class helper for TComicTestForm
    procedure Execute;
  end;
procedure TComicSelfTestHelper.Execute;
begin
  if (GetEnvironmentVariable('MANGAMAKER_DATA_ROOT')='') or
    not TPath.GetFullPath(DataRoot).StartsWith(IncludeTrailingPathDelimiter(TPath.GetFullPath(TestFolder)),True) then
    raise Exception.Create('Self-test data must be isolated under its output TestFolder.');
  ForceDirectories(TestFolder); B:=TBitmap.Create; Lines:=TStringList.Create;
  try
    Check(not HasCharacter,'empty library blocks production');
    B.SetSize(700,440); B.Canvas.Brush.Color:=$E9C193; B.Canvas.FillRect(Rect(0,0,700,440));
    B.Canvas.Brush.Color:=$997752; B.Canvas.Ellipse(120,50,500,430); B.SaveToFile(TPath.Combine(TestFolder,'reference.bmp'));
    A:=TComicAsset.Create; A.Name:='テスト人物'; A.FileName:='reference.bmp'; FCharacters.Add(A);
    ForceDirectories(TPath.Combine(DataRoot,'Characters'));
    TFile.Copy(TPath.Combine(TestFolder,'reference.bmp'),TPath.Combine(DataRoot,'Characters\reference.bmp'),True);
    Check(HasCharacter,'character name and reference enable production');
    WriteAssets(FCharacters,TPath.Combine(DataRoot,'Characters\Library.json'));
    RunPageRefreshChecks(Self);
    RunPageDefaultsChecks(Self);
    RunSafetyChecks(Self);
    RunScriptChecks(Self);
    FProject:=CreateFixtureProject; FProject.Initialize('保存テスト・日本語','第1話'); FPageIndex:=0;
    A:=FProject.ImportImage(TPath.Combine(TestFolder,'reference.bmp'),''); A.Name:='場面画像'; AssetID:=A.ID;
    P:=TComicPanel.Create; P.Bounds:=TRectF.Create(60,60,1140,1100); P.ImageID:=AssetID; P.Zoom:=1.5; P.PanX:=42; Page.Panels.Add(P);
    Balloon:=TComicBalloon.Create; Balloon.Text:='漫画を作ろう！'; Balloon.HasTail:=True; Balloon.PanelID:=P.ID;
    Balloon.TailX:=480; Balloon.TailY:=540; Page.Balloons.Add(Balloon);
    FProject.Save; Snapshot:=FProject.Snapshot;
    Loaded:=CreateFixtureProject;
    try
      Loaded.Load(TPath.Combine(FProject.Folder,'Project.json'));
      Check(Loaded.Snapshot=Snapshot,'UTF-8 project save and load roundtrip');
      Check(Loaded.Pages[0].Panels[0].ImageID=AssetID,'stable image UID after loading');
    finally Loaded.Free; end;
    Checkpoint; Page.Panels[0].Bounds.Right:=900; Changed; Undo(nil);
    Check(Page.Panels[0].Bounds.Right=1140,'panel undo'); Redo(nil);
    Check(Page.Panels[0].Bounds.Right=900,'panel redo');
    RunRenderChecks(Self);
    RunEditingChecks(Self);
    RunTextSessionChecks(Self);
    RunInlineTextChecks(Self);
    RunPlacementChecks(Self); RunDialogueRefinementChecks(Self); RunManualTextFlowChecks(Self);
    RunEffectRotationChecks(Self); RunPageResizeChecks(Self); RunDragDropChecks(Self);
    RunBalloonSelectionChecks(Self);
    RunTextNavigationChecks(Self);
    RunTextLayoutChecks(Self);
    RunPageBasisChecks(Self);
    RunPanelGroupChecks(Self);
    RunLayoutManagementChecks(Self);
    RunFontStyleChecks(Self);
    RunCreatedPanelSelectionChecks(Self);
    RunTailChecks(Self);
    RunBalloonInteractionChecks(Self);
    RunBalloonContourChecks(Self);
    RunTextPlacementChecks(Self);
    RunTextScaledWrappingChecks(Self);
    RunGenerationPresetChecks(Self);
    RunBridgeChecks(Self);
    RunCharacterGroupChecks(Self);
    RunSceneGenerationChecks(Self);
    RunAssetDialogChecks(Self);
    RunEffectChecks(Self);
    RunDragCommandChecks(Self);
    RunBlurScaleChecks(Self);
    RunRecentProjectChecks(Self);
    RunGapSnapChecks(Self);
    RunPanelTransformSnapChecks(Self);
    RunImageLayoutChecks(Self);
    RunExportReviewChecks(Self);
    RunBulkDataChecks(Self);
    RunIconChecks(Self);
    RunMenuChecks(Self);
    Layout:=TComicLayout.Create; Layout.Name:='楕円のテスト・共通';
    Page.Panels[0].Shape:=1; Layout.Capture(FProject,Page); FLayouts.Add(Layout);
    J:=Layout.Json;
    try Check((Pos('imageId',J.ToJSON)=0) and (Pos('balloons',J.ToJSON)=0) and (Pos(AssetID,J.ToJSON)=0),
      'layout contains geometry only'); finally J.Free; end;
    SaveLayouts(FLayouts,TPath.Combine(DataRoot,'Presets\Layouts.json'));
    LibraryCopy:=TObjectList<TComicLayout>.Create;
    try
      SeedLayouts(LibraryCopy); LoadLayouts(LibraryCopy,TPath.Combine(DataRoot,'Presets\Layouts.json'));
      Check((LibraryCopy.Count=BuiltInLayoutCount+1) and (LibraryCopy.Last.ID=Layout.ID) and (LibraryCopy.Last.Name=Layout.Name),
        'shared custom layout persists with stable ID and Japanese name');
      Loaded:=CreateFixtureProject;
      try
        Loaded.Pages.Add(TComicPage.Create); LibraryCopy.Last.Apply(Loaded.Pages[0],600,850);
        Check((Loaded.Pages[0].Panels[0].Bounds.Right=450) and (Loaded.Pages[0].Panels[0].Shape=1),
          'layout scales to a different page resolution');
        Check((Loaded.Pages[0].Panels[0].ID<>Page.Panels[0].ID) and (Loaded.Pages[0].Panels[0].ImageID=''),
          'layout creates new panels without image assignments');
      finally Loaded.Free; end;
      AtomicWrite(TPath.Combine(TestFolder,'bad-layouts.json'),'{"version":1,"layouts":[{"id":"broken","name":"bad","width":1200,"height":1700,"panels":[{"x":0,"y":0,"w":-1,"h":100}]}]}');
      Failed:=False;
      try LoadLayouts(LibraryCopy,TPath.Combine(TestFolder,'bad-layouts.json')); except Failed:=True; end;
      Check(Failed and (LibraryCopy.Count=BuiltInLayoutCount+1),'invalid library preserves existing layouts');
    finally LibraryCopy.Free; end;
    FLayoutList.Items.AddObject(Layout.Name,Layout);
    RefreshUI; FirstID:=Page.ID;
    ApplyLayout(FLayouts[3],-1);
    Check((Page.Panels.Count=4) and (Page.Balloons.Count=0),'template replacement clears old panel content');
    Undo(nil);
    Check((Page.Panels.Count=1) and (Page.Panels[0].ImageID=AssetID) and
      (Page.Panels[0].Zoom=1.5) and (Page.Panels[0].PanX=42) and
      (Page.Balloons.Count=1) and (Page.Balloons[0].Text='漫画を作ろう！') and
      (Page.Balloons[0].TailX=480),'template undo restores image placement and whole balloon');
    Redo(nil); Check(Page.Panels.Count=4,'template redo');
    FLayoutList.ItemIndex:=1; R:=FPages.ItemRect(0);
    PagesDragDrop(FPages,FLayoutList,8,R.Bottom-1);
    SecondID:=Page.ID;
    Check((FProject.Pages.Count=2) and (FProject.Pages[0].ID=FirstID) and (Page.Panels.Count=2),
      'drop layout between pages inserts and selects a new page');
    Undo(nil); Check((FProject.Pages.Count=1) and (FProject.Pages[0].ID=FirstID),'insert undo restores page sequence');
    Redo(nil); Check((FProject.Pages.Count=2) and (FProject.Pages[1].ID=SecondID),'insert redo keeps new page UID');
    SelectOnly(1); AddPage(nil); ThirdID:=Page.ID; AddPage(nil); FourthID:=Page.ID;
    FPages.ItemIndex:=0; FPages.Selected[0]:=True; FPages.Selected[1]:=False;
    FPages.Selected[2]:=True; FPages.Selected[3]:=False; PageSelect(nil);
    R:=FPages.ItemRect(3); PagesDragDrop(FPages,FPages,8,R.Bottom-1);
    Check((FProject.Pages[0].ID=SecondID) and (FProject.Pages[1].ID=FourthID) and
      (FProject.Pages[2].ID=FirstID) and (FProject.Pages[3].ID=ThirdID),
      'multi-page drag preserves relative order');
    Check(FPages.Selected[2] and FPages.Selected[3] and (FPages.SelCount=2),'selection follows moved page UIDs');
    Undo(nil); Check((FProject.Pages[0].ID=FirstID) and (FProject.Pages[2].ID=ThirdID),'multi-page move undo');
    Redo(nil); Check(FProject.Pages[2].ID=FirstID,'multi-page move redo');
    SelectOnly(2); FTabs.ActivePageIndex:=2; TabChanged(nil); Capture('image-drop-before');
    FImages.ItemIndex:=0;
    Check(not Assigned(FImages.OnDblClick),'image assignment has no double-click shortcut');
    Check(FImages.Top=MulDiv(98,CurrentPPI,96),'image list follows the assignment and snap guidance header');
    R:=FPageRect;
    DragDrop(FCanvas,FImages,R.Left+Round(800*FScale),R.Top+Round(400*FScale));
    Check(Page.Panels[0].ImageID=AssetID,'image drop assigns the panel under the pointer without prior selection');
    Check((ActiveControl=FView) and (Length(SelectedPanelIDs)=1),'drop selects its target and enables canvas shortcuts');
    Snapshot:=FProject.Snapshot;
    Check(PrepareImageContext(Point(-1,-1)) and (FPanelIndex=0),'keyboard context preserves selected panel');
    Check(not PrepareImageContext(Point(R.Left+Round(600*FScale),R.Top+Round(850*FScale))),
      'gutter context does not offer image detach');
    SelectSinglePanel(1);
    Check(PrepareImageContext(Point(R.Left+Round(800*FScale),R.Top+Round(400*FScale))) and FDetachImageMenu.Enabled,
      'image context targets the clicked assigned panel');
    Check(FPanelIndex=0,'image context ignores the previously selected different panel');
    FDetachImageMenu.Click;
    Check((Page.Panels[0].ImageID='') and (FProject.Asset(AssetID)<>nil),'context detach preserves source asset');
    Undo(nil); Check(FProject.Snapshot=Snapshot,'context detach undo restores image placement');
    R:=FPageRect; Check(PrepareImageContext(Point(R.Left+Round(800*FScale),R.Top+Round(400*FScale))),
      'image context can reopen after undo');
    ImageKey:=VK_DELETE; Key(Self,ImageKey,[]);
    Check(Page.Panels[0].ImageID='','Delete detaches selected image in image mode');
    Undo(nil); Check(FProject.Snapshot=Snapshot,'Delete detach undo restores image placement');
    ActiveControl:=FImages; ImageKey:=VK_DELETE; Key(Self,ImageKey,[]);
    Check(FProject.Snapshot=Snapshot,'Delete in image list does not detach canvas image');
    FProject.Pages[0].Panels[0].ImageID:=AssetID;
    FProject.Pages[0].Panels[1].ImageID:=AssetID;
    FPanelIndex:=0; DetachImage(nil);
    Check((Page.Panels[0].ImageID='') and (FProject.Asset(AssetID)<>nil),'detach preserves project image');
    Undo(nil); Check(Page.Panels[0].ImageID=AssetID,'detach undo restores image assignment');
    RefreshUI; FTabs.ActivePageIndex:=0; TabChanged(nil); Capture('window-layouts');
    Check(not Visible,'UI capture keeps main window hidden');
    FTabs.ActivePageIndex:=2; TabChanged(nil); Capture('window-images');
    DragOver(FCanvas,FImages,-1,-1,dsDragMove,Accept); Check(not Accept,'image drop outside page is rejected');
    R:=FPageRect; DragOver(FCanvas,FImages,R.Left+Round(800*FScale),R.Top+Round(400*FScale),dsDragMove,Accept);
    Check(Accept,'image thumbnail can be dropped on a panel');
    DragOver(FCanvas,FImages,R.Left+Round(600*FScale),R.Top+Round(850*FScale),dsDragMove,Accept);
    Check(not Accept,'image drop in gutter is rejected');
    FRenderer.ExportPage(FProject,Page,TPath.Combine(TestFolder,'page.png'));
    N:=ExportSequence(FProject,FRenderer,False); Check(N=4,'first PNG export renders every page');
    Check(ExportSequence(FProject,FRenderer,False)=0,'unchanged export reuses PNG cache');
    CacheFile:=TPath.Combine(FProject.Folder,'Output\.cache\'+FirstID+'.png');
    Snapshot:=THashSHA2.GetHashStringFromFile(CacheFile);
    FProject.Pages.Move(2,0); FPageIndex:=0; Changed(False);
    Check(ExportSequence(FProject,FRenderer,False)=0,'page reorder copies cached PNG without rerendering');
    Check(THashSHA2.GetHashStringFromFile(TPath.Combine(FProject.Folder,'Output\0001.png'))=Snapshot,
      'sequential filename follows reordered page UID');
    Checkpoint; Page.Panels[0].PanX:=222; Changed;
    SignatureLock:=CreateFile(PChar(CacheFile+'.signature'),GENERIC_READ,FILE_SHARE_READ or FILE_SHARE_WRITE,
      nil,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,0);
    if SignatureLock=INVALID_HANDLE_VALUE then RaiseLastOSError;
    try
      Failed:=False;
      try ExportSequence(FProject,FRenderer,False); except Failed:=True; end;
      Check(Failed,'locked signature injects export publication failure');
      Check(THashSHA2.GetHashStringFromFile(CacheFile)=Snapshot,'signature invalidation failure keeps previous cached PNG');
    finally CloseHandle(SignatureLock); end;
    Undo(nil); Check(ExportSequence(FProject,FRenderer,False)=0,'undo after locked-signature failure reuses valid old cache');
    Check(THashSHA2.GetHashStringFromFile(TPath.Combine(FProject.Folder,'Output\0001.png'))=Snapshot,
      'undo after signature failure exports the correct previous image');
    Checkpoint; Page.Panels[0].PanX:=333; Changed;
    SignatureLock:=CreateFile(PChar(CacheFile+'.signature.tmp'),GENERIC_READ or GENERIC_WRITE,FILE_SHARE_READ,
      nil,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,0);
    if SignatureLock=INVALID_HANDLE_VALUE then RaiseLastOSError;
    try
      Failed:=False;
      try ExportSequence(FProject,FRenderer,False); except Failed:=True; end;
      Check(Failed and not FileExists(CacheFile+'.signature'),
        'signature write failure leaves no stale signature beside replaced PNG');
    finally CloseHandle(SignatureLock); end;
    Undo(nil); Check(ExportSequence(FProject,FRenderer,False)=1,'undo after signature write failure rerenders safely');
    Check(THashSHA2.GetHashStringFromFile(TPath.Combine(FProject.Folder,'Output\0001.png'))=Snapshot,
      'signature write failure recovery restores the correct previous image');
    Checkpoint; Page.Panels[0].PanX:=123; Changed;
    Check(ExportSequence(FProject,FRenderer,False)=1,'single-page edit rerenders only that page');
    Undo(nil); Check(ExportSequence(FProject,FRenderer,False)=1,'undo after export cannot reuse stale content');
    Checkpoint; Page.Panels[0].PanX:=321; Changed;
    Check(ExportSequence(FProject,FRenderer,False)=1,'new edit after undo cannot collide with old revision');
    B.SetSize(700,440); B.Canvas.Brush.Color:=$4466AA; B.Canvas.FillRect(Rect(0,0,700,440));
    B.SaveToFile(FProject.ImagePath(AssetID));
    Check(ExportSequence(FProject,FRenderer,False)=2,'same-path image replacement rerenders referencing pages only');
    Check(ExportSequence(FProject,FRenderer,False)=0,'updated image export becomes stable');
    A2:=FProject.ImportImage(TPath.Combine(TestFolder,'reference.bmp'),''); A2.Name:='別の場面';
    Check(ExportSequence(FProject,FRenderer,False)=0,'unused image import does not rerender pages');
    FProject.Width:=600; FProject.Height:=850;
    Check(ExportSequence(FProject,FRenderer,False)=4,'resolution change invalidates every page');
    Check(ExportSequence(FProject,FRenderer,True)=4,'all-pages export forces rerender');
    P:=FProject.Pages[1].Panels[0]; BeforeOutput:=FProject.Pages[1].OutputRevision;
    P.ImageID:=A2.ID; Inc(FProject.Pages[1].Revision);
    TFile.WriteAllText(FProject.ImagePath(A2.ID),'not an image',TEncoding.UTF8);
    Failed:=False;
    try ExportSequence(FProject,FRenderer,False); except Failed:=True; end;
    Check(Failed and (FProject.Pages[1].OutputRevision=BeforeOutput),'failed page is not recorded as exported');
    TFile.Copy(TPath.Combine(TestFolder,'reference.bmp'),FProject.ImagePath(A2.ID),True);
    Check(ExportSequence(FProject,FRenderer,False)=1,'failed export can be retried successfully');
    Checkpoint; FProject.Pages.Delete(3); Changed(False);
    Check(ExportSequence(FProject,FRenderer,False)=0,'page deletion does not rerender surviving pages');
    Check(not FileExists(TPath.Combine(FProject.Folder,'Output\0004.png')),'page deletion removes stale sequence file');
    Undo(nil); Check(ExportSequence(FProject,FRenderer,False)=0,'undo deletion reuses removed page cache');
    Check(FileExists(TPath.Combine(FProject.Folder,'Output\0004.png')),'undo deletion restores fourth sequential output');
    Redo(nil); Check(ExportSequence(FProject,FRenderer,False)=0,'redo deletion reuses surviving page caches');
    Check(not FileExists(TPath.Combine(FProject.Folder,'Output\0004.png')),'redo deletion cleans sequence using actual export history');
    Snapshot:=FProject.Snapshot; SecondID:=FProject.Pages[1].ID; SelectOnly(0); FPages.Selected[2]:=True;
    RemoveSelectedPages(False);
    Check((FProject.Pages.Count=1) and (FProject.Pages[0].ID=SecondID),'multi-page deletion removes exactly the selection');
    Undo(nil);
    Check((FProject.Pages.Count=3) and (FProject.Pages[1].ID=SecondID),'multi-page deletion undo restores contents and order');
    Redo(nil); Check(FProject.Pages.Count=1,'multi-page deletion redo'); Undo(nil);
    SelectOnly(0); FPages.SelectAll; RemoveSelectedPages(False);
    Check((FProject.Pages.Count=0) and (Page=nil),'all-pages deletion leaves a valid empty project');
    Undo(nil); Check(FProject.Pages.Count=3,'all-pages deletion undo');
    FProject.Width:=1200; FProject.Height:=1700; FPageIndex:=0; RefreshUI;
    RunGeometryChecks(Self);
    FTabs.ActivePageIndex:=0; TabChanged(nil); Capture('window-final');
    Dialog:=TAssetDialog.CreateManager(Self,FCharacters,nil,True);
    try
      Dialog.HandleNeeded; B.SetSize(Dialog.ClientWidth,Dialog.ClientHeight); Dialog.PaintTo(B.Canvas,0,0);
      B.SaveToFile(TPath.Combine(TestFolder,'window-characters.bmp'));
    finally Dialog.Free; end;
    FProject.Save; FDirty:=False;
    RunViewportChecks(Self);
    RunMaterialPaneChecks(Self);
    FModeButtons[4].Click; FEffectCategory.ItemIndex:=0; EffectCategoryChanged(nil);
    Capture('window-materials-96');
    Check(FEffectList.Height>FEffectList.ItemHeight*2,'integrated material pane leaves space for thumbnails');
    // 非表示フォームを描画しても実モニターの96PPIへ戻らないよう、拡縮後は自動調整を止める。
    Scaled:=True; ScaleForPPI(144); Scaled:=False; Capture('window-materials-144');
    Check((CurrentPPI=144) and (FEffectList.Height>=FEffectList.ItemHeight) and
      (FEffectList.Top>=FEffectPane.GroupList.Top+FEffectPane.GroupList.Height),
      'material pane scales without overlapping groups or clipping its first thumbnail row');
    Scaled:=True; ScaleForPPI(96);
    Lines.Add('PASS: hidden VCL captures, no external generation or transmission.');
    TFile.WriteAllText(TPath.Combine(TestFolder,'result.txt'),Lines.Text,TEncoding.UTF8);
  finally Lines.Free; B.Free; end;
end;


procedure RunSelfTests(Host: TComicTestForm; const Folder: string);
begin Host.TestFolder:=Folder; Host.Execute; end;
end.
