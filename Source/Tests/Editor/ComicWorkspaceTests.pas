unit ComicWorkspaceTests;

// 責務：メニュー・入力範囲・表示・DPIの回帰を検証する。物理モニター操作とは区別する。
interface
uses ComicTestSupport;
procedure RunViewportChecks(Host: TComicTestForm);
procedure RunExportReviewChecks(Host: TComicTestForm);
procedure RunIconChecks(Host: TComicTestForm);
procedure RunMenuChecks(Host: TComicTestForm);
implementation
uses Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, Winapi.Imm,
  System.SysUtils, System.Classes, System.Types, System.UITypes,
  System.Math, System.IOUtils, System.Generics.Collections, System.JSON,
  System.Hash, System.DateUtils, Vcl.Controls, Vcl.Forms,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Menus,
  Vcl.Dialogs, Vcl.Graphics, Vcl.Imaging.pngimage, ComicModel,
  ComicEditing, ComicIconButton, ComicEffects, ComicExportDialog;
type
  TComicWorkspaceTestsHelper = class helper for TComicTestForm
    procedure ViewportChecks;
    procedure ExportReviewChecks;
    procedure IconChecks;
    procedure MenuChecks;
  end;
procedure TComicWorkspaceTestsHelper.ViewportChecks;
  var Probe: TComicTestForm; Project: TComicProject; Panel: TComicPanel; Balloon: TComicBalloon;
    Tail: TComicTail; Overlay: TComicOverlay; Asset: TComicAsset; PPI,I: Integer;
    Before,Outer: string; World,After,Pan,Start: TPointF; At: TPoint; Zoom: Double;
    KeyCode: Word; Bitmap: TBitmap; PNG: TPngImage; Bounds: TRectF;
    function Pixel(const P: TPointF): TPoint;
    begin Probe.UpdateViewport; Result:=Point(Probe.FPageRect.Left+Round(P.X*Probe.FScale),Probe.FPageRect.Top+Round(P.Y*Probe.FScale)); end;
    procedure Wheel(Delta: Integer; const P: TPoint);
    var S: TPoint;
    begin S:=Probe.FCanvas.ClientToScreen(P); Probe.Perform(WM_MOUSEWHEEL,MakeWParam(0,Delta),MakeLParam(S.X,S.Y)); end;
    procedure Mode(Index,Tool: Integer);
    begin Probe.CancelDrag; Probe.FTabs.ActivePageIndex:=Index; Probe.TabChanged(nil); Probe.FTool:=Tool; Probe.FPanelIndex:=0; Probe.FBalloonIndex:=-1; Probe.SelectSinglePanel(0); end;
    procedure Draw(const Name: string);
    begin Probe.HandleNeeded; Bitmap.SetSize(Probe.ClientWidth,Probe.ClientHeight); Probe.PaintTo(Bitmap.Canvas,0,0);
      PNG.Assign(Bitmap); PNG.SaveToFile(TPath.Combine(TestFolder,Name+'-'+IntToStr(PPI)+'.png')); end;
    procedure Untouched(const Message: string);
    begin Check((Probe.FProject.Snapshot=Before) and (Probe.FUndo.Count=0) and (Probe.FRedo.Count=0) and not Probe.FDirty,Message+' '+IntToStr(PPI)); end;
  begin
    Outer:=FProject.Snapshot;
    Probe:=TComicTestForm.Create(nil); Bitmap:=TBitmap.Create; PNG:=TPngImage.Create;
    try
      Project:=CreateFixtureProject; Project.Initialize('表示操作テスト','1');
      Asset:=Project.ImportImage(TPath.Combine(TestFolder,'reference.bmp'),'');
      Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(100,120,500,550); Panel.ImageID:=Asset.ID; Project.Pages[0].Panels.Add(Panel);
      Overlay:=TComicOverlay.Create; Overlay.Bounds:=TRectF.Create(0.2,0.2,0.7,0.7); Overlay.MaterialID:=Probe.FEffectMaterials[0].ID; Overlay.FileName:=Probe.FEffectMaterials[0].FileName; Panel.Overlays.Add(Overlay);
      Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(620,650,1000,1080); Panel.ImageID:=Asset.ID; Project.Pages[0].Panels.Add(Panel);
      Balloon:=TComicBalloon.Create; Balloon.Bounds:=TRectF.Create(200,200,420,330); Balloon.Text:='表示テスト'; Project.Pages[0].Balloons.Add(Balloon);
      Tail:=TComicTail.Create; Tail.Root:=TPointF.Create(280,320); Tail.Tip:=TPointF.Create(570,600); Tail.Width:=35; Balloon.Tails.Add(Tail);
      Project.Pages.Add(TComicPage.Create); Probe.AdoptProject(Project,False);
      Before:=Probe.FProject.Snapshot;
      for PPI in [96,144] do begin
        Probe.Scaled:=True; Probe.ScaleForPPI(PPI); Probe.Scaled:=False;
        Probe.Width:=MulDiv(1420,PPI,96); Probe.Height:=MulDiv(920,PPI,96);
        Check(Probe.CurrentPPI=PPI,'viewport uses requested real VCL PPI '+IntToStr(PPI));
        Mode(1,0); Probe.ResetViewport; Draw('viewport-fit');
        Check(SameValue(Probe.FViewZoom,1) and (Probe.FScale>0),'viewport starts in fit '+IntToStr(PPI));
        At:=Pixel(TPointF.Create(300,400)); World:=Probe.ToPage(At.X,At.Y); Zoom:=Probe.FViewZoom;
        Wheel(120,At); After:=Probe.ToPage(At.X,At.Y);
        Check((Probe.FViewZoom>Zoom) and (Hypot(World.X-After.X,World.Y-After.Y)*Probe.FScale<=1.5),'wheel zoom keeps cursor world anchor '+IntToStr(PPI));
        Zoom:=Probe.FViewZoom; Wheel(30,At); Check(Probe.FViewZoom>Zoom,'high-resolution wheel delta zooms smoothly '+IntToStr(PPI));
        Zoom:=Probe.FViewZoom; Wheel(120,Point(-5,-5)); Check(Probe.FViewZoom=Zoom,'wheel outside canvas leaves display alone '+IntToStr(PPI));
        Wheel(24000,At); Wheel(24000,At); Check(SameValue(Probe.FViewZoom,16),'wheel upper zoom limit '+IntToStr(PPI));
        Wheel(-24000,At); Wheel(-24000,At); Check(SameValue(Probe.FViewZoom,0.1),'wheel lower zoom limit '+IntToStr(PPI));
        KeyCode:=Ord('0'); Probe.Key(nil,KeyCode,[ssCtrl]); Check((KeyCode=0) and SameValue(Probe.FViewZoom,1),'Ctrl+0 restores fit '+IntToStr(PPI));
        Untouched('wheel and fit preserve data undo and dirty state');
        At:=Pixel(TPointF.Create(300,400)); Pan:=Probe.FViewPan;
        Probe.FCanvas.Perform(WM_MBUTTONDOWN,MK_MBUTTON,MakeLParam(At.X,At.Y));
        Check(Probe.FViewPanning and not Probe.FDragging,'middle button takes view priority over objects '+IntToStr(PPI));
        Probe.FCanvas.Perform(WM_MOUSEMOVE,MK_MBUTTON,MakeLParam(At.X+70,At.Y+40));
        Check((Probe.FViewPan<>Pan) and (Probe.FPanelIndex=0),'middle drag pans without changing selection '+IntToStr(PPI));
        Zoom:=Probe.FViewZoom; Wheel(120,At); Check(Probe.FViewZoom=Zoom,'wheel waits until active pan is released '+IntToStr(PPI));
        Probe.MouseUp(nil,mbLeft,[],At.X+70,At.Y+40); Check(Probe.FViewPanning,'other button release does not end middle pan '+IntToStr(PPI));
        Probe.FCanvas.Perform(WM_MBUTTONUP,0,MakeLParam(At.X+70,At.Y+40));
        Check(not Probe.FViewPanning and (Probe.FCanvas.Cursor=crDefault),'middle button release ends pan '+IntToStr(PPI));
        Untouched('middle pan preserves data undo and dirty state');
        At:=Pixel(TPointF.Create(35,35)); Check(Probe.EmptyViewPoint(Probe.ToPage(At.X,At.Y)),'blank page margin is an empty pan target '+IntToStr(PPI));
        Probe.FCanvas.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(At.X,At.Y));
        Check(Probe.FViewPanning and not Probe.FDragging,'empty left press starts view pan '+IntToStr(PPI));
        Probe.FCanvas.Perform(WM_MOUSEMOVE,MK_LBUTTON,MakeLParam(At.X+35,At.Y+25));
        Probe.FCanvas.Perform(WM_LBUTTONUP,0,MakeLParam(At.X+35,At.Y+25)); Untouched('empty left drag preserves data undo and dirty state');
        Pan:=Probe.FViewPan; Probe.MouseDown(nil,mbMiddle,[],At.X,At.Y); Probe.MouseMove(nil,[ssMiddle],At.X+40,At.Y+20);
        KeyCode:=VK_ESCAPE; Probe.Key(nil,KeyCode,[]);
        Check(not Probe.FViewPanning and (Probe.FViewPan=Pan),'Esc rolls back only the current view pan '+IntToStr(PPI));
        Probe.MouseDown(nil,mbMiddle,[],At.X,At.Y); Probe.MouseMove(nil,[ssMiddle],At.X+40,At.Y+20); Pan:=Probe.FViewPan;
        Probe.FView.Perform(WM_CAPTURECHANGED,0,0);
        Check(not Probe.FViewPanning and (Probe.FViewPan=Pan),'capture loss releases pan and retains display position '+IntToStr(PPI));
        Probe.MouseDown(nil,mbMiddle,[],At.X,At.Y); Probe.MouseMove(nil,[],At.X+5,At.Y+5);
        Check(not Probe.FViewPanning,'missing held-button flag releases pan '+IntToStr(PPI));
        Probe.MouseDown(nil,mbMiddle,[],At.X,At.Y); Probe.FPages.ItemIndex:=1; Probe.PageSelect(nil);
        Check(not Probe.FViewPanning and SameValue(Probe.FViewZoom,1),'page switch releases pan and restores fit '+IntToStr(PPI));
        Probe.FPages.ItemIndex:=0; Probe.PageSelect(nil); Mode(1,1); At:=Pixel(TPointF.Create(35,35));
        Probe.MouseDown(nil,mbLeft,[],At.X,At.Y); Start:=Probe.FStart;
        Check(Probe.FFirst and not Probe.FViewPanning,'creation tool keeps empty left click as its first point '+IntToStr(PPI));
        Wheel(120,At); Probe.MouseDown(nil,mbMiddle,[],At.X,At.Y); Probe.MouseMove(nil,[ssMiddle],At.X+20,At.Y+10); Probe.MouseUp(nil,mbMiddle,[],At.X+20,At.Y+10);
        Check(Probe.FFirst and (Probe.FStart=Start),'wheel and middle pan preserve pending creation coordinates '+IntToStr(PPI));
        KeyCode:=VK_ESCAPE; Probe.Key(nil,KeyCode,[]); Mode(1,0); Probe.ResetViewport;
        At:=Pixel(TPointF.Create(300,400)); Wheel(120,At); Wheel(120,At); Probe.MouseDown(nil,mbMiddle,[],At.X,At.Y); Probe.MouseMove(nil,[ssMiddle],At.X+20,At.Y+10); Probe.MouseUp(nil,mbMiddle,[],At.X+20,At.Y+10);
        Draw('viewport-zoom-pan'); Untouched('navigation after creation preserves project');
        Bounds:=Probe.Page.Panels[0].Bounds; At:=Pixel(Bounds.CenterPoint); Pan:=Probe.FViewPan;
        Probe.MouseDown(nil,mbLeft,[],At.X,At.Y); Check(Probe.FDragging and not Probe.FViewPanning,'panel body edits before empty-pan fallback after zoom '+IntToStr(PPI));
        Zoom:=Probe.FViewZoom; Wheel(120,At); Check(Probe.FViewZoom=Zoom,'wheel cannot shift an in-progress edit frame '+IntToStr(PPI));
        Probe.MouseMove(nil,[ssLeft,ssAlt],At.X+18,At.Y+12); Check(Probe.Page.Panels[0].Bounds<>Bounds,'zoomed canvas drag edits panel geometry '+IntToStr(PPI));
        Probe.FView.Perform(WM_CAPTURECHANGED,0,0);
        Check(not Probe.FDragging and (Probe.Page.Panels[0].Bounds=Bounds) and (Probe.FViewPan=Pan),'capture loss cancels edit without panning or adding undo '+IntToStr(PPI));
        for I:=0 to 7 do begin
          At:=Pixel(EditHandles(Probe.Page.Panels[0].Bounds)[I]); Probe.MouseDown(nil,mbLeft,[],At.X,At.Y);
          Check(Probe.FDragging and not Probe.FViewPanning and (Probe.FDragHandle=I+1),'zoomed panel handle keeps priority '+IntToStr(I)+' '+IntToStr(PPI)); Probe.CancelDrag;
        end;
        At:=Pixel(Probe.VertexHandles(Probe.Page.Panels[0])[0]); Probe.MouseDown(nil,mbLeft,[],At.X,At.Y);
        Check(Probe.FDragging and (Probe.FDragVertex>=0) and not Probe.FViewPanning,Format('vertex handle keeps priority %d [drag=%s pan=%s vertex=%d handle=%d scale=%.6f x=%d y=%d]',[PPI,BoolToStr(Probe.FDragging,True),BoolToStr(Probe.FViewPanning,True),Probe.FDragVertex,Probe.FDragHandle,Probe.FScale,At.X,At.Y])); Probe.CancelDrag;
        Probe.FSelectedPanels.Add(Probe.Page.Panels[1].ID); Probe.FPanelIndex:=1;
        At:=Pixel(Probe.SelectedPanelBounds.CenterPoint); Probe.MouseDown(nil,mbLeft,[],At.X,At.Y);
        Check(Probe.FDragging and (Length(Probe.FDragGroup)=2) and not Probe.FViewPanning,'selected group gap remains group move '+IntToStr(PPI)); Probe.CancelDrag;
        Mode(2,0); At:=Pixel(EditHandles(Probe.FRenderer.ImageBounds(Probe.FProject,Probe.Page.Panels[0]))[0]); Probe.MouseDown(nil,mbLeft,[],At.X,At.Y);
        Check(Probe.FDragging and not Probe.FViewPanning,'image handle keeps priority outside panel '+IntToStr(PPI)); Probe.CancelDrag;
        Mode(3,0); Probe.FBalloonIndex:=0; At:=Pixel(Probe.Page.Balloons[0].Bounds.CenterPoint); Probe.MouseDown(nil,mbLeft,[],At.X,At.Y);
        Check(Probe.FDragging and not Probe.FViewPanning,'balloon body keeps priority '+IntToStr(PPI)); Probe.CancelDrag;
        Probe.FTool:=13; At:=Pixel(Probe.FRenderer.BalloonTextBounds(Probe.Page.Balloons[0]).CenterPoint); Probe.MouseDown(nil,mbLeft,[],At.X,At.Y);
        Check(Probe.FDragging and not Probe.FViewPanning,'text placement keeps priority '+IntToStr(PPI)); Probe.CancelDrag;
        Probe.FTool:=12; Probe.FTailIndex:=0; At:=Pixel(Probe.Page.Balloons[0].Tails[0].Handles[2]); Probe.MouseDown(nil,mbLeft,[],At.X,At.Y);
        Check(Probe.FDragging and (Probe.FDragTailHandle>0) and not Probe.FViewPanning,'tail handle keeps priority '+IntToStr(PPI)); Probe.CancelDrag;
        Check(not Probe.EmptyViewPoint(TPointF.Create(550,580)),'visible tail is not empty space '+IntToStr(PPI));
        Mode(4,0); Probe.FEffectCategory.ItemIndex:=0; Probe.FEffectIndex:=0; At:=Pixel(EditHandles(OverlayBounds(Probe.Page.Panels[0],Probe.Page.Panels[0].Overlays[0]))[0]); Probe.MouseDown(nil,mbLeft,[],At.X,At.Y);
        Check(Probe.FDragging and not Probe.FViewPanning,'material handle keeps priority '+IntToStr(PPI)); Probe.CancelDrag;
        Mode(1,0); Probe.FSnap.Checked:=True; World:=Probe.FProject.PageBasis.Frame.TopLeft;
        After:=Probe.SnapCreationPoint(TPointF.Create(World.X+3/Probe.FScale,World.Y+2/Probe.FScale));
        Check(Hypot(After.X-World.X,After.Y-World.Y)<0.01,'zoom and pan retain frame snapping coordinates '+IntToStr(PPI));
        Untouched('all navigation and cancelled priority probes preserve data');
      end;
      Probe.MouseDown(nil,mbMiddle,[],10,10); Project:=CreateFixtureProject; Project.Folder:=Probe.FProject.Folder; Project.Restore(Probe.FProject.Snapshot);
      Probe.AdoptProject(Project,False);
      Check(not Probe.FViewPanning and SameValue(Probe.FViewZoom,1),'project replacement releases view pan and resets camera');
      Check(FProject.Snapshot=Outer,'viewport checks preserve the outer smoke-test project');
    finally PNG.Free; Bitmap.Free; Probe.Free; end;
  end;


