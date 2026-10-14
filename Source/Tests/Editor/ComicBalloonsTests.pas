unit ComicBalloonsTests;

// 責務：本体・しっぽ・文字の複合配置と輪郭を検証し、保存・取消・Undoの整合を確認する。
interface
uses ComicTestSupport;
procedure RunTailChecks(Host: TComicTestForm);
procedure RunBalloonContourChecks(Host: TComicTestForm);
procedure RunTextPlacementChecks(Host: TComicTestForm);
procedure RunTextScaledWrappingChecks(Host: TComicTestForm);
implementation
uses Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, Winapi.Imm,
  System.SysUtils, System.Classes, System.Types, System.UITypes,
  System.Math, System.IOUtils, System.Generics.Collections, System.JSON,
  System.Hash, System.DateUtils, Vcl.Controls, Vcl.Forms,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Menus,
  Vcl.Dialogs, Vcl.Graphics, Vcl.Imaging.pngimage, ComicModel,
  ComicRender, ComicExport, ComicEditing, ComicIconButton,
  ComicTextLayout;
type
  TComicBalloonsTestsHelper = class helper for TComicTestForm
    procedure TailChecks;
    procedure BalloonContourChecks;
    procedure TextPlacementChecks;
    procedure TextScaledWrappingChecks;
  end;
