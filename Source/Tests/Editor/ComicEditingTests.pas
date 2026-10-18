unit ComicEditingTests;

// 責務：ドラッグ・複数選択・取消の回帰を検証し、1操作Undoと作品状態の保持を確認する。
interface
uses ComicTestSupport;
procedure RunEditingChecks(Host: TComicTestForm);
procedure RunCreatedPanelSelectionChecks(Host: TComicTestForm);
procedure RunPanelGroupChecks(Host: TComicTestForm);
procedure RunDragCommandChecks(Host: TComicTestForm);
implementation
uses Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, Winapi.Imm,
  System.SysUtils, System.Classes, System.Types, System.UITypes,
  System.Math, System.IOUtils, System.Generics.Collections, System.JSON,
  System.Hash, System.DateUtils, Vcl.Controls, Vcl.Forms,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Menus,
  Vcl.Dialogs, Vcl.Graphics, Vcl.Imaging.pngimage, ComicModel,
  ComicEditing, ComicIconButton, ComicGeometry, ComicPanelTransform,
  ComicEffects, ComicExportDialog;
type
  TComicEditingTestsHelper = class helper for TComicTestForm
    procedure EditingChecks;
    procedure CreatedPanelSelectionChecks;
    procedure PanelGroupChecks;
    procedure DragCommandChecks;
  end;
