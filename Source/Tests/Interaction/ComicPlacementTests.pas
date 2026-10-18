unit ComicPlacementTests;

// 責務：配置方式、セリフ選択・吸着、手動改行の入力とキャレットを隔離フォームで検証する。
interface
uses ComicTestSupport;
procedure RunPlacementChecks(Host: TComicTestForm);
procedure RunDialogueRefinementChecks(Host: TComicTestForm);
procedure RunManualTextFlowChecks(Host: TComicTestForm);
implementation
uses Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.Types, System.Math, System.IOUtils,
  System.JSON, Vcl.Controls, Vcl.Graphics, Vcl.Imaging.pngimage, ComicModel, ComicTextLayout,
  ComicRender, ComicPlacementPreview, ComicDialogueTransform;
type
  TPlacementTestsHelper = class helper for TComicTestForm
    procedure PlacementChecks;
    procedure DialogueRefinementChecks;
    procedure ManualTextFlowChecks;
  end;

procedure TPlacementTestsHelper.PlacementChecks;
var Probe: TComicTestForm; Project: TComicProject; Shot,Prediction,Completed: Vcl.Graphics.TBitmap; PNG: TPngImage;
  A,Z: TPoint; Mode,Tool,PPI,Count,History,X,Y,White,Black: Integer; Before: string; Owner: TComicBalloon;
  Preview: TComicBalloon; Same: Boolean;
  procedure Paint;
  begin Probe.HandleNeeded; Shot.SetSize(Probe.ClientWidth,Probe.ClientHeight); Probe.PaintTo(Shot.Canvas,0,0); end;
  function Screen(const P: TPointF): TPoint;
  begin Result:=Point(Probe.FPageRect.Left+Round(P.X*Probe.FScale),Probe.FPageRect.Top+Round(P.Y*Probe.FScale)); end;
  function Objects: Integer;
  begin
    if Tool in [1,2,3] then Result:=Probe.Page.Panels.Count
    else if Tool in [7,11] then Result:=Probe.Page.Balloons[0].Tails.Count else Result:=Probe.Page.Balloons.Count;
  end;
  procedure Down(const P: TPoint);
  begin Probe.MouseDown(Probe.FCanvas,mbLeft,[ssAlt],P.X,P.Y); end;
  procedure Up(const P: TPoint);
  begin Probe.MouseUp(Probe.FCanvas,mbLeft,[ssAlt],P.X,P.Y); end;
  procedure SetTool;
  begin
    Probe.CancelDrag; Probe.FFirst:=False; Probe.FBalloonIndex:=0; Probe.ActiveControl:=Probe.FView;
    if Tool in [1,2,3] then Probe.FTabs.ActivePageIndex:=1 else Probe.FTabs.ActivePageIndex:=3;
    Probe.FTool:=Tool; Paint;
  end;