procedure RunViewportChecks(Host: TComicTestForm);
begin Host.ViewportChecks; end;
procedure TComicWorkspaceTestsHelper.ExportReviewChecks;
  var Probe: TComicTestForm; Project: TComicProject; Panel: TComicPanel; D: TComicExportDialog;
    ImageID,Before,Original,Output: string; PPI,I,Kind,X,Y,History: Integer; All: Boolean;
    PointA: TPointF; PNG: TPngImage; Control: TControl; LabelControl: TLabel; Radio: TRadioGroup;
    procedure AddPanel(PageIndex: Integer; const ID: string; const Bounds: TRectF);
    begin Panel:=TComicPanel.Create; Panel.Bounds:=Bounds; Panel.ImageID:=ID; Project.Pages[PageIndex].Panels.Add(Panel); end;
    procedure CheckLayout(const Name: string);
    var Margin,I,J,RadioCount: Integer;
    begin
      D.HandleNeeded; D.Scaled:=True; D.ScaleForPPI(PPI); D.Scaled:=False;
      D.ClientWidth:=MulDiv(600,PPI,96); if D.WarningText='' then D.ClientHeight:=MulDiv(246,PPI,96) else D.ClientHeight:=MulDiv(340,PPI,96);
      D.Realign; B.SetSize(D.ClientWidth,D.ClientHeight); D.PaintTo(B.Canvas,0,0);
      PNG.Assign(B); PNG.SaveToFile(TPath.Combine(TestFolder,Name+'-'+IntToStr(PPI)+'.png'));
      RadioCount:=0; Margin:=MulDiv(8,PPI,96);
      for I:=0 to D.ComponentCount-1 do if D.Components[I] is TControl then begin
        Control:=TControl(D.Components[I]); if not Control.Visible then Continue;
        Check((Control.Left>=0) and (Control.Top>=0) and (Control.Left+Control.Width<=D.ClientWidth) and
          (Control.Top+Control.Height<=D.ClientHeight),'export review control fits '+Control.ClassName+' '+IntToStr(PPI)+' '+IntToStr(Kind));
        if Control is TRadioGroup then begin
          Radio:=TRadioGroup(Control); Inc(RadioCount);
          Check((Radio.Items.Count=2) and (Radio.ItemIndex=0) and (Radio.Height>=MulDiv(80,PPI,96)),
            'export review retains both reachable output choices with changed-only default '+IntToStr(PPI)+' '+IntToStr(Kind));
          for J:=0 to D.ComponentCount-1 do if (D.Components[J] is TLabel) and TLabel(D.Components[J]).Visible then begin
            LabelControl:=TLabel(D.Components[J]); Check(LabelControl.Top+LabelControl.Height+Margin<=Radio.Top,
              'export warning and output path do not overlap output choices '+IntToStr(PPI)+' '+IntToStr(Kind));
          end;
        end;
      end;
      Check(RadioCount=1,'export review has a single output selection stage '+IntToStr(PPI)+' '+IntToStr(Kind));
    end;
  begin
    Original:=FProject.Snapshot; Probe:=TComicTestForm.Create(nil); D:=nil; PNG:=TPngImage.Create;
    try
      Project:=CreateFixtureProject; Project.Initialize('出力確認 fixture','1'); Probe.AdoptProject(Project,False);
      ImageID:=Project.ImportImage(TPath.Combine(TestFolder,'reference.bmp'),'').ID; Project.Pages.Add(TComicPage.Create);
      AddPanel(0,ImageID,TRectF.Create(100,100,400,400)); AddPanel(0,ImageID,TRectF.Create(450,100,750,400));
      AddPanel(0,'',TRectF.Create(800,100,1100,400)); AddPanel(1,'missing-asset',TRectF.Create(100,100,400,400));
      AddPanel(1,ImageID,TRectF.Create(450,100,750,400)); Before:=Project.Snapshot; Output:=TPath.Combine(Project.Folder,'Output');
      Probe.RefreshUI; Probe.FTabs.ActivePageIndex:=1; Probe.TabChanged(nil); Probe.SelectSinglePanel(2); Probe.FTool:=0;
      Probe.HandleNeeded; B.SetSize(Probe.ClientWidth,Probe.ClientHeight); Probe.PaintTo(B.Canvas,0,0);
      PointA:=Probe.Page.Panels[2].Bounds.CenterPoint; X:=Probe.FPageRect.Left+Round(PointA.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(PointA.Y*Probe.FScale);
      Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y); Probe.MouseMove(Probe.FCanvas,[ssLeft,ssAlt],X+20,Y+12);
      Check(Probe.FDragging and (Project.Snapshot<>Before),'export review starts with a pending panel drag');
      History:=Probe.FUndo.Count; D:=Probe.CreateExportOptions;
      Check(not Probe.FDragging and (Project.Snapshot=Before) and (Probe.FUndo.Count=History),'opening export review cancels a pending drag before counting warnings');
      Check((Pos('画像未配置・参照切れ：2 コマ',D.WarningText)>0) and (Pos('同じ画像の重複配置：2 コマ',D.WarningText)>0),
        'export review counts missing images and reused image identities across every page');
      Check(D.OutputPath=Output,'export review retains the complete project output path');
      for I:=0 to D.ComponentCount-1 do if D.Components[I] is TEdit then begin
        with TEdit(D.Components[I]) do begin
          Check(ReadOnly and (Text=Output) and ShowHint and (Hint=Output),'long export path is selectable read-only text with a full-path hint');
          SelectAll; Check(SelText=Output,'entire export path can be selected without modifying it');
        end;
      end;
      D.ModalResult:=mrCancel; Check(not D.Accepted(All) and not All,'warning review cancellation cannot accept output');
      D.ModalResult:=mrOK; Check(D.Accepted(All) and not All,'warnings allow explicit changed-only output without a second confirmation');
      for I:=0 to D.ComponentCount-1 do if D.Components[I] is TRadioGroup then TRadioGroup(D.Components[I]).ItemIndex:=1;
      Check(D.Accepted(All) and All,'warnings allow explicit all-page output without rejecting duplicate images'); FreeAndNil(D);
      for Kind:=0 to 2 do for PPI in [96,144] do begin
        case Kind of
          0: D:=TComicExportDialog.CreateOptions(Probe,Output,Probe.OpenOutput,'');
          1: D:=TComicExportDialog.CreateOptions(Probe,Output,Probe.OpenOutput,'画像未配置・参照切れ：2 コマ。画像のない部分も含めて出力します。');
          2: D:=Probe.CreateExportOptions;
        end;
        CheckLayout('export-review-'+IntToStr(Kind));
        PostMessage(D.Handle,WM_CLOSE,0,0); D.ShowModal;
        Check((D.ModalResult=mrCancel) and (Project.Snapshot=Before) and (Probe.FUndo.Count=History),
          'native export review close preserves project and undo '+IntToStr(PPI)+' '+IntToStr(Kind)); FreeAndNil(D);
      end;
      Project.Pages[0].Panels.Delete(2); Project.Pages.Delete(1); Project.Pages[0].Panels.Delete(1); Probe.RefreshUI;
      D:=Probe.CreateExportOptions; Check(D.WarningText='','unique valid image assignments do not show an export warning'); FreeAndNil(D);
      Check(Length(TDirectory.GetFiles(Output))=0,'cancelled export review creates no output PNG or cache files');
      Check(FProject.Snapshot=Original,'export review fixtures preserve the active project');
    finally D.Free; PNG.Free; Probe.Free; end;
  end;