procedure TComicEditingTestsHelper.EditingChecks;
  var Original,AfterResize,ImageRect,Scaled: TRectF; Handles: TArray<TPointF>;
    K,X,Y,UndoCount,Revision: Integer; Before,ID: string; KeyValue: Word;
    OldZoom,OldPanX,OldPanY,TailRatioX,TailRatioY: Double;
  begin
    FTabs.ActivePageIndex:=1; TabChanged(nil); FPanelIndex:=0;
    Capture('window-panel-handles'); Original:=Page.Panels[0].Bounds;
    Before:=FProject.Snapshot; UndoCount:=FUndo.Count; Revision:=Page.Revision;
    X:=FPageRect.Left+Round((Original.Left+Original.Right)/2*FScale);
    Y:=FPageRect.Top+Round((Original.Top+Original.Bottom)/2*FScale);
    MouseDown(FCanvas,mbLeft,[],X,Y); MouseUp(FCanvas,mbLeft,[],X,Y);
    Check((FProject.Snapshot=Before) and (FUndo.Count=UndoCount) and (Page.Revision=Revision),
      'selection without dragging does not create an edit');
    for K:=1 to 8 do begin
      FPanelIndex:=0; Handles:=EditHandles(Page.Panels[0].Bounds);
      X:=FPageRect.Left+Round(Handles[K-1].X*FScale); Y:=FPageRect.Top+Round(Handles[K-1].Y*FScale);
      MouseDown(FCanvas,mbLeft,[],X,Y); Check(FDragHandle=K,'panel handle '+IntToStr(K)+' can be selected');
      MouseMove(FCanvas,[ssLeft],X+20,Y+20); MouseUp(FCanvas,mbLeft,[],X+20,Y+20);
      AfterResize:=Page.Panels[0].Bounds;
      Check((AfterResize.Width>=30) and (AfterResize.Height>=30) and (AfterResize<>Original),
        'panel handle '+IntToStr(K)+' resizes valid bounds');
      Undo(nil); Check(Page.Panels[0].Bounds=Original,'panel handle '+IntToStr(K)+' undo restores bounds');
    end;
    Scaled:=ResizeRect(Original,TPointF.Create(100000,100000),1,30);
    Check((Scaled.Width=30) and (Scaled.Height=30),'panel resize cannot invert geometry');
    FPanelIndex:=0; Before:=FProject.Snapshot; UndoCount:=FUndo.Count;
    Handles:=EditHandles(Original); X:=FPageRect.Left+Round(Handles[4].X*FScale); Y:=FPageRect.Top+Round(Handles[4].Y*FScale);
    MouseDown(FCanvas,mbLeft,[],X,Y); MouseMove(FCanvas,[ssLeft],X+25,Y+25);
    KeyValue:=VK_ESCAPE; Key(Self,KeyValue,[]);
    Check((FProject.Snapshot=Before) and (FUndo.Count=UndoCount) and not FDragging,
      'Esc cancels in-progress drag without changing undo history');
    Page.Panels[0].Shape:=1;
    Check((HitPanel(TPointF.Create(Original.Left+2,Original.Top+2))=-1) and
      (HitPanel(TPointF.Create((Original.Left+Original.Right)/2,(Original.Top+Original.Bottom)/2))=0),
      'ellipse hit test follows actual shape');
    Page.Panels[0].Shape:=2;
    Check(HitPanel(TPointF.Create(Original.Left+1,Original.Top+1))=-1,'rounded panel excludes outside corners');
    Page.Panels[0].Shape:=0;
    FTabs.ActivePageIndex:=2; TabChanged(nil); FPanelIndex:=0;
    ImageRect:=FRenderer.ImageBounds(FProject,Page.Panels[0]);
    OldZoom:=Page.Panels[0].Zoom; OldPanX:=Page.Panels[0].PanX; OldPanY:=Page.Panels[0].PanY;
    for K:=1 to 8 do begin
      Scaled:=ResizeImageRect(ImageRect,TPointF.Create(60,40),K,0.1);
      Check(Abs(Scaled.Width/Scaled.Height-ImageRect.Width/ImageRect.Height)<0.0001,
        'image handle '+IntToStr(K)+' preserves aspect ratio');
    end;
    FPanelIndex:=0; Capture('window-image-handles');
    Handles:=EditHandles(ImageRect); X:=FPageRect.Left+Round(Handles[5].X*FScale); Y:=FPageRect.Top+Round(Handles[5].Y*FScale);
    MouseDown(FCanvas,mbLeft,[],X,Y); Check(FDragHandle=6,'image edge handle selects beyond the panel');
    MouseMove(FCanvas,[ssLeft],X,Y+30); MouseUp(FCanvas,mbLeft,[],X,Y+30);
    Check((Page.Panels[0].Bounds=Original) and (Page.Panels[0].Zoom>OldZoom),'image resize changes zoom while keeping panel geometry');
    Undo(nil); Check((Abs(Page.Panels[0].Zoom-OldZoom)<0.0001) and (Page.Panels[0].PanX=OldPanX) and
      (Page.Panels[0].PanY=OldPanY),'image resize undo restores zoom and position together');
    FPanelIndex:=0; X:=FPageRect.Left+Round((Original.Left+Original.Right)/2*FScale);
    Y:=FPageRect.Top+Round((Original.Top+Original.Bottom)/2*FScale);
    MouseDown(FCanvas,mbLeft,[],X,Y); MouseMove(FCanvas,[ssLeft],X+25,Y+10); MouseUp(FCanvas,mbLeft,[],X+25,Y+10);
    Check((Page.Panels[0].Bounds=Original) and (Page.Panels[0].PanX>OldPanX) and
      (Page.Panels[0].PanY>OldPanY),'image drag pans without moving the panel'); Undo(nil);
    FTabs.ActivePageIndex:=3; TabChanged(nil); FBalloonIndex:=0; FPanelIndex:=0;
    Original:=Page.Balloons[0].Bounds; ID:=Page.Balloons[0].PanelID;
    TailRatioX:=(Page.Balloons[0].TailX-Original.Left)/Original.Width;
    TailRatioY:=(Page.Balloons[0].TailY-Original.Top)/Original.Height;
    Capture('window-balloon-handles'); Handles:=EditHandles(Original);
    X:=FPageRect.Left+Round(Handles[4].X*FScale); Y:=FPageRect.Top+Round(Handles[4].Y*FScale);
    MouseDown(FCanvas,mbLeft,[],X,Y); MouseMove(FCanvas,[ssLeft],X+20,Y+30); MouseUp(FCanvas,mbLeft,[],X+20,Y+30);
    AfterResize:=Page.Balloons[0].Bounds;
    Check((Page.Balloons[0].PanelID=ID) and
      (Abs((Page.Balloons[0].TailX-AfterResize.Left)/AfterResize.Width-TailRatioX)<0.0001) and
      (Abs((Page.Balloons[0].TailY-AfterResize.Top)/AfterResize.Height-TailRatioY)<0.0001) and
      (Page.Balloons[0].Text='漫画を作ろう！'),'balloon resize keeps tail and text attached');
    Undo(nil); Check(Page.Balloons[0].Bounds=Original,'balloon resize undo');
    FBalloonIndex:=0; FTool:=5; EditBalloonText(nil);
    Check(FTool=5,'double click cannot interrupt balloon creation');
    FTool:=0; EditBalloonText(nil);
    Check(InlineTextActive and (FInlineText.Text=Page.Balloons[0].Text),'double click reopens selected balloon text on the canvas');
    FinishInlineText(False); FTool:=0;
    X:=FPageRect.Left+Round((Original.Left+Original.Right)/2*FScale);
    Y:=FPageRect.Top+Round((Original.Top+Original.Bottom)/2*FScale);
    FCanvas.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(X,Y));
    Check(ActiveControl=FView,'normal canvas MouseDown transfers focus through shared production path');
    FCanvas.Perform(WM_LBUTTONUP,0,MakeLParam(X,Y));
    FCanvas.Perform(WM_LBUTTONDBLCLK,MK_LBUTTON,MakeLParam(X,Y));
    FCanvas.Perform(WM_LBUTTONUP,0,MakeLParam(X,Y));
    Check(InlineTextActive and not FDragging and (FInlineText.Input.ImeMode=imOpen),
      'real VCL double-click then ssDouble MouseDown preserves inline input session');
    FinishInlineText(False);
    ActiveControl:=FText; KeyValue:=VK_ESCAPE; Key(Self,KeyValue,[]);
    Check(KeyValue=VK_ESCAPE,'IME editor keeps its own Esc handling'); ActiveControl:=nil;
    FTabs.ActivePageIndex:=0; TabChanged(nil);
  end;