begin
  Probe:=TComicTestForm.Create(nil); Shot:=Vcl.Graphics.TBitmap.Create; Shot.PixelFormat:=pf32bit; PNG:=TPngImage.Create;
  Prediction:=Vcl.Graphics.TBitmap.Create; Completed:=Vcl.Graphics.TBitmap.Create;
  try
    Prediction.PixelFormat:=pf32bit; Completed.PixelFormat:=pf32bit; Prediction.SetSize(240,340); Completed.SetSize(240,340);
    Project:=CreateFixtureProject; Project.Initialize('ドラッグ配置 fixture','1'); Project.ImportImage(TPath.Combine(TestFolder,'reference.bmp'),'');
    Probe.AdoptProject(Project,False); Owner:=TComicBalloon.Create; Owner.Bounds:=TRectF.Create(100,100,800,900);
    Owner.FillColor:=$D7F4FF; Owner.BorderColor:=$303080; Owner.BorderWidth:=11; Owner.Contour:=bcWave;
    Probe.Page.Balloons.Add(Owner); Probe.RefreshUI;
    Check(Probe.FDragPlacementMenu.Checked,'drag placement is the default and has an accessible menu toggle');
    for PPI in [96,144] do for Mode:=0 to 1 do for Tool in [1,2,3,5,6,10,7,11] do begin
      Probe.Scaled:=True; Probe.ScaleForPPI(PPI); Probe.Scaled:=False; Probe.FDragPlacementMenu.Checked:=Mode=0; SetTool;
      Probe.FContour.ItemIndex:=Ord(PPI=144)*2+Mode;
      A:=Screen(TPointF.Create(400,400)); Z:=Screen(TPointF.Create(950,1100));
      Count:=Objects; History:=Probe.FUndo.Count; Before:=Project.Snapshot; Down(A);
      if Mode=1 then Up(A);
      Probe.MouseMove(Probe.FCanvas,[ssLeft,ssAlt],Z.X,Z.Y);
      Check((Objects=Count) and (Project.Snapshot=Before) and (Probe.FUndo.Count=History),
        'placement preview leaves model and undo unchanged');
      if (Mode=0) and (PPI=144) and (Tool in [5,7]) then begin Paint; PNG.Assign(Shot); PNG.SaveToFile(TPath.Combine(TestFolder,'placement-preview-'+IntToStr(Tool)+'.png')); end;
      if Tool in [5,6,7,10,11] then begin
        Preview:=CreateBalloonPlacementPreview(Tool,Probe.FStart,Probe.FLast,Probe.Page.Balloons[0],TComicBalloonContour(Probe.FContour.ItemIndex));
        try Probe.FRenderer.Draw(Prediction.Canvas,Project,Probe.Page,Rect(0,0,240,340),False,Preview); finally Preview.Free; end;
        Check(Project.Snapshot=Before,'completed-style balloon preview does not publish a model change');
      end;
      if Mode=1 then Down(Z); Up(Z);
      Check((Objects=Count+1) and (Probe.FUndo.Count=History+1) and not Probe.FFirst and not Probe.FPlacementDragging,
        Format('placement completes once: tool%d mode%d DPI%d',[Tool,Mode,PPI]));
      if Tool in [5,6,7,10,11] then begin
        Probe.FRenderer.Draw(Completed.Canvas,Project,Probe.Page,Rect(0,0,240,340),False);
        Same:=True; for Y:=0 to Completed.Height-1 do
          if not CompareMem(Prediction.ScanLine[Y],Completed.ScanLine[Y],Completed.Width*4) then begin Same:=False; Break; end;
        Check(Same,'balloon or joined tail preview matches completed pixels across contours, input modes and DPI');
      end;
      if Tool=7 then Check(Abs(Probe.Page.Balloons[0].Tails.Last.Width-700/3)<0.001,'two-point or drag triangular root is twice the former width');
      if Tool=11 then Check(Abs(Probe.Page.Balloons[0].Tails.Last.Width-700/6)<0.001,'thought tail retains its original circle sizes');
      Probe.Undo(nil); Check(Project.Snapshot=Before,'placement undo restores exact scene'); Probe.Redo(nil); Probe.Undo(nil);
      SetTool; Count:=Objects; History:=Probe.FUndo.Count; Before:=Project.Snapshot; Down(A); if Mode=1 then Up(A);
      Z:=Point(A.X+1,A.Y+1); if Mode=1 then Down(Z); Up(Z);
      Check((Objects=Count) and (Project.Snapshot=Before) and (Probe.FUndo.Count=History) and not Probe.FFirst,
        'nearby endpoints create no object or undo and clear the preview');
    end;
    Tool:=10; Probe.FDragPlacementMenu.Checked:=True; SetTool; A:=Screen(TPointF.Create(750,850)); Z:=Screen(TPointF.Create(300,300));
    Before:=Project.Snapshot; History:=Probe.FUndo.Count; Down(A); Probe.MouseMove(Probe.FCanvas,[ssLeft],Z.X,Z.Y); Probe.ViewCaptureLost(nil);
    Check(not Probe.FFirst and not Probe.FPlacementDragging and (Project.Snapshot=Before) and (Probe.FUndo.Count=History),'capture loss cancels placement without publishing geometry');
    Down(A); Probe.FDragPlacementMenu.Click;
    Check(not Probe.FFirst and not Probe.FPlacementDragging and not Probe.FDragPlacementMenu.Checked and (Project.Snapshot=Before),'placement method can be switched while a preview is pending');
    Shot.SetSize(120,120); Shot.Canvas.Brush.Color:=clGray; Shot.Canvas.FillRect(Rect(0,0,120,120));
    DrawPanelPlacementPreview(Shot.Canvas,Point(0,0),1,Rect(0,0,120,120),1,TPointF.Create(10,10),TPointF.Create(100,100));
    White:=0; Black:=0; for X:=10 to 99 do for Y:=10 to 11 do begin
      if Shot.Canvas.Pixels[X,Y]=clWhite then Inc(White); if Shot.Canvas.Pixels[X,Y]=clBlack then Inc(Black);
    end;
    Check((White>0) and (Black>0) and (Shot.Canvas.Pixels[50,50]=clGray),'panel prediction retains black and white dots and transparent interior');
  finally Probe.Free; Shot.Free; PNG.Free; Prediction.Free; Completed.Free; end;