procedure TComicBalloonsTestsHelper.TailChecks;
  var Probe: TComicTestForm; Project,Reloaded: TComicProject; Balloon,LegacyA,LegacyB: TComicBalloon;
    Panel: TComicPanel; Tail: TComicTail; ID1,ID2,Before,Text: string; History,K,X,Y,PPI: Integer;
    KeyValue: Word; Original: TComicBalloonTransform; R: TRectF; PointA,Sample: TPointF;
    Region: HRGN; J: TJSONObject; Pair: TJSONPair; Failed: Boolean; PNG: TPngImage;
    Reference,Shifted: TBitmap; Saved: Integer; Same: Boolean;
    procedure CaptureTail(const Name: string);
    begin
      Probe.UpdateIconState; Probe.HandleNeeded; B.SetSize(Probe.ClientWidth,Probe.ClientHeight); Probe.PaintTo(B.Canvas,0,0);
      PNG.Assign(B); PNG.SaveToFile(TPath.Combine(TestFolder,Name+'.png'));
    end;
    procedure Tool(Tag: Integer);
    var Button: TComicIconButton;
    begin
      for Button in Probe.FIconButtons do if (Button.Context=3) and (Button.Tag=Tag) and (Button.Role in [brTool,brTail]) then begin Button.Click; Exit; end;
    end;
    procedure Click(PX,PY: Single);
    begin
      X:=Probe.FPageRect.Left+Round(PX*Probe.FScale); Y:=Probe.FPageRect.Top+Round(PY*Probe.FScale);
      Probe.FCanvas.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(X,Y)); Probe.FCanvas.Perform(WM_LBUTTONUP,0,MakeLParam(X,Y));
    end;
    procedure SelectBalloon;
    begin
      Tool(0); R:=Probe.Page.Balloons[0].Bounds; Click(R.CenterPoint.X,R.CenterPoint.Y);
    end;
    procedure TailStateEqual(const Source: TComicBalloonTransform; const Target: TRectF; const Message: string);
    var I: Integer; SX,SY: Double;
    begin
      SX:=Target.Width/Source.Bounds.Width; SY:=Target.Height/Source.Bounds.Height;
      for I:=0 to High(Source.Tails) do begin Tail:=Probe.Page.Balloons[0].Tails[I];
        Check((Abs(Tail.Root.X-(Target.Left+(Source.Tails[I].Root.X-Source.Bounds.Left)*SX))<0.01) and
          (Abs(Tail.Root.Y-(Target.Top+(Source.Tails[I].Root.Y-Source.Bounds.Top)*SY))<0.01) and
          (Abs(Tail.Tip.X-(Target.Left+(Source.Tails[I].Tip.X-Source.Bounds.Left)*SX))<0.01) and
          (Abs(Tail.Tip.Y-(Target.Top+(Source.Tails[I].Tip.Y-Source.Bounds.Top)*SY))<0.01),Message+' '+IntToStr(I));
      end;
    end;
  begin
    Probe:=TComicTestForm.Create(nil); PNG:=TPngImage.Create; Reference:=TBitmap.Create; Shifted:=TBitmap.Create;
    try
      Project:=TComicProject.Create; Project.Initialize('複数しっぽ fixture','1'); Probe.AdoptProject(Project,False);
      Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(100,100,900,1200); Panel.ImageID:=Project.ImportImage(TPath.Combine(TestFolder,'reference.bmp'),'').ID;
      Probe.Page.Panels.Add(Panel);
      Balloon:=TComicBalloon.Create; Balloon.Bounds:=TRectF.Create(150,150,550,550); Balloon.PanelID:=Panel.ID; Balloon.Text:='複数のしっぽ';
      Probe.Page.Balloons.Add(Balloon); Probe.RefreshUI; Probe.FTabs.ActivePageIndex:=3; Probe.TabChanged(nil); Probe.FBalloonIndex:=0; Probe.LoadBalloonControls(Balloon);
      CaptureTail('tail-empty'); Before:=Project.Snapshot; History:=Probe.FUndo.Count;
      Tool(7); Click(350,350); Check(Probe.FFirst and (Project.Snapshot=Before) and (Probe.FUndo.Count=History),
        Format('first tail click only previews a root without changing project or history: tool=%d first=%s balloon=%d same=%s undo=%d/%d',
          [Probe.FTool,BoolToStr(Probe.FFirst,True),Probe.FBalloonIndex,BoolToStr(Project.Snapshot=Before,True),Probe.FUndo.Count,History]));
      KeyValue:=VK_ESCAPE; Probe.Key(Probe,KeyValue,[]);
      Check(not Probe.FFirst and (Project.Snapshot=Before),'escape cancels pending tail creation');
      Tool(7); Click(50,50); Check(not Probe.FFirst and (Project.Snapshot=Before),'tail creation refuses a root outside its selected body');
      Click(350,350); Click(200,750); ID1:=Probe.Page.Balloons[0].Tails[0].ID;
      Check((Probe.Page.Balloons[0].Tails.Count=1) and (Probe.Page.Balloons[0].Tails[0].Kind=ctTriangle) and (Probe.FUndo.Count=History+1),
        'two clicks create one owned triangular tail as one undo operation');
      Tool(11); Click(450,450); Click(850,600); ID2:=Probe.Page.Balloons[0].Tails[1].ID;
      Check((Probe.Page.Balloons[0].Tails.Count=2) and (Probe.Page.Balloons[0].Tails[1].Kind=ctThought),
        'thought tail appends without replacing the existing triangular tail');
      Region:=TailRegion(Probe.Page.Balloons[0].Tails[1],Point(0,0),1);
      try Check(PtInRegion(Region,583,500) and PtInRegion(Region,717,550) and PtInRegion(Region,850,600) and not PtInRegion(Region,650,525),
        'thought tail is composed of three separate decreasing circles'); finally Winapi.Windows.DeleteObject(Region); end;
      Probe.Undo(nil); Check((Probe.Page.Balloons[0].Tails.Count=1) and (Probe.Page.Balloons[0].Tails[0].ID=ID1),'tail addition undo retains previous tail identity');
      Probe.Redo(nil); Check((Probe.Page.Balloons[0].Tails.Count=2) and (Probe.Page.Balloons[0].Tails[1].ID=ID2),'tail addition redo restores both owned identities');
      SelectBalloon; Before:=Project.Snapshot; Probe.FTailIndex:=0; Tool(12); Probe.FTailIndex:=0;
      for K:=1 to 3 do begin
        Tail:=Probe.Page.Balloons[0].Tails[0]; PointA:=Tail.Handles[K-1];
        X:=Probe.FPageRect.Left+Round(PointA.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(PointA.Y*Probe.FScale);
        Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y);
        Check(Probe.FDragTailHandle=K,'tail edit handle '+IntToStr(K)+' selects root width or tip');
        Probe.MouseMove(Probe.FCanvas,[ssLeft],X+9,Y+7); Probe.MouseUp(Probe.FCanvas,mbLeft,[],X+9,Y+7);
        Check((Probe.Page.Balloons[0].Tails[0].ID=ID1) and (Probe.Page.Balloons[0].Tails[1].ID=ID2) and
          Probe.Page.Balloons[0].Tails[0].Valid,'tail handle '+IntToStr(K)+' edits geometry while retaining sibling and ownership');
        Probe.Undo(nil); Check(Project.Snapshot=Before,'tail handle '+IntToStr(K)+' undo restores the entire compound balloon');
        SelectBalloon; Tool(12); Probe.FTailIndex:=0;
      end;
      Tail:=Probe.Page.Balloons[0].Tails[0]; PointA:=Tail.Tip;
      X:=Probe.FPageRect.Left+Round(PointA.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(PointA.Y*Probe.FScale);
      Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y); Probe.MouseMove(Probe.FCanvas,[ssLeft],X+12,Y+9);
      KeyValue:=VK_ESCAPE; Probe.Key(Probe,KeyValue,[]);
      Check((Project.Snapshot=Before) and not Probe.FDragging,'escape cancels individual tail dragging without changing siblings');
      SelectBalloon; Tool(12); Probe.FTailIndex:=0; Probe.DeleteTail(nil);
      Check((Probe.Page.Balloons[0].Tails.Count=1) and (Probe.Page.Balloons[0].Tails[0].ID=ID2) and (Probe.Page.Balloons.Count=1),
        'individual tail deletion keeps the other tail body and text');
      Probe.Undo(nil); Check(Project.Snapshot=Before,'individual tail deletion undo restores stable identities');
      SelectBalloon; Original:=Probe.Page.Balloons[0].CaptureTransform; R:=Original.Bounds;
      X:=Probe.FPageRect.Left+Round(R.CenterPoint.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(R.CenterPoint.Y*Probe.FScale);
      Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y); Probe.MouseMove(Probe.FCanvas,[ssLeft],X+20,Y+12); Probe.MouseUp(Probe.FCanvas,mbLeft,[],X+20,Y+12);
      TailStateEqual(Original,Probe.Page.Balloons[0].Bounds,'body move carries every owned tail root and tip');
      Probe.Undo(nil); Check(Project.Snapshot=Before,'body move undo restores all owned components');
      SelectBalloon; Original:=Probe.Page.Balloons[0].CaptureTransform; R:=Original.Bounds;
      X:=Probe.FPageRect.Left+Round(R.Right*Probe.FScale); Y:=Probe.FPageRect.Top+Round(R.Bottom*Probe.FScale);
      Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y); Probe.MouseMove(Probe.FCanvas,[ssLeft],X+35,Y+20); Probe.MouseUp(Probe.FCanvas,mbLeft,[],X+35,Y+20);
      TailStateEqual(Original,Probe.Page.Balloons[0].Bounds,'body resize carries every owned tail root and tip');
      Check((Probe.Page.Balloons[0].FontSize>Original.FontSize) and (Probe.Page.Balloons[0].BorderWidth=3) and
        (Probe.FFont.Text=IntToStr(Probe.Page.Balloons[0].FontSize)),'body resize scales text while retaining output-pixel border width and matching controls');
      Project.Save; Reloaded:=TComicProject.Create;
      try Reloaded.Load(TPath.Combine(Project.Folder,'Project.json'));
        Check((Reloaded.Snapshot=Project.Snapshot) and (Reloaded.Pages[0].Balloons[0].Tails.Count=2),'multiple triangular and thought tails save and reload with exact geometry');
      finally Reloaded.Free; end;
      Probe.Undo(nil); Check(Project.Snapshot=Before,'compound balloon resize undo restores original font and tails');
      SelectBalloon; Balloon:=Probe.Page.Balloons[0]; Original:=Balloon.CaptureTransform; R:=Original.Bounds; R.Offset(70,40);
      R.Right:=R.Left+Original.Bounds.Width*1.3; R.Bottom:=R.Top+Original.Bounds.Height*1.15;
      Check(Balloon.ApplyTransform(Original,R),'compound balloon model applies independent axis scales');
      Probe.LoadBalloonControls(Balloon); Probe.FFillColor:=clYellow; Probe.FBorderColor:=clNavy; Probe.FBorderWidth.ItemIndex:=Probe.FBorderWidth.Items.IndexOf('4'); Probe.ApplyText(nil);
      Check((Balloon.FillColor=clYellow) and (Balloon.BorderColor=clNavy) and (Balloon.BorderWidth=4),'balloon appearance applies fill border color and fixed pixel width');
      Reference.SetSize(600,850); Shifted.SetSize(750,950);
      FRenderer.Draw(Reference.Canvas,Project,Probe.Page,Rect(0,0,600,850),False); PNG.Assign(Reference); PNG.SaveToFile(TPath.Combine(TestFolder,'tails-composite.png'));
      Saved:=SaveDC(Shifted.Canvas.Handle);
      try SetViewportOrgEx(Shifted.Canvas.Handle,75,50,nil); FRenderer.Draw(Shifted.Canvas,Project,Probe.Page,Rect(0,0,600,850),False);
      finally RestoreDC(Shifted.Canvas.Handle,Saved); Shifted.Canvas.Refresh; end;
      Same:=True; for X:=0 to 599 do for Y:=0 to 849 do if Reference.Canvas.Pixels[X,Y]<>Shifted.Canvas.Pixels[X+75,Y+50] then Same:=False;
      Check(Same,'compound tail unions circles text and fixed borders match under translated DC rendering');
      Tail:=Balloon.Tails[1]; X:=Round(Tail.Tip.X/2); Y:=Round(Tail.Tip.Y/2);
      Check(Reference.Canvas.Pixels[X,Y]=clYellow,'overflow thought tail paints its tip circle above neighboring space');
      Balloon.Overflow:=False; FRenderer.Draw(Reference.Canvas,Project,Probe.Page,Rect(0,0,600,850),False);
      Check(Reference.Canvas.Pixels[X,Y]=clWhite,'owner clipping applies to all tails as part of the compound balloon'); Balloon.Overflow:=True;
      Tail:=Balloon.Tails[0]; Sample:=TPointF.Create(Tail.Root.X+(Tail.Tip.X-Tail.Root.X)*0.8,Tail.Root.Y+(Tail.Tip.Y-Tail.Root.Y)*0.8);
      Balloon.Transparent:=True; FRenderer.Draw(Reference.Canvas,Project,Probe.Page,Rect(0,0,600,850),False);
      Check(Reference.Canvas.Pixels[Round(Sample.X/2),Round(Sample.Y/2)]<>clYellow,'text-only transparency omits every owned tail from completed PNG'); Balloon.Transparent:=False;
      J:=Balloon.Json; Pair:=J.RemovePair('tails'); Pair.Free; LegacyA:=TComicBalloon.Create; LegacyB:=TComicBalloon.Create;
      try LegacyA.Read(J); LegacyB.Read(J);
        Check((LegacyA.Tails.Count=1) and (LegacyA.Tails[0].ID=LegacyB.Tails[0].ID) and
          (LegacyA.TailX=Balloon.TailX) and (LegacyA.TailY=Balloon.TailY),'legacy single-tail data receives a stable default identity without losing its tip');
      finally LegacyA.Free; LegacyB.Free; J.Free; end;
      J:=Balloon.Tails[0].Json; Pair:=J.RemovePair('width'); Pair.Free; J.AddPair('width',TJSONNumber.Create(-1)); Tail:=TComicTail.Create;
      try Failed:=False; try Tail.Read(J); except Failed:=True; end; Check(Failed,'invalid tail width cannot be loaded'); finally Tail.Free; J.Free; end;
      Before:=Project.Snapshot; Original:=Balloon.CaptureTransform; R:=Original.Bounds; R.Left:=NaN;
      Check(not Balloon.ApplyTransform(Original,R) and (Project.Snapshot=Before),'invalid compound target cannot partially mutate tails body or font');
      for PPI in [96,144] do begin
        Probe.Scaled:=True; Probe.ScaleForPPI(PPI); Probe.Scaled:=False; Probe.Width:=MulDiv(940,PPI,96); Probe.Height:=MulDiv(660,PPI,96); Probe.Realign;
        Probe.FBalloonIndex:=0; Tool(12); Probe.FTailIndex:=1; CaptureTail('tail-dpi'+IntToStr(PPI)+'-before');
        PointA:=Probe.Page.Balloons[0].Tails[1].Tip; X:=Probe.FPageRect.Left+Round(PointA.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(PointA.Y*Probe.FScale);
        History:=Probe.FUndo.Count; Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y);
        Check((Probe.FDragTailHandle=3) and (Probe.FTailIndex=1),'thought tip handle selects the correct owned tail at PPI '+IntToStr(PPI));
        Probe.MouseMove(Probe.FCanvas,[ssLeft],X-MulDiv(15,PPI,96),Y+MulDiv(12,PPI,96)); Probe.MouseUp(Probe.FCanvas,mbLeft,[],X-MulDiv(15,PPI,96),Y+MulDiv(12,PPI,96));
        Check((Probe.FUndo.Count=History+1) and Probe.Page.Balloons[0].Tails[1].Valid,'thought tip edit commits once at PPI '+IntToStr(PPI));
        CaptureTail('tail-dpi'+IntToStr(PPI)+'-after'); Probe.Undo(nil);
        Check(Project.Snapshot=Before,'DPI tail edit undo restores exact compound data '+IntToStr(PPI));
      end;
      Probe.FBalloonIndex:=0; Probe.FPanelIndex:=0; Text:=Probe.Page.Balloons[0].Text;
      Check(ExportSequence(Project,Probe.FRenderer,False)=1,'new multiple-tail scene exports to a complete PNG');
      Check(ExportSequence(Project,Probe.FRenderer,False)=0,'unchanged compound-tail scene reuses its PNG');
      Before:=Project.Snapshot; Probe.FTailIndex:=0; Probe.DeleteTail(nil);
      Check(ExportSequence(Project,Probe.FRenderer,False)=1,'individual tail deletion invalidates its page PNG');
      Probe.Undo(nil); Check((Probe.Page.Balloons[0].Tails.Count=2) and (Probe.Page.Balloons[0].Text=Text),'undo after tail export restores every original owned tail and text');
      Check(ExportSequence(Project,Probe.FRenderer,False)=1,'undo after tail export redraws the restored compound content safely');
    finally Shifted.Free; Reference.Free; PNG.Free; Probe.Free; end;
  end;