procedure RunEditingChecks(Host: TComicTestForm);
begin Host.EditingChecks; end;
procedure TComicEditingTestsHelper.CreatedPanelSelectionChecks;
  var Probe: TComicTestForm; Project,Reloaded: TComicProject; Panel: TComicPanel; Initial,Before,AID,BID,DID,CID: string;
    X,Y,Kind: Integer;
    procedure Tool(Tag: Integer);
    var Button: TComicIconButton;
    begin
      for Button in Probe.FIconButtons do if (Button.Role=brTool) and (Button.Context=1) and (Button.Tag=Tag) then begin Button.Click; Exit; end;
    end;
    procedure Click(PX,PY: Integer; Ctrl: Boolean=False);
    var Flags: Integer;
    begin
      X:=Probe.FPageRect.Left+Round(PX*Probe.FScale); Y:=Probe.FPageRect.Top+Round(PY*Probe.FScale);
      Flags:=MK_LBUTTON; if Ctrl then Flags:=Flags or MK_CONTROL;
      Probe.FCanvas.Perform(WM_LBUTTONDOWN,Flags,MakeLParam(X,Y)); Probe.FCanvas.Perform(WM_LBUTTONUP,0,MakeLParam(X,Y));
    end;
  begin
    Probe:=TComicTestForm.Create(nil); Probe.FDragPlacementMenu.Checked:=False;
    try
      Project:=CreateFixtureProject; Project.Initialize('新規コマ選択 fixture','1'); Probe.AdoptProject(Project,False);
      Project.ImportImage(TPath.Combine(TestFolder,'reference.bmp'),'');
      Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(100,100,300,300); AID:=Panel.ID; Probe.Page.Panels.Add(Panel);
      Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(400,100,600,300); BID:=Panel.ID; Probe.Page.Panels.Add(Panel);
      Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(100,600,300,800); DID:=Panel.ID; Probe.Page.Panels.Add(Panel);
      Initial:=Project.Snapshot; Probe.RefreshUI; Probe.FTabs.ActivePageIndex:=1; Probe.TabChanged(nil);
      for Kind in [1,8] do begin
        Project.Restore(Initial); Probe.FUndo.Clear; Probe.FRedo.Clear; Probe.FSelectedPanels.Clear; Probe.FPanelIndex:=-1;
        Probe.RefreshUI; Probe.HandleNeeded; B.SetSize(Probe.ClientWidth,Probe.ClientHeight); Probe.PaintTo(B.Canvas,0,0);
        Tool(0); Click(200,200); Click(500,200,True);
        Check(Length(Probe.SelectedPanelIDs)=2,'creation fixture starts with a real two-panel selection '+IntToStr(Kind));
        Tool(Kind); Click(650,600);
        if Kind=1 then Click(850,800) else begin Click(850,600); Click(850,800); Click(650,600); end;
        Check(Probe.Page.Panels.Count=4,'creation fixture creates the new rectangle or polygon '+IntToStr(Kind));
        CID:=Probe.Page.Panels[3].ID;
        Check((Length(Probe.SelectedPanelIDs)=1) and (Probe.SelectedPanelIDs[0]=CID) and
          (Probe.FSelectedPanels.Count=1) and Probe.FSelectedPanels.Contains(CID),
          'newly created panel replaces both primary and UID selection '+IntToStr(Kind));
        Tool(0); Click(200,700,True);
        Check((Length(Probe.SelectedPanelIDs)=2) and Probe.FSelectedPanels.Contains(CID) and Probe.FSelectedPanels.Contains(DID) and
          not Probe.FSelectedPanels.Contains(AID) and not Probe.FSelectedPanels.Contains(BID),
          'control click after creation adds only the new panel and requested existing panel '+IntToStr(Kind));
        Before:=Project.Snapshot; Probe.DeleteObject(nil);
        Check((Probe.Page.Panels.Count=2) and (Probe.Page.Panels[0].ID=AID) and (Probe.Page.Panels[1].ID=BID),
          'delete after creation cannot remove a stale previous group '+IntToStr(Kind));
        Probe.Undo(nil); Check(Project.Snapshot=Before,'undo restores only the correctly deleted new selection '+IntToStr(Kind));
        Project.Save; Reloaded:=CreateFixtureProject;
        try Reloaded.Load(TPath.Combine(Project.Folder,'Project.json')); Check(Reloaded.Snapshot=Before,'creation selection regression saves and reloads '+IntToStr(Kind));
        finally Reloaded.Free; end;
      end;
    finally Probe.Free; end;
  end;

