unit ComicTextTests;

// 責務：文字移動・IME受取・装飾・組版の回帰を検証する。実IME候補操作の代替とは扱わない。
interface
uses ComicTestSupport;
procedure RunTextNavigationChecks(Host: TComicTestForm);
procedure RunTextSessionChecks(Host: TComicTestForm);
procedure RunTextLayoutChecks(Host: TComicTestForm);
procedure RunFontStyleChecks(Host: TComicTestForm);
implementation
uses Winapi.Windows, Winapi.Messages, Winapi.ShellAPI, Winapi.Imm,
  System.SysUtils, System.Classes, System.Types, System.UITypes,
  System.Math, System.IOUtils, System.Generics.Collections, System.JSON,
  System.Hash, System.DateUtils, Vcl.Controls, Vcl.Forms,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls, Vcl.Menus,
  Vcl.Dialogs, Vcl.Graphics, Vcl.Imaging.pngimage, ComicModel,
  ComicTextInput, ComicTextLayout, WindowsImeController, ComicFontHistory;
type
  TComicTextTestsHelper = class helper for TComicTestForm
    procedure TextNavigationChecks;
    procedure TextSessionChecks;
    procedure TextLayoutChecks;
    procedure FontStyleChecks;
  end;
procedure TComicTextTestsHelper.TextNavigationChecks;
  var EditorDialog,NativeDialog: TComicTextDialog; KeyValue: Word; Text,Emoji,Joined,Before: string;
    Count,I,PPI,OldPPI: Integer; PNG: TPngImage; Stop: TComicCaretStop;
    Context,OriginalContext: HIMC; ImeState: TWindowsImeState; OriginalOpen,SessionOpen: Boolean; Conversion,Sentence: DWORD;
    procedure Command(Key: Word; Shift: TShiftState=[]);
    begin KeyValue:=Key; EditorDialog.Editor.Command(KeyValue,Shift); end;
    procedure CaptureText(const Name: string);
    begin
      EditorDialog.HandleNeeded; B.SetSize(EditorDialog.ClientWidth,EditorDialog.ClientHeight); EditorDialog.PaintTo(B.Canvas,0,0);
      PNG.Assign(B); PNG.SaveToFile(TPath.Combine(TestFolder,Name+'.png'));
    end;
  begin
    Before:=FProject.Snapshot; PNG:=TPngImage.Create;
    EditorDialog:=TComicTextDialog.CreateEditor(Self,'',False,True);
    try
      EditorDialog.Editor.Font.Name:='Consolas';
      EditorDialog.Editor.Text:='abcd'+#13#10+'xy'+#13#10+'12345';
      Command(VK_HOME,[ssCtrl]); Command(VK_RIGHT); Command(VK_RIGHT); Command(VK_RIGHT);
      Command(VK_DOWN); Check(EditorDialog.Editor.CaretIndex=8,'down arrow reaches the nearest position on a shorter visual line');
      Command(VK_UP); Check(EditorDialog.Editor.CaretIndex=3,'up arrow restores the preferred column after a short line');
      Command(VK_DOWN); Command(VK_DOWN); Check(EditorDialog.Editor.CaretIndex=13,'repeated line movement preserves preferred column');
      Command(VK_UP,[ssShift]); Check((EditorDialog.Editor.SelectionAnchor=13) and (EditorDialog.Editor.CaretIndex=8),
        'shift line movement extends selection without losing the anchor');
      Command(VK_HOME); Check(EditorDialog.Editor.CaretIndex=6,'home moves to the current visual-line start');
      Command(VK_END); Check(EditorDialog.Editor.CaretIndex=8,'end moves to the current visual-line end');
      EditorDialog.Editor.Text:='one two  three'; Command(VK_HOME,[ssCtrl]); Command(VK_RIGHT,[ssCtrl]);
      Check(EditorDialog.Editor.CaretIndex=4,'control right moves to the next word'); Command(VK_DELETE,[ssCtrl]);
      Check(EditorDialog.Editor.Text='one three','control delete removes the following word and spaces as one edit');
      Command(Ord('Z'),[ssCtrl]); Check((EditorDialog.Editor.Text='one two  three') and (EditorDialog.Editor.CaretIndex=4),
        'input undo restores text caret and selection'); Command(Ord('Y'),[ssCtrl]);
      Check(EditorDialog.Editor.Text='one three','input redo restores a word edit');
      EditorDialog.Editor.Input.Perform(WM_CHAR,Ord('日'),0); Command(Ord('Z'),[ssCtrl]);
      Check(EditorDialog.Editor.Text='one three','typing creates an independent input undo step');
      EditorDialog.Editor.Input.Perform(WM_CHAR,Ord('本'),0); Command(Ord('Y'),[ssCtrl]);
      Check(EditorDialog.Editor.Text='one 本three','new typing after input undo clears redo');
      Emoji:=WideChar($D83D)+WideChar($DE00); Joined:=WideChar($D83D)+WideChar($DC69)+WideChar($200D)+WideChar($D83D)+WideChar($DCBB);
      EditorDialog.Editor.Text:='A'+'か'+WideChar($3099)+Emoji+Joined+#13#10+'B';
      Command(VK_LEFT); Command(VK_LEFT); Command(VK_LEFT); Check(EditorDialog.Editor.CaretIndex=5,
        'caret treats a joined emoji sequence as one unit'); Command(VK_LEFT); Check(EditorDialog.Editor.CaretIndex=3,
        'caret keeps surrogate pairs intact with adjacent clusters'); Command(VK_BACK);
      Check(EditorDialog.Editor.Text='A'+Emoji+Joined+#13#10+'B','backspace deletes a kana and combining mark together');
      Command(Ord('Z'),[ssCtrl]); Check(EditorDialog.Editor.Text='A'+'か'+WideChar($3099)+Emoji+Joined+#13#10+'B',
        'input undo restores an entire combining cluster');
      EditorDialog.Editor.Text:=''; EditorDialog.Editor.Input.Perform(WM_CHAR,$D83D,0);
      Check(EditorDialog.Editor.Text='','high surrogate is buffered until its complete character arrives');
      EditorDialog.Editor.Input.Perform(WM_CHAR,$DE00,0);
      Check(EditorDialog.Editor.Text=Emoji,'paired WM_CHAR messages insert one complete character');
      Command(Ord('Z'),[ssCtrl]); Check(EditorDialog.Editor.Text='','one input undo removes the complete surrogate pair');
      EditorDialog.Editor.Input.Perform(WM_UNICHAR,$1F600,0);
      Check(EditorDialog.Editor.Text=Emoji,'WM_UNICHAR inserts a supplementary Unicode character intact');
      EditorDialog.Editor.Text:='AB'; Command(VK_HOME,[ssCtrl]); Command(VK_RIGHT,[ssShift]);
      EditorDialog.Editor.Input.DeliverComposition('','にほん',2,True);
      CaptureText('text-ime-preedit-horizontal');
      Check((EditorDialog.Editor.Text='AB') and EditorDialog.Editor.Composing and
        (EditorDialog.Editor.CompositionText='にほん') and (EditorDialog.Editor.CompositionCursor=2),
        'IME preedit replaces selected display text without mutating the edit buffer');
      Command(Ord('Z'),[ssCtrl]); Check(EditorDialog.Editor.Text='AB','input undo passes through while IME composition is active');
      EditorDialog.Editor.Vertical:=True; CaptureText('text-ime-preedit-vertical');
      Check(EditorDialog.Editor.CaretBounds.Width>EditorDialog.Editor.CaretBounds.Height,
        'vertical IME preedit uses column layout and a horizontal caret');
      EditorDialog.Editor.Input.DeliverComposition('日本','',0,False);
      Check(EditorDialog.Editor.Text='日本B','IME result replaces selection once as one committed string');
      Command(Ord('Z'),[ssCtrl]); Check((EditorDialog.Editor.Text='AB') and (EditorDialog.Editor.SelectionAnchor=0) and
        (EditorDialog.Editor.CaretIndex=1),'one input undo restores the selection before IME result insertion');
      Context:=ImmCreateContext; Check(Context<>0,'isolated Windows IME context can be created for API lifecycle checks');
      OriginalContext:=ImmAssociateContext(EditorDialog.Editor.Input.Handle,Context);
      try
        OriginalOpen:=ImmGetOpenStatus(Context); SuspendWindowsIme(EditorDialog.Editor.Input.Handle,ImeState);
        Check(ImeState.Valid and (ImeState.Context=Context) and (ImeState.WasOpen=OriginalOpen),
          'IME snapshot retains its actual context and previous open state');
        if ImeState.HasConversionMode then ImmSetConversionStatus(Context,ImeState.ConversionMode xor IME_CMODE_FULLSHAPE,ImeState.SentenceMode);
        ImmAssociateContext(EditorDialog.Editor.Input.Handle,0); RestoreWindowsIme(EditorDialog.Editor.Input.Handle,ImeState);
        Check(not ImeState.Valid and (ImmGetOpenStatus(Context)=OriginalOpen),
          'IME state restores even after the input receiver detaches its context');
        if ImeState.HasConversionMode then
          Check(ImmGetConversionStatus(Context,Conversion,Sentence) and (Conversion=ImeState.ConversionMode) and
            (Sentence=ImeState.SentenceMode),'isolated IME context restores its captured conversion and sentence modes');
      finally ImmAssociateContext(EditorDialog.Editor.Input.Handle,OriginalContext); ImmDestroyContext(Context); end;
      OriginalContext:=ImmGetContext(EditorDialog.Editor.Input.Handle);
      Check(OriginalContext<>0,'input receiver has an isolated process-default IME context before detachment');
      if OriginalContext<>0 then begin
        OriginalOpen:=ImmGetOpenStatus(OriginalContext); ImmReleaseContext(EditorDialog.Editor.Input.Handle,OriginalContext);
        ImmAssociateContext(EditorDialog.Editor.Input.Handle,0);
        try
          SuspendWindowsIme(EditorDialog.Editor.Input.Handle,ImeState);
          Check(ImeState.Valid and (ImeState.Context=OriginalContext) and (ImeState.WasOpen=OriginalOpen),
            'IME snapshot before re-entry captures state even while receiver context is detached');
          Context:=ImmGetContext(EditorDialog.Editor.Input.Handle);
          Check(Context=0,'capturing detached IME state keeps the inactive receiver detached');
          if Context<>0 then ImmReleaseContext(EditorDialog.Editor.Input.Handle,Context);
          RestoreWindowsIme(EditorDialog.Editor.Input.Handle,ImeState);
          Check(ImmGetOpenStatus(OriginalContext)=OriginalOpen,'detached receiver snapshot restores original default-context open state');
        finally ImmAssociateContext(EditorDialog.Editor.Input.Handle,OriginalContext); ImmSetOpenStatus(OriginalContext,OriginalOpen); end;
        EditorDialog.Editor.EndSession;
        try
          for I:=0 to 1 do begin
            ImmSetOpenStatus(OriginalContext,I<>0); SessionOpen:=ImmGetOpenStatus(OriginalContext);
            Lines.Add('INFO: IME API requestedOpen='+BoolToStr(I<>0,True)+' observedOpen='+BoolToStr(SessionOpen,True));
            ImmAssociateContext(EditorDialog.Editor.Input.Handle,0); EditorDialog.Editor.BeginSession(False);
            EditorDialog.Editor.Input.Perform(CM_ENTER,0,0); EditorDialog.Editor.Input.Perform(WM_SETFOCUS,0,0);
            Check(EditorDialog.Editor.SessionActive,'real session activates from detached IME context '+IntToStr(I));
            EditorDialog.Editor.Input.Perform(CM_EXIT,0,0); EditorDialog.Editor.Input.Perform(WM_KILLFOCUS,0,0);
            Check(ImmGetOpenStatus(OriginalContext)=SessionOpen,'input focus exit restores actual original open state '+IntToStr(I));
            EditorDialog.Editor.Input.Perform(CM_ENTER,0,0); EditorDialog.Editor.Input.Perform(WM_SETFOCUS,0,0);
            EditorDialog.Editor.EndSession;
            Check(not EditorDialog.Editor.SessionActive and (EditorDialog.Editor.Input.ImeMode=imDisable) and
              (ImmGetOpenStatus(OriginalContext)=SessionOpen),'session completion after focus re-entry restores IME state '+IntToStr(I));
            NativeDialog:=TComicTextDialog.CreateEditor(Self,'native modal 取消',I=1,False);
            try
              PostMessage(NativeDialog.Handle,WM_CLOSE,0,0);
              Check((NativeDialog.ShowModal=mrCancel) and (NativeDialog.Editor.Text='native modal 取消') and
                (FProject.Snapshot=Before),'native text dialog focus and close preserve cancelled text and project '+IntToStr(I));
            finally NativeDialog.Free; end;
            Check(ImmGetOpenStatus(OriginalContext)=SessionOpen,'native text dialog destruction restores its original IME open state '+IntToStr(I));
          end;
        finally
          EditorDialog.Editor.EndSession; ImmAssociateContext(EditorDialog.Editor.Input.Handle,OriginalContext);
          ImmSetOpenStatus(OriginalContext,OriginalOpen); EditorDialog.Editor.BeginSession(True);
        end;
      end;
      EditorDialog.Editor.Vertical:=True; EditorDialog.Editor.Text:='abcd'+#13#10+'xy'+#13#10+'12345';
      Command(VK_HOME,[ssCtrl]); Command(VK_DOWN); Command(VK_DOWN); Command(VK_DOWN); Command(VK_LEFT);
      Check(EditorDialog.Editor.CaretIndex=8,'vertical left arrow moves to the next column at the nearest height');
      Command(VK_RIGHT); Check(EditorDialog.Editor.CaretIndex=3,'vertical right arrow restores preferred height');
      Command(VK_UP); Check(EditorDialog.Editor.CaretIndex=2,'vertical up arrow moves to the previous text unit');
      Text:=''; for I:=1 to 160 do Text:=Text+'長い文字入力 '+IntToStr(I)+#13#10;
      OldPPI:=EditorDialog.CurrentPPI;
      for PPI in [96,144] do begin
        EditorDialog.Scaled:=True; EditorDialog.ScaleForPPI(PPI); EditorDialog.Scaled:=False;
        EditorDialog.ClientWidth:=MulDiv(680,PPI,96); EditorDialog.ClientHeight:=MulDiv(440,PPI,96); EditorDialog.Realign;
        EditorDialog.Editor.Vertical:=False; EditorDialog.Editor.Text:=Text; CaptureText('text-long-horizontal-'+IntToStr(PPI));
        Check((EditorDialog.Editor.ScrollPosition>0) and (EditorDialog.Editor.CaretBounds.Top>=0) and
          (EditorDialog.Editor.CaretBounds.Bottom<=EditorDialog.Editor.ClientHeight),
          'long horizontal input scrolls the caret into view at PPI '+IntToStr(PPI));
        Command(VK_HOME,[ssCtrl]); Check(EditorDialog.Editor.ScrollPosition=0,'document home returns horizontal scroll to start at PPI '+IntToStr(PPI));
        Count:=EditorDialog.Editor.Text.Length; Stop:=EditorDialog.Editor.Layout.CaretStop(0);
        EditorDialog.Editor.Perform(WM_LBUTTONDOWN,MK_LBUTTON,MakeLParam(Stop.Point.X+1,Stop.Point.Y+1));
        Check(EditorDialog.Editor.CaretIndex=0,'horizontal hit test uses the same layout as rendering at PPI '+IntToStr(PPI));
        Command(VK_END,[ssCtrl]); Check(EditorDialog.Editor.CaretIndex=Count,'document end retains the full long buffer at PPI '+IntToStr(PPI));
        EditorDialog.Editor.Vertical:=True; CaptureText('text-long-vertical-'+IntToStr(PPI));
        Check((EditorDialog.Editor.ScrollPosition>0) and (EditorDialog.Editor.CaretBounds.Left>=0) and
          (EditorDialog.Editor.CaretBounds.Right<=EditorDialog.Editor.ClientWidth),
          'long vertical input scrolls leftward columns into view at PPI '+IntToStr(PPI));
        Command(VK_HOME,[ssCtrl]); Check(EditorDialog.Editor.ScrollPosition=0,'document home returns vertical scroll to start at PPI '+IntToStr(PPI));
      end;
      EditorDialog.Scaled:=True; EditorDialog.ScaleForPPI(OldPPI); EditorDialog.Scaled:=False;
      Command(VK_ESCAPE);
      Check(FProject.Snapshot=Before,'navigation scrolling Unicode deletion and input undo leave project data unchanged on cancel');
    finally EditorDialog.Free; PNG.Free; end;
  end;

procedure RunTextNavigationChecks(Host: TComicTestForm);
begin Host.TextNavigationChecks; end;
procedure TComicTextTestsHelper.TextSessionChecks;
  var Dialog: TComicTextDialog; Before,NewText,Emoji: string; KeyValue: Word; OldUndo,OldRedo: TList<string>;
    OldPPI: Integer; OriginalScaled: Boolean; PPI,K: Integer; PNG: TPngImage;
    procedure Command(Key: Word; Shift: TShiftState=[]);
    begin KeyValue:=Key; Dialog.Editor.Command(KeyValue,Shift); end;
    procedure SaveEditor(const Name: string);
    begin
      Dialog.HandleNeeded; B.SetSize(Dialog.ClientWidth,Dialog.ClientHeight); Dialog.PaintTo(B.Canvas,0,0);
      PNG.Assign(B); PNG.SaveToFile(TPath.Combine(TestFolder,Name+'.png'));
    end;
  begin
    Before:=FProject.Snapshot; OldUndo:=FUndo; OldRedo:=FRedo;
    FUndo:=TList<string>.Create; FRedo:=TList<string>.Create; PNG:=TPngImage.Create;
    Emoji:=WideChar($D83D)+WideChar($DE00); NewText:='A'+Emoji+#13#10+'B';
    FTabs.ActivePageIndex:=3; TabChanged(nil); FBalloonIndex:=0; FPanelIndex:=0;
    try
      Dialog:=TComicTextDialog.CreateEditor(Self,Page.Balloons[0].Text,False,True);
      try
        Check(Dialog.Editor.SessionActive and (Dialog.Editor.Input.ImeMode=imOpen),'dedicated input session enables only its IME receiver');
        Dialog.Editor.Text:='A'+Emoji+#13#10+'B';
        Command(VK_LEFT); Check(Dialog.Editor.CaretIndex=5,'library caret moves before final character');
        Command(VK_LEFT); Check(Dialog.Editor.CaretIndex=3,'library caret crosses CRLF as one boundary');
        Command(VK_LEFT); Check(Dialog.Editor.CaretIndex=1,'library caret crosses surrogate pair without splitting');
        Command(VK_RIGHT,[ssShift]); Command(VK_BACK);
        Check(Dialog.Editor.Text='A'+#13#10+'B','selected surrogate pair deletes as a complete unit');
        Dialog.Editor.Text:=''; Dialog.Editor.Input.Perform(WM_CHAR,Ord('日'),0); Dialog.Editor.Input.Perform(WM_CHAR,Ord('本'),0);
        Check((Dialog.Editor.Text='日本') and (Dialog.Editor.Input.Text=''),'copied IME receiver WM_CHAR forwards committed text into external buffer');
        Dialog.Editor.Input.Perform(WM_IME_STARTCOMPOSITION,0,0);
        Check(Dialog.Editor.Composing,'IME start message activates pending composition state');
        Command(VK_RETURN,[ssCtrl]);
        Check((Dialog.ModalResult=0) and (Dialog.Editor.Text='日本'),'pending IME composition cannot commit whole dialog');
        KeyValue:=VK_RETURN; Dialog.KeyDown(KeyValue,[ssCtrl]);
        Check((KeyValue=VK_RETURN) and (Dialog.ModalResult=0),'dialog shortcut passes pending composition to IME receiver');
        Dialog.Editor.Input.Perform(WM_IME_ENDCOMPOSITION,0,0);
        Check(not Dialog.Editor.Composing,'IME end message clears pending composition state');
        Dialog.Editor.Text:=NewText; SaveEditor('text-horizontal-96');
        Check(Dialog.Editor.CaretBounds.Height>Dialog.Editor.CaretBounds.Width,'horizontal input preview uses a vertical pseudo caret');
        for K:=0 to Dialog.ComponentCount-1 do if (Dialog.Components[K] is TButton) and
          (Pos('取消',TButton(Dialog.Components[K]).Caption)>0) then Dialog.ActiveControl:=TWinControl(Dialog.Components[K]);
        KeyValue:=VK_ESCAPE; Dialog.KeyDown(KeyValue,[]); FinishTextDialog(Dialog);
        Check(KeyValue=0,'Esc cancels dedicated dialog while cancel button has focus');
        Check((Dialog.ModalResult=mrCancel) and (FProject.Snapshot=Before) and (FUndo.Count=0),
          'dedicated text cancel preserves balloon and undo history');
        Check(not Dialog.Editor.SessionActive and not Dialog.Editor.Input.Enabled and
          (Dialog.Editor.Input.ImeMode=imDisable),'closing input session disables receiver and ends composition');
      finally Dialog.Free; end;
      Dialog:=TComicTextDialog.CreateEditor(Self,Page.Balloons[0].Text,True,True);
      try
        Dialog.Editor.Text:=NewText; SaveEditor('text-vertical-96');
        Check(Dialog.Editor.CaretBounds.Width>Dialog.Editor.CaretBounds.Height,'vertical input preview uses the requested horizontal pseudo caret');
        OldPPI:=Dialog.CurrentPPI; OriginalScaled:=Dialog.Scaled;
        try
          for PPI in [96,144] do begin
            Dialog.Scaled:=True; Dialog.ScaleForPPI(PPI); Dialog.Scaled:=False;
            Dialog.ClientWidth:=MulDiv(680,PPI,96); Dialog.ClientHeight:=MulDiv(440,PPI,96); Dialog.Realign;
            SaveEditor('text-vertical-'+IntToStr(PPI));
            Check((Dialog.CurrentPPI=PPI) and (Dialog.Editor.CaretBounds.Width>Dialog.Editor.CaretBounds.Height),
              'vertical pseudo caret remains horizontal at VCL PPI '+IntToStr(PPI));
          end;
        finally
          Dialog.Scaled:=True; Dialog.ScaleForPPI(OldPPI);
          Dialog.ClientWidth:=MulDiv(680,OldPPI,96); Dialog.ClientHeight:=MulDiv(440,OldPPI,96); Dialog.Scaled:=OriginalScaled;
        end;
        Check(FProject.Snapshot=Before,'typing and DPI preview do not mutate the balloon before commit');
        for K:=0 to Dialog.ComponentCount-1 do if (Dialog.Components[K] is TButton) and
          (Pos('確定',TButton(Dialog.Components[K]).Caption)>0) then Dialog.ActiveControl:=TWinControl(Dialog.Components[K]);
        KeyValue:=VK_RETURN; Dialog.KeyDown(KeyValue,[ssCtrl]); FinishTextDialog(Dialog);
        Check(KeyValue=0,'Ctrl Enter commits dedicated dialog while accept button has focus');
        Check((Dialog.ModalResult=mrOK) and (Page.Balloons[0].Text=NewText) and (FUndo.Count=1),
          'dedicated text commit updates balloon as one undo operation');
        FProject.Save; Loaded:=TComicProject.Create;
        try Loaded.Load(TPath.Combine(FProject.Folder,'Project.json'));
          Check(Loaded.Pages[0].Balloons[0].Text=NewText,'committed Unicode and multiline buffer save and reload');
        finally Loaded.Free; end;
        Undo(nil); Check(Page.Balloons[0].Text='漫画を作ろう！','dedicated text undo restores previous balloon text');
        Redo(nil); Check(Page.Balloons[0].Text=NewText,'dedicated text redo restores committed Unicode text'); Undo(nil);
      finally Dialog.Free; end;
      Dialog:=TComicTextDialog.CreateEditor(Self,NewText,False,True);
      try
        Check(Dialog.Editor.Text=NewText,'dedicated text reopens existing multiline Unicode buffer');
        Command(VK_HOME,[ssCtrl]); Command(VK_DELETE);
        Check(Dialog.Editor.Text=Emoji+#13#10+'B','library delete at start preserves following surrogate pair');
        Command(VK_ESCAPE);
        Check(not Dialog.Visible,'all dedicated text checks remain hidden without focus transfer');
      finally Dialog.Free; end;
      Check(FProject.Snapshot=Before,'text session tests restore complete original project');
    finally
      PNG.Free; FUndo.Free; FRedo.Free; FUndo:=OldUndo; FRedo:=OldRedo;
      FText.Text:=Page.Balloons[0].Text; FTabs.ActivePageIndex:=0; TabChanged(nil); ActiveControl:=nil; RefreshUI;
    end;
  end;

procedure RunTextSessionChecks(Host: TComicTestForm);
begin Host.TextSessionChecks; end;
procedure TComicTextTestsHelper.TextLayoutChecks;
  var Layout: TComicTextLayout; Cell: TComicTextCell; Sample,Joined: string;
    Tcy,Rotated,Clustered,Same: Boolean; Clone: TComicProject; Balloon: TComicBalloon;
    Reference,Shifted: TBitmap; PNG: TPngImage; X,Y,Saved: Integer;
  begin
    Layout:=TComicTextLayout.Create; Reference:=TBitmap.Create; Shifted:=TBitmap.Create;
    Clone:=TComicProject.Create; PNG:=TPngImage.Create;
    try
      B.Canvas.Font.Name:='Yu Gothic'; B.Canvas.Font.Height:=-32;
      Joined:=WideChar($D83D)+WideChar($DC69)+WideChar($200D)+WideChar($D83D)+WideChar($DCBB);
      Sample:='「12月、かなーABC」'+'か'+WideChar($3099)+Joined;
      Layout.Build(B.Canvas,Sample,Rect(16,16,500,500),True); Tcy:=False; Rotated:=False; Clustered:=False;
      for Cell in Layout.Cells do begin
        if Copy(Sample,Cell.Index+1,Cell.Count)='12' then Tcy:=Cell.TateChuYoko and (Cell.Count=2);
        if Copy(Sample,Cell.Index+1,Cell.Count)='ー' then Rotated:=Cell.Rotate;
        if Copy(Sample,Cell.Index+1,Cell.Count)=Joined then Clustered:=Cell.Count=5;
      end;
      Check(Tcy,'vertical layout places a two-digit number in one upright cell');
      Check(Rotated,'vertical layout rotates the prolonged sound mark');
      Check(Clustered,'shared layout retains a joined supplementary emoji in one cell');
      Check(Layout.CaretStop(2).Index=2,'vertical two-digit cell retains an insertion position between its digits');
      Layout.Build(B.Canvas,'漢漢、字',Rect(0,0,200,Layout.Step*2),True);
      Check((Layout.Cells[2].Line=0) and (Layout.Cells[3].Line=1),'basic Japanese wrapping keeps closing punctuation with its previous column');
      Layout.Build(B.Canvas,'漢「字',Rect(0,0,200,Layout.Step*2),True);
      Check((Layout.Cells[1].Line=1) and (Layout.Cells[2].Line=1),'basic Japanese wrapping keeps an opening bracket with its following character');
      Clone.Folder:=FProject.Folder; Clone.Restore(FProject.Snapshot);
      Clone.Pages[0].Panels.Clear; Clone.Pages[0].Balloons.Clear;
      Balloon:=TComicBalloon.Create; Balloon.Text:=Sample+#13#10+'縦書き。35歳！'; Balloon.Vertical:=True;
      Balloon.Transparent:=True; Balloon.Overflow:=True; Balloon.Bounds:=TRectF.Create(100,100,950,1500);
      Clone.Pages[0].Balloons.Add(Balloon); Reference.SetSize(600,850); Shifted.SetSize(750,950);
      FRenderer.Draw(Reference.Canvas,Clone,Clone.Pages[0],Rect(0,0,600,850),False);
      Saved:=SaveDC(Shifted.Canvas.Handle);
      try SetViewportOrgEx(Shifted.Canvas.Handle,75,50,nil);
        FRenderer.Draw(Shifted.Canvas,Clone,Clone.Pages[0],Rect(0,0,600,850),False);
      finally RestoreDC(Shifted.Canvas.Handle,Saved); Shifted.Canvas.Refresh; end;
      Same:=True;
      for X:=0 to 599 do for Y:=0 to 849 do if Reference.Canvas.Pixels[X,Y]<>Shifted.Canvas.Pixels[X+75,Y+50] then Same:=False;
      PNG.Assign(Reference); PNG.SaveToFile(TPath.Combine(TestFolder,'text-shared-vertical.png'));
      PNG.Assign(Shifted); PNG.SaveToFile(TPath.Combine(TestFolder,'text-shared-vertical-shifted.png'));
      Check(Same,'vertical rotations and shared text layout render identically under a translated DC');
      PNG.Assign(Reference); PNG.SaveToFile(TPath.Combine(TestFolder,'text-shared-vertical.png'));
      Clone.Save; Loaded:=TComicProject.Create;
      try Loaded.Load(TPath.Combine(Clone.Folder,'Project.json'));
        Check(Loaded.Pages[0].Balloons[0].Text=Balloon.Text,'shared vertical layout text survives project save and reload');
      finally Loaded.Free; end;
      FProject.Save;
    finally PNG.Free; Clone.Free; Shifted.Free; Reference.Free; Layout.Free; end;
  end;

procedure RunTextLayoutChecks(Host: TComicTestForm);
begin Host.TextLayoutChecks; end;
procedure TComicTextTestsHelper.FontStyleChecks;
  var Probe: TComicTestForm; Project,Reloaded: TComicProject; Balloon: TComicBalloon; Dialog: TComicTextDialog;
    History,CopyHistory: TComicFontHistory; FontFile,Path,Before,Choices: string; OriginalBytes: TBytes;
    Existed,Failed: Boolean; Lock: THandle; I,X,Y,RedPixels: Integer; PNG: TPngImage; KeyValue: Word;
  begin
    FontFile:=TPath.Combine(DataRoot,'Presets\FontHistory.json'); Existed:=FileExists(FontFile);
    if Existed then OriginalBytes:=TFile.ReadAllBytes(FontFile);
    Probe:=TComicTestForm.Create(nil); History:=TComicFontHistory.Create; CopyHistory:=TComicFontHistory.Create; PNG:=TPngImage.Create;
    try
      Project:=TComicProject.Create; Project.Initialize('文字装飾 fixture','1'); Probe.AdoptProject(Project,False);
      Balloon:=TComicBalloon.Create; Balloon.Transparent:=True; Balloon.Bounds:=TRectF.Create(100,100,900,1300);
      Probe.Page.Balloons.Add(Balloon); Probe.RefreshUI; Probe.FTabs.ActivePageIndex:=3; Probe.TabChanged(nil); Probe.FBalloonIndex:=0;
      Probe.LoadBalloonControls(Balloon); Before:=Project.Snapshot; Choices:=Probe.FFontFamily.Items.Text;
      Probe.FFontFamily.ItemIndex:=Probe.FFontFamily.Items.IndexOf('Consolas');
      Check(Probe.FFontFamily.ItemIndex>=0,'font selector offers installed Consolas');
      Probe.FFontBold.Checked:=True; Probe.FFontItalic.Checked:=True; Probe.FFontUnderline.Checked:=True; Probe.FFontStrikeOut.Checked:=True;
      Probe.FTextColor:=clRed; Probe.FText.Text:='Style 12 日本語'; Probe.ApplyText(nil);
      Check((Probe.Page.Balloons[0].FontFamily='Consolas') and (Probe.Page.Balloons[0].FontColor=clRed) and
        (Probe.Page.Balloons[0].FontStyle=[fsBold,fsItalic,fsUnderline,fsStrikeOut]),
        'applying balloon text stores family color and uniform decorations together');
      Check(Probe.FFontFamily.Items.Text=Choices,'recording a used font keeps the open font-selector order unchanged');
      Probe.FontDropDown(nil);
      Check((Probe.FFontFamily.Items[0]='Consolas') and (Probe.FFontFamily.Text='Consolas'),
        'next font dropdown places usage history first while retaining current selection');
      Project.Save; Reloaded:=TComicProject.Create;
      try Reloaded.Load(TPath.Combine(Project.Folder,'Project.json'));
        Check((Reloaded.Pages[0].Balloons[0].FontFamily='Consolas') and (Reloaded.Pages[0].Balloons[0].FontColor=clRed) and
          (Reloaded.Pages[0].Balloons[0].FontStyle=[fsBold,fsItalic,fsUnderline,fsStrikeOut]),
          'balloon font family color and all decorations survive save and reload');
      finally Reloaded.Free; end;
      B.SetSize(600,850); FRenderer.Draw(B.Canvas,Project,Probe.Page,Rect(0,0,600,850),False); RedPixels:=0;
      for X:=0 to 599 do for Y:=0 to 849 do if B.Canvas.Pixels[X,Y]=clRed then Inc(RedPixels);
      Check(RedPixels>0,'completed page renderer uses the stored text color'); PNG.Assign(B); PNG.SaveToFile(TPath.Combine(TestFolder,'text-font-style.png'));
      Probe.Undo(nil); Check(Project.Snapshot=Before,'one undo restores original text and every font attribute');
      Probe.Redo(nil); Probe.FBalloonIndex:=0; Probe.LoadBalloonControls(Probe.Page.Balloons[0]);
      Dialog:=Probe.CreateBalloonTextDialog;
      try
        Check((Dialog.Editor.Font.Name='Consolas') and (Dialog.Editor.Font.Color=clRed) and
          (Dialog.Editor.Font.Style=[fsBold,fsItalic,fsUnderline,fsStrikeOut]),
          'dedicated input receives the selected balloon font color and decoration');
        Before:=Project.Snapshot; KeyValue:=VK_ESCAPE; Dialog.KeyDown(KeyValue,[]); Probe.FinishTextDialog(Dialog);
        Check(Project.Snapshot=Before,'canceling styled dedicated input preserves the balloon');
      finally Dialog.Free; end;
      Path:=TPath.Combine(TestFolder,'font-history.json'); History.Remember('Yu Gothic',Path); History.Remember('Consolas',Path); History.Remember('Yu Gothic',Path);
      Check((Length(History.Names)=2) and (History.Names[0]='Yu Gothic'),'font history moves reused families to the front without duplication');
      CopyHistory.Load(Path); Check(string.Join('|',CopyHistory.Names)=string.Join('|',History.Names),'font usage history survives UTF-8 save and reload');
      Before:=string.Join('|',History.Names); Lock:=CreateFile(PChar(Path),GENERIC_READ,FILE_SHARE_READ,nil,OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,0);
      Check(Lock<>INVALID_HANDLE_VALUE,'font-history publication failure can be injected with a file lock');
      try Failed:=False; try History.Remember('Segoe UI',Path); except Failed:=True; end;
        Check(Failed and (string.Join('|',History.Names)=Before),'failed font-history save restores the original usage order');
      finally CloseHandle(Lock); end;
      AtomicWrite(Path,'["valid-prefix",42]'); Failed:=False; try History.Load(Path); except Failed:=True; end;
      Check(Failed and (string.Join('|',History.Names)=Before),'malformed font history cannot replace valid state with a partial prefix');
      for I:=1 to 15 do History.Remember('font-'+IntToStr(I),Path);
      Check((Length(History.Names)=10) and (History.Names[0]='font-15'),'font usage history keeps only its ten most recent families');
    finally
      PNG.Free; CopyHistory.Free; History.Free; Probe.Free;
      if Existed then TFile.WriteAllBytes(FontFile,OriginalBytes) else if FileExists(FontFile) then TFile.Delete(FontFile);
    end;
  end;

procedure RunFontStyleChecks(Host: TComicTestForm);
begin Host.FontStyleChecks; end;
end.
