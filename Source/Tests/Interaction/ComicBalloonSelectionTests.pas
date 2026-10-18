unit ComicBalloonSelectionTests;

// 責務：最後に指定した文字サイズの継承と、吹き出し編集からコマを操作できない境界を検証する。
interface
uses ComicTestSupport;
procedure RunBalloonSelectionChecks(Host: TComicTestForm);
implementation
uses Winapi.Windows, System.SysUtils, System.Classes, System.Types, System.IOUtils,
  System.Hash, Vcl.Controls, Vcl.StdCtrls, Vcl.Graphics, Vcl.Imaging.pngimage,
  ComicModel, ComicFontHistory, ComicRender, ComicEditing;
type
  TBalloonSelectionTests = class helper for TComicTestForm
    procedure FontSizeChecks;
    procedure BalloonModeChecks(PPI: Integer; Zoom: Double);
  end;

procedure TBalloonSelectionTests.FontSizeChecks;
var Probe,Restart: TComicTestForm; Project: TComicProject; Balloon: TComicBalloon;
  Settings: TComicFontHistory; Path,Before,SizePath: string; Original: TBytes; Existed,Failed: Boolean;
  Lock: THandle; History,N: Integer; At,Finish: TPoint; Invalid: string; Shot: TBitmap;
  procedure Choose(const Text: string);
  begin Probe.FFont.Text:=Text; Probe.FFont.OnChange(Probe.FFont); end;
  procedure Select(Index: Integer);
  begin Probe.FBalloonIndex:=Index; if Index>=0 then Probe.LoadBalloonControls(Probe.Page.Balloons[Index]); end;
  procedure BeginInput(Index: Integer);
  begin Select(Index); Probe.FTool:=14; Probe.FTextToolVertical:=True; Probe.StartInlineText; end;