procedure RunCreatedPanelSelectionChecks(Host: TComicTestForm);
begin Host.CreatedPanelSelectionChecks; end;
procedure TComicEditingTestsHelper.PanelGroupChecks;
  var Probe: TComicTestForm; Project,Reloaded: TComicProject; Panel: TComicPanel; Balloon: TComicBalloon;
    IDs: TArray<string>; Items: TArray<TComicPanelTransform>; Original,Target,OtherBounds: TRectF;
    Before,BaseModel,FirstID,SecondID,ThirdID,ImageID: string; KeyValue: Word; K,X,Y,PPI,History: Integer;
    PNG: TPngImage; Point: TPointF;
    procedure CaptureGroup(const Name: string);
    begin
      Probe.HandleNeeded; B.SetSize(Probe.ClientWidth,Probe.ClientHeight); Probe.PaintTo(B.Canvas,0,0);
      PNG.Assign(B); PNG.SaveToFile(TPath.Combine(TestFolder,Name+'.png'));
    end;
    procedure ClickPanel(Index: Integer; Ctrl: Boolean=False);
    var Center: TPointF; Flags: Integer;
    begin
      Center:=Probe.Page.Panels[Index].Bounds.CenterPoint;
      // 三角形の外接中心は斜辺上となるため、DPIに関係なく内部と判定できる位置を選ぶ。
      if Index=1 then Center.Y:=Probe.Page.Panels[Index].Bounds.Top+Probe.Page.Panels[Index].Bounds.Height/3;
      X:=Probe.FPageRect.Left+Round(Center.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(Center.Y*Probe.FScale);
      Flags:=MK_LBUTTON; if Ctrl then Flags:=Flags or MK_CONTROL;
      Probe.FCanvas.Perform(WM_LBUTTONDOWN,Flags,MakeLParam(X,Y)); Probe.FCanvas.Perform(WM_LBUTTONUP,0,MakeLParam(X,Y));
    end;
    procedure SelectPair;
    begin
      X:=Probe.FPageRect.Left+Round(1100*Probe.FScale); Y:=Probe.FPageRect.Top+Round(1600*Probe.FScale);
      Probe.FCanvas.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(X,Y)); Probe.FCanvas.Perform(WM_LBUTTONUP,0,MakeLParam(X,Y));
      ClickPanel(0); ClickPanel(1,True);
    end;
  begin
    Probe:=TComicTestForm.Create(nil); PNG:=TPngImage.Create;
    try
      Project:=CreateFixtureProject; Project.Initialize('複数コマ fixture','1'); Probe.AdoptProject(Project,False);
      ImageID:=Project.ImportImage(TPath.Combine(TestFolder,'reference.bmp'),'').ID;
      Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(100,100,500,500); Panel.ImageID:=ImageID; Panel.PanX:=20; Panel.PanY:=10;
      FirstID:=Panel.ID; Probe.Page.Panels.Add(Panel);
      Panel:=TComicPanel.Create; Panel.SetVertices([TPointF.Create(650,150),TPointF.Create(1000,150),TPointF.Create(900,550)]);
      Panel.ImageID:=ImageID; SecondID:=Panel.ID; Probe.Page.Panels.Add(Panel);
      Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(100,800,500,1200); Panel.Shape:=1; ThirdID:=Panel.ID;
      Probe.Page.Panels.Add(Panel); OtherBounds:=Panel.Bounds;
      Balloon:=TComicBalloon.Create; Balloon.PanelID:=FirstID; Balloon.Text:='選択側'; Probe.Page.Balloons.Add(Balloon);
      Balloon:=TComicBalloon.Create; Balloon.PanelID:=ThirdID; Balloon.Text:='保持側'; Probe.Page.Balloons.Add(Balloon);
      Probe.RefreshUI; Probe.FTabs.ActivePageIndex:=1; Probe.TabChanged(nil); Before:=Project.Snapshot; BaseModel:=Before; History:=Probe.FUndo.Count;
      CaptureGroup('panel-group-initial'); SelectPair;
      Check((Length(Probe.SelectedPanelIDs)=2) and (Project.Snapshot=Before) and (Probe.FUndo.Count=History),
        'real control-clicks select two panels without changing project or history');
      ClickPanel(1,True); Check(Length(Probe.SelectedPanelIDs)=1,'control-click toggles a selected panel off'); ClickPanel(1,True);
      Original:=Probe.SelectedPanelBounds; CaptureGroup('panel-group-selected');
      Check((Original.Left=100) and (Original.Top=100) and (Original.Right=1000) and (Original.Bottom=550),
        'multiple panels expose one combined outer selection rectangle');
      for K:=1 to 8 do begin
        if K>1 then SelectPair;
        Original:=Probe.SelectedPanelBounds; Point:=EditHandles(Original)[K-1];
        X:=Probe.FPageRect.Left+Round(Point.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(Point.Y*Probe.FScale);
        Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y);
        Check((Probe.FDragHandle=K) and (Length(Probe.FDragGroup)=2) and (Probe.FDragVertex=-1),
          'group outer handle '+IntToStr(K)+' starts a shared transform');
        Probe.MouseMove(Probe.FCanvas,[ssLeft],X+18,Y+11); Probe.MouseUp(Probe.FCanvas,mbLeft,[],X+18,Y+11);
        Check((Probe.Page.Panels[2].Bounds=OtherBounds) and (Probe.Page.Panels[0].ID=FirstID) and
          (Probe.Page.Panels[1].ID=SecondID) and ValidPolygon(Probe.Page.Panels[1].Vertices) and
          (Probe.Page.Panels[0].ImageID=ImageID), 'group handle '+IntToStr(K)+' keeps identities images and unselected geometry');
        Probe.Undo(nil); Check(Project.Snapshot=Before,'group handle '+IntToStr(K)+' undoes all members as one edit');
      end;
      SelectPair; Original:=Probe.SelectedPanelBounds; Point:=Original.CenterPoint;
      X:=Probe.FPageRect.Left+Round(Point.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(Point.Y*Probe.FScale);
      Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y); Check(Length(Probe.FDragGroup)=2,'dragging the gap inside a group starts a whole-selection move');
      Probe.MouseMove(Probe.FCanvas,[ssLeft],X+25,Y+18); KeyValue:=VK_ESCAPE; Probe.Key(Probe,KeyValue,[]);
      Check((Project.Snapshot=Before) and (Probe.FUndo.Count=0) and not Probe.FDragging,
        'escape cancels every group member without leaving history or partial geometry');
      SelectPair; IDs:=Probe.SelectedPanelIDs; Items:=CapturePanelTransforms(Probe.Page,IDs); Original:=PanelGroupBounds(Items);
      Target:=TRectF.Create(Original.Left+20,Original.Top+30,Original.Left+20+Original.Width*1.4,Original.Top+30+Original.Height*0.8);
      Check(ApplyPanelGroupTransform(Probe.Page,Items,Original,Target),'group model accepts independent horizontal and vertical scaling');
      Check((Abs(Probe.Page.Panels[0].Bounds.Width-560)<0.001) and (Abs(Probe.Page.Panels[0].Bounds.Height-320)<0.001) and
        (Abs(Probe.Page.Panels[0].PanX-28)<0.001) and (Abs(Probe.Page.Panels[0].PanY-8)<0.001),
        'group proportions scale panel sizes spacing and relative image pan independently');
      Check((Items[0].Bounds.Width=400) and (Items[1].Vertices[0].X=650),'group source transforms own stable original geometry for repeated drag updates');
      Project.Save; Reloaded:=CreateFixtureProject;
      try Reloaded.Load(TPath.Combine(Project.Folder,'Project.json')); Check(Reloaded.Snapshot=Project.Snapshot,'mixed-shape group transforms survive save and reload');
      finally Reloaded.Free; end;
      Project.Restore(Before); Probe.RefreshUI; SelectPair;
      Probe.DeleteObject(nil); Check((Probe.Page.Panels.Count=1) and (Probe.Page.Panels[0].ID=ThirdID) and
        (Probe.Page.Balloons.Count=1) and (Probe.Page.Balloons[0].Text='保持側') and (Project.Assets.Count=1),
        'group deletion removes selected owners and their balloons while retaining other content and source images');
      Probe.Undo(nil); Check(Project.Snapshot=Before,'one undo restores deleted panel group and owned balloons');
      Probe.ActiveControl:=Probe.FView; KeyValue:=Ord('A'); Probe.Key(Probe,KeyValue,[ssCtrl]);
      Check(Length(Probe.SelectedPanelIDs)=3,'control A in the panel canvas selects every panel');
      KeyValue:=VK_DELETE; Probe.Key(Probe,KeyValue,[]);
      Check((Probe.Page.Panels.Count=0) and (Probe.Page.Balloons.Count=0) and (Project.Assets.Count=1),
        'delete key removes the whole canvas selection as one edit'); Probe.Undo(nil);
      Probe.Page.Panels[1].SetVertices([TPointF.Create(650,150),TPointF.Create(1000,550),TPointF.Create(998,550)]);
      IDs:=[FirstID,SecondID]; Items:=CapturePanelTransforms(Probe.Page,IDs); Original:=PanelGroupBounds(Items); Before:=Project.Snapshot;
      Target:=TRectF.Create(Original.Left,Original.Top,Original.Left+Original.Width/100,Original.Top+Original.Height/100);
      Check(not ApplyPanelGroupTransform(Probe.Page,Items,Original,Target) and (Project.Snapshot=Before),
        'one invalid thin member rejects the entire group transform atomically');
      Project.Restore(BaseModel); Before:=BaseModel; Probe.RefreshUI;
      for PPI in [96,144] do begin
        Probe.Scaled:=True; Probe.ScaleForPPI(PPI); Probe.Scaled:=False;
        Probe.Width:=MulDiv(940,PPI,96); Probe.Height:=MulDiv(660,PPI,96); Probe.Realign;
        Probe.FSelectedPanels.Clear; Probe.FPanelIndex:=-1; CaptureGroup('panel-group-dpi'+IntToStr(PPI)+'-before');
        SelectPair; Check(Length(Probe.SelectedPanelIDs)=2,'group selection uses VCL control-clicks at PPI '+IntToStr(PPI));
        Original:=Probe.SelectedPanelBounds; Point:=EditHandles(Original)[4];
        X:=Probe.FPageRect.Left+Round(Point.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(Point.Y*Probe.FScale);
        History:=Probe.FUndo.Count; Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y);
        Probe.MouseMove(Probe.FCanvas,[ssLeft],X+MulDiv(12,PPI,96),Y+MulDiv(20,PPI,96));
        Probe.MouseUp(Probe.FCanvas,mbLeft,[],X+MulDiv(12,PPI,96),Y+MulDiv(20,PPI,96));
        Check((Probe.FUndo.Count=History+1) and ValidPolygon(Probe.Page.Panels[1].Vertices),
          'group resize remains valid and commits once at PPI '+IntToStr(PPI));
        CaptureGroup('panel-group-dpi'+IntToStr(PPI)+'-after'); Probe.Undo(nil);
        Check(Project.Snapshot=Before,'group DPI resize restores all original members on undo '+IntToStr(PPI));
      end;
    finally PNG.Free; Probe.Free; end;
  end;