end;

procedure TPlacementTestsHelper.DialogueRefinementChecks;
var Probe: TComicTestForm; Project,Loaded: TComicProject; Balloon: TComicBalloon; Shot: Vcl.Graphics.TBitmap; PNG: TPngImage;
  PPI,Orientation,History,N: Integer; A,Z: TPoint; R: TRectF; P: TPointF; Before,After: string;
  procedure Paint;
  begin Probe.HandleNeeded; Shot.SetSize(Probe.ClientWidth,Probe.ClientHeight); Probe.PaintTo(Shot.Canvas,0,0); end;
  function Screen(const P: TPointF): TPoint;
  begin Result:=Point(Probe.FPageRect.Left+Round(P.X*Probe.FScale),Probe.FPageRect.Top+Round(P.Y*Probe.FScale)); end;
  function GuidePixels: Integer;
  var X,Y: Integer; Pixel: PCardinal;
  begin
    Result:=0; for Y:=Probe.FPageRect.Top to Probe.FPageRect.Bottom-1 do begin
      Pixel:=Shot.ScanLine[Shot.Height-1-Y]; Inc(Pixel,Probe.FPageRect.Left);
      for X:=Probe.FPageRect.Left to Probe.FPageRect.Right-1 do begin
        if (Pixel^ and $FFFFFF)=$E060E0 then Inc(Result); Inc(Pixel);
      end;
    end;
  end;