procedure RunTailChecks(Host: TComicTestForm);
begin Host.TailChecks; end;
procedure TComicBalloonsTestsHelper.BalloonContourChecks;
  const ShapeNames: array[0..2] of string = ('四角','楕円','角丸');
    ContourNames: array[1..3] of string = ('ギザギザ','波線','雲形');
  var Probe: TComicTestForm; Project,Reloaded: TComicProject; Balloon,Legacy: TComicBalloon;
    Panel: TComicPanel; Tail: TComicTail; Reference,Shifted: TBitmap;
    Shape,Kind,PPI,X,Y,Saved,History,Index: Integer; Body,Plain,Difference,Translated: HRGN;
    RegionBounds: TRect; Bounds: TRectF; Before,After,LabelText: string; Same,Failed: Boolean;
    J: TJSONObject; Pair: TJSONPair; Q,Outside: TPointF; KeyValue: Word;
    procedure SelectBalloon;
    begin Probe.FBalloonIndex:=0; Probe.FTool:=0; Probe.LoadBalloonControls(Probe.Page.Balloons[0]); Probe.UpdateIconState; end;
    procedure PaintProbe;
    begin Probe.HandleNeeded; B.SetSize(Probe.ClientWidth,Probe.ClientHeight); Probe.PaintTo(B.Canvas,0,0); end;
  begin
    Probe:=TComicTestForm.Create(nil); Reference:=TBitmap.Create; Shifted:=TBitmap.Create;
    try
      Project:=TComicProject.Create; Project.Initialize('吹き出し輪郭サンプル','1'); Project.Width:=900; Project.Height:=1050;
      Probe.AdoptProject(Project,False); Project.ImportImage(TPath.Combine(TestFolder,'reference.bmp'),'');
      Panel:=TComicPanel.Create; Panel.Bounds:=TRectF.Create(30,30,870,1020); Panel.ImageID:=Project.Assets[0].ID;
      Probe.Page.Panels.Add(Panel); Balloon:=TComicBalloon.Create; Balloon.Bounds:=TRectF.Create(200,250,650,650);
      Balloon.PanelID:=Panel.ID; Balloon.Text:='輪郭テスト'; Probe.Page.Balloons.Add(Balloon);
      Tail:=TComicTail.Create; Tail.Root:=Balloon.Bounds.CenterPoint; Tail.Tip:=TPointF.Create(780,800); Tail.Width:=120; Balloon.Tails.Add(Tail);
      Probe.RefreshUI; Probe.FTabs.ActivePageIndex:=3; Probe.TabChanged(nil); SelectBalloon;
      Reference.PixelFormat:=pf24bit; Reference.SetSize(450,525); Shifted.PixelFormat:=pf24bit; Shifted.SetSize(500,560);
      for Shape:=0 to 2 do for Kind:=1 to 3 do begin
        Balloon:=Probe.Page.Balloons[0]; Balloon.Shape:=Shape; Balloon.Contour:=TComicBalloonContour(Kind);
        LabelText:=Format('contour %d shape %d',[Kind,Shape]);
        Body:=BalloonBodyRegion(Balloon,Point(0,0),1); Plain:=ShapeRegion(Rect(200,250,650,650),Shape);
        Difference:=CreateRectRgn(0,0,0,0); Translated:=BalloonBodyRegion(Balloon,Point(23,17),1);
        try
          GetRgnBox(Body,RegionBounds);
          Check((RegionBounds.Width>300) and (RegionBounds.Height>300) and (RegionBounds.Left>=200) and
            (RegionBounds.Top>=250) and (RegionBounds.Right<=651) and (RegionBounds.Bottom<=651) and
            PtInRegion(Body,425,450),LabelText+' has a filled center and stays inside the editable body bounds');
          Check(CombineRgn(Difference,Plain,Body,RGN_XOR)=COMPLEXREGION,LabelText+' differs from its plain basic shape');
          OffsetRgn(Translated,-23,-17); Check(EqualRgn(Body,Translated),LabelText+' geometry is independent of canvas origin');
          Outside:=TPointF.Create(0,0);
          for X:=200 to 650 do for Y:=250 to 650 do
            if PtInRegion(Plain,X,Y) and not PtInRegion(Body,X,Y) then begin Outside:=TPointF.Create(X,Y); Break; end;
          Probe.FBalloonIndex:=-1;
          Check((Outside.X<>0) and (Probe.HitBalloon(Outside)=-1) and not Probe.InsideBalloonBody(Balloon,Outside) and
            (Probe.HitBalloon(Balloon.Bounds.CenterPoint)=0),LabelText+' selection and tail roots follow the visible contour');
        finally Winapi.Windows.DeleteObject(Translated); Winapi.Windows.DeleteObject(Difference);
          Winapi.Windows.DeleteObject(Plain); Winapi.Windows.DeleteObject(Body); end;
        FRenderer.Draw(Reference.Canvas,Project,Probe.Page,Rect(0,0,450,525),False);
        Saved:=SaveDC(Shifted.Canvas.Handle);
        try SetViewportOrgEx(Shifted.Canvas.Handle,23,17,nil); FRenderer.Draw(Shifted.Canvas,Project,Probe.Page,Rect(0,0,450,525),False);
        finally RestoreDC(Shifted.Canvas.Handle,Saved); Shifted.Canvas.Refresh; end;
        Same:=True;
        for Y:=0 to 524 do if not CompareMem(Reference.ScanLine[Y],
          Pointer(NativeUInt(Shifted.ScanLine[Y+17])+23*3),450*3) then Same:=False;
        if not Same then begin
          Reference.SaveToFile(TPath.Combine(TestFolder,'contour-reference.bmp'));
          Shifted.SaveToFile(TPath.Combine(TestFolder,'contour-translated.bmp'));
        end;
        Check(Same,LabelText+' body tails border and text match under translated DC rendering');
        // 本体中央へ接続したしっぽでも、合成領域の内側に余計な縁を出さないことを確認する。
        Check(Reference.Canvas.Pixels[215,240]=clWhite,LabelText+' merged tail has no internal border at its root');
        Before:=Project.Snapshot; Project.Save; Reloaded:=TComicProject.Create;
        try Reloaded.Load(TPath.Combine(Project.Folder,'Project.json'));
          Check(Reloaded.Snapshot=Before,LabelText+' saves and reloads without changing text or tail identity');
        finally Reloaded.Free; end;
        SelectBalloon; Before:=Project.Snapshot; History:=Probe.FUndo.Count;
        Probe.FContour.ItemIndex:=0; Probe.ApplyText(nil); After:=Project.Snapshot;
        Check((Probe.Page.Balloons[0].Contour=bcPlain) and (Probe.FUndo.Count=History+1),LabelText+' setting applies as one undo operation');
        Probe.Undo(nil); Check(Project.Snapshot=Before,LabelText+' undo restores the original compound balloon');
        Probe.Redo(nil); Check(Project.Snapshot=After,LabelText+' redo restores the chosen contour'); Probe.Undo(nil);
      end;
      Balloon:=Probe.Page.Balloons[0]; Balloon.Contour:=bcCloud;
      J:=Balloon.Json; Pair:=J.RemovePair('contour'); Pair.Free; Legacy:=TComicBalloon.Create;
      try Legacy.Read(J); Check(Legacy.Contour=bcPlain,'missing contour in existing version 3 data defaults to plain');
        for Index:=0 to 3 do begin
          Pair:=J.RemovePair('contour'); Pair.Free;
          case Index of
            0: J.AddPair('contour',TJSONNumber.Create(-1)); 1: J.AddPair('contour',TJSONNumber.Create(4));
            2: J.AddPair('contour',TJSONNumber.Create(1.5)); 3: J.AddPair('contour',TJSONString.Create('cloud'));
          end;
          Failed:=False; try Legacy.Read(J); except Failed:=True; end;
          Check(Failed,'invalid contour is rejected '+IntToStr(Index));
        end;
      finally Legacy.Free; J.Free; end;
      // 3種類の輪郭がドラッグ・拡縮・取消でも複合オブジェクトの関係を保つことを確認する。
      for PPI in [96,144] do for Kind:=1 to 3 do begin
        Probe.Scaled:=True; Probe.ScaleForPPI(PPI); Probe.Scaled:=False;
        Probe.Width:=MulDiv(940,PPI,96); Probe.Height:=MulDiv(660,PPI,96); Probe.Realign;
        Balloon:=Probe.Page.Balloons[0]; Balloon.Contour:=TComicBalloonContour(Kind); SelectBalloon; PaintProbe;
        Before:=Project.Snapshot; Bounds:=Balloon.Bounds; Q:=Bounds.BottomRight;
        X:=Probe.FPageRect.Left+Round(Q.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(Q.Y*Probe.FScale);
        Probe.FCanvas.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(X,Y));
        Probe.FCanvas.Perform(WM_MOUSEMOVE,MK_LBUTTON,MakeLParam(X+20,Y+15));
        Probe.FCanvas.Perform(WM_LBUTTONUP,0,MakeLParam(X+20,Y+15));
        Balloon:=Probe.Page.Balloons[0]; LabelText:=Format('contour %d at PPI %d',[Kind,PPI]);
        Check((Balloon.Contour=TComicBalloonContour(Kind)) and (Balloon.Bounds.Width>Bounds.Width) and
          (Balloon.BorderWidth=3) and (Balloon.Tails.Count=1),LabelText+' resize preserves contour and fixed border with its owned tail');
        Probe.Undo(nil); Check(Project.Snapshot=Before,LabelText+' resize undo restores all compound data');
        SelectBalloon; PaintProbe; Q:=Probe.Page.Balloons[0].Bounds.CenterPoint;
        X:=Probe.FPageRect.Left+Round(Q.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(Q.Y*Probe.FScale);
        Probe.FCanvas.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(X,Y));
        Probe.FCanvas.Perform(WM_MOUSEMOVE,MK_LBUTTON,MakeLParam(X+20,Y+15));
        KeyValue:=VK_ESCAPE; Probe.Key(Probe,KeyValue,[]);
        Check((Project.Snapshot=Before) and not Probe.FDragging,LabelText+' escape cancels the entire compound move');
        TScrollBox(Probe.FContour.Parent).ScrollInView(Probe.FContour); PaintProbe;
        Check(Probe.FContour.ClientToScreen(Point(0,0)).Y>=Probe.FContour.Parent.ClientToScreen(Point(0,0)).Y,
          LabelText+' contour choice can be reached by scrolling the narrow settings panel');
      end;
      Balloon:=Probe.Page.Balloons[0]; Balloon.Contour:=bcCloud; Balloon.Text:=''; Balloon.FillColor:=clYellow;
      Balloon.Overflow:=True; Panel:=Probe.Page.Panels[0]; Panel.Bounds:=TRectF.Create(30,30,600,720);
      FRenderer.Draw(Reference.Canvas,Project,Probe.Page,Rect(0,0,450,525),False);
      Check(Reference.Canvas.Pixels[354,365]=clYellow,'contour and tail overflow together above the panel edge');
      Balloon.Overflow:=False; FRenderer.Draw(Reference.Canvas,Project,Probe.Page,Rect(0,0,450,525),False);
      Check(Reference.Canvas.Pixels[354,365]=clWhite,'owner clipping covers decorated body and tail together');
      Balloon.Overflow:=True; Balloon.Transparent:=True;
      FRenderer.Draw(Reference.Canvas,Project,Probe.Page,Rect(0,0,450,525),False);
      Check(Reference.Canvas.Pixels[354,365]=clWhite,'text-only output hides decorated body and every tail');
      Balloon.Transparent:=False; Balloon.FillColor:=clWhite; Balloon.Text:='雲形'; SelectBalloon;
      Check(ExportSequence(Project,Probe.FRenderer,False)=1,'decorated balloon first export renders its page');
      Check(ExportSequence(Project,Probe.FRenderer,False)=0,'unchanged decorated balloon reuses its PNG');
      Probe.FContour.ItemIndex:=1; Probe.ApplyText(nil);
      Check(ExportSequence(Project,Probe.FRenderer,False)=1,'contour edit invalidates the page PNG');
      Probe.Undo(nil); Check(ExportSequence(Project,Probe.FRenderer,False)=1,'undo after contour export redraws restored content');
      // 同じ検証画像を使い、形状と輪郭の違いだけを比較できる見本を残す。
      Probe.Page.Balloons.Clear; Panel:=Probe.Page.Panels[0]; Panel.Bounds:=TRectF.Create(30,30,870,1020);
      for Shape:=0 to 2 do for Kind:=1 to 3 do begin
        Balloon:=TComicBalloon.Create; Balloon.Shape:=Shape; Balloon.Contour:=TComicBalloonContour(Kind); Balloon.PanelID:=Panel.ID;
        X:=55+(Kind-1)*275; Y:=70+Shape*315; Balloon.Bounds:=TRectF.Create(X,Y,X+235,Y+230);
        Balloon.FontSize:=25; Balloon.Text:=ShapeNames[Shape]+sLineBreak+ContourNames[Kind]; Probe.Page.Balloons.Add(Balloon);
        Tail:=TComicTail.Create; Tail.Root:=Balloon.Bounds.CenterPoint; Tail.Tip:=TPointF.Create(X+200,Y+275); Tail.Width:=32; Balloon.Tails.Add(Tail);
      end;
      Project.Save; FRenderer.ExportPage(Project,Probe.Page,TPath.Combine(TestFolder,'balloon-contours.png'));
      AtomicWrite(TPath.Combine(TestFolder,'contour-sample-project.txt'),TPath.Combine(Project.Folder,'Project.json'));
      // 小さな表示でも有効なGDI領域となり、描画の都合でモデルを書き換えないことを確認する。
      Balloon:=Probe.Page.Balloons[0]; Before:=Project.Snapshot;
      Body:=BalloonBodyRegion(Balloon,Point(0,0),0.01);
      try Check(Body<>0,'tiny decorated balloon preview creates a valid region'); finally Winapi.Windows.DeleteObject(Body); end;
      Check(Project.Snapshot=Before,'previewing contours never mutates the saved model');
    finally Shifted.Free; Reference.Free; Probe.Free; end;
  end;

