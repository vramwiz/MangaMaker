unit ComicRenderingTests;

// 責務：画素・フィルター・大量ページを検証する。並行実行の時間を単独性能と比較しない。
interface
uses ComicTestSupport;
procedure RunRenderChecks(Host: TComicTestForm);
procedure RunEffectChecks(Host: TComicTestForm);
procedure RunBlurScaleChecks(Host: TComicTestForm);
procedure RunBulkDataChecks(Host: TComicTestForm);
implementation
uses Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, Winapi.Imm,
  System.SysUtils, System.Classes, System.Types, System.UITypes,
  System.Math, System.IOUtils, System.Generics.Collections, System.JSON,
  System.Hash, System.DateUtils, Vcl.Controls, Vcl.Forms,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Menus,
  Vcl.Dialogs, Vcl.Graphics, Vcl.Imaging.pngimage, ComicModel,
  ComicRender, ComicLayouts, ComicExport, ComicEditing,
  ComicEffects, ComicEffectDialog, ComicFilters;
type
  TComicRenderingTestsHelper = class helper for TComicTestForm
    procedure RenderChecks;
    procedure EffectChecks;
    procedure BlurScaleChecks;
    procedure BulkDataChecks;
  end;
procedure TComicRenderingTestsHelper.RenderChecks;
  var Clone: TComicProject; Reference,Shifted,Warm: TBitmap; Extra: TComicBalloon;
    X,Y,SavedDC: Integer; Same: Boolean;
  begin
    Clone:=TComicProject.Create; Reference:=TBitmap.Create; Shifted:=TBitmap.Create; Warm:=TBitmap.Create;
    try
      Clone.Folder:=FProject.Folder; Clone.Restore(FProject.Snapshot);
      Extra:=TComicBalloon.Create; Extra.Text:='二つ目の吹き出し'; Extra.Bounds:=TRectF.Create(650,300,950,600);
      Extra.PanelID:=Clone.Pages[0].Panels[0].ID; Extra.Overflow:=False;
      Extra.HasTail:=True; Extra.TailX:=650; Extra.TailY:=660;
      Clone.Pages[0].Panels[0].Shape:=1;
      Clone.Pages[0].Balloons.Add(Extra);
      Reference.SetSize(600,850); Shifted.SetSize(750,950);
      FRenderer.Draw(Reference.Canvas,Clone,Clone.Pages[0],Rect(0,0,600,850),False); Warm.Assign(Reference);
      SavedDC:=SaveDC(Shifted.Canvas.Handle);
      try
        SetViewportOrgEx(Shifted.Canvas.Handle,75,50,nil);
        FRenderer.Draw(Shifted.Canvas,Clone,Clone.Pages[0],Rect(0,0,600,850),False);
      finally RestoreDC(Shifted.Canvas.Handle,SavedDC); Shifted.Canvas.Refresh; end;
      Same:=True; X:=3;
      while X<600 do begin Y:=3;
        while Y<850 do begin
          if Reference.Canvas.Pixels[X,Y]<>Shifted.Canvas.Pixels[X+75,Y+50] then Same:=False;
          Inc(Y,13);
        end;
        Inc(X,13);
      end;
      Check(Same,'translated DC rendering matches PNG coordinates and balloon clipping');
      Check(Reference.Canvas.Pixels[462,225]=clWhite,'clipped balloon cannot paint beyond its owner panel');
      FRenderer.Draw(Reference.Canvas,Clone,Clone.Pages[0],Rect(0,0,600,850),False);
      Same:=True; X:=3;
      while X<600 do begin Y:=3;
        while Y<850 do begin
          if Reference.Canvas.Pixels[X,Y]<>Warm.Canvas.Pixels[X,Y] then Same:=False;
          Inc(Y,13);
        end;
        Inc(X,13);
      end;
      Check(Same,'repeated canvas rendering keeps multiple balloon fonts stable');
      Reference.SaveToFile(TPath.Combine(TestFolder,'render-balloons.bmp'));
      Clone.Pages[0].Panels[0].SetVertices([TPointF.Create(100,100),TPointF.Create(1100,100),TPointF.Create(1100,1500)]);
      Extra.Bounds:=TRectF.Create(100,900,600,1400); Extra.HasTail:=False;
      FRenderer.Draw(Reference.Canvas,Clone,Clone.Pages[0],Rect(0,0,600,850),False);
      SavedDC:=SaveDC(Shifted.Canvas.Handle);
      try SetViewportOrgEx(Shifted.Canvas.Handle,75,50,nil);
        FRenderer.Draw(Shifted.Canvas,Clone,Clone.Pages[0],Rect(0,0,600,850),False);
      finally RestoreDC(Shifted.Canvas.Handle,SavedDC); Shifted.Canvas.Refresh; end;
      Same:=True; X:=3;
      while X<600 do begin Y:=3;
        while Y<850 do begin
          if Reference.Canvas.Pixels[X,Y]<>Shifted.Canvas.Pixels[X+75,Y+50] then Same:=False;
          Inc(Y,13);
        end;
        Inc(X,13);
      end;
      Check(Same,'polygon and owner-clipped balloon match under translated DC rendering');
      Check(Reference.Canvas.Pixels[80,600]=clWhite,'polygon owner clips balloon outside actual triangle');
      Reference.SaveToFile(TPath.Combine(TestFolder,'render-polygon-balloons.bmp'));
    finally Warm.Free; Shifted.Free; Reference.Free; Clone.Free; end;
  end;