procedure RunExportReviewChecks(Host: TComicTestForm);
begin Host.ExportReviewChecks; end;
procedure TComicWorkspaceTestsHelper.IconChecks;
  var OriginalPPI,OriginalW,OriginalH: Integer; OriginalScaled: Boolean; Model: string; Button,Probe: TComicIconButton;
    KeyValue: Word; NormalColor,HoverColor,SelectedColor,PressedColor,DisabledColor: TColor;
    PNG: TPngImage; RectA,RectB: TRect;
    function Find(Role: TComicButtonRole; Tag: Integer; Context: Integer=-1): TComicIconButton;
    var Candidate: TComicIconButton;
    begin
      Result:=nil; for Candidate in FIconButtons do
        if (Candidate.Role=Role) and (Candidate.Tag=Tag) and (Candidate.Context=Context) then Exit(Candidate);
      if Result=nil then raise Exception.Create('Icon command not found.');
    end;
    procedure SaveUI(const Name: string);
    begin
      UpdateIconState; HandleNeeded; B.SetSize(ClientWidth,ClientHeight); PaintTo(B.Canvas,0,0);
      PNG.Assign(B); PNG.SaveToFile(TPath.Combine(TestFolder,Name+'.png'));
    end;
    procedure CheckLayout(PPI,W,H: Integer; const Name: string);
    var Mode,PX,PY,Category: Integer; AllFit,NoOverlap: Boolean; First,Second: TComicIconButton; Scroll: TScrollBox;
    begin
      Scaled:=True; ScaleForPPI(PPI);
      // 非表示HWNDの実モニターDPIとは区別し、VCLの拡縮済みPPIでオフスクリーン検証を行う。
      Scaled:=False; Width:=MulDiv(W,PPI,96); Height:=MulDiv(H,PPI,96); Realign;
      Check((PixelsPerInch=PPI) and (CurrentPPI=PPI),Name+' applies requested VCL PPI '+IntToStr(PPI));
      for Mode:=0 to High(FModeButtons) do begin
        FModeButtons[Mode].Click;
        if Mode in [1,3] then TScrollBox(FTabs.ActivePage.Controls[0]).VertScrollBar.Position:=0;
        SaveUI(Name+'-mode'+IntToStr(Mode)); AllFit:=True; NoOverlap:=True;
        for First in FIconButtons do begin
          if (First.Left<0) or (First.Left+First.Width>First.Parent.ClientWidth) then AllFit:=False;
          for Second in FIconButtons do if (First<>Second) and (First.Parent=Second.Parent) then begin
            RectA:=First.BoundsRect; RectB:=Second.BoundsRect;
            if IntersectRect(RectA,RectA,RectB) then NoOverlap:=False;
          end;
        end;
        Check(AllFit and NoOverlap,Name+' mode '+IntToStr(Mode)+' icon bounds fit without overlap');
        Check((FModeTitle.Caption=FTabs.ActivePage.Caption) and FModeButtons[Mode].Selected,
          Name+' mode '+IntToStr(Mode)+' keeps selected icon and readable mode title');
        if Mode=1 then begin
          Scroll:=TScrollBox(FTabs.ActivePage.Controls[0]); Second:=nil;
          for First in FIconButtons do if (First.Role=brRegister) and (First.Parent=Scroll) then Second:=First;
          Check(Second<>nil,Name+' panel register command exists');
          Scroll.ScrollInView(Second); ActiveControl:=Second;
          Check((Second.Top>=0) and (Second.Top+Second.Height<=Scroll.ClientHeight),
            Name+' panel bottom action remains reachable by scrolling and focus');
          SaveUI(Name+'-mode1-scrolled');
        end;
        if Mode=3 then begin
          PX:=FPageRect.Left+Round(Page.Balloons[0].Bounds.CenterPoint.X*FScale);
          PY:=FPageRect.Top+Round(Page.Balloons[0].Bounds.CenterPoint.Y*FScale);
          FCanvas.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(PX,PY));
          FCanvas.Perform(WM_LBUTTONUP,0,MakeLParam(PX,PY));
          Scroll:=TScrollBox(FText.Parent); Second:=Find(brDeleteBalloon,1);
          Scroll.ScrollInView(Second); ActiveControl:=Second;
          Check((Second.Top>=0) and (Second.Top+Second.Height<=Scroll.ClientHeight),
            Name+' bottom actions remain reachable by scrolling and keyboard focus');
          SaveUI(Name+'-mode3-scrolled');
        end;
        if Mode=4 then begin
          for Category:=0 to 2 do begin
            FEffectCategory.ItemIndex:=Category; EffectCategoryChanged(nil); SaveUI(Name+'-mode4-category'+IntToStr(Category));
            Check((FEffectCategory.Left>=0) and (FEffectCategory.Top>=0) and
              (FEffectCategory.Left+FEffectCategory.Width<=FEffectCategory.Parent.ClientWidth) and
              (FEffectList.ItemHeight>0),Name+' effect category remains reachable '+IntToStr(Category));
            if Category>0 then begin
              Second:=Find(brDeleteEffect,Category); Scroll:=TScrollBox(Second.Parent); Scroll.ScrollInView(Second);
              if Second.Enabled then ActiveControl:=Second;
              Check((Second.Top>=0) and (Second.Top+Second.Height<=Scroll.ClientHeight),
                Name+' effect removal remains reachable by scrolling '+IntToStr(Category));
              SaveUI(Name+'-mode4-category'+IntToStr(Category)+'-scrolled');
            end;
          end;
          FEffectCategory.ItemIndex:=0; EffectCategoryChanged(nil);
        end;
      end;
      Check(not Visible,Name+' UI validation stays hidden');
    end;
    procedure SelectionStateChecks;
    var PX,PY,UndoCount: Integer; Bounds: TRectF; EmptyPanel: TComicPanel;
      procedure RenderGeometry;
      begin
        // 状態を同期し直す補助処理を挟まず、実際の選択イベントだけでUIが更新されるか確認する。
        B.SetSize(ClientWidth,ClientHeight); PaintTo(B.Canvas,0,0);
      end;
      procedure ClickPage(X,Y: Single);
      begin
        PX:=FPageRect.Left+Round(X*FScale); PY:=FPageRect.Top+Round(Y*FScale);
        FCanvas.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(PX,PY));
        FCanvas.Perform(WM_LBUTTONUP,0,MakeLParam(PX,PY));
      end;
    begin
      UndoCount:=FUndo.Count; FModeButtons[1].Click; RenderGeometry; Bounds:=Page.Panels[0].Bounds;
      ClickPage((Bounds.Left+Bounds.Right)/2,(Bounds.Top+Bounds.Bottom)/2);
      Check(Find(brDeletePanel,0).Enabled,'normal panel selection enables panel actions');
      ClickPage(FProject.Width-30,FProject.Height-30);
      Check((FPanelIndex=-1) and not Find(brDeletePanel,0).Enabled and not FDetachImageMenu.Enabled,
        'blank canvas click immediately disables panel actions without screenshot resync');
      FModeButtons[3].Click; RenderGeometry; Bounds:=Page.Balloons[0].Bounds;
      ClickPage((Bounds.Left+Bounds.Right)/2,(Bounds.Top+Bounds.Bottom)/2);
      Check(Find(brTail,7,3).Enabled and Find(brDeleteBalloon,1).Enabled and Find(brApplyText,0).Enabled,
        'normal balloon selection enables balloon actions');
      ClickPage(FProject.Width-30,FProject.Height-30);
      Check((FBalloonIndex=-1) and not Find(brTail,7,3).Enabled and not Find(brDeleteBalloon,1).Enabled and not Find(brApplyText,0).Enabled,
        'blank canvas click immediately disables balloon actions without screenshot resync');
      EmptyPanel:=TComicPanel.Create; EmptyPanel.Bounds:=TRectF.Create(950,600,1140,1640); Page.Panels.Add(EmptyPanel);
      try
        FModeButtons[2].Click; FImages.ItemIndex:=0; ImageSelectionChanged(FImages); RenderGeometry;
        Bounds:=Page.Panels[0].Bounds; ClickPage((Bounds.Left+Bounds.Right)/2,(Bounds.Top+Bounds.Bottom)/2);
        Check(FDetachImageMenu.Enabled,'assigned image selection enables context detach');
        ClickPage(1040,1200);
        Check((FPanelIndex=1) and not FDetachImageMenu.Enabled,
          'unassigned panel selection immediately updates image actions on early return');
      finally Page.Panels.Delete(Page.Panels.Count-1); FPanelIndex:=-1; end;
      Check(FUndo.Count=UndoCount,'selection-state events do not add undo history');
      Check(FProject.Snapshot=Model,'selection-state events preserve project data');
    end;
  begin
    Model:=FProject.Snapshot; OriginalPPI:=CurrentPPI; OriginalW:=Width; OriginalH:=Height; OriginalScaled:=Scaled;
    PNG:=TPngImage.Create;
    try
      Check(FIconButtons.Count>=30,'switching and editing commands use consistent icon controls');
      for Button in FIconButtons do Check((Button.Caption<>'') and (Button.Hint<>'') and Button.ShowHint and Button.TabStop,
        'icon keeps operation name, hint and tab stop: '+Button.Caption);
      FModeButtons[1].Click;
      Button:=Find(brTool,1,1); ActiveControl:=Button;
      Button.Perform(CM_DIALOGKEY,VK_SPACE,0);
      Check((FTool=1) and Button.Selected,'Space selects the rectangle tool and its selected state');
      KeyValue:=Ord('3'); Key(Self,KeyValue,[ssCtrl]);
      Check((FTabs.ActivePageIndex=2) and (KeyValue=0),'Ctrl+3 selects image placement');
      KeyValue:=VK_TAB; Key(Self,KeyValue,[ssCtrl]);
      Check(FTabs.ActivePageIndex=3,'Ctrl+Tab cycles screen modes');
      KeyValue:=VK_TAB; Key(Self,KeyValue,[ssCtrl,ssShift]);
      Check(FTabs.ActivePageIndex=2,'Ctrl+Shift+Tab cycles screen modes backwards');
      FModeButtons[0].Click; ActiveControl:=FModeButtons[0];
      FModeButtons[0].Perform(WM_KEYDOWN,VK_RIGHT,0);
      Check((FTabs.ActivePageIndex=1) and (ActiveControl=FModeButtons[1]),'arrow key switches mode and focus');
      Button:=Find(brTool,0,1); ActiveControl:=Button; Button.Perform(WM_KEYDOWN,VK_RIGHT,0);
      Check((FTool=1) and (ActiveControl=Find(brTool,1,1)),'arrow key switches edit tool and focus');
      Button.Perform(CM_MOUSEENTER,0,0);
      Check(Button.Hovered and (FStatus.SimpleText=Button.Hint),'hover highlights icon and exposes status help');
      Button.Perform(CM_MOUSELEAVE,0,0); Check(not Button.Hovered,'mouse leave clears hover');
      SelectionStateChecks;
      Probe:=TComicIconButton.Create(Self);
      try
        Probe.Parent:=FView; Probe.SetBounds(4,4,44,44); Probe.Icon:=ciRectangle; Probe.Caption:='test';
        Probe.ControlStyle:=Probe.ControlStyle-[csCaptureMouse]; Probe.OnClick:=IconTestClick;
        ActiveControl:=Probe; FIconTestClicks:=0;
        Probe.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(20,20));
        Probe.Perform(WM_LBUTTONUP,0,MakeLParam(20,20));
        Check(FIconTestClicks=1,'native mouse messages invoke an icon command exactly once');
        FIconTestClicks:=0; Probe.Perform(WM_KEYDOWN,VK_SPACE,0); Probe.Perform(WM_CHAR,VK_SPACE,0); Probe.Perform(WM_KEYUP,VK_SPACE,0);
        Check(FIconTestClicks=1,'Space invokes an icon command exactly once');
        FIconTestClicks:=0; Probe.Perform(CM_DIALOGKEY,VK_RETURN,0); Probe.Perform(WM_CHAR,VK_RETURN,0); Probe.Perform(WM_KEYUP,VK_RETURN,0);
        Check(FIconTestClicks=1,'Enter invokes an icon command exactly once');
        Probe.Enabled:=False; FIconTestClicks:=0; Probe.Click; Probe.Perform(WM_KEYDOWN,VK_SPACE,0);
        Check(FIconTestClicks=0,'disabled icon cannot invoke an action'); Probe.Enabled:=True;
        FView.Enabled:=False; Probe.Click; Probe.Perform(WM_KEYDOWN,VK_SPACE,0);
        Check(FIconTestClicks=0,'disabled parent prevents icon action'); FView.Enabled:=True;
        B.SetSize(220,44); Probe.Perform(CM_MOUSELEAVE,0,0); Probe.Selected:=False;
        Probe.RenderTo(B.Canvas,Rect(0,0,44,44)); NormalColor:=B.Canvas.Pixels[8,8];
        Probe.Perform(CM_MOUSEENTER,0,0); Probe.RenderTo(B.Canvas,Rect(44,0,88,44)); HoverColor:=B.Canvas.Pixels[52,8];
        Probe.Selected:=True; Probe.Perform(CM_MOUSELEAVE,0,0); Probe.RenderTo(B.Canvas,Rect(88,0,132,44)); SelectedColor:=B.Canvas.Pixels[96,8];
        Probe.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(20,20)); Probe.RenderTo(B.Canvas,Rect(132,0,176,44)); PressedColor:=B.Canvas.Pixels[140,8];
        Probe.Perform(WM_LBUTTONUP,0,MakeLParam(20,20)); Probe.Enabled:=False;
        Probe.RenderTo(B.Canvas,Rect(176,0,220,44)); DisabledColor:=B.Canvas.Pixels[184,8];
        PNG.Assign(B); PNG.SaveToFile(TPath.Combine(TestFolder,'icon-states.png'));
        Check((NormalColor<>HoverColor) and (NormalColor<>SelectedColor) and (NormalColor<>PressedColor) and
          (NormalColor<>DisabledColor),'normal, hover, selected, pressed and disabled appearance are distinct');
      finally ActiveControl:=nil; Probe.Free; FView.Enabled:=True; end;
      CheckLayout(96,1420,920,'ui-96');
      CheckLayout(96,940,660,'ui-96-narrow');
      CheckLayout(144,1200,820,'ui-144');
      CheckLayout(144,940,660,'ui-144-narrow');
      Check(FProject.Snapshot=Model,'icon switching, keyboard and DPI layout preserve project data');
    finally
      PNG.Free; Scaled:=True; ScaleForPPI(OriginalPPI); Width:=OriginalW; Height:=OriginalH; Scaled:=OriginalScaled;
      FTabs.ActivePageIndex:=0; TabChanged(nil); ActiveControl:=nil; Realign;
    end;
  end;