begin
  Probe:=TComicTestForm.Create(nil); Shot:=Vcl.Graphics.TBitmap.Create; Shot.PixelFormat:=pf32bit; PNG:=TPngImage.Create;
  try
    Project:=CreateFixtureProject; Project.Initialize('セリフ吸着 fixture','1'); Probe.AdoptProject(Project,False);
    Balloon:=TComicBalloon.Create; Balloon.Bounds:=TRectF.Create(200,250,850,1050); Balloon.Shape:=0; Balloon.Text:='選択と移動'+#13#10+'文字の中心';
    Probe.Page.Balloons.Add(Balloon); Probe.RefreshUI; Probe.FTabs.ActivePageIndex:=3;
    for PPI in [96,144] do for Orientation:=0 to 1 do begin
      Balloon:=Probe.Page.Balloons[0]; Balloon.Vertical:=Orientation=1; Balloon.TextOffset:=TPointF.Create(60,90);
      Probe.Scaled:=True; Probe.ScaleForPPI(PPI); Probe.Scaled:=False; Probe.FBalloonIndex:=0; Probe.FTool:=0; Probe.ActiveControl:=Probe.FView; Paint;
      Before:=Project.Snapshot; History:=Probe.FUndo.Count; R:=Probe.FRenderer.BalloonTextBounds(Balloon); A:=Screen(R.CenterPoint);
      Probe.MouseDown(Probe.FCanvas,mbLeft,[],A.X,A.Y); Probe.MouseUp(Probe.FCanvas,mbLeft,[],A.X,A.Y);
      Check((Probe.FTool=13) and not Probe.InlineTextActive and (Probe.FBalloonIndex=0) and (Project.Snapshot=Before),
        'body tool click on dialogue selects dialogue handles without entering input');
      Probe.MouseDown(Probe.FCanvas,mbLeft,[],A.X,A.Y);
      P:=Balloon.Bounds.CenterPoint; P.Offset(2/Probe.FScale,-2/Probe.FScale); Z:=Screen(P);
      Probe.MouseMove(Probe.FCanvas,[ssLeft],Z.X,Z.Y);
      R:=Probe.FRenderer.BalloonTextBounds(Balloon);
      Check(Probe.FDialogueSnap.HasX and Probe.FDialogueSnap.HasY and (R.CenterPoint.Distance(Balloon.Bounds.CenterPoint)<0.01),
        'dialogue center snaps on both axes within DPI-scaled tolerance');
      Paint; N:=GuidePixels; Check(N>20,'snapped dialogue displays temporary center guides');
      if (PPI=144) and (Orientation=1) then begin PNG.Assign(Shot); PNG.SaveToFile(TPath.Combine(TestFolder,'dialogue-center-guides.png')); end;
      Probe.MouseMove(Probe.FCanvas,[ssLeft,ssAlt],Z.X,Z.Y);
      Check(not (Probe.FDialogueSnap.HasX or Probe.FDialogueSnap.HasY) and
        (Probe.FRenderer.BalloonTextBounds(Balloon).CenterPoint.Distance(Balloon.Bounds.CenterPoint)>1),'Alt releases center snapping without cumulative drift');
      Probe.MouseMove(Probe.FCanvas,[ssLeft],Z.X,Z.Y); Probe.MouseUp(Probe.FCanvas,mbLeft,[],Z.X,Z.Y);
      Paint; Check((GuidePixels=0) and not (Probe.FDialogueSnap.HasX or Probe.FDialogueSnap.HasY) and
        (Probe.FUndo.Count=History+1),'release hides guides and records one text-only move');
      After:=Project.Snapshot; Project.Save; Loaded:=CreateFixtureProject;
      try Loaded.Load(TPath.Combine(Project.Folder,'Project.json')); Check(Loaded.Snapshot=After,'snapped relative dialogue position survives save and reload'); finally Loaded.Free; end;
      Probe.Undo(nil); Check(Project.Snapshot=Before,'snapped dialogue undo restores exact position'); Probe.Redo(nil); Probe.Undo(nil);
    end;
    Balloon:=Probe.Page.Balloons[0]; Probe.FBalloonIndex:=0; Probe.FTool:=0; R:=Balloon.Bounds; A:=Screen(R.TopLeft);
    Probe.MouseDown(Probe.FCanvas,mbLeft,[],A.X,A.Y); Check((Probe.FTool=0) and (Probe.FDragHandle=1),'body resize handles keep priority over automatic dialogue selection'); Probe.CancelDrag;
  finally Probe.Free; Shot.Free; PNG.Free; end;
end;