procedure RunRenderChecks(Host: TComicTestForm);
begin Host.RenderChecks; end;
procedure TComicRenderingTestsHelper.EffectChecks;
  var Probe: TComicTestForm; Project,Reloaded: TComicProject; Panel: TComicPanel; Material: TComicEffectMaterial;
    MaterialLibrary,CopyLibrary,Broken: TObjectList<TComicEffectMaterial>; Manager: TComicEffectDialog; Layout: TComicLayout;
    Before,After,Original,Path,ID,CopyPath,LibraryBytes: string; PNG: TPngImage; Reference,Shifted,Pixels: TBitmap;
    PointA: TPointF; Bounds,OriginalBounds: TRectF; X,Y,K,Kind,Shape,Frame,PPI,History,Saved,I: Integer; Lock: THandle; KeyValue: Word;
    Failed,Accept,Same: Boolean; Color: TColor; Json: TJSONObject;
    function CurrentPanel: TComicPanel;
    begin Result:=Probe.Page.Panels[0]; end;
    procedure CaptureEffect(const Name: string);
    begin Probe.UpdateIconState; Probe.HandleNeeded; B.SetSize(Probe.ClientWidth,Probe.ClientHeight); Probe.PaintTo(B.Canvas,0,0); PNG.Assign(B);
      PNG.SaveToFile(TPath.Combine(TestFolder,Name+'.png')); end;
  begin
    Original:=FProject.Snapshot; Probe:=TComicTestForm.Create(nil); PNG:=TPngImage.Create; Reference:=TBitmap.Create; Shifted:=TBitmap.Create; Pixels:=TBitmap.Create;
    MaterialLibrary:=TObjectList<TComicEffectMaterial>.Create; CopyLibrary:=TObjectList<TComicEffectMaterial>.Create; Broken:=TObjectList<TComicEffectMaterial>.Create; Manager:=nil; Layout:=TComicLayout.Create;
    try
      SeedEffectMaterials(MaterialLibrary); EnsureBuiltInMaterialFiles(MaterialLibrary);
      PNG.LoadFromFile(EffectMaterialPath(MaterialLibrary[0])); Check((PNG.Width=512) and (PNG.AlphaScanline[256]^[256]=0), 'built-in focus material leaves its centre transparent');
      Pixels.PixelFormat:=pf24bit; Pixels.SetSize(64,64); Pixels.Canvas.Brush.Color:=clRed; Pixels.Canvas.FillRect(Rect(0,0,64,64)); PNG.Assign(Pixels); PNG.CreateAlpha;
      for Y:=0 to 63 do for X:=0 to 63 do if X<32 then PNG.AlphaScanline[Y]^[X]:=128 else PNG.AlphaScanline[Y]^[X]:=0;
      Path:=TPath.Combine(TestFolder,'half-transparent-effect.png'); PNG.SaveToFile(Path);
      Path:=TPath.Combine(TestFolder,'effect-library.json'); Material:=ImportEffectMaterial(MaterialLibrary,'半透明効果',TPath.Combine(TestFolder,'half-transparent-effect.png'),Path); ID:=Material.ID;
      SaveEffectMaterials(MaterialLibrary,Path); SeedEffectMaterials(CopyLibrary); LoadEffectMaterials(CopyLibrary,Path);
      Check((CopyLibrary.Count=4) and (CopyLibrary[3].ID=ID) and (CopyLibrary[3].Name='半透明効果'),'custom effect material saves and reloads stable identity');
      LibraryBytes:=TFile.ReadAllText(Path,TEncoding.UTF8); Lock:=CreateFile(PChar(Path),GENERIC_READ,FILE_SHARE_READ,nil,OPEN_EXISTING,0,0);
      try
        Failed:=False; try RenameEffectMaterial(MaterialLibrary,Material,'保存に失敗',Path); except Failed:=True; end;
        Check(Failed and (Material.Name='半透明効果') and (TFile.ReadAllText(Path,TEncoding.UTF8)=LibraryBytes),'failed effect rename preserves name and original library');
        Failed:=False; try DeleteEffectMaterial(MaterialLibrary,Material,Path); except Failed:=True; end;
        Check(Failed and (MaterialLibrary.Count=4) and (MaterialLibrary[3]=Material),'failed effect deletion restores the exact item and order');
      finally CloseHandle(Lock); end;
      Json:=Material.Json; try AtomicWrite(Path,'{"version":1,"materials":['+Json.ToJSON+',42]}'); finally Json.Free; end;
      Failed:=False; try LoadEffectMaterials(Broken,Path); except Failed:=True; end;
      Check(Failed and (Broken.Count=0),'malformed effect library cannot publish a valid prefix'); AtomicWrite(Path,LibraryBytes);
      Project:=TComicProject.Create; Project.Initialize('漫画効果 fixture','1'); Probe.AdoptProject(Project,False); Project.ImportImage(TPath.Combine(TestFolder,'reference.bmp'),'');
      Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(100,100,900,1300); OriginalBounds:=Panel.Bounds; Probe.Page.Panels.Add(Panel); Probe.RefreshUI;
      Probe.FModeButtons[4].Click; CaptureEffect('effects-material-empty'); Probe.FEffectList.Items.AddObject(Material.Name,Material); Probe.FEffectList.ItemIndex:=Probe.FEffectList.Count-1;
      PointA:=OriginalBounds.CenterPoint; X:=Probe.FPageRect.Left+Round(PointA.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(PointA.Y*Probe.FScale);
      Before:=Project.Snapshot; Probe.DragOver(Probe.FCanvas,Probe.FEffectList,X,Y,dsDragMove,Accept); Check(Accept,'material D&D accepts a target panel');
      Probe.DragDrop(Probe.FCanvas,Probe.FEffectList,X,Y);
      Check((CurrentPanel.Overlays.Count=1) and (CurrentPanel.Overlays[0].MaterialID=ID) and (OverlayBounds(CurrentPanel,CurrentPanel.Overlays[0])=OriginalBounds),
        'material drop creates a separately identified panel-sized overlay');
      CopyPath:=SafeChild(Project.Folder,CurrentPanel.Overlays[0].FileName); Check(FileExists(CopyPath),'applied material receives a project-local PNG snapshot');
      Reference.SetSize(320,452); Probe.FRenderer.Draw(Reference.Canvas,Project,Probe.Page,Rect(0,0,320,452),False);
      Color:=Reference.Canvas.Pixels[80,110]; Check((GetRValue(Color)>240) and (GetGValue(Color)<170),'half-transparent PNG blends its red ink with the panel background');
      Check(Reference.Canvas.Pixels[187,110]=$F5F2EF,'transparent PNG half preserves the panel background');
      After:=Project.Snapshot; Probe.Undo(nil); Check(Project.Snapshot=Before,'material application undoes as one operation'); Probe.Redo(nil); Check(Project.Snapshot=After,'material application redo restores its retained PNG');
      for K:=1 to 8 do begin
        Probe.FPanelIndex:=0; Probe.FEffectIndex:=0; Bounds:=OverlayBounds(CurrentPanel,CurrentPanel.Overlays[0]); PointA:=EditHandles(Bounds)[K-1];
        X:=Probe.FPageRect.Left+Round(PointA.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(PointA.Y*Probe.FScale); Before:=Project.Snapshot;
        Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y); Check(Probe.FDragHandle=K,'effect material handle '+IntToStr(K)+' is selectable');
        Probe.MouseMove(Probe.FCanvas,[ssLeft],X+14,Y+10); Probe.MouseUp(Probe.FCanvas,mbLeft,[],X+14,Y+10);
        Bounds:=OverlayBounds(CurrentPanel,CurrentPanel.Overlays[0]);
        Check((CurrentPanel.Bounds=OriginalBounds) and (Abs(Bounds.Width/Bounds.Height-OriginalBounds.Width/OriginalBounds.Height)<0.0001),
          'effect material handle '+IntToStr(K)+' keeps aspect ratio and owner geometry');
        Project.Save; Reloaded:=TComicProject.Create;
        try Reloaded.Load(TPath.Combine(Project.Folder,'Project.json')); Check(Reloaded.Snapshot=Project.Snapshot,'effect handle saves and reloads '+IntToStr(K)); finally Reloaded.Free; end;
        Probe.Undo(nil); Check(Project.Snapshot=Before,'effect handle undo restores exact placement '+IntToStr(K));
      end;
      Probe.FPanelIndex:=0; Probe.FEffectIndex:=0; Bounds:=OverlayBounds(CurrentPanel,CurrentPanel.Overlays[0]); PointA:=Bounds.CenterPoint;
      X:=Probe.FPageRect.Left+Round(PointA.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(PointA.Y*Probe.FScale); Before:=Project.Snapshot; History:=Probe.FUndo.Count;
      Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y); Probe.MouseMove(Probe.FCanvas,[ssLeft],X+20,Y+15); KeyValue:=VK_ESCAPE; Probe.Key(Probe,KeyValue,[]);
      Check((Project.Snapshot=Before) and (Probe.FUndo.Count=History),'escape restores a pending material movement without history');
      Probe.FPanelIndex:=0; Probe.FEffectIndex:=0; Probe.ApplyEffectMaterial(0,MaterialLibrary[2]);
      Check(CurrentPanel.Overlays.Count=2,'panel supports multiple independently placed materials');
      Before:=Project.Snapshot; Probe.DeleteEffect(nil); Check(CurrentPanel.Overlays.Count=1,'material deletion affects only selected overlay'); Probe.Undo(nil); Check(Project.Snapshot=Before,'material deletion undo restores its identity and file');
      for Kind:=1 to 4 do begin
        Probe.FEffectCategory.ItemIndex:=1; Probe.EffectCategoryChanged(nil); Probe.FPanelIndex:=0; Probe.LoadPanelEffectControls;
        Probe.FFilterKind.ItemIndex:=Kind; Probe.FFilterStrength.ItemIndex:=3; Before:=Project.Snapshot; Probe.ApplyFilter(nil);
        Check(CurrentPanel.FilterKind=Kind,'filter type '+IntToStr(Kind)+' applies without an overlay geometry');
        History:=Probe.FUndo.Count; Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y); Probe.MouseMove(Probe.FCanvas,[ssLeft],X+10,Y+10);
        Check(not Probe.FDragging and (Probe.FUndo.Count=History),'filter selection has no drag or eight-point geometry '+IntToStr(Kind));
        Probe.Undo(nil); Check(Project.Snapshot=Before,'filter undo restores the previous state '+IntToStr(Kind));
      end;
      Pixels.SetSize(31,31); Pixels.Canvas.Brush.Color:=clWhite; Pixels.Canvas.FillRect(Rect(0,0,31,31)); Pixels.Canvas.Pixels[15,15]:=clBlack;
      ApplyComicFilter(Pixels,3,100); Check((Pixels.Canvas.Pixels[15,15]<>clBlack) and (Pixels.Canvas.Pixels[16,15]<>clWhite) and
        (Pixels.Canvas.Pixels[0,0]=clWhite),'blur spreads a local impulse and retains remote white pixels');
      Pixels.SetSize(1,1); Pixels.Canvas.Pixels[0,0]:=RGB(100,120,140); ApplyComicFilter(Pixels,2,100);
      Check(Pixels.Canvas.Pixels[0,0]=TColor(RGB(116,116,116)),'grayscale uses deterministic weighted luminance');
      Failed:=False; try ApplyComicFilter(Pixels,99,0); except Failed:=True; end; Check(Failed,'invalid filter kind is rejected even at zero strength');
      Probe.FEffectCategory.ItemIndex:=2; Probe.EffectCategoryChanged(nil); Probe.FPanelIndex:=0; Probe.LoadPanelEffectControls;
      Probe.FFrameKind.ItemIndex:=1; Probe.FPanelBorderColor:=clNavy; Before:=Project.Snapshot; Probe.ApplyFrame(nil);
      Check((CurrentPanel.FrameKind=1) and (CurrentPanel.BorderColor=clNavy),'frame appearance stores decoration and colour');
      Probe.Undo(nil); Check(Project.Snapshot=Before,'frame appearance undo restores its original border');
      Reference.SetSize(240,340); Shifted.SetSize(360,430);
      for Shape:=0 to 3 do for Frame:=0 to 2 do begin
        Panel:=CurrentPanel; Panel.Shape:=Shape;
        if Shape=3 then Panel.SetVertices([TPointF.Create(100,100),TPointF.Create(900,100),TPointF.Create(700,1300),TPointF.Create(100,1100)]);
        Panel.FrameKind:=Frame; Panel.FilterKind:=1+(Shape mod 4); Panel.FilterStrength:=75;
        Probe.FRenderer.Draw(Reference.Canvas,Project,Probe.Page,Rect(0,0,240,340),False); Saved:=SaveDC(Shifted.Canvas.Handle);
        try SetViewportOrgEx(Shifted.Canvas.Handle,75,50,nil); Probe.FRenderer.Draw(Shifted.Canvas,Project,Probe.Page,Rect(0,0,240,340),False);
        finally RestoreDC(Shifted.Canvas.Handle,Saved); Shifted.Canvas.Refresh; end;
        Same:=True; for X:=0 to 239 do for Y:=0 to 339 do if Reference.Canvas.Pixels[X,Y]<>Shifted.Canvas.Pixels[X+75,Y+50] then Same:=False;
        Check(Same,'filtered panel alpha materials and frame match translated DC '+IntToStr(Shape)+' '+IntToStr(Frame));
      end;
      Panel:=CurrentPanel; Panel.Shape:=0; Panel.SetBounds(OriginalBounds); Panel.FrameKind:=1; Panel.FilterKind:=1;
      Bounds:=OverlayBounds(Panel,Panel.Overlays[0]); Before:=Project.Snapshot;
      Probe.FSplitA:=TPointF.Create(500,100); Probe.FSplitB:=TPointF.Create(500,1300);
      Probe.FSplitC:=TPointF.Create(520,100); Probe.FSplitD:=TPointF.Create(520,1300); Probe.CommitSplit(0);
      Check((Probe.Page.Panels.Count=2) and (OverlayBounds(Probe.Page.Panels[0],Probe.Page.Panels[0].Overlays[0])=Bounds) and
        (OverlayBounds(Probe.Page.Panels[1],Probe.Page.Panels[1].Overlays[0])=Bounds), 'panel split preserves the global material position in both clipped fragments');
      Check((Probe.Page.Panels[0].Overlays[0].ID<>Probe.Page.Panels[1].Overlays[0].ID) and
        (Probe.Page.Panels[0].FilterKind=1) and (Probe.Page.Panels[1].FrameKind=1), 'panel split assigns new second-fragment effect identity and retains filter frame settings');
      Probe.Undo(nil); Check(Project.Snapshot=Before,'split undo restores the complete material and style owner');
      Layout.Capture(Project,Probe.Page); Layout.Apply(Project.Pages[0],Project.Width,Project.Height);
      Check((CurrentPanel.Overlays.Count=0) and (CurrentPanel.FilterKind=0) and (CurrentPanel.FrameKind=0),'common layout templates exclude materials filters and frame decoration');
      Project.Restore(After); Probe.FPanelIndex:=0; Probe.FEffectIndex:=0; Probe.RefreshUI;
      DeleteEffectMaterial(MaterialLibrary,Material,Path); Probe.RefreshEffectMaterials; Probe.FRenderer.ClearCache;
      Check((FindEffectMaterial(MaterialLibrary,ID)=nil) and FileExists(CopyPath),'common material deletion preserves the project-local applied PNG');
      Check(ExportSequence(Project,Probe.FRenderer,False)=1,'effect fixture exports with its applied material snapshot');
      Check(ExportSequence(Project,Probe.FRenderer,False)=0,'unchanged material snapshot reuses cached page PNG');
      PNG.LoadFromFile(CopyPath); PNG.Canvas.Pixels[0,0]:=clGreen; PNG.SaveToFile(CopyPath);
      Check(ExportSequence(Project,Probe.FRenderer,False)=1,'same-path effect PNG byte changes invalidate the page cache');
      Before:=Project.Snapshot; Project.Save; Reloaded:=TComicProject.Create;
      try Reloaded.Load(TPath.Combine(Project.Folder,'Project.json')); Check(Reloaded.Snapshot=Before,'complete material ownership and style data save and reload'); finally Reloaded.Free; end;
      // Undo後は出力状態が未確定へ戻る仕様なので、DPI操作の比較条件も同じ状態に揃える。
      Project.Pages[0].OutputRevision:=-1;
      Manager:=TComicEffectDialog.CreateManager(Self,CopyLibrary,True,Path);
      for PPI in [96,144] do begin
        Probe.Scaled:=True; Probe.ScaleForPPI(PPI); Probe.Scaled:=False; Probe.Width:=MulDiv(940,PPI,96); Probe.Height:=MulDiv(660,PPI,96); Probe.Realign;
        Probe.FEffectCategory.ItemIndex:=0; Probe.EffectCategoryChanged(nil); Probe.FPanelIndex:=0; Probe.FEffectIndex:=0;
        CaptureEffect('effects-material-'+IntToStr(PPI));
        Before:=Project.Snapshot; History:=Probe.FUndo.Count; Bounds:=OverlayBounds(CurrentPanel,CurrentPanel.Overlays[0]); PointA:=Bounds.CenterPoint;
        X:=Probe.FPageRect.Left+Round(PointA.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(PointA.Y*Probe.FScale);
        Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y); Probe.MouseMove(Probe.FCanvas,[ssLeft],X+MulDiv(12,PPI,96),Y+MulDiv(15,PPI,96));
        Probe.MouseUp(Probe.FCanvas,mbLeft,[],X+MulDiv(12,PPI,96),Y+MulDiv(15,PPI,96));
        Check((Probe.FUndo.Count=History+1) and (CurrentPanel.Bounds=OriginalBounds),'effect movement commits one operation at PPI '+IntToStr(PPI));
        Probe.Undo(nil); Check(Project.Snapshot=Before,'effect DPI movement undo '+IntToStr(PPI));
        for K:=1 to 8 do begin
          Probe.FPanelIndex:=0; Probe.FEffectIndex:=0; Bounds:=OverlayBounds(CurrentPanel,CurrentPanel.Overlays[0]); PointA:=EditHandles(Bounds)[K-1];
          X:=Probe.FPageRect.Left+Round(PointA.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(PointA.Y*Probe.FScale);
          Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y); Check(Probe.FDragHandle=K,'effect DPI handle '+IntToStr(K)+' '+IntToStr(PPI));
          Probe.MouseMove(Probe.FCanvas,[ssLeft],X+MulDiv(10,PPI,96),Y+MulDiv(8,PPI,96)); KeyValue:=VK_ESCAPE; Probe.Key(Probe,KeyValue,[]);
          Check(Project.Snapshot=Before,'effect DPI handle cancel '+IntToStr(K)+' '+IntToStr(PPI));
        end;
        Manager.Scaled:=True; Manager.ScaleForPPI(PPI); Manager.Scaled:=False; Manager.ClientWidth:=MulDiv(880,PPI,96); Manager.ClientHeight:=MulDiv(620,PPI,96); Manager.Realign;
        Manager.HandleNeeded; B.SetSize(Manager.ClientWidth,Manager.ClientHeight); Manager.PaintTo(B.Canvas,0,0); PNG.Assign(B); PNG.SaveToFile(TPath.Combine(TestFolder,'effect-library-'+IntToStr(PPI)+'.png'));
        for I:=0 to Manager.ComponentCount-1 do if Manager.Components[I] is TButton then with TButton(Manager.Components[I]) do
          Check((Left>=0) and (Top>=0) and (Left+Width<=Parent.ClientWidth) and (Top+Height<=Parent.ClientHeight),'material manager action is reachable '+Caption+' '+IntToStr(PPI));
      end;
      Check(ExportSequence(Project,Probe.FRenderer,False)=0,'effect DPI undo reuses the unchanged rendered page despite pending output status');
      Check(FProject.Snapshot=Original,'effect fixtures preserve the active project');
    finally Manager.Free; Layout.Free; Broken.Free; CopyLibrary.Free; MaterialLibrary.Free; Pixels.Free; Shifted.Free; Reference.Free; PNG.Free; Probe.Free; end;
  end;