begin
  SizePath:=TPath.Combine(DataRoot,'Presets\FontSize.json'); Existed:=FileExists(SizePath);
  if Existed then Original:=TFile.ReadAllBytes(SizePath);
  Probe:=TComicTestForm.Create(nil); Shot:=TBitmap.Create;
  try
    Project:=CreateFixtureProject; Project.Initialize('文字サイズ記憶 fixture','1');
    Project.ImportImage(TPath.Combine(TestFolder,'reference.bmp'),''); Probe.AdoptProject(Project,False);
    Balloon:=TComicBalloon.Create; Balloon.Text:='既存セリフ'; Balloon.FontSize:=19; Probe.Page.Balloons.Add(Balloon);
    Balloon:=TComicBalloon.Create; Balloon.FontSize:=20; Probe.Page.Balloons.Add(Balloon);
    Project.Save; Probe.RefreshUI; Probe.FTabs.ActivePageIndex:=3; Probe.TabChanged(nil);
    Check(Probe.FFont.Style=csDropDown,'font size accepts both a list choice and a typed integer');
    Select(-1); Before:=Project.Snapshot; History:=Probe.FUndo.Count;
    N:=Probe.FFont.Items.IndexOf('32'); Probe.FFont.ItemIndex:=N; Probe.FFont.OnChange(Probe.FFont);
    Check((Probe.FFontHistory.LastSize=32) and (Project.Snapshot=Before) and (Probe.FUndo.Count=History),
      'size list choice without a selection changes only the remembered default');
    Choose('37'); Check(Probe.FFontHistory.LastSize=37,'a typed non-list size becomes the last size');
    Select(0); Check((Probe.FFont.Text='19') and (Probe.FFontHistory.LastSize=37),
      'selecting an existing dialogue shows its own size without replacing the last chosen size');
    Choose('43'); Check((Probe.Page.Balloons[0].FontSize=43) and (Probe.FFontHistory.LastSize=43),
      'typed size applies immediately and updates the default');
    Before:=Project.Snapshot; History:=Probe.FUndo.Count;
    for Invalid in TArray<string>.Create('','abc','0','-1','1001','2147483648') do begin
      Choose(Invalid); Check((Project.Snapshot=Before) and (Probe.FUndo.Count=History) and (Probe.FFontHistory.LastSize=43),
        'incomplete or out-of-range size input preserves content, undo and preference');
    end;
    Select(0); Choose('43'); Check(Probe.FUndo.Count=History,'choosing the current size does not create an edit');
    Probe.Undo(nil); Check((Probe.Page.Balloons[0].FontSize=19) and (Probe.FFontHistory.LastSize=43),
      'undo restores the dialogue size while retaining the last explicitly chosen default');
    BeginInput(0); Check(Probe.FInlineText.Preview.FontSize=19,'editing nonempty dialogue preserves its saved size'); Probe.FinishInlineText(False);
    BeginInput(1); Check((Probe.FInlineText.Preview.FontSize=43) and (Probe.Page.Balloons[1].FontSize=20),
      'empty dialogue starts with the remembered size in the cancelable preview');
    Probe.FinishInlineText(False); Check(Probe.Page.Balloons[1].FontSize=20,'canceling empty dialogue input preserves its original size');
    BeginInput(1); Probe.FInlineText.Text:='新しいセリフ'; Probe.FinishInlineText(True);
    Check((Probe.Page.Balloons[1].FontSize=43) and (Probe.Page.Balloons[1].Text='新しいセリフ'),
      'accepting new text saves its preview size with the dialogue');
    Probe.FTool:=5; Probe.FBalloonIndex:=-1; Probe.HandleNeeded;
    Shot.SetSize(Probe.ClientWidth,Probe.ClientHeight); Probe.PaintTo(Shot.Canvas,0,0);
    At:=Point(Probe.FPageRect.Left+Round(100*Probe.FScale),Probe.FPageRect.Top+Round(200*Probe.FScale));
    Finish:=Point(Probe.FPageRect.Left+Round(450*Probe.FScale),Probe.FPageRect.Top+Round(600*Probe.FScale));
    Probe.MouseDown(Probe.FCanvas,mbLeft,[],At.X,At.Y); Probe.MouseUp(Probe.FCanvas,mbLeft,[],Finish.X,Finish.Y);
    Check((Probe.Page.Balloons.Count=3) and (Probe.Page.Balloons.Last.FontSize=43),
      'drag-created balloon uses the remembered size rather than the selected old dialogue size');
    Restart:=TComicTestForm.Create(nil);
    try Check((Restart.FFontHistory.LastSize=43) and (Restart.FFont.Text='43'),'last size and its editable field survive a fresh form startup');
    finally Restart.Free; end;
    Project.Save; Restart:=TComicTestForm.Create(nil);
    try
      var Reloaded:=CreateFixtureProject;
      Reloaded.Load(TPath.Combine(Project.Folder,'Project.json')); Restart.AdoptProject(Reloaded,False);
      Check((Restart.Page.Balloons[0].FontSize=19) and (Restart.Page.Balloons[1].FontSize=43),
        'saved dialogue sizes survive independently from the global default');
    finally Restart.Free; end;
    Settings:=TComicFontHistory.Create; Path:=TPath.Combine(TestFolder,'size-preference.json');
    try
      Settings.LoadSize(Path); Settings.RememberSize(1); Settings.RememberSize(1000);
      Check((Settings.LastSize=1000) and (TFile.ReadAllText(Path)='1000'),'font-size preference accepts both supported boundaries');
      Settings.RememberSize(0); Check(Settings.LastSize=1000,'invalid preference cannot replace the valid size');
      Lock:=CreateFile(PChar(Path),GENERIC_READ,FILE_SHARE_READ,nil,OPEN_EXISTING,0,0);
      try Failed:=False; try Settings.RememberSize(51); except Failed:=True; end;
        Check(Failed and (Settings.LastSize=51) and (TFile.ReadAllText(Path)='1000'),
          'failed preference publication preserves the file and retains the session choice');
      finally CloseHandle(Lock); end;
    finally Settings.Free; end;
    for Invalid in TArray<string>.Create('null','"43"','43.5','0','1001','{broken') do begin
      AtomicWrite(Path,Invalid); Settings:=TComicFontHistory.Create;
      try Settings.LoadSize(Path); Settings.RememberSize(57);
        Check((Settings.LastSize=57) and (TFile.ReadAllText(Path)=Invalid),'malformed preference is retained without blocking this session');
      finally Settings.Free; end;
    end;
  finally
    Probe.Free; Shot.Free;
    if Existed then TFile.WriteAllBytes(SizePath,Original) else if FileExists(SizePath) then TFile.Delete(SizePath);
  end;
end;

procedure TBalloonSelectionTests.BalloonModeChecks(PPI: Integer; Zoom: Double);
var Probe: TComicTestForm; Project: TComicProject; Panel: TComicPanel; Balloon: TComicBalloon;
  Shot: TBitmap; PNG: TPngImage; Points: TArray<TPointF>; P: TPointF; At,Finish: TPoint;
  Before,Draft: string; History,Redo: Integer; Key: Word;
  function Screen(const P: TPointF): TPoint;
  begin Result:=Point(Probe.FPageRect.Left+Round(P.X*Probe.FScale),Probe.FPageRect.Top+Round(P.Y*Probe.FScale)); end;
  procedure Paint;
  begin Probe.HandleNeeded; Shot.SetSize(Probe.ClientWidth,Probe.ClientHeight); Probe.PaintTo(Shot.Canvas,0,0); end;