procedure RunBalloonContourChecks(Host: TComicTestForm);
begin Host.BalloonContourChecks; end;
procedure TComicBalloonsTestsHelper.TextPlacementChecks;
  var Probe: TComicTestForm; Project,Reloaded: TComicProject; Balloon: TComicBalloon; Tail: TComicTail;
    Before,TailBefore: string; BodyBounds,TextBounds: TRectF; PointA: TPointF; X,Y,K,PPI,Orientation,History: Integer;
    KeyValue: Word; PNG: TPngImage; Original: TComicBalloonTransform; Invalid: TRectF;
    procedure CaptureText(const Name: string);
    begin
      Probe.UpdateIconState; Probe.HandleNeeded; B.SetSize(Probe.ClientWidth,Probe.ClientHeight); Probe.PaintTo(B.Canvas,0,0);
      PNG.Assign(B); PNG.SaveToFile(TPath.Combine(TestFolder,Name+'.png'));
    end;
    procedure SelectText;
    var Button: TComicIconButton;
    begin
      Probe.FBalloonIndex:=0; Probe.LoadBalloonControls(Probe.Page.Balloons[0]); Probe.UpdateIconState;
      for Button in Probe.FIconButtons do if Button.Role=brTextPlacement then begin Button.Click; Exit; end;
    end;
  begin
    Probe:=TComicTestForm.Create(nil); PNG:=TPngImage.Create;
    try
      Project:=TComicProject.Create; Project.Initialize('文字配置 fixture','1'); Probe.AdoptProject(Project,False);
      Project.ImportImage(TPath.Combine(TestFolder,'reference.bmp'),'');
      Balloon:=TComicBalloon.Create; Balloon.Text:='文字位置'; Balloon.Bounds:=TRectF.Create(150,150,650,650);
      Tail:=TComicTail.Create; Tail.Root:=Balloon.Bounds.CenterPoint; Tail.Tip:=TPointF.Create(850,800); Balloon.Tails.Add(Tail);
      Probe.Page.Balloons.Add(Balloon); BodyBounds:=Balloon.Bounds; Probe.RefreshUI; Probe.FTabs.ActivePageIndex:=3; Probe.TabChanged(nil);
      SelectText; CaptureText('text-placement-centered'); TextBounds:=Probe.FRenderer.BalloonTextBounds(Balloon);
      Check((Abs(TextBounds.CenterPoint.X-BodyBounds.CenterPoint.X)<=1) and (Abs(TextBounds.CenterPoint.Y-BodyBounds.CenterPoint.Y)<=1),
        'default balloon text block is centered inside its body');
      Before:=Project.Snapshot; J:=Tail.Json; try TailBefore:=J.ToJSON; finally J.Free; end;
      PointA:=TextBounds.CenterPoint; X:=Probe.FPageRect.Left+Round(PointA.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(PointA.Y*Probe.FScale);
      Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y); Check(Probe.FDragHandle=0,'text interior starts a text-only movement');
      Probe.MouseMove(Probe.FCanvas,[ssLeft],X+15,Y+11); Probe.MouseUp(Probe.FCanvas,mbLeft,[],X+15,Y+11);
      J:=Probe.Page.Balloons[0].Tails[0].Json;
      try Check((Probe.Page.Balloons[0].Bounds=BodyBounds) and (J.ToJSON=TailBefore) and
        (Abs(Probe.Page.Balloons[0].TextOffset.X)>1) and (Abs(Probe.Page.Balloons[0].TextOffset.Y)>1),
        'text movement updates its relative offset while preserving body and tail geometry'); finally J.Free; end;
      Probe.Undo(nil); Check(Project.Snapshot=Before,'text placement undo restores the compound balloon in one operation');
      for K:=1 to 8 do begin
        SelectText; TextBounds:=Probe.FRenderer.BalloonTextBounds(Probe.Page.Balloons[0]); PointA:=EditHandles(TextBounds)[K-1];
        X:=Probe.FPageRect.Left+Round(PointA.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(PointA.Y*Probe.FScale);
        Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y); Check(Probe.FDragHandle=K,'text outer handle '+IntToStr(K)+' is selectable');
        Probe.MouseMove(Probe.FCanvas,[ssLeft],X+12,Y+8); Probe.MouseUp(Probe.FCanvas,mbLeft,[],X+12,Y+8);
        Check((Probe.Page.Balloons[0].Bounds=BodyBounds) and (Probe.Page.Balloons[0].FontSize<>40) and
          (Probe.FFont.Text=IntToStr(Probe.Page.Balloons[0].FontSize)), 'text handle '+IntToStr(K)+' scales glyphs without resizing the body');
        Probe.Undo(nil); Check(Project.Snapshot=Before,'text handle '+IntToStr(K)+' undo restores size and placement');
      end;
      SelectText; TextBounds:=Probe.FRenderer.BalloonTextBounds(Probe.Page.Balloons[0]); PointA:=TextBounds.CenterPoint;
      X:=Probe.FPageRect.Left+Round(PointA.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(PointA.Y*Probe.FScale);
      History:=Probe.FUndo.Count; Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y); Probe.MouseMove(Probe.FCanvas,[ssLeft],X+20,Y+20);
      KeyValue:=VK_ESCAPE; Probe.Key(Probe,KeyValue,[]);
      Check((Project.Snapshot=Before) and (Probe.FUndo.Count=History),'escape cancels pending text movement without mutating the body');
      Probe.Page.Balloons[0].TextOffset:=TPointF.Create(40,-25); Original:=Probe.Page.Balloons[0].CaptureTransform;
      Invalid:=Original.Bounds; Invalid.Right:=Invalid.Left+Invalid.Width*1.5; Invalid.Bottom:=Invalid.Top+Invalid.Height*0.8;
      Check(Probe.Page.Balloons[0].ApplyTransform(Original,Invalid) and
        (Abs(Probe.Page.Balloons[0].TextOffset.X-60)<0.001) and (Abs(Probe.Page.Balloons[0].TextOffset.Y+20)<0.001),
        'whole balloon resize carries the text offset with independent axis ratios');
      Project.Save; Reloaded:=TComicProject.Create;
      try Reloaded.Load(TPath.Combine(Project.Folder,'Project.json')); Check(Reloaded.Snapshot=Project.Snapshot,'text placement and styled compound data survive save and reload');
      finally Reloaded.Free; end;
      Original:=Probe.Page.Balloons[0].CaptureTransform; Probe.Page.Balloons[0].TextOffset:=TPointF.Create(80000,0);
      Original:=Probe.Page.Balloons[0].CaptureTransform; Invalid:=Original.Bounds; Invalid.Right:=Invalid.Left+Invalid.Width*2; Before:=Project.Snapshot;
      Check(not Probe.Page.Balloons[0].ApplyTransform(Original,Invalid) and (Project.Snapshot=Before),'invalid scaled text offset rejects every compound component atomically');
      Probe.Page.Balloons[0].TextOffset:=TPointF.Create(15,12);
      for Orientation:=0 to 1 do for PPI in [96,144] do begin
        Probe.Page.Balloons[0].Vertical:=Orientation=1; Before:=Project.Snapshot;
        Probe.Scaled:=True; Probe.ScaleForPPI(PPI); Probe.Scaled:=False; Probe.Width:=MulDiv(940,PPI,96); Probe.Height:=MulDiv(660,PPI,96); Probe.Realign;
        SelectText; CaptureText('text-placement-'+IntToStr(Orientation)+'-dpi'+IntToStr(PPI)+'-before');
        TextBounds:=Probe.FRenderer.BalloonTextBounds(Probe.Page.Balloons[0]); PointA:=TextBounds.CenterPoint;
        X:=Probe.FPageRect.Left+Round(PointA.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(PointA.Y*Probe.FScale);
        History:=Probe.FUndo.Count; Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y);
        Probe.MouseMove(Probe.FCanvas,[ssLeft],X+MulDiv(12,PPI,96),Y+MulDiv(14,PPI,96)); Probe.MouseUp(Probe.FCanvas,mbLeft,[],X+MulDiv(12,PPI,96),Y+MulDiv(14,PPI,96));
        Check(Probe.FUndo.Count=History+1,'text placement commits once for orientation '+IntToStr(Orientation)+' at PPI '+IntToStr(PPI));
        CaptureText('text-placement-'+IntToStr(Orientation)+'-dpi'+IntToStr(PPI)+'-after'); Probe.Undo(nil);
        Check(Project.Snapshot=Before,'text DPI placement undo restores exact content '+IntToStr(Orientation)+' '+IntToStr(PPI));
      end;
    finally PNG.Free; Probe.Free; end;
  end;