procedure RunEffectChecks(Host: TComicTestForm);
begin Host.EffectChecks; end;
procedure TComicRenderingTestsHelper.BlurScaleChecks;
  var Project: TComicProject; Panel: TComicPanel; Renderer: TComicRenderer; Pattern,Full,Preview,Reduced: TBitmap;
    Asset: TComicAsset; Path: string; X,Y,Size: Integer; Same: Boolean;
  begin
    Project:=TComicProject.Create; Renderer:=TComicRenderer.Create; Pattern:=TBitmap.Create; Full:=TBitmap.Create; Preview:=TBitmap.Create; Reduced:=TBitmap.Create;
    try
      Project.Initialize('ぼかし解像度 fixture','1'); Project.Width:=320; Project.Height:=320;
      Pattern.PixelFormat:=pf24bit; Pattern.SetSize(320,320); Pattern.Canvas.Brush.Color:=clWhite; Pattern.Canvas.FillRect(Rect(0,0,320,320));
      Pattern.Canvas.Brush.Color:=clBlack; Pattern.Canvas.FillRect(Rect(128,0,192,320)); Path:=TPath.Combine(TestFolder,'blur-pattern.bmp'); Pattern.SaveToFile(Path);
      Asset:=Project.ImportImage(Path,''); Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(0,0,320,320); Panel.ImageID:=Asset.ID;
      Panel.BorderWidth:=0; Panel.FilterKind:=3; Panel.FilterStrength:=100; Project.Pages[0].Panels.Add(Panel);
      Full.PixelFormat:=pf24bit; Full.SetSize(320,320); Renderer.Draw(Full.Canvas,Project,Project.Pages[0],Rect(0,0,320,320),False);
      for Size in [80,160,240] do begin
        Preview.PixelFormat:=pf24bit; Preview.SetSize(Size,Size); Reduced.PixelFormat:=pf24bit; Reduced.SetSize(Size,Size);
        Renderer.Draw(Preview.Canvas,Project,Project.Pages[0],Rect(0,0,Size,Size),False); SetStretchBltMode(Reduced.Canvas.Handle,HALFTONE);
        Reduced.Canvas.StretchDraw(Rect(0,0,Size,Size),Full); Same:=True;
        for X:=0 to Size-1 do for Y:=0 to Size-1 do if Preview.Canvas.Pixels[X,Y]<>Reduced.Canvas.Pixels[X,Y] then Same:=False;
        Check(Same,'blur preview exactly matches the downsampled output raster at size '+IntToStr(Size));
      end;
    finally Reduced.Free; Preview.Free; Full.Free; Pattern.Free; Renderer.Free; Project.Free; end;
  end;