procedure RunIconChecks(Host: TComicTestForm);
begin Host.IconChecks; end;
procedure TComicWorkspaceTestsHelper.MenuChecks;
  var I,Mode: Integer; Project: TComicProject; Control: TWinControl; KeyValue: Word; Model: string;
    function HasCommand(Item: TMenuItem; Handler: TNotifyEvent; Code: TShortCut): Boolean;
    var Child: TMenuItem;
    begin
      Result:=(TMethod(Item.OnClick).Code=TMethod(Handler).Code) and
        (TMethod(Item.OnClick).Data=TMethod(Handler).Data) and (Item.ShortCut=Code);
      if Result then Exit;
      for Child in Item do if HasCommand(Child,Handler,Code) then Exit(True);
    end;
  begin
    Model:=FProject.Snapshot; Mode:=FTabs.ActivePageIndex; Control:=ActiveControl;
    for I:=0 to ControlCount-1 do Check(Controls[I].Align<>alTop,'no root top toolbar after menu migration '+IntToStr(I));
    Check(HasCommand(Menu.Items,NewProject,ShortCut(Ord('N'),[ssCtrl])),'new project remains on its menu with Ctrl+N');
    Check(HasCommand(Menu.Items,OpenProject,ShortCut(Ord('O'),[ssCtrl])),'open remains on its menu with Ctrl+O');
    Check(HasCommand(Menu.Items,SaveProject,ShortCut(Ord('S'),[ssCtrl])),'save remains on its menu with Ctrl+S');
    Check(HasCommand(Menu.Items,Characters,ShortCut(Ord('C'),[ssCtrl,ssShift])),'characters menu shows Ctrl+Shift+C');
    Check(HasCommand(Menu.Items,Images,ShortCut(Ord('I'),[ssCtrl,ssShift])),'images menu shows Ctrl+Shift+I');
    Check(HasCommand(Menu.Items,Undo,ShortCut(Ord('Z'),[ssCtrl])),'undo remains on its menu with Ctrl+Z');
    Check(HasCommand(Menu.Items,Redo,ShortCut(Ord('Y'),[ssCtrl])),'redo remains on its menu with Ctrl+Y');
    Check(HasCommand(Menu.Items,ExportPNG,ShortCut(Ord('E'),[ssCtrl])),'PNG export menu shows Ctrl+E');
    for I:=0 to High(FModeMenu) do begin
      FModeMenu[I].Click;
      Check((FTabs.ActivePageIndex=I) and FModeMenu[I].Checked and FModeButtons[I].Selected and
        (FModeTitle.Caption=FTabs.ActivePage.Caption),'menu and right tool mode state stay synchronized '+IntToStr(I));
    end;
    FModeMenu[Mode].Click;
    Project:=FProject; FProject:=nil;
    try
      UpdateIconState;
      Check(not FSaveMenu.Enabled and not FExportMenu.Enabled and not FImagesMenu.Enabled,'project menu commands disable without a project');
      Check(not FUndoMenu.Enabled and not FRedoMenu.Enabled and not FFitMenu.Enabled,'undo redo and fit disable without a project');
      for I:=0 to High(FModeMenu) do Check(not FModeMenu[I].Enabled,'mode menu disables without a project '+IntToStr(I));
    finally FProject:=Project; UpdateIconState; end;
    Check(FSaveMenu.Enabled and FExportMenu.Enabled and FImagesMenu.Enabled,'project commands re-enable after restoring the loaded project');
    Check((FUndoMenu.Enabled=(FUndo.Count>0)) and (FRedoMenu.Enabled=(FRedo.Count>0)),'menu undo and redo reflect actual history availability');
    FModeMenu[3].Click; ActiveControl:=FText;
    try
      Check(not GlobalShortcutsAllowed,'text editor keeps application shortcuts out of its input scope');
      KeyValue:=Ord('1'); Key(Self,KeyValue,[ssCtrl]);
      Check((KeyValue=Ord('1')) and (FTabs.ActivePageIndex=3),'Ctrl+1 is left to text input without switching modes');
      KeyValue:=Ord('0'); Key(Self,KeyValue,[ssCtrl]);
      Check(KeyValue=Ord('0'),'Ctrl+0 is left to text input without resetting view');
      KeyValue:=VK_TAB; Key(Self,KeyValue,[ssCtrl]);
      Check((KeyValue=VK_TAB) and (FTabs.ActivePageIndex=3),'Ctrl+Tab is left to text input');
    finally FModeMenu[Mode].Click; ActiveControl:=Control; end;
    Check(FProject.Snapshot=Model,'menu mode switching and shortcut guards preserve the entire project');
  end;



procedure RunMenuChecks(Host: TComicTestForm);
begin Host.MenuChecks; end;
end.