procedure RunTextPlacementChecks(Host: TComicTestForm);
begin Host.TextPlacementChecks; end;
procedure TComicBalloonsTestsHelper.TextScaledWrappingChecks;
  var Probe: TComicTestForm; Project,Reloaded: TComicProject; Balloon: TComicBalloon; Layout: TComicTextLayout;
    Base,After,Before,Resized,LabelText: string; OldBounds,NewBounds: TRectF; P,Q: TPointF;
    K,Orientation,PPI,X,Y,DX,DY,History: Integer; Ratio,Scale: Double; KeyValue: Word; PNG: TPngImage;
    function LayoutSignature(Target: TComicBalloon): string;
    var Cell: TComicTextCell;
    begin
      Scale:=BuildBalloonTextLayout(B.Canvas,Target,Layout); Result:=IntToStr(Layout.LineCount)+'|';
      for Cell in Layout.Cells do Result:=Result+Format('%d,%d,%d,%d,%d,%d,%d;',[Cell.Index,Cell.Count,Cell.Line,
        Cell.Bounds.Left,Cell.Bounds.Top,Cell.Bounds.Right,Cell.Bounds.Bottom]);
    end;
  begin
    Probe:=TComicTestForm.Create(nil); Layout:=TComicTextLayout.Create; PNG:=TPngImage.Create;
    try
      Project:=TComicProject.Create; Project.Initialize('折返し拡縮 fixture','1'); Probe.AdoptProject(Project,False);
      Project.ImportImage(TPath.Combine(TestFolder,'reference.bmp'),''); Balloon:=TComicBalloon.Create;
      Balloon.Bounds:=TRectF.Create(350,400,650,760); Balloon.FontSize:=32;
      Balloon.Text:='長文の折返し12を保つ。ーABC「配置」と幅を確認する。'+
        '長文の折返し12を保つ。ーABC「配置」と幅を確認する。'+
        '長文の折返し12を保つ。ーABC「配置」と幅を確認する。';
      Project.Pages[0].Balloons.Add(Balloon); Probe.RefreshUI; Probe.FTabs.ActivePageIndex:=3; Probe.TabChanged(nil);
      for Orientation:=0 to 1 do for PPI in [96,144] do begin
        Balloon:=Probe.Page.Balloons[0]; Balloon.Vertical:=Orientation=1; Before:=Project.Snapshot;
        Probe.Scaled:=True; Probe.ScaleForPPI(PPI); Probe.Scaled:=False;
        Probe.Width:=MulDiv(940,PPI,96); Probe.Height:=MulDiv(660,PPI,96); Probe.Realign; Probe.HandleNeeded;
        B.SetSize(Probe.ClientWidth,Probe.ClientHeight); Probe.PaintTo(B.Canvas,0,0);
        Base:=LayoutSignature(Balloon); Check(Layout.LineCount>2,'long scaling fixture wraps into several lines or columns '+IntToStr(Orientation));
        for K:=1 to 8 do begin
          Balloon:=Probe.Page.Balloons[0]; Probe.FBalloonIndex:=0; Probe.LoadBalloonControls(Balloon); Probe.FTool:=13; Probe.UpdateIconState;
          OldBounds:=Probe.FRenderer.BalloonTextBounds(Balloon); P:=EditHandles(OldBounds)[K-1];
          X:=Probe.FPageRect.Left+Round(P.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(P.Y*Probe.FScale);
          DX:=0; DY:=0;
          case K of
            1: begin DX:=-20; DY:=-20; end; 2: DY:=-20;
            3: begin DX:=20; DY:=-20; end; 4: DX:=20;
            5: begin DX:=20; DY:=20; end; 6: DY:=20;
            7: begin DX:=-20; DY:=20; end; 8: DX:=-20;
          end;
          DX:=MulDiv(DX,PPI,96); DY:=MulDiv(DY,PPI,96); History:=Probe.FUndo.Count;
          Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y); Probe.MouseMove(Probe.FCanvas,[ssLeft],X+DX,Y+DY);
          Probe.MouseUp(Probe.FCanvas,mbLeft,[],X+DX,Y+DY); Balloon:=Probe.Page.Balloons[0];
          LabelText:=Format('long text %d PPI%d handle%d',[Orientation,PPI,K]);
          After:=LayoutSignature(Balloon); Ratio:=Balloon.FontSize/32; NewBounds:=Probe.FRenderer.BalloonTextBounds(Balloon);
          Check((After=Base) and (Scale=Ratio) and (Ratio>1) and (Balloon.TextLayoutFontSize=32),LabelText+' retains every wrap and cell while scaling');
          Check((Abs(NewBounds.Width/OldBounds.Width-Ratio)<0.0001) and (Abs(NewBounds.Height/OldBounds.Height-Ratio)<0.0001) and
            (Balloon.Bounds=TRectF.Create(350,400,650,760)),LabelText+' keeps the full block aspect ratio and body');
          Resized:=Project.Snapshot; Project.Save; Reloaded:=TComicProject.Create;
          try Reloaded.Load(TPath.Combine(Project.Folder,'Project.json'));
            Check((Reloaded.Snapshot=Resized) and (LayoutSignature(Reloaded.Pages[0].Balloons[0])=Base),LabelText+' saves and reloads its wrapping basis');
          finally Reloaded.Free; end;
          Check(Probe.FUndo.Count=History+1,LabelText+' commits once');
          if K=5 then begin
            B.SetSize(Probe.ClientWidth,Probe.ClientHeight); Probe.PaintTo(B.Canvas,0,0); PNG.Assign(B);
            PNG.SaveToFile(TPath.Combine(TestFolder,Format('text-scaled-wrapped-%d-%d.png',[Orientation,PPI])));
          end;
          Probe.Undo(nil); Check(Project.Snapshot=Before,LabelText+' undo restores automatic layout');
          Probe.Redo(nil); Check(Project.Snapshot=Resized,LabelText+' redo restores exact scaled geometry'); Probe.Undo(nil);
        end;
        Balloon:=Probe.Page.Balloons[0]; Probe.FBalloonIndex:=0; Probe.FTool:=13; OldBounds:=Probe.FRenderer.BalloonTextBounds(Balloon);
        Q:=EditHandles(OldBounds)[4]; X:=Probe.FPageRect.Left+Round(Q.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(Q.Y*Probe.FScale);
        History:=Probe.FUndo.Count; Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y); Probe.MouseMove(Probe.FCanvas,[ssLeft],X+30,Y+30);
        KeyValue:=VK_ESCAPE; Probe.Key(Probe,KeyValue,[]);
        Check((Project.Snapshot=Before) and (Probe.FUndo.Count=History),'cancelled long text scaling restores layout basis and history '+IntToStr(Orientation)+' '+IntToStr(PPI));
      end;
    finally PNG.Free; Layout.Free; Probe.Free; end;
  end;

procedure RunTextScaledWrappingChecks(Host: TComicTestForm);
begin Host.TextScaledWrappingChecks; end;
end.