procedure RunBlurScaleChecks(Host: TComicTestForm);
begin Host.BlurScaleChecks; end;
procedure TComicRenderingTestsHelper.BulkDataChecks;
  var Project,Reloaded: TComicProject; Page: TComicPage; Panel: TComicPanel; Balloon: TComicBalloon; Renderer: TComicRenderer;
    Metrics: TStringList; Bitmap: TBitmap; ImageID,Text,Snapshot,Path: string; I,K,Rendered: Integer; Started: UInt64; Basis: TComicPageBasis;
  begin
    Project:=TComicProject.Create; Reloaded:=TComicProject.Create; Renderer:=TComicRenderer.Create; Metrics:=TStringList.Create; Bitmap:=TBitmap.Create;
    try
      Project.Initialize('大量データ fixture','1'); Project.Pages.Clear; Basis:=Project.PageBasis;
      Basis.Width:=240; Basis.Height:=360; Basis.Left:=10; Basis.Right:=10; Basis.Top:=10; Basis.Bottom:=10; Project.SetPageBasis(Basis);
      ImageID:=Project.ImportImage(TPath.Combine(TestFolder,'reference.bmp'),'').ID;
      Text:='大量ページ・文字・画像参照の検証。';
      for I:=0 to 79 do begin
        Page:=TComicPage.Create; Project.Pages.Add(Page);
        for K:=0 to 5 do begin
          Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(10+(K mod 2)*112,10+(K div 2)*114,110+(K mod 2)*112,112+(K div 2)*114);
          Panel.ImageID:=ImageID; Panel.Number:=K+1; Panel.FilterKind:=(I+K) mod 3; Page.Panels.Add(Panel);
          Balloon:=TComicBalloon.Create; Balloon.PanelID:=Panel.ID; Balloon.Bounds:=Panel.Bounds; Balloon.Text:=Text+Text+Text+IntToStr(I);
          Balloon.FontSize:=8; Balloon.Vertical:=(I+K) mod 2=0; Balloon.Overflow:=False; Page.Balloons.Add(Balloon);
        end;
      end;
      Started:=GetTickCount64; Project.Save; Snapshot:=Project.Snapshot; Metrics.Add('save_80_pages_480_panels_ms='+UIntToStr(GetTickCount64-Started));
      Started:=GetTickCount64; Reloaded.Load(TPath.Combine(Project.Folder,'Project.json')); Metrics.Add('reload_80_pages_ms='+UIntToStr(GetTickCount64-Started));
      Check((Reloaded.Pages.Count=80) and (Reloaded.Pages[79].Panels.Count=6) and (Reloaded.Snapshot=Snapshot),
        'eighty pages with four hundred eighty panels and balloons save and reload exact Unicode data');
      Started:=GetTickCount64; Rendered:=ExportSequence(Project,Renderer,False); Metrics.Add('export_80_small_pages_ms='+UIntToStr(GetTickCount64-Started));
      Check(Rendered=80,'large page sequence exports every page'); Started:=GetTickCount64;
      Check(ExportSequence(Project,Renderer,False)=0,'large unchanged sequence reuses every cached PNG'); Metrics.Add('unchanged_export_80_pages_ms='+UIntToStr(GetTickCount64-Started));
      Project.Pages[40].Panels[0].PanX:=12; Check(ExportSequence(Project,Renderer,False)=1,'one changed panel redraws only its page in a large sequence');
      Project.Pages[0].Panels[0].Bounds:=TRectF.Create(-20000,-20000,50000,50000); Project.Pages[0].Panels[0].FilterKind:=3;
      Bitmap.PixelFormat:=pf24bit; Bitmap.SetSize(240,360); Started:=GetTickCount64;
      Renderer.Draw(Bitmap.Canvas,Project,Project.Pages[0],Rect(0,0,240,360),False);
      Check(Bitmap.Canvas.Pixels[120,300]<>clWhite,'huge off-page blurred panel renders through page-bounded scratch raster');
      Metrics.Add('huge_panel_bounded_render_ms='+UIntToStr(GetTickCount64-Started));
      Project.Pages[0].Balloons[0].Text:=StringOfChar('漢',6000); Project.Pages[0].Balloons[0].FontSize:=16;
      for K:=0 to 1 do begin
        Project.Pages[0].Balloons[0].Vertical:=K=1; Started:=GetTickCount64; Renderer.Draw(Bitmap.Canvas,Project,Project.Pages[0],Rect(0,0,240,360),False);
        Metrics.Add('render_6000_chars_'+IntToStr(K)+'_ms='+UIntToStr(GetTickCount64-Started));
        Check(Length(Project.Pages[0].Balloons[0].Text)=6000,'long horizontal or vertical render preserves its complete text '+IntToStr(K));
      end;
      Project.Pages.Clear; Basis.Width:=1200; Basis.Height:=1700; Basis.Left:=60; Basis.Right:=60; Basis.Top:=60; Basis.Bottom:=60; Project.SetPageBasis(Basis);
      Bitmap.SetSize(2400,3200); Bitmap.Canvas.Brush.Color:=clWhite; Bitmap.Canvas.FillRect(Rect(0,0,2400,3200));
      Bitmap.Canvas.Brush.Color:=clBlue; Bitmap.Canvas.Ellipse(300,400,2100,2800); Path:=TPath.Combine(TestFolder,'large-reference.bmp'); Bitmap.SaveToFile(Path);
      ImageID:=Project.ImportImage(Path,'').ID;
      for I:=0 to 5 do begin
        Page:=TComicPage.Create; Project.Pages.Add(Page);
        for K:=0 to 1 do begin
          Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(60,60+K*800,1140,820+K*800); Panel.ImageID:=ImageID;
          Panel.FilterKind:=3; Panel.FilterStrength:=75; Page.Panels.Add(Panel);
          Balloon:=TComicBalloon.Create; Balloon.PanelID:=Panel.ID; Balloon.Bounds:=TRectF.Create(220,160+K*800,620,560+K*800);
          Balloon.Text:=Text+Text+IntToStr(I); Balloon.Vertical:=K=1; Balloon.FontSize:=32; Page.Balloons.Add(Balloon);
        end;
      end;
      Started:=GetTickCount64; Project.Save; Reloaded.Load(TPath.Combine(Project.Folder,'Project.json'));
      Check(Reloaded.Snapshot=Project.Snapshot,'normal-resolution project with a large shared image saves and reloads');
      Metrics.Add('normal_6_pages_save_reload_ms='+UIntToStr(GetTickCount64-Started)); Started:=GetTickCount64;
      Check(ExportSequence(Project,Renderer,False)=6,'six normal 1200x1700 pages with 2400x3200 image and blur export successfully');
      Metrics.Add('normal_6_pages_large_image_export_ms='+UIntToStr(GetTickCount64-Started));
      Check(ExportSequence(Project,Renderer,False)=0,'normal-resolution large-image sequence reuses every cached page');
      Metrics.SaveToFile(TPath.Combine(TestFolder,'performance.txt'),TEncoding.UTF8);
    finally Bitmap.Free; Metrics.Free; Renderer.Free; Reloaded.Free; Project.Free; end;
  end;

procedure RunBulkDataChecks(Host: TComicTestForm);
begin Host.BulkDataChecks; end;
end.