procedure TPlacementTestsHelper.ManualTextFlowChecks;
var Probe: TComicTestForm; Project,Loaded: TComicProject; Balloon: TComicBalloon; Shot: Vcl.Graphics.TBitmap; Layout: TComicTextLayout;
  PNG: TPngImage; Vertical: Boolean; PPI: Integer; Anchor,Current: TPointF; Scale: Double; Original: TRectF; Before: string; Key: Word;
  JSON: TJSONObject; Pair: TJSONPair; CopyBalloon: TComicBalloon; Rejected: Boolean;
  procedure Paint;
  begin Probe.HandleNeeded; Shot.SetSize(Probe.ClientWidth,Probe.ClientHeight); Probe.PaintTo(Shot.Canvas,0,0); end;
  function FirstStop: TPointF;
  var Stop: TPoint;
  begin Stop:=Probe.FInlineText.Layout.CaretStop(0).Point;
    Result:=Probe.FInlineText.Preview.Bounds.CenterPoint+Probe.FInlineText.Preview.TextOffset+TPointF.Create(Stop.X,Stop.Y); end;
  procedure CheckCentered;
  var Preview: TComicBalloon; R: TRectF;
  begin
    Preview:=Probe.FInlineText.Preview; R:=Probe.FRenderer.BalloonTextBounds(Preview);
    Check((Preview.TextOffset=Balloon.TextOffset) and
      (R.CenterPoint.Distance(Preview.Bounds.CenterPoint+Preview.TextOffset)<1.5),
      'typing keeps automatic centering around the unchanged relative dialogue position');
  end;