begin
  Probe:=TComicTestForm.Create(nil); Shot:=TBitmap.Create; PNG:=TPngImage.Create;
  try
    Project:=CreateFixtureProject; Project.Initialize('吹き出し選択境界 fixture','1'); Probe.AdoptProject(Project,False);
    Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(100,150,1100,1500);
    Panel.ImageID:=Project.ImportImage(TPath.Combine(TestFolder,'reference.bmp'),'').ID; Probe.Page.Panels.Add(Panel);
    Balloon:=TComicBalloon.Create; Balloon.Bounds:=TRectF.Create(400,400,800,1000); Balloon.Shape:=0;
    Balloon.Text:='編集対象'; Balloon.PanelID:=Panel.ID; Probe.Page.Balloons.Add(Balloon);
    Project.Save; Probe.RefreshUI; Probe.Scaled:=True; Probe.ScaleForPPI(PPI); Probe.Scaled:=False; Probe.FViewZoom:=Zoom;
    Probe.FPanelIndex:=0; Probe.FSelectedPanels.Add(Panel.ID); Probe.FTabs.ActivePageIndex:=3; Probe.TabChanged(nil);
    Check((Probe.FPanelIndex=-1) and (Probe.FSelectedPanels.Count=0),'entering balloon mode clears panel selection'); Paint;
    Before:=Project.Snapshot; History:=Probe.FUndo.Count; Redo:=Probe.FRedo.Count;
    Draft:=TFile.ReadAllText(TPath.Combine(Project.Folder,'Draft.json'),TEncoding.UTF8);
    Points:=EditHandles(Panel.Bounds); SetLength(Points,9); Points[8]:=TPointF.Create(250,300);
    for P in Points do begin
      Probe.CancelDrag; Probe.FPanelIndex:=0; Probe.FSelectedPanels.Add(Panel.ID); Probe.FBalloonIndex:=-1; Probe.FTool:=0; Paint;
      At:=Screen(P); Probe.MouseDown(Probe.FCanvas,mbLeft,[],At.X,At.Y);
      Check((Probe.FPanelIndex=-1) and (Probe.FSelectedPanels.Count=0) and not Probe.FDragging,
        Format('balloon mode cannot select a panel body or its stale handles: DPI=%d zoom=%.2f',[PPI,Zoom]));
      Probe.MouseMove(Probe.FCanvas,[ssLeft],At.X+40,At.Y+30); Probe.MouseUp(Probe.FCanvas,mbLeft,[],At.X+40,At.Y+30);
      Check((Project.Snapshot=Before) and (Probe.FUndo.Count=History) and (Probe.FRedo.Count=Redo) and
        (TFile.ReadAllText(TPath.Combine(Project.Folder,'Draft.json'),TEncoding.UTF8)=Draft),
        'panel body/handle drag in balloon mode preserves geometry, image, draft and undo');
      Probe.FViewPan:=TPointF.Zero; Probe.UpdateViewport;
    end;
    Probe.CancelDrag; Probe.FBalloonIndex:=0; Probe.FTool:=0; Probe.LoadBalloonControls(Balloon); Paint;
    At:=Screen(TPointF.Create(450,450)); Probe.MouseDown(Probe.FCanvas,mbLeft,[],At.X,At.Y);
    Check(Probe.FDragging and (Probe.FBalloonIndex=0) and (Probe.FPanelIndex=-1),'balloon body remains selectable without selecting its owner');
    Probe.MouseMove(Probe.FCanvas,[ssLeft,ssAlt],At.X+20,At.Y+10); Probe.MouseUp(Probe.FCanvas,mbLeft,[ssAlt],At.X+20,At.Y+10);
    Check((Panel.Bounds=TRectF.Create(100,150,1100,1500)) and (Project.Snapshot<>Before),'moving the balloon preserves its owner panel');
    Probe.FBalloonIndex:=0; Probe.FTool:=14; Probe.FTextToolVertical:=True; Probe.StartInlineText; Paint;
    At:=Screen(Balloon.Bounds.TopLeft); Probe.MouseDown(Probe.FCanvas,mbLeft,[],At.X,At.Y); Probe.MouseUp(Probe.FCanvas,mbLeft,[],At.X,At.Y);
    Check(not Probe.InlineTextActive and (Probe.FTool=0) and (Probe.FBalloonIndex=0) and (Probe.FPanelIndex=-1),
      'clicking the balloon frame during text input selects only that balloon');
    Key:=Ord('T'); Probe.Key(Probe,Key,[]);
    Check((Probe.FTool=13) and (Probe.FBalloonIndex=0),'T selects dialogue after a balloon-frame click');
    Probe.FTool:=5; At:=Screen(TPointF.Create(200,1100)); Finish:=Screen(TPointF.Create(600,1400));
    Probe.MouseDown(Probe.FCanvas,mbLeft,[],At.X,At.Y); Probe.MouseUp(Probe.FCanvas,mbLeft,[],Finish.X,Finish.Y);
    Check((Probe.Page.Balloons.Count=2) and (Probe.Page.Balloons.Last.PanelID=Panel.ID) and (Probe.FPanelIndex=-1),
      'new balloon still records its owner panel without selecting the panel');
    Probe.FTool:=0; Probe.FBalloonIndex:=-1; Probe.FPanelIndex:=0; Paint;
    if (PPI=144) and (Zoom<1) then begin PNG.Assign(Shot); PNG.SaveToFile(TPath.Combine(TestFolder,'balloon-no-panel-selection.png')); end;
  finally Probe.Free; Shot.Free; PNG.Free; end;
end;

procedure RunBalloonSelectionChecks(Host: TComicTestForm);
var PPI: Integer; Zoom: Double;
begin
  Host.FontSizeChecks;
  for PPI in [96,144] do for Zoom in TArray<Double>.Create(0.75,1.5) do Host.BalloonModeChecks(PPI,Zoom);
end;
end.
