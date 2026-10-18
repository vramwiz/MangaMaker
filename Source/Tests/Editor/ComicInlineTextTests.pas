unit ComicInlineTextTests;

// 責務：ページ上の文字入力、IME保護、座標変換、確定・取消と保存失敗の原子性を検証する。
interface
uses ComicTestSupport;
procedure RunInlineTextChecks(Host: TComicTestForm);
implementation
uses Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, System.Types,
  System.Math, System.IOUtils, System.JSON, Vcl.Controls, Vcl.Graphics, Vcl.Imaging.pngimage,
  ComicModel, ComicTextLayout, ComicRender, ComicEditing;
type
  TInlineTextTests = class helper for TComicTestForm
    procedure InlineTextChecks;
  end;
procedure TInlineTextTests.InlineTextChecks;
var Probe: TComicTestForm; Project,Reloaded: TComicProject; Balloon: TComicBalloon;
  Image: Vcl.Graphics.TBitmap; PNG: TPngImage; Layout: TComicTextLayout;
  Before,Reply,Emoji: string; KeyValue: Word; Count: Integer;
  OldScaled,Failed: Boolean; Lock: THandle; Start,Finish: TPoint; Center: TPointF; S: Double;
  procedure PaintProbe;
  begin
    Probe.HandleNeeded; Image.SetSize(Probe.ClientWidth,Probe.ClientHeight);
    Probe.PaintTo(Image.Canvas,0,0);
  end;
  procedure Key(Key: Word; Shift: TShiftState=[]);
  begin KeyValue:=Key; Probe.Key(Probe,KeyValue,Shift); end;
  procedure Command(Key: Word; Shift: TShiftState=[]);
  begin KeyValue:=Key; Probe.FInlineText.Command(KeyValue,Shift); end;
  procedure SelectBalloon;
  begin Probe.FBalloonIndex:=0; Probe.FPanelIndex:=0; Probe.FTool:=0; Probe.ActiveControl:=Probe.FView; end;
  procedure BeginText(Vertical: Boolean);
  begin
    SelectBalloon; Probe.FTool:=14; Probe.FTextToolVertical:=Vertical;
    Probe.StartInlineText; PaintProbe;
  end;
  function ScreenStop(Index: Integer): TPoint;
  var P: TPoint;
  begin
    P:=Probe.FInlineText.Layout.CaretStop(Index).Point;
    Center:=Probe.FInlineText.Preview.Bounds.CenterPoint;
    Center.Offset(Probe.FInlineText.Preview.TextOffset.X,Probe.FInlineText.Preview.TextOffset.Y);
    Result:=Point(Probe.FPageRect.Left+Round((Center.X+P.X)*Probe.FScale),
      Probe.FPageRect.Top+Round((Center.Y+P.Y)*Probe.FScale));
  end;
  procedure ToolChecks;
  begin
    Project:=CreateFixtureProject; Project.Initialize('ページ上の文字入力 fixture','1');
    Project.ImportImage(TPath.Combine(TestFolder,'reference.bmp'),'');
    Probe.AdoptProject(Project,False); Probe.FTabs.ActivePageIndex:=3; Probe.TabChanged(nil); PaintProbe;
    Key(Ord('U')); Check((KeyValue=0) and (Probe.FTool=10),'U selects rectangular balloon');
    Start:=Point(Probe.FPageRect.Left+Round(200*Probe.FScale),Probe.FPageRect.Top+Round(200*Probe.FScale));
    Finish:=Point(Probe.FPageRect.Left+Round(750*Probe.FScale),Probe.FPageRect.Top+Round(900*Probe.FScale));
    Probe.MouseDown(Probe.FCanvas,mbLeft,[],Start.X,Start.Y);
    Probe.MouseMove(Probe.FCanvas,[ssLeft],Finish.X,Finish.Y); Probe.MouseUp(Probe.FCanvas,mbLeft,[],Finish.X,Finish.Y);
    Check((Probe.Page.Balloons.Count=1) and (Probe.Page.Balloons[0].Text='') and Probe.Page.Balloons[0].Vertical,
      'newly placed balloon starts empty and vertical');
    Key(Ord('U')); Check(Probe.FTool=5,'U cycles to ellipse');
    Key(Ord('U')); Check(Probe.FTool=6,'U cycles to rounded rectangle');
    Key(Ord('U'),[ssShift]); Check(Probe.FTool=5,'Shift U cycles shapes backwards');
    Key(Ord('S')); Check(Probe.FTool=0,'S selects selection tool');
    Key(Ord('P')); Check(Probe.FTool=7,'P selects triangle tail');
    Key(Ord('P')); Check(Probe.FTool=11,'P cycles to thought tail');
    Key(Ord('T')); Check((Probe.FTool=13) and Probe.FTextToolVertical,'first T selects vertical dialogue handles');
    Key(Ord('T')); Check(not Probe.FTextToolVertical,'second T arms horizontal text');
    Check(not Probe.Page.Balloons[0].Vertical and not Probe.InlineTextActive,'writing direction applies immediately without starting input');
    Key(Ord('S')); Key(Ord('T')); Check(Probe.FTextToolVertical,'returning to T defaults to vertical');
    Before:=Project.Snapshot; Count:=Probe.FUndo.Count;
  end;
  procedure CompositionChecks;
  begin
    Probe.MouseDown(Probe.FCanvas,mbLeft,[],Start.X+30,Start.Y+30);
    Probe.MouseUp(Probe.FCanvas,mbLeft,[],Start.X+30,Start.Y+30);
    Check(Probe.InlineTextActive and (Probe.FInlineText.Text=''),'clicking a balloon with text tool starts inline input');
    Check(not Probe.GlobalShortcutsAllowed,'inline input owns character keys and editing shortcuts');
    Key(Ord('S')); Check((KeyValue=Ord('S')) and (Probe.FTool=14),'S is not stolen from active text entry');
    Probe.FInlineText.Input.Perform(WM_CHAR,Ord('S'),0); Probe.FInlineText.Input.Perform(WM_CHAR,Ord('T'),0);
    Check(Probe.FInlineText.Text='ST','literal S and T are accepted during text editing');
    Check((Project.Snapshot=Before) and (Probe.FUndo.Count=Count),'inline typing changes only the preview');
    Probe.FInlineText.Input.DeliverComposition('','変換中',1,True); PaintProbe;
    Check(Probe.FInlineText.Composing and (Probe.FInlineText.Preview.Text='ST変換中'),'IME preedit appears in page preview');
    Command(VK_RETURN,[ssCtrl]); Check(Probe.InlineTextActive and (KeyValue=VK_RETURN),'IME confirmation does not accept the session');
    Command(VK_ESCAPE); Check(Probe.InlineTextActive and (KeyValue=VK_ESCAPE),'IME Escape does not cancel the session');
    Probe.FInlineText.Input.DeliverComposition('確定','',0,False);
    Check(Probe.FInlineText.Text='ST確定','IME result is inserted once');
    Command(VK_ESCAPE); Check(not Probe.InlineTextActive and (Project.Snapshot=Before) and
      (Probe.FUndo.Count=Count),'Escape cancels inline text and leaves project and undo unchanged');
  end;
  procedure CommitChecks;
  begin
    Emoji:=WideChar($D83D)+WideChar($DE00);
    BeginText(True); Probe.FInlineText.Input.Perform(WM_CHAR,Ord('日'),0);
    Probe.FInlineText.Input.Perform(WM_CHAR,Ord('本'),0); Command(VK_RETURN);
    Probe.FInlineText.Input.DeliverComposition(Emoji,'',0,False); PaintProbe;
    Check(Probe.FInlineText.Text='日本'+#13#10+Emoji,'inline entry supports Japanese newline and surrogate pair');
    Command(VK_BACK); Check(Probe.FInlineText.Text='日本'+#13#10,'Backspace deletes a whole surrogate pair');
    Command(Ord('Z'),[ssCtrl]); Check(Probe.FInlineText.Text='日本'+#13#10+Emoji,'inline Undo is independent of project Undo');
    Command(VK_RETURN,[ssCtrl]);
    Check(not Probe.InlineTextActive and (Probe.FUndo.Count=Count+1) and (Probe.Page.Balloons[0].Text='日本'+#13#10+Emoji),
      'Ctrl Enter commits text as one project Undo');
    Probe.Undo(nil);
    Check(Probe.Page.Balloons[0].Text='','project Undo restores empty balloon');
    Probe.Redo(nil); Check(Probe.Page.Balloons[0].Text='日本'+#13#10+Emoji,'project Redo restores entered text');
    Project.Save; Reloaded:=CreateFixtureProject;
    try Reloaded.Load(TPath.Combine(Project.Folder,'Project.json'));
      Check(Reloaded.Pages[0].Balloons[0].Text=Probe.Page.Balloons[0].Text,'inline text persists through save and reload');
    finally Reloaded.Free; end;
  end;
  procedure SelectionAndLayoutChecks;
  var PPI,Zoom,I: Integer;
  begin
    BeginText(False); Probe.FInlineText.Text:='abc'+#13#10+'日本語'; PaintProbe;
    Start:=ScreenStop(0); Finish:=ScreenStop(3);
    Probe.MouseDown(Probe.FCanvas,mbLeft,[],Start.X,Start.Y);
    Probe.MouseMove(Probe.FCanvas,[ssLeft],Finish.X,Finish.Y);
    Probe.MouseUp(Probe.FCanvas,mbLeft,[],Finish.X,Finish.Y);
    Check((Probe.FInlineText.SelectionAnchor=0) and (Probe.FInlineText.CaretIndex=3),
      Format('canvas drag selects text at the displayed caret stops: active=%s tool=%d anchor=%d caret=%d',
        [BoolToStr(Probe.InlineTextActive,True),Probe.FTool,Probe.FInlineText.SelectionAnchor,Probe.FInlineText.CaretIndex]));
    Command(VK_DELETE); Check(Probe.FInlineText.Text=#13#10+'日本語','Delete removes only the selected text');
    Command(Ord('Z'),[ssCtrl]); Check(Probe.FInlineText.Text='abc'+#13#10+'日本語','inline selection deletion can be undone');
    Probe.FInlineText.Text:='文字配置の確認'+#13#10+'二行目';
    OldScaled:=Probe.Scaled;
    for PPI in [96,144] do begin
      Probe.Scaled:=True; Probe.ScaleForPPI(PPI); Probe.Scaled:=False;
      for Zoom in [1,2] do begin
        Probe.FViewZoom:=Zoom; PaintProbe;
        Check(Probe.FInlineText.CaretBounds.Height>Probe.FInlineText.CaretBounds.Width,
          'horizontal inline caret is vertical at PPI '+IntToStr(PPI)+' zoom '+IntToStr(Zoom));
        S:=BuildBalloonTextLayout(Image.Canvas,Probe.FInlineText.Preview,Layout);
        Check((Abs(S-1)<0.0001) and (Layout.Cells.Count=Probe.FInlineText.Layout.Cells.Count),
          'inline edit and final rendering share text layout at PPI '+IntToStr(PPI)+' zoom '+IntToStr(Zoom));
        for I:=0 to Layout.Cells.Count-1 do
          Check(Layout.Cells[I].Bounds=Probe.FInlineText.Layout.Cells[I].Bounds,'inline glyph cell matches renderer '+IntToStr(I));
        PaintProbe; PNG.Assign(Image); PNG.SaveToFile(TPath.Combine(TestFolder,Format('inline-%d-%d.png',[PPI,Zoom])));
      end;
    end;
    Probe.Scaled:=OldScaled; Probe.FViewZoom:=1; Probe.FinishInlineText(False);
  end;
  procedure SaveFailureChecks;
  begin
    BeginText(True); PaintProbe;
    Check(Probe.FInlineText.CaretBounds.Width>Probe.FInlineText.CaretBounds.Height,'vertical inline caret is horizontal');
    Before:=Project.Snapshot; Count:=Probe.FUndo.Count; Probe.FInlineText.Text:='保存失敗後にも入力を保持';
    Lock:=CreateFile(PChar(TPath.Combine(Project.Folder,'Draft.json')),GENERIC_READ,0,nil,OPEN_EXISTING,0,0);
    Check(Lock<>INVALID_HANDLE_VALUE,'inline save-failure fixture locks its own draft');
    try
      Failed:=False; try Probe.FinishInlineText(True); except Failed:=True; end;
      Check(Failed and Probe.InlineTextActive and (Probe.FInlineText.Text='保存失敗後にも入力を保持') and
        (Project.Snapshot=Before) and (Probe.FUndo.Count=Count),'failed draft save preserves model undo and input buffer');
    finally CloseHandle(Lock); end;
    Probe.FinishInlineText(True);
    Check(not Probe.InlineTextActive and (Probe.Page.Balloons[0].Text='保存失敗後にも入力を保持') and
      (Probe.FUndo.Count=Count+1),'retry commits preserved inline text once');
  end;
  procedure NavigationChecks;
  var Vertical: Boolean; Along,Cross: Word;
  begin
    for Vertical in [False,True] do begin
      BeginText(Vertical); Probe.FInlineText.Text:='abcde'+#13#10+'x'+#13#10+'abcde';
      if Vertical then begin Along:=VK_DOWN; Cross:=VK_LEFT; end
      else begin Along:=VK_RIGHT; Cross:=VK_DOWN; end;
      Command(VK_HOME,[ssCtrl]); Command(Along); Command(Along); Command(VK_HOME);
      Check(Probe.FInlineText.CaretIndex=0,'inline Home finds line start with a centered negative origin');
      Command(VK_END); Check(Probe.FInlineText.CaretIndex=5,'inline End finds line end with a centered negative origin');
      Command(VK_HOME,[ssCtrl]); Command(Along); Command(Along); Command(Cross); Command(Cross);
      Check(Probe.FInlineText.CaretIndex=12,'inline line and column navigation retains a negative preferred position');
      Probe.FinishInlineText(False);
    end;
  end;
  procedure CompositionRenderingChecks;
  var Reference,Overlay: Vcl.Graphics.TBitmap; Vertical,Underline,Same: Boolean;
    PX,PY: Integer; A,B: PCardinal; Caret: TRect;
  begin
    Reference:=Vcl.Graphics.TBitmap.Create; Overlay:=Vcl.Graphics.TBitmap.Create;
    try
      Reference.PixelFormat:=pf32bit; Reference.SetSize(Probe.FCanvas.Width,Probe.FCanvas.Height);
      for Vertical in [False,True] do for Underline in [False,True] do begin
        if Underline then Include(Probe.Page.Balloons[0].FontStyle,fsUnderline)
        else Exclude(Probe.Page.Balloons[0].FontStyle,fsUnderline);
        BeginText(Vertical); Probe.FInlineText.Text:='';
        Probe.FInlineText.Input.DeliverComposition('','変換中',1,True); PaintProbe;
        Probe.FRenderer.Draw(Reference.Canvas,Project,Probe.Page,Probe.FPageRect,True,Probe.FInlineText.Preview);
        Overlay.Assign(Reference);
        Probe.FInlineText.DrawOverlay(Overlay.Canvas,Probe.FPageRect.TopLeft,Probe.FScale,Probe.FPageRect,Probe.Page);
        Caret:=Probe.FInlineText.CaretBounds; Same:=True;
        for PY:=0 to Reference.Height-1 do begin
          A:=Reference.ScanLine[PY]; B:=Overlay.ScanLine[PY];
          for PX:=0 to Reference.Width-1 do begin
            if not Caret.Contains(Point(PX,PY)) and (A^<>B^) then Same:=False;
            Inc(A); Inc(B);
          end;
        end;
        Check(Same,'inline composition adds no temporary underlines while preserving explicit font decoration');
        if Vertical and not Underline then begin
          PNG.Assign(Overlay); PNG.SaveToFile(TPath.Combine(TestFolder,'inline-preedit-without-extra-lines.png'));
        end;
        Probe.FInlineText.Input.DeliverComposition('','',0,False); Probe.FinishInlineText(False);
      end;
      Exclude(Probe.Page.Balloons[0].FontStyle,fsUnderline);
    finally Reference.Free; Overlay.Free; end;
  end;
  procedure LifecycleChecks;
  begin
    BeginText(False); Before:=Project.Snapshot;
    Probe.BridgeRequest('{"version":1,"action":"status"}',Reply);
    Check(Pos('"ok":true',Reply)>0,'bridge status remains readable during inline entry');
    Probe.BridgeRequest('{"version":1,"action":"create_asset","library":"images","projectId":"'+Project.ID+'","name":"拒否"}',Reply);
    Check((Pos('"ok":false',Reply)>0) and (Project.Snapshot=Before),'bridge mutations cannot conflict with an inline session');
    Probe.FInlineText.Text:='画面切替で確定'; Probe.FTabs.ActivePageIndex:=1; Probe.TabChanged(nil);
    Check(not Probe.InlineTextActive and (Probe.Page.Balloons[0].Text='画面切替で確定'),'mode change commits inline buffer before leaving');
    Probe.FTabs.ActivePageIndex:=3; SelectBalloon; Probe.EditBalloonText(nil);
    Check(Probe.InlineTextActive and not Probe.FInlineText.Vertical,'double click preserves existing writing direction');
    Probe.FinishInlineText(False); Check(Probe.FText.Text=Probe.Page.Balloons[0].Text,'fallback memo stays synchronized');
    Balloon:=Probe.Page.Balloons[0]; Check(Balloon.FontSize=24,'inline edit preserves the smaller default font size');
  end;
  procedure DialogueSelectionChecks;
  var P,Q: TPointF; R,AfterBounds: TRectF; K,Orientation,PPI,X,Y,DX,DY,N: Integer;
    Base,After: string; CharacterAxis,Same: Boolean; Cell: TComicTextCell;
    Widths: TArray<Integer>; LineCount: Integer;
  begin
    BeginText(True); Probe.FInlineText.Text:='枠を選ぶ'; PaintProbe;
    P:=TPointF.Create(Probe.Page.Balloons[0].Bounds.Left,Probe.Page.Balloons[0].Bounds.CenterPoint.Y);
    X:=Probe.FPageRect.Left+Round(P.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(P.Y*Probe.FScale);
    Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y); Probe.MouseUp(Probe.FCanvas,mbLeft,[],X,Y);
    Check(not Probe.InlineTextActive and (Probe.FTool=0) and (Probe.FBalloonIndex=0) and
      (Probe.Page.Balloons[0].Text='枠を選ぶ'),'clicking frame during input commits and selects body');
    Key(Ord('T')); Check((Probe.FTool=13) and not Probe.InlineTextActive,'T selects dialogue separately from body and input');
    Key(VK_RETURN); Check(Probe.InlineTextActive,'Enter starts input from dialogue selection'); Probe.FinishInlineText(False);
    for Orientation:=0 to 1 do for PPI in [96,144] do begin
      Balloon:=Probe.Page.Balloons[0]; Balloon.Vertical:=Orientation=1;
      Balloon.Text:='間隔12を確認する。'+#13#10+'次の行34も確認する。'; Balloon.ResetTextLayout;
      Balloon.CharacterSpacing:=1; Balloon.LineSpacing:=1; Balloon.TextOffset:=TPointF.Zero;
      Probe.LoadBalloonControls(Balloon); Probe.FTool:=13; Probe.FBalloonIndex:=0;
      Probe.Scaled:=True; Probe.ScaleForPPI(PPI); Probe.Scaled:=False; PaintProbe;
      Base:=Project.Snapshot;
      BuildBalloonTextLayout(Image.Canvas,Balloon,Layout); LineCount:=Layout.LineCount;
      SetLength(Widths,Layout.Cells.Count); for N:=0 to Layout.Cells.Count-1 do Widths[N]:=Layout.Cells[N].Bounds.Width;
      for K in [2,4,6,8] do begin
        Balloon:=Probe.Page.Balloons[0]; Probe.FTool:=13; Probe.FBalloonIndex:=0;
        R:=Probe.FRenderer.BalloonTextBounds(Balloon); P:=EditHandles(R)[K-1];
        X:=Probe.FPageRect.Left+Round(P.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(P.Y*Probe.FScale);
        Probe.MouseMove(Probe.FCanvas,[],X,Y);
        Check(Probe.FCanvas.Cursor<>crDefault,'dialogue spacing handle has resize cursor');
        DX:=0; DY:=0; case K of 2: DY:=-20; 4: DX:=20; 6: DY:=20; 8: DX:=-20; end;
        Count:=Probe.FUndo.Count; Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y);
        Check(Probe.FDragHandle=K,'dialogue side handle starts interval adjustment');
        Probe.MouseMove(Probe.FCanvas,[ssLeft],X+DX,Y+DY); Probe.MouseUp(Probe.FCanvas,mbLeft,[],X+DX,Y+DY);
        CharacterAxis:=((Orientation=1) and (K in [2,6])) or ((Orientation=0) and (K in [4,8]));
        Check((Balloon.FontSize=24) and ((Balloon.CharacterSpacing>1)=CharacterAxis) and
          ((Balloon.LineSpacing>1)=(not CharacterAxis)),'side handles change the appropriate interval while preserving font size');
        BuildBalloonTextLayout(Image.Canvas,Balloon,Layout);
        Check(Layout.LineCount=LineCount,'interval change preserves wrapping');
        Same:=Length(Widths)=Layout.Cells.Count;
        for N:=0 to Layout.Cells.Count-1 do if Layout.Cells[N].Bounds.Width<>Widths[N] then Same:=False;
        Check(Same,'interval change preserves every glyph width');
        AfterBounds:=Probe.FRenderer.BalloonTextBounds(Balloon);
        if K in [2,6] then Check((AfterBounds.Height>R.Height) and (Abs(AfterBounds.Width-R.Width)<1),
          'vertical side drag increases only vertical extent without distorting glyphs')
        else Check((AfterBounds.Width>R.Width) and (Abs(AfterBounds.Height-R.Height)<1),
          'horizontal side drag increases only horizontal extent without distorting glyphs');
        if K in [2,6] then begin
          if K=2 then Check(Abs(AfterBounds.Bottom-R.Bottom)<1,'top spacing handle anchors bottom')
          else Check(Abs(AfterBounds.Top-R.Top)<1,'bottom spacing handle anchors top');
        end else if K=4 then Check(Abs(AfterBounds.Left-R.Left)<1,'right spacing handle anchors left')
        else Check(Abs(AfterBounds.Right-R.Right)<1,'left spacing handle anchors right');
        After:=Project.Snapshot; Check(Probe.FUndo.Count=Count+1,'interval drag creates one undo');
        Project.Save; Reloaded:=CreateFixtureProject;
        try Reloaded.Load(TPath.Combine(Project.Folder,'Project.json')); Check(Reloaded.Snapshot=After,'intervals and offset survive save/reload');
        finally Reloaded.Free; end;
        Probe.Undo(nil); Check(Project.Snapshot=Base,'interval undo restores exact original');
        Probe.Redo(nil); Check(Project.Snapshot=After,'interval redo restores exact adjusted state'); Probe.Undo(nil);
      end;
      Balloon:=Probe.Page.Balloons[0]; Balloon.CharacterSpacing:=1.5; Balloon.LineSpacing:=1.8;
      BeginText(Orientation=1); PaintProbe;
      BuildBalloonTextLayout(Image.Canvas,Probe.FInlineText.Preview,Layout);
      Same:=Layout.Stops.Count=Probe.FInlineText.Layout.Stops.Count;
      for N:=0 to Layout.Stops.Count-1 do if Layout.Stops[N].Point<>Probe.FInlineText.Layout.Stops[N].Point then Same:=False;
      Check(Same,'all input caret positions share adjusted dialogue spacing');
      if Orientation=1 then for Cell in Layout.Cells do if Cell.TateChuYoko then
        Check(Layout.CaretStop(Cell.Index+1,Cell.Line).Point.Y=Cell.Bounds.Top+Layout.Step div 2,
          'every spaced two-digit vertical cell keeps its interior caret within the glyph');
      Probe.FinishInlineText(False);
      // 次のPPIでは同じ基準へ戻す。Undoで破棄されたオブジェクトを再利用しない。
      Balloon:=Probe.Page.Balloons[0]; Balloon.CharacterSpacing:=1; Balloon.LineSpacing:=1;
    end;
    Balloon:=Probe.Page.Balloons[0]; Probe.LoadBalloonControls(Balloon); Probe.FTool:=13;
    PaintProbe; PNG.Assign(Image); PNG.SaveToFile(TPath.Combine(TestFolder,'dialogue-selection-144.png'));
    R:=Probe.FRenderer.BalloonTextBounds(Balloon); Q:=R.CenterPoint;
    X:=Probe.FPageRect.Left+Round(Q.X*Probe.FScale); Y:=Probe.FPageRect.Top+Round(Q.Y*Probe.FScale);
    Probe.MouseDown(Probe.FCanvas,mbLeft,[],X,Y); Probe.MouseUp(Probe.FCanvas,mbLeft,[],X,Y);
    Check(Probe.InlineTextActive,'dialogue click without drag starts direct editing'); Probe.FinishInlineText(False);
  end;
  procedure ImmediateSettingsChecks;
  var Base,After: string; N: Integer;
  begin
    Balloon:=Probe.Page.Balloons[0]; SelectBalloon; Probe.LoadBalloonControls(Balloon);
    Base:=Project.Snapshot; Count:=Probe.FUndo.Count;
    Probe.LoadBalloonControls(Balloon); Check((Project.Snapshot=Base) and (Probe.FUndo.Count=Count),'selection loads controls without creating edits');
    Probe.FFontBold.Checked:=not Probe.FFontBold.Checked;
    Check((fsBold in Balloon.FontStyle) and (Probe.FUndo.Count=Count+1),'font checkbox applies immediately with one undo');
    After:=Project.Snapshot; Probe.Undo(nil); Check(Project.Snapshot=Base,'instant setting undo restores original');
    Probe.Redo(nil); Check(Project.Snapshot=After,'instant setting redo restores chosen style');
    Balloon:=Probe.Page.Balloons[0]; SelectBalloon; Probe.LoadBalloonControls(Balloon);
    N:=Probe.FFont.Items.IndexOf('48'); Probe.FFont.ItemIndex:=N; Probe.FFont.OnChange(Probe.FFont);
    Check(Balloon.FontSize=48,'font size selection applies immediately');
    Probe.FContour.ItemIndex:=1; Probe.FContour.OnChange(Probe.FContour); Check(Balloon.Contour=bcJagged,'contour selection applies immediately');
    Base:=Project.Snapshot; Count:=Probe.FUndo.Count; Probe.BalloonSettingsChanged(Probe.FContour);
    Check((Project.Snapshot=Base) and (Probe.FUndo.Count=Count),'unchanged setting does not create an undo');
    Probe.ActiveControl:=Probe.FText; Probe.MemoFocusChanged(nil); Base:=Project.Snapshot; Count:=Probe.FUndo.Count;
    Probe.FText.Text:='保険'; Probe.FText.Text:='保険のメモ';
    Check((Balloon.Text='保険のメモ') and (Probe.FUndo.Count=Count+1),'fallback memo updates live and groups a focus session into one undo');
    Probe.ActiveControl:=Probe.FView; Probe.Undo(nil); Check(Project.Snapshot=Base,'memo undo restores text from before the focus session');
    Balloon:=Probe.Page.Balloons[0]; SelectBalloon; Probe.LoadBalloonControls(Balloon); Base:=Project.Snapshot; Count:=Probe.FUndo.Count;
    Lock:=CreateFile(PChar(TPath.Combine(Project.Folder,'Draft.json')),GENERIC_READ,0,nil,OPEN_EXISTING,0,0);
    try
      Failed:=False; try Probe.FFontItalic.Checked:=not Probe.FFontItalic.Checked; except Failed:=True; end;
      Check(Failed and (Project.Snapshot=Base) and (Probe.FUndo.Count=Count),'instant setting save failure restores content and undo');
      Check(Probe.FFontItalic.Checked=(fsItalic in Balloon.FontStyle),'instant setting save failure restores its control');
    finally CloseHandle(Lock); end;
    PaintProbe; PNG.Assign(Image); PNG.SaveToFile(TPath.Combine(TestFolder,'dialogue-settings-live.png'));
  end;
  procedure SpacingCompatibilityChecks;
  var JSON: TJSONObject; CopyBalloon: TComicBalloon; Pair: TJSONPair; Value: Double;
  begin
    CopyBalloon:=TComicBalloon.Create; JSON:=Probe.Page.Balloons[0].Json;
    try
      Pair:=JSON.RemovePair('characterSpacing'); Pair.Free; Pair:=JSON.RemovePair('lineSpacing'); Pair.Free;
      CopyBalloon.Read(JSON); Check((CopyBalloon.CharacterSpacing=1) and (CopyBalloon.LineSpacing=1),
        'old balloon files without spacing load at the original intervals');
      for Value in TArray<Double>.Create(0,9) do begin
        JSON.AddPair('characterSpacing',TJSONNumber.Create(Value)); Failed:=False;
        try CopyBalloon.Read(JSON); except Failed:=True; end;
        Check(Failed,'invalid serialized character spacing is rejected'); Pair:=JSON.RemovePair('characterSpacing'); Pair.Free;
        JSON.AddPair('lineSpacing',TJSONNumber.Create(Value)); Failed:=False;
        try CopyBalloon.Read(JSON); except Failed:=True; end;
        Check(Failed,'invalid serialized line spacing is rejected'); Pair:=JSON.RemovePair('lineSpacing'); Pair.Free;
      end;
    finally JSON.Free; CopyBalloon.Free; end;
  end;
begin
  Probe:=TComicTestForm.Create(nil); Image:=Vcl.Graphics.TBitmap.Create;
  PNG:=TPngImage.Create; Layout:=TComicTextLayout.Create;
  try
    ToolChecks; CompositionChecks; CommitChecks; SelectionAndLayoutChecks; NavigationChecks;
    CompositionRenderingChecks; SaveFailureChecks; LifecycleChecks;
    DialogueSelectionChecks; ImmediateSettingsChecks; SpacingCompatibilityChecks;
  finally Probe.Free; Image.Free; PNG.Free; Layout.Free; end;
end;
procedure RunInlineTextChecks(Host: TComicTestForm);
var Path: string; Before: TBytes; Existed: Boolean;
begin
  Path:=TPath.Combine(DataRoot,'Presets\FontSize.json'); Existed:=FileExists(Path);
  if Existed then Before:=TFile.ReadAllBytes(Path);
  try Host.InlineTextChecks;
  finally
    if Existed then TFile.WriteAllBytes(Path,Before) else if FileExists(Path) then TFile.Delete(Path);
  end;
end;
end.