begin
  Probe:=TComicTestForm.Create(nil); Shot:=Vcl.Graphics.TBitmap.Create; Layout:=TComicTextLayout.Create; PNG:=TPngImage.Create;
  try
    Project:=CreateFixtureProject; Project.Initialize('手動改行 fixture','1'); Probe.AdoptProject(Project,False);
    Balloon:=TComicBalloon.Create; Balloon.Bounds:=TRectF.Create(300,300,450,500); Probe.Page.Balloons.Add(Balloon); Probe.RefreshUI; Probe.FTabs.ActivePageIndex:=3;
    Check((Balloon.FontSize=24) and not Balloon.AutoWrap,'new balloons start with smaller text and manual newlines');
    for PPI in [96,144] do for Vertical in [False,True] do begin
      Balloon:=Probe.Page.Balloons[0]; Balloon.Text:=''; Balloon.Vertical:=Vertical; Balloon.TextOffset:=TPointF.Create(18,-12); Original:=Balloon.Bounds;
      Probe.Scaled:=True; Probe.ScaleForPPI(PPI); Probe.Scaled:=False; Probe.FBalloonIndex:=0; Probe.BeginTextInput(nil); Paint;
      Check(not Probe.FInlineText.CaretBounds.IsEmpty and Probe.FPageRect.Contains(Probe.FInlineText.CaretBounds.CenterPoint),
        'empty input displays its planned insertion caret inside the page');
      Anchor:=FirstStop; Check(Anchor.Distance(Balloon.Bounds.CenterPoint+Balloon.TextOffset)<0.01,'empty insertion caret starts at the relative dialogue center');
      Probe.FInlineText.Text:='漢'; Paint; Anchor:=FirstStop; CheckCentered;
      Probe.FInlineText.Text:=StringOfChar('漢',12); Paint; Current:=FirstStop;
      Check((Probe.FInlineText.Layout.LineCount=1) and (Anchor.Distance(Current)>24) and
        (Probe.FInlineText.Preview.FontSize=24) and (Balloon.Bounds=Original),'long inline input recenters without changing font size or wrapping at the body edge');
      CheckCentered;
      Probe.FInlineText.Input.DeliverComposition('',StringOfChar('文',8),4,True); Paint; CheckCentered;
      Check(Probe.FInlineText.Layout.LineCount=1,'IME preedit does not introduce automatic line or column breaks');
      Probe.FInlineText.Input.DeliverComposition('','',0,False);
      Key:=VK_RETURN; Probe.FInlineText.Command(Key,[]); Probe.FInlineText.Input.DeliverComposition('文','',0,False); Paint;
      Check(Probe.FInlineText.Layout.LineCount=2,'only Enter starts another line or column'); CheckCentered;
      Key:=VK_BACK; Probe.FInlineText.Command(Key,[]); Paint; CheckCentered;
      if (PPI=144) and Vertical then begin PNG.Assign(Shot); PNG.SaveToFile(TPath.Combine(TestFolder,'inline-manual-overflow-caret.png')); end;
      Before:=Project.Snapshot; Scale:=BuildBalloonTextLayout(Shot.Canvas,Probe.FInlineText.Preview,Layout); Current:=Probe.FInlineText.Preview.TextOffset;
      Probe.FinishInlineText(True); Balloon:=Probe.Page.Balloons[0];
      Check(not Balloon.AutoWrap and (Balloon.TextOffset=Current) and (Scale=1),'accepting input preserves manual layout and the exact displayed offset');
      BuildBalloonTextLayout(Shot.Canvas,Balloon,Layout); Check(Layout.LineCount=2,'completed renderer also uses explicit newlines only');
      Probe.Undo(nil); Check(Project.Snapshot=Before,'manual layout changes are one undo operation'); Probe.Redo(nil);
    end;
    Balloon:=Probe.Page.Balloons[0]; Balloon.AutoWrap:=True; Balloon.TextLayoutSize:=TSizeF.Create(100,120);
    Balloon.TextLayoutFontSize:=32; Balloon.FontSize:=47; Balloon.Text:='以前の折返しを持つ長いセリフを編集する';
    Before:=Project.Snapshot;
    Probe.FBalloonIndex:=0; Probe.BeginTextInput(nil); Paint;
    BuildBalloonTextLayout(Shot.Canvas,Probe.FInlineText.Preview,Layout); CheckCentered;
    Check(not Probe.FInlineText.Preview.AutoWrap and (Layout.LineCount=1),
      'editing old wrapped text preserves centered placement while switching to explicit newlines');
    Probe.FinishInlineText(False); Check(Project.Snapshot=Before,'cancel retains the old automatic wrapping and scale');
    Probe.FBalloonIndex:=0; Probe.BeginTextInput(nil); Probe.FInlineText.Text:=Probe.FInlineText.Text+'追記'; Probe.FinishInlineText(True);
    Check(not Balloon.AutoWrap and (Balloon.FontSize=47) and (Balloon.TextLayoutFontSize=32),
      'accepting manual editing preserves an existing glyph scaling basis');
    Project.Save; Loaded:=CreateFixtureProject;
    try Loaded.Load(TPath.Combine(Project.Folder,'Project.json')); Check(Loaded.Snapshot=Project.Snapshot,'manual wrapping origin and scale persist through save and reload'); finally Loaded.Free; end;
    JSON:=Balloon.Json; CopyBalloon:=TComicBalloon.Create;
    try
      Pair:=JSON.RemovePair('autoWrap'); Pair.Free; Pair:=JSON.RemovePair('fontSize'); Pair.Free; CopyBalloon.Read(JSON);
      Check(CopyBalloon.AutoWrap and (CopyBalloon.FontSize=40),'legacy files retain automatic wrapping and their historical default size');
    finally JSON.Free; CopyBalloon.Free; end;
    Before:=Project.Snapshot; Probe.FBalloonIndex:=0; Probe.BeginTextInput(nil);
    Probe.FInlineText.Text:='保存前に座標を検証'; Probe.FInlineText.Preview.TextOffset:=TPointF.Create(90001,0);
    Rejected:=False; try Probe.FinishInlineText(True); except Rejected:=True; end;
    Check(Rejected and Probe.InlineTextActive and (Project.Snapshot=Before),
      'out-of-range manual-layout offset is rejected before publishing a draft and retains the input buffer');
    Probe.FinishInlineText(False);
  finally Probe.Free; Shot.Free; Layout.Free; PNG.Free; end;
end;
procedure RunPlacementChecks(Host: TComicTestForm);
begin Host.PlacementChecks; end;
procedure RunDialogueRefinementChecks(Host: TComicTestForm);
begin Host.DialogueRefinementChecks; end;
procedure RunManualTextFlowChecks(Host: TComicTestForm);
begin Host.ManualTextFlowChecks; end;
end.