procedure RunPanelGroupChecks(Host: TComicTestForm);
begin Host.PanelGroupChecks; end;
procedure TComicEditingTestsHelper.DragCommandChecks;
  var Probe: TComicTestForm; Project: TComicProject; Panel: TComicPanel; Base,Before,Original,After: string;
    Bounds: TRectF; P: TPointF; X,Y,K,History,I,PPI: Integer; KeyValue: Word; ExportDialog: TComicExportDialog; All: Boolean;
    procedure StartDrag;
    begin
      Probe.FTabs.ActivePageIndex:=4; Probe.FEffectCategory.ItemIndex:=0; Probe.FEffectPages.ActivePageIndex:=0;
      Probe.FPanelIndex:=0; Probe.FEffectIndex:=0; Probe.RefreshUI; Probe.HandleNeeded;
      B.SetSize(Probe.ClientWidth,Probe.ClientHeight); Probe.PaintTo(B.Canvas,0,0);
      Bounds:=OverlayBounds(Probe.Page.Panels[0],Probe.Page.Panels[0].Overlays[0]); P:=Bounds.CenterPoint;
      X:=Probe.FPageRect.Left+Round(P.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(P.Y*Probe.FScale);
      Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y); Probe.MouseMove(Probe.FCanvas,[ssLeft],X+12,Y+10);
      Check(Probe.FDragging and (Project.Snapshot<>Base),'command fixture starts a moved uncommitted material');
    end;
  begin
    Original:=FProject.Snapshot; Probe:=TComicTestForm.Create(nil);
    try
      Project:=CreateFixtureProject; Project.Initialize('ドラッグ中コマンド fixture','1'); Probe.AdoptProject(Project,False);
      Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(100,100,550,1200); Panel.ImageID:=Project.ImportImage(TPath.Combine(TestFolder,'reference.bmp'),'').ID; Probe.Page.Panels.Add(Panel);
      Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(650,100,1100,1200); Probe.Page.Panels.Add(Panel); Project.Pages.Add(TComicPage.Create);
      Probe.ApplyEffectMaterial(0,Probe.FEffectMaterials[0]); Base:=Project.Snapshot;
      for K:=0 to 5 do begin
        Project.Restore(Base); Probe.FUndo.Clear; Probe.FRedo.Clear; Probe.FPageIndex:=0; StartDrag;
        case K of
          0: begin KeyValue:=VK_DELETE; Probe.ActiveControl:=Probe.FView; Probe.Key(Probe,KeyValue,[]);
            Check(Probe.Page.Panels[0].Overlays.Count=0,'delete during material dragging resolves the restored owner before deletion'); end;
          1: begin Probe.FPanelIndex:=1; Probe.FFilterKind.ItemIndex:=2; Probe.FFilterStrength.ItemIndex:=3; Probe.ApplyFilter(nil);
            Check((Probe.Page.Panels[1].FilterKind=2) and (OverlayBounds(Probe.Page.Panels[0],Probe.Page.Panels[0].Overlays[0])=Bounds),
              'filter on another panel cancels the material drag and uses the current target'); end;
          2: begin Probe.FPanelIndex:=1; Probe.FFrameKind.ItemIndex:=1; Probe.FPanelBorderWidth.ItemIndex:=3; Probe.ApplyFrame(nil);
            Check(Probe.Page.Panels[1].FrameKind=1,'frame command during material drag resolves its restored target'); end;
          3: begin Probe.FPanelIndex:=0; Probe.DetachImage(nil); Check(Probe.Page.Panels[0].ImageID='','image detach during material dragging does not use a freed panel'); end;
          4: begin Probe.FTabs.ActivePageIndex:=1; Probe.SelectSinglePanel(0); Probe.DeleteObject(nil); Check(Probe.Page.Panels.Count=1,'panel delete during dragging removes its restored owner'); end;
          5: begin Probe.FPages.ClearSelection; Probe.FPages.Selected[0]:=True;
            Probe.PagesDragDrop(Probe.FPages,Probe.FPages,8,Probe.FPages.ItemRect(1).Bottom-1);
            Check((Probe.FPageIndex=1) and (Project.Pages[1].Panels.Count=2),'page reorder during dragging resolves fresh page objects'); end;
        end;
        Check(not Probe.FDragging and (Probe.FUndo.Count=1),'command cancels pending material edit and commits once '+IntToStr(K));
        Probe.Undo(nil); Check(Project.Snapshot=Base,'command undo restores unmodified original material and project '+IntToStr(K));
      end;
      Project.Restore(Base); Probe.FUndo.Clear; Probe.FRedo.Clear; Probe.FPageIndex:=0; Probe.Checkpoint;
      Probe.Page.Panels[0].BorderWidth:=6; Probe.Changed; Before:=Project.Snapshot; StartDrag; Probe.Undo(nil);
      Check((Project.Snapshot=Base) and not Probe.FDragging,'undo during dragging cancels the drag then undoes the previous committed operation');
      StartDrag; Probe.Redo(nil); Check((Project.Snapshot=Before) and not Probe.FDragging,'redo during dragging cancels it before restoring committed data');
      for PPI in [96,144] do begin
        Probe.Scaled:=True; Probe.ScaleForPPI(PPI); Probe.Scaled:=False; Probe.Width:=MulDiv(940,PPI,96); Probe.Height:=MulDiv(660,PPI,96); Probe.Realign;
        Before:=Project.Snapshot; History:=Probe.FUndo.Count; StartDrag; ExportDialog:=Probe.CreateExportOptions;
        try
          ExportDialog.ModalResult:=mrCancel;
          Check(not ExportDialog.Accepted(All) and not All and not Probe.FDragging and (Project.Snapshot=Before) and (Probe.FUndo.Count=History),
            'export dialog cancellation after dragging preserves exact committed data '+IntToStr(PPI));
          ExportDialog.HandleNeeded; ExportDialog.Scaled:=True; ExportDialog.ScaleForPPI(PPI); ExportDialog.Scaled:=False;
          ExportDialog.ClientWidth:=MulDiv(600,PPI,96); if ExportDialog.WarningText='' then ExportDialog.ClientHeight:=MulDiv(246,PPI,96) else ExportDialog.ClientHeight:=MulDiv(340,PPI,96); ExportDialog.Realign;
          ExportDialog.HandleNeeded; B.SetSize(ExportDialog.ClientWidth,ExportDialog.ClientHeight); ExportDialog.PaintTo(B.Canvas,0,0);
          for I:=0 to ExportDialog.ComponentCount-1 do if ExportDialog.Components[I] is TButton then with TButton(ExportDialog.Components[I]) do
            Check((Left>=0) and (Top>=0) and (Left+Width<=Parent.ClientWidth) and (Top+Height<=Parent.ClientHeight),
              'export dialog action remains reachable '+Caption+' '+IntToStr(PPI)+' '+Format('bounds %d,%d,%d,%d parent %d,%d',[Left,Top,Width,Height,Parent.ClientWidth,Parent.ClientHeight]));
          PostMessage(ExportDialog.Handle,WM_CLOSE,0,0);
          Check((ExportDialog.ShowModal=mrCancel) and not ExportDialog.Accepted(All) and not All and
            (Project.Snapshot=Before) and (Probe.FUndo.Count=History),
            'native export modal cancellation preserves committed data and history '+IntToStr(PPI));
        finally ExportDialog.Free; end;
      end;
      After:=Project.Snapshot; History:=Probe.FUndo.Count; Probe.FPanelIndex:=0; StartDrag; KeyValue:=VK_ESCAPE; Probe.Key(Probe,KeyValue,[]);
      Check((Project.Snapshot=After) and (Probe.FUndo.Count=History),'escape after command replay preserves history and exact restored data');
      Check(FProject.Snapshot=Original,'drag command fixtures preserve the active project');
    finally Probe.Free; end;
  end;

procedure RunDragCommandChecks(Host: TComicTestForm);
begin Host.DragCommandChecks; end;
end.
